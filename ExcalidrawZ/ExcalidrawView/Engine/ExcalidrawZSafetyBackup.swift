//
//  ExcalidrawZSafetyBackup.swift
//  ExcalidrawZ
//
//  ExcalidrawZ personal build: a safety net for canvas content that does not
//  depend on the normal save pipeline.
//
//  - Every `stateChanged` message arms a backup cycle *before* any of the
//    save pipeline's guards run.
//  - A cycle reads what is really on the canvas (`getCurrentFileSnapshot`,
//    which does not take part in autosave) and, when the elements changed,
//    writes a copy to `Application Support/SafetyBackups/<file>/`.
//  - For linked local files it also compares the canvas with the file on
//    disk. When the canvas has been stable for a while but the disk copy
//    still differs, the save pipeline has dropped the edits: warn the user.
//

import Foundation
import CryptoKit
import Logging

final class ExcalidrawZSafetyBackup {
    /// Delay between the first change of a burst and the snapshot.
    static let firstDelay: TimeInterval = 10
    /// Minimum time between two backups of the same file.
    static let minimumBackupInterval: TimeInterval = 30
    /// Delay before re-checking a canvas/disk mismatch.
    static let mismatchRecheckDelay: TimeInterval = 15
    static let maximumBackupsPerFile = 30

    static var rootDirectory: URL? {
        try? FileManager.default.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        ).appendingPathComponent("SafetyBackups", isDirectory: true)
    }

    private let logger = Logger(label: "SafetyBackup")
    private weak var core: ExcalidrawCore?

    // Main-actor state.
    private var pendingTask: Task<Void, Never>?
    private var lastBackupAt: [String: Date] = [:]
    private var lastBackupSignature: [String: String] = [:]
    /// Canvas signature seen at the previous cycle while the disk differed.
    private var mismatchCandidate: [String: String] = [:]
    private var warnedFileIDs: Set<String> = []

    init(core: ExcalidrawCore) {
        self.core = core
    }

    /// Called for every `stateChanged` message, before any save guard.
    @MainActor
    func noteStateChanged() {
        guard pendingTask == nil else { return }
        schedule(after: Self.firstDelay)
    }

    @MainActor
    private func schedule(after delay: TimeInterval) {
        pendingTask?.cancel()
        pendingTask = Task { @MainActor [weak self] in
            try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
            guard !Task.isCancelled, let self else { return }
            self.pendingTask = nil
            await self.runCycle()
        }
    }

    @MainActor
    private func runCycle() async {
        guard let core else { return }
        let sync = core.documentSyncController
        // Skip while a file is (re)loading: the canvas may hold a half-applied
        // scene. The next stateChanged after the load re-arms the cycle.
        guard let fileID = sync.currentLoadedFileID,
              !sync.hasPendingFileLoad,
              !core.isLoading else { return }

        let elements: [[String: Any]]
        do {
            let snapshot = try await core.getCurrentFileSnapshot(includeFiles: false)
            elements = try Self.elements(in: snapshot.documentData(includeFiles: false))
        } catch {
            logger.warning("Safety backup: could not read the canvas: \(error)")
            return
        }
        guard sync.currentLoadedFileID == fileID, !sync.hasPendingFileLoad else { return }

        let signature = Self.signature(of: elements)
        let displayName = self.displayName(for: fileID, core: core)

        // 1. Backup.
        let now = Date()
        if signature != lastBackupSignature[fileID] {
            if let last = lastBackupAt[fileID],
               now.timeIntervalSince(last) < Self.minimumBackupInterval {
                schedule(after: Self.minimumBackupInterval - now.timeIntervalSince(last))
            } else {
                await writeBackup(fileID: fileID, displayName: displayName, core: core)
                lastBackupSignature[fileID] = signature
                lastBackupAt[fileID] = now
            }
        }

        // 2. Unsaved-changes watchdog (linked local files only).
        await checkDisk(fileID: fileID, displayName: displayName, canvasSignature: signature, core: core)
    }

    // MARK: - Backup

    @MainActor
    private func writeBackup(fileID: String, displayName: String, core: ExcalidrawCore) async {
        guard let root = Self.rootDirectory else { return }
        let documentData: Data
        do {
            let snapshot = try await core.getCurrentFileSnapshot(includeFiles: true)
            documentData = try snapshot.documentData(includeFiles: true)
        } catch {
            logger.warning("Safety backup: could not read the canvas with files: \(error)")
            return
        }
        guard core.documentSyncController.currentLoadedFileID == fileID else { return }

        let folder = root.appendingPathComponent(
            Self.folderName(displayName: displayName, fileID: fileID),
            isDirectory: true
        )
        let logger = self.logger
        await Task.detached(priority: .utility) {
            do {
                let data = try Self.backupDocument(from: documentData)
                try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
                let sourceNote = folder.appendingPathComponent("source.txt")
                if !FileManager.default.fileExists(atPath: sourceNote.path) {
                    try Data("\(Self.readableSource(of: fileID))\n".utf8).write(to: sourceNote, options: .atomic)
                }
                let formatter = DateFormatter()
                formatter.locale = Locale(identifier: "en_US_POSIX")
                formatter.dateFormat = "yyyy-MM-dd HH-mm-ss"
                let url = folder.appendingPathComponent("\(formatter.string(from: Date())).excalidraw")
                try data.write(to: url, options: .atomic)
                Self.prune(folder: folder)
                logger.info("Safety backup written: \(folder.lastPathComponent)/\(url.lastPathComponent) (\(data.count) bytes)")
            } catch {
                logger.warning("Safety backup: write failed for \(displayName): \(error)")
            }
        }.value
    }

    /// Wraps the snapshot (`elements`, `appState`, `files`) as a standalone
    /// `.excalidraw` document that any Excalidraw app can open.
    private static func backupDocument(from documentData: Data) throws -> Data {
        let payload = try JSONSerialization.jsonObject(with: documentData) as? [String: Any] ?? [:]
        let appState = payload["appState"] as? [String: Any] ?? [:]
        var keptAppState: [String: Any] = [
            "viewBackgroundColor": appState["viewBackgroundColor"] ?? "#ffffff"
        ]
        if let gridSize = appState["gridSize"] {
            keptAppState["gridSize"] = gridSize
        }
        let document: [String: Any] = [
            "type": "excalidraw",
            "version": 2,
            "source": "ExcalidrawZ safety backup",
            "elements": payload["elements"] ?? [Any](),
            "appState": keptAppState,
            "files": payload["files"] ?? [String: Any]()
        ]
        return try JSONSerialization.data(withJSONObject: document)
    }

    private static func prune(folder: URL) {
        let fileManager = FileManager.default
        guard let names = try? fileManager.contentsOfDirectory(atPath: folder.path) else { return }
        let backups = names.filter { $0.hasSuffix(".excalidraw") }.sorted()
        for name in backups.dropLast(maximumBackupsPerFile) {
            try? fileManager.removeItem(at: folder.appendingPathComponent(name))
        }
    }

    // MARK: - Watchdog

    @MainActor
    private func checkDisk(
        fileID: String,
        displayName: String,
        canvasSignature: String,
        core: ExcalidrawCore
    ) async {
        guard let url = URL(string: fileID), url.isFileURL else { return }
        let diskSignature: String
        do {
            let data = try await LocalFolder.withSecurityScopedAccessToContainingFolder(for: url) {
                try Data(contentsOf: url)
            }
            diskSignature = Self.signature(of: try Self.elements(in: data))
        } catch {
            logger.debug("Safety backup: could not read \(url.lastPathComponent) for comparison: \(error)")
            return
        }

        if diskSignature == canvasSignature {
            mismatchCandidate[fileID] = nil
            if warnedFileIDs.remove(fileID) != nil {
                logger.info("Safety backup: \(url.lastPathComponent) is saved again")
            }
            return
        }

        if mismatchCandidate[fileID] == canvasSignature {
            // The canvas did not change since the last check, yet the disk
            // copy still differs: the save pipeline dropped the edits.
            guard !warnedFileIDs.contains(fileID) else { return }
            warnedFileIDs.insert(fileID)
            logger.warning("Safety backup: canvas of \(url.lastPathComponent) is not being saved to disk")
            let folder = Self.rootDirectory?
                .appendingPathComponent(Self.folderName(displayName: displayName, fileID: fileID))
            core.publishError(UnsavedChangesError(fileName: url.lastPathComponent, backupFolder: folder))
        } else {
            mismatchCandidate[fileID] = canvasSignature
            if pendingTask == nil {
                schedule(after: Self.mismatchRecheckDelay)
            }
        }
    }

    struct UnsavedChangesError: LocalizedError {
        let fileName: String
        let backupFolder: URL?

        var errorDescription: String? {
            "“\(fileName)” 的修改没有写入磁盘"
        }

        var recoverySuggestion: String? {
            var text = "画布上的最新内容已存进安全备份"
            if let backupFolder {
                text += "：\(backupFolder.path)"
            }
            return text + "。请先别切换或关闭这个文件，用“导出”另存一份。"
        }
    }

    // MARK: - Helpers

    private static func elements(in documentData: Data) throws -> [[String: Any]] {
        let payload = try JSONSerialization.jsonObject(with: documentData) as? [String: Any]
        return payload?["elements"] as? [[String: Any]] ?? []
    }

    /// Identity of the visible content: every live element's id, version and
    /// versionNonce (the nonce changes on every mutation, even when a tool
    /// recreates an element with the same id and version).
    static func signature(of elements: [[String: Any]]) -> String {
        elements
            .filter { ($0["isDeleted"] as? Bool) != true }
            .map {
                let id = $0["id"] as? String ?? "?"
                let version = ($0["version"] as? NSNumber)?.intValue ?? -1
                let nonce = ($0["versionNonce"] as? NSNumber)?.int64Value ?? -1
                return "\(id):\(version):\(nonce)"
            }
            .sorted()
            .joined(separator: ",")
    }

    @MainActor
    private func displayName(for fileID: String, core: ExcalidrawCore) -> String {
        if let url = URL(string: fileID), url.isFileURL {
            return url.deletingPathExtension().lastPathComponent
        }
        if core.parent?.file?.id == fileID, let name = core.parent?.file?.name, !name.isEmpty {
            return name
        }
        return "Untitled"
    }

    private static func folderName(displayName: String, fileID: String) -> String {
        let unsafe = CharacterSet(charactersIn: "/:\\").union(.controlCharacters)
        let cleaned = displayName.components(separatedBy: unsafe).joined(separator: "_")
        let hash = SHA256.hash(data: Data(fileID.utf8)).prefix(4).map { String(format: "%02x", $0) }.joined()
        return "\(cleaned.prefix(80))-\(hash)"
    }

    private static func readableSource(of fileID: String) -> String {
        if let url = URL(string: fileID), url.isFileURL {
            return url.path
        }
        return "ExcalidrawZ file id: \(fileID)"
    }
}

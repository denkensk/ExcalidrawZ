//
//  ExcalidrawZFileLogHandler.swift
//  ExcalidrawZ
//
//  ExcalidrawZ personal build: also write logs to
//  ~/Library/Containers/<bundle id>/Data/Library/Logs/ExcalidrawZ.log so a
//  problem can be investigated after the fact, without launching the app
//  with `open --stdout`.
//

import Foundation
import Logging

struct ExcalidrawZFileLogHandler: LogHandler {
    static let maximumFileSize = 10 * 1024 * 1024

    static var logFileURL: URL? {
        FileManager.default.urls(for: .libraryDirectory, in: .userDomainMask).first?
            .appendingPathComponent("Logs", isDirectory: true)
            .appendingPathComponent("ExcalidrawZ.log")
    }

    private static let writer = Writer(url: logFileURL)

    let label: String
    var logLevel: Logger.Level = .info
    var metadata: Logger.Metadata = [:]
    var metadataProvider: Logger.MetadataProvider?

    init(label: String) {
        self.label = label
    }

    subscript(metadataKey key: String) -> Logger.Metadata.Value? {
        get { metadata[key] }
        set { metadata[key] = newValue }
    }

    func log(event: LogEvent) {
        var merged = metadata
        if let provided = metadataProvider?.get() {
            merged.merge(provided) { _, new in new }
        }
        if let eventMetadata = event.metadata {
            merged.merge(eventMetadata) { _, new in new }
        }
        let metadataText = merged.isEmpty
            ? ""
            : " " + merged.sorted { $0.key < $1.key }.map { "\($0.key)=\($0.value)" }.joined(separator: " ")
        Self.writer.write(
            "\(Self.timestamp()) \(event.level) \(label):\(metadataText) \(event.message)\n"
        )
    }

    private static func timestamp() -> String {
        let formatter = ISO8601DateFormatter()
        formatter.timeZone = .current
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter.string(from: Date())
    }

    private final class Writer: @unchecked Sendable {
        private let queue = DispatchQueue(label: "ExcalidrawZFileLogHandler")
        private var handle: FileHandle?

        init(url: URL?) {
            guard let url else { return }
            let fileManager = FileManager.default
            try? fileManager.createDirectory(
                at: url.deletingLastPathComponent(),
                withIntermediateDirectories: true
            )
            // Keep one previous log; start a new one when it grows too large.
            if let size = (try? fileManager.attributesOfItem(atPath: url.path))?[.size] as? Int,
               size > ExcalidrawZFileLogHandler.maximumFileSize {
                let previous = url.deletingPathExtension().appendingPathExtension("1.log")
                try? fileManager.removeItem(at: previous)
                try? fileManager.moveItem(at: url, to: previous)
            }
            if !fileManager.fileExists(atPath: url.path) {
                fileManager.createFile(atPath: url.path, contents: nil)
            }
            handle = try? FileHandle(forWritingTo: url)
            _ = try? handle?.seekToEnd()
        }

        func write(_ line: String) {
            queue.async { [handle] in
                try? handle?.write(contentsOf: Data(line.utf8))
            }
        }
    }
}

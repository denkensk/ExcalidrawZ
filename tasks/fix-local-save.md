---
id: fix-local-save
title: 本地文件夹文件的修改没保存（加安全备份、未保存提醒、日志文件）
status: active
updated: 2026-11-02
---

## Goal
用户（2026-11-02）在本地文件夹文件 `~/Documents/Excalidraw/MaaS/Core metric.excalidraw` 里写了约一小时内容，没有自动保存，切换画布后全部丢失，找不回来。用户说遇到过不止一次："切换画布之后回来，就只能看到最原始的内容"。

用户同意的方案（2026-11-02）：根因还没复现出来，先保证"不管什么原因，内容都丢不了"，再找根因。
1. 安全备份：独立于保存流程，定期把画布上实际的内容另存一份。
2. 让"悄悄丢弃保存"不再悄悄：warning 日志 + 磁盘对不上时弹提示。
3. 日志常开，写进文件，下次出事能查。

## 已确认的事实（出事那次）
- App 从 00:03 一直开到 12:56；00:16 添加了 `~/Documents/Excalidraw` 本地文件夹。
- 00:16 之后，本地文件的保存一次都没走完：`updateLocalFile` 每次成功都会写本地文件检查点（`ExcalidrawZLocal.sqlite` 的 `ZLOCALFILECHECKPOINT`），但检查点是 0 条，数据库从 00:16 起没再被写。
- `Core metric.excalidraw` 最后写入是 11:37:04，那是打开文件 8 秒后的"只写 appState"保存（`AppState-only local file update saved`，不记检查点），不是用户的内容。
- 11:36:53 出现了第二次 "Configure Web View"（画布网页重建），接着 "LocalFolderMonitor: Failed to access security-scoped URL: alreadyMonitoring"。日志里没有任何保存失败。
- WebView 存储是不落盘的（localStorage / IndexedDB 为空）；没有 Time Machine 快照。数据快照留在 `/tmp/xz-recovery-125755`。

## 复现情况
用 debug 日志（`EXCALIDRAWZ_LOG_LEVEL=debug`）实测，全新启动的 App 下都正常：手动编辑、MCP 程序修改、切换文件再切回、⌘W 关窗口再打开。⌘N 在 App 里是"新建文件"，不是新窗口，所以**多窗口还没测**。
怀疑方向（未证实）：每个窗口有自己的 `FileState`（`ContentView` 的 `@StateObject`），文件夹监控是全 App 共用；出现第二套窗口界面后，`FileState.shouldIgnoreUpdate` 这个开关可能一直关着（`recoverWatchUpdate` 在 `activeCanvasIsLoading` 为 true 时无限重试），用户编辑被 `shouldAcceptCanvasUpdate` 静默丢弃；程序修改有 programmatic allowance，不受影响。

## Progress
- [x] Release 日志级别开关：`EXCALIDRAWZ_LOG_LEVEL`（`ExcalidrawZApp.swift`）
- [x] 安全备份 + 未保存看门狗：新文件 `ExcalidrawZ/ExcalidrawView/Engine/ExcalidrawZSafetyBackup.swift`；挂接点 `ExcalidrawCore.swift`（`safetyBackup`）、`ExcalidrawCore+ScriptMessage.swift`（`onStateChanged` 最前面）
- [x] 静默丢弃改 warning：`FileState.shouldAcceptCanvasUpdate`、`ExcalidrawEditor.persistCanvasUpdate`（3 处）、`ExcalidrawDocumentSyncController`（文件不匹配 1 处 + 写入时切换 2 处）
- [x] 日志文件：新文件 `ExcalidrawZ/Utils/ExcalidrawZFileLogHandler.swift`，写到容器里的 `Library/Logs/ExcalidrawZ.log`（超过 10MB 轮换成 `.1.log`）
- [x] 签名加 `versionNonce`；程序修改（MCP/AI）也挂接备份（`ExcalidrawDocumentProgrammaticSnapshotCommitter`）
- [x] 构建（`/tmp/xz-build4`）并端到端验证（`/tmp/xz_test_watchdog.sh`，只动测试文件）：修改后 6 秒出备份；`chflags uchg` 让文件写不进去 → 30 秒后看门狗提示、备份里有没存进去的内容、磁盘没有；解锁后磁盘恢复写入、日志 "is saved again"；备份文件能在 App 里打开。日志文件正常。
- [x] 测完删掉了容器偏好里的 `ExcalidrawZMCPServerEnabled`
- [x] 装到 `~/Applications`（2026-11-02 17:16，用户同意；签名校验通过、启动正常、日志文件在写）
- [x] 清理：5 个测试文件、测试备份文件夹、临时构建和调试日志都删了；`MaaS` 只剩 `Core metric`、`Dynamo`
- [ ] 找到根因并修
- [x] 已提交到 `fix/local-save` 分支（从 `feat/partial-text-color` 分出，2 个提交：代码、项目记忆），还没推送

## Next
1. 根因：下次用户再遇到看门狗提示或丢数据，先查安全备份（容器 `Application Support/SafetyBackups/`）把内容找回，再查 `ExcalidrawZ.log` 里 "Dropped canvas update" / "Rejected canvas update" / "Dropped stateChanged" / "not being saved to disk" 前后的记录。可疑方向：多窗口（菜单里新开窗口，不是 ⌘N）、App 长时间运行 + 睡眠后窗口重建。
2. 推送：等用户要求。推到 `fork` 的 `fix/local-save`；`feat/partial-text-color` 里没有这次修复，以后构建要在 `fix/local-save` 上（或先合并）。
3. 另记：网页发来的 `didSetActiveTool` 里 `type = bucketfill`（填充桶）Swift 端解码失败，只影响工具栏状态，可以顺手让 Swift 端认识或忽略未知工具。
4. `/tmp/xz-recovery-125755` 是出事那天 App 数据目录的快照，确认不需要后可以删。

## Relevant files
- 新文件：`ExcalidrawZ/ExcalidrawView/Engine/ExcalidrawZSafetyBackup.swift`、`ExcalidrawZ/Utils/ExcalidrawZFileLogHandler.swift`
- 日志：容器 `Library/Logs/ExcalidrawZ.log`

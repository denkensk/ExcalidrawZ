---
id: feat-partial-text-color
title: 文字框内局部文字上色（自建 Mac 版）
status: active
updated: 2026-11-01
---

## Goal
在 Mac 主编辑器里，选中文字框内的一部分文字单独上色，并打包成自建版 App 自己用。

和用户确认过的需求（2026-11-01 采访）：
- 只做局部**颜色**，第一版不做加粗。
- 操作：双击进入编辑 → 选中**部分**文字 → 点左侧属性面板"描边"的颜色。不选或全选（开始编辑时默认全选）→ 照旧整框改色。
- 整框改色时清掉局部颜色（全部变成新颜色）。
- 在彩色文字末尾接着打字，新字沿用前一个字的颜色（Word 式）。
- 文件只在自建版里打开（不考虑 Obsidian / excalidraw.com / 实时协作）。

## Progress
- [x] 评估和需求采访
- [x] 内核：数据（`customData.excalidrawZTextColors`）、画布和 SVG 渲染、编辑框叠加层、描边色动作、编辑中的 ⌘Z / ⌘⇧Z
- [x] 测试：新增 36 个；内核完整套件 2721 个通过
- [x] WebKit 实测（截图）：上色、续写、撤销、再次编辑、深色模式，叠加层和画布逐像素对齐
- [x] 自建配置、`scripts/build-personal.sh`、`scripts/fetch-packages.py`；App 装到 `~/Applications/ExcalidrawZ Personal.app`
- [x] 修复：Swift `AnyCodable` 读不了对象数组 → 颜色区间改存为平行数组
- [x] 用户实测："看着好像没问题了"；颜色能正常保存
- [ ] 两个仓库的改动都**还没提交**（`feat/partial-text-color` 分支），等用户决定
- [ ] 可选：Quick Look、历史版本、备份预览也显示局部颜色（`ExcalidrawRenderer.swift`，约半天）
- [ ] 可选：加粗（数据结构已留位置；建议用描边模拟，字宽不变）

## Next
等用户决定要不要提交两个仓库的改动。提交的话在各自的 `feat/partial-text-color` 分支上分开提交：
- 内核：2 个新模块和 2 个测试文件，加 6 个原有文件里的挂接点。
- ExcalidrawZ：10 个自建配置文件。

## Relevant files
内核（`~/Documents/code/github/excalidraw`）：
- `packages/element/src/excalidrawZTextColors.ts`：存储、校验、区间运算、按行切段、画布和 SVG 辅助
- `packages/excalidraw/wysiwyg/textColorEditor.ts`：编辑时的叠加层、输入法下划线、选区记忆、上色撤销
- 挂接点：`packages/element/src/renderElement.ts`、`packages/excalidraw/renderer/staticSvgScene.ts`、`packages/excalidraw/wysiwyg/textWysiwyg.tsx`、`packages/excalidraw/components/App.text.ts`、`packages/excalidraw/actions/actionProperties.tsx`、`packages/element/src/index.ts`
- 测试：`packages/element/tests/excalidrawZTextColors.test.ts`、`packages/excalidraw/wysiwyg/textColorEditor.test.tsx`

ExcalidrawZ（本仓库）：
- 自建配置：`ExcalidrawZ.xcodeproj/project.pbxproj`、两个 `.entitlements`、`ExcalidrawZApp.swift`、`Persistence/PersistenceController.swift`、`Utils/ExcalidrawServer.swift`，以及 4 处改用 `ExcalidrawServer.indexURL` 的文件
- 脚本（git 忽略）：`scripts/build-personal.sh`、`scripts/fetch-packages.py`

## Notes
- blocked_by: none
- 用户还没专门反馈两点：中文输入法在彩色文字里打字（拼音下划线），以及选中彩色文字时的选区高亮（WebKit 截图看不到选区，只能真机看）。
- 设计决定和踩坑见 `memory/decisions.md`（2026-11-01）。

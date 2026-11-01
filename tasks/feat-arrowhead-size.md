---
id: feat-arrowhead-size
title: 缩短箭头两翼（自建 Mac 版）
status: active
updated: 2026-11-01
---

## Goal
用户反馈（2026-11-01）：箭头（`arrow` 样式）的两翼太长，在密集的图里会挡住别的元素。要把两翼改短，已有文件里的箭头也一起变，不改数据格式。

## Progress
- [x] 方案：只改渲染尺寸。官方两翼 25px、张角 20°，和线粗无关 → 改成 13px、30°（稍窄一点，沿线往回伸的长度不到一半）
- [x] 用内核真实渲染出对比图（官方、A 18px·24°、B 15px·28°、C 13px·30°）；我推荐 B，**用户选了 C**
- [x] 内核：新文件 `excalidrawZArrowheads.ts` 放常量，`bounds.ts` 加两处挂接点，新增 2 个测试
- [x] tsc、eslint、`bounds.test.ts` 和新测试通过（C 尺寸下重跑过）
- [x] 内核完整测试套件（C 尺寸）：163 个文件全部通过（2676 通过、47 跳过、1 todo），没有快照受影响
- [x] 按 C 构建（先装到临时目录，确认网页包里尺寸是 13、角度是 30），经用户同意正常退出 App 后装到 `~/Applications` 并重新打开；网页包能正常加载，日志无新错误
- [ ] 用户在 App 里实测、确认尺寸
- [ ] 改动还没提交

## Next
等用户在 App 里实测：已有文件打开就是新箭头，不用重画。
- 想换尺寸：只改 `excalidrawZArrowheads.ts` 里的两个常量，然后跑 `./scripts/build-personal.sh`（先退出 App）。尺寸不要低于 13（约 12.2 以下官方测试会失败，10 及以下会除零），角度不超过 30（见 decisions）。
- 提交：两个仓库的改动都还没提交，等用户要求。箭头只改了内核的 3 个文件（见下），提交时单独开 `feat/arrowhead-size` 分支，和局部颜色分开。

## Relevant files
内核（`~/Documents/code/github/excalidraw`，目前在 `feat/partial-text-color` 分支上，和局部颜色的改动混在同一个工作区，但文件不重叠；提交时单独开 `feat/arrowhead-size`）：
- `packages/element/src/excalidrawZArrowheads.ts`：尺寸、角度常量
- `packages/element/src/bounds.ts`：`getArrowheadSize()` 和 `ARROW_ARROWHEAD_ANGLE` 两处挂接点
- `packages/element/tests/excalidrawZArrowheads.test.ts`

## Notes
- blocked_by: none
- 对比图：`/tmp/xz-arrows/compare.png`；出图用的临时测试在 `/tmp/xz-arrows/harness.test.tsx`（要用时拷回 `packages/excalidraw/tests/`，用环境变量 `XZ_SIZE`、`XZ_ANGLE`、`XZ_LABEL` 指定尺寸和文件名）。
- Quick Look、历史版本、备份预览用原生渲染器，它自己画 10px、30° 的箭头，不受影响。
- 可选：粗线（4px）配 15px 箭头略显短粗，如果用户在意，可以让尺寸随线粗变化（要改 `getArrowheadSize` 的调用方式，挂接点会多一些）。

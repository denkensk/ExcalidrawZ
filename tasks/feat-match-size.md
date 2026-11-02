---
id: feat-match-size
title: 对齐面板加"统一宽度 / 高度 / 尺寸"（自建 Mac 版）
status: active
updated: 2026-11-02
---

## Goal
用户需求（2026-11-01）：同时选中几个框时，一键让它们的宽和高一样。放在属性面板的"对齐"里。

和用户确认过的方案（2026-11-01）：
- 以**最大**为准：宽取最宽的，高取最高的（框只变大，文字不会挤出来）。
- **中心不动**：每个框以自己的中心改尺寸。
- 三个按钮：统一宽度、统一高度、统一尺寸，在对齐按钮下面单独一行（一行放不下第 5 个按钮）。
- 只改长方形、菱形、椭圆；同时选中的箭头、文字不改，连着的箭头跟着框走。

## Progress
- [x] 内核：新文件 `excalidrawZMatchSize.tsx`（三个动作、按钮行、图标），4 个原有文件加挂接点，3 个语言文件加翻译
- [x] 新增 7 个测试；tsc、eslint 通过；内核完整套件 164 个文件全部通过（2683 通过、47 跳过、1 todo）
- [x] WebKit 实测截图（`/tmp/xz-matchsize/out/`）：新按钮行显示正常；统一后中心不变、标签居中、箭头绑定保留；撤销、只统一宽/高都正常；只选一个框时整行隐藏
- [x] 构建（先装到临时目录），经用户同意正常退出 App 后装到 `~/Applications` 并重新打开（2026-11-02）；服务正常启动、7 个本地文件都在，日志没有新错误
- [ ] 用户实测
- [x] 已提交并推到 fork（内核提交 "ExcalidrawZ: match width / height / size actions"），现在在 `custom` 分支里

## Next
等用户在 App 里实测：选中两个以上的框 → 属性面板"对齐"下面第三行。
- 想改规则（以谁为准、固定点、参与的图形类型）：都在 `excalidrawZMatchSize.tsx` 的 `matchElementsSize` / `isMatchSizeTarget`，改完跑测试和 tsc，再 `./scripts/build-personal.sh`（先退出 App）。

## Relevant files
内核（`~/Documents/code/github/excalidraw`，`custom` 分支）：
- 新：`packages/excalidraw/actions/excalidrawZMatchSize.tsx`、`excalidrawZMatchSize.test.tsx`
- 挂接点：`packages/excalidraw/actions/types.ts`（ActionName）、`actions/index.ts`（导出，触发注册）、`components/Actions.tsx`（`AlignFieldset` 里渲染 `MatchSizeButtons`）
- 翻译：`packages/excalidraw/locales/en.json`、`zh-CN.json`、`zh-TW.json`（`labels.matchWidth/matchHeight/matchSize`）

## Notes
- blocked_by: none
- 不按组处理：选中的组里如果有多个框，每个框都会被统一。
- 便签（stickynote）、图片、文字不参与统一。
- 框之间本来离得近、尺寸差得多时，统一后会贴在一起，中间的箭头被压短；用等距分布（只选框，别连箭头一起选，见 decisions.md 2026-11-02 align-evenly）或撤销。用户如果在意，可以考虑"统一后保持原来的间距"之类的选项（还没做）。

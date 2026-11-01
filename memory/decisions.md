# 决策与踩坑记录（只追加）

## 2026-11-01 — feat-partial-text-color
**Decision:** 局部颜色存在文字元素的 `customData.excalidrawZTextColors`，位置按 `originalText`（UTF-16 偏移）计算；用文本长度 + FNV-1a 哈希 + 写入时的整框颜色（`baseColor`）做校验，不匹配就当作没有局部颜色。
**Reason:** Excalidraw 读取文件时只保留已知字段和 `customData`，Swift 端模型也一样，新加的顶层字段会丢。按原文记位置，重新换行时不用改区间。哈希能防止文字被别处改过后颜色涂错位置。`baseColor` 不一致即失效，这样任何途径整框改色（面板、吸管、AI）都会自动清掉局部颜色。
**Affects:** `excalidraw/packages/element/src/excalidrawZTextColors.ts`

## 2026-11-01 — feat-partial-text-color
**Decision:** 颜色区间存成平行数组 `ranges: { starts, ends, colors }`，不用 `[{start, end, color}]`。
**Reason:** ExcalidrawZ Swift 端自写的 `AnyCodable` 没有"对象数组"这个 case。只要 `customData` 里出现对象数组，整条 stateChanged 消息就解码失败：弹出 "The data couldn't be read because it isn't in the correct format."，修改也不会保存。用户实测时撞到了这个问题。jsdom 和 WebKit 测试都覆盖不到，所以写进 `customData` 的新结构要单独用 Swift 解码器验证一遍。另外有单元测试检查存储结构里不出现对象数组。
**Affects:** `excalidraw/packages/element/src/excalidrawZTextColors.ts`；对应的 Swift 代码在 `ExcalidrawZ/Models/ExcalidrawElementBase.swift`（未改）

## 2026-11-01 — feat-partial-text-color
**Decision:** 编辑时显示颜色的做法：textarea 的文字设为透明（`-webkit-text-fill-color`），下面叠一层复制了 textarea 内联样式的镜像 div 来显示颜色；只在文字有局部颜色时启用。
**Reason:** textarea 只能显示一种颜色。镜像层和 textarea 都由浏览器排版，换行和位置天然一致（WebKit 截图验证过逐像素对齐）。输入法、撤销、粘贴仍由原生 textarea 处理。用 text-fill 而不用 `color: transparent`，光标会自然沿用文字颜色。没有局部颜色的文字完全走原来的路径。
**Affects:** `excalidraw/packages/excalidraw/wysiwyg/textColorEditor.ts`、`textWysiwyg.tsx`

## 2026-11-01 — feat-partial-text-color
**Decision:** 只有选中**部分**文字时才局部上色；全选或不选时照旧整框改色。
**Reason:** 按回车开始编辑时文字默认全选。如果全选也走局部上色，形状边框不会再跟着文字一起变色，便签的整体颜色也会失效（完整测试套件里的便签测试因此失败过）。
**Affects:** `textColorEditor.ts` 的 `getTextEditorSelection`、`actions/actionProperties.tsx`

## 2026-11-01 — feat-partial-text-color
**Decision:** 编辑中按 ⌘Z / ⌘⇧Z 时，如果上一步是上色且之后文字没改过，就撤销/重做上色；否则交给 textarea 原生撤销。
**Reason:** 原生撤销只认识文字改动，上色后直接按 ⌘Z 会撤掉之前打的字。
**Affects:** `textColorEditor.ts`（`handleKeyDown`）、`textWysiwyg.tsx`（`onkeydown`）

## 2026-11-01 — feat-partial-text-color
**Decision（坑）:** 内核里几个容易踩的点：
- `newElementWith` 会忽略值为 `undefined` 的字段；如果这是唯一的改动，它直接返回原元素。所以清空颜色时返回 `customData: {}`，不能返回 `undefined`。
- `withBatchedUpdates` 只转发一个参数：多参数的回调要包在闭包里再调用。
- `mutateElement` 原地修改不会让画布的文字缓存失效：颜色数据必须用 `newElementWith` 生成新元素。
- `yarn prettier` 是仓库脚本，会格式化整个仓库（之前误改过 `fonts.css`，已还原）：用 `node_modules/.bin/prettier --write <文件>`。
- vite 构建时会对测试文件做类型检查，测试里的类型错误也会让 `yarn build` 失败。
- WKWebView 的 `takeSnapshot` 不截选区高亮，选区效果只能在真机上看。
**Affects:** 内核构建、测试流程

## 2026-11-01 — feat-partial-text-color
**Decision:** 自建 App 的配置：Release Bundle ID 改为 `com.qingcan.excalidrawz`；去掉 iCloud、推送、钥匙串共享组、App Group 权限；ad-hoc 签名并关闭 Hardened Runtime；强制关闭 CloudKit；Sparkle 不启动；Release 端口改为 8497。
**Reason:** 免费 Apple ID 开不了这些受限权限。同一个 Bundle ID 会和官方版共用沙盒容器。Sparkle 可能用官方版覆盖自建版。两个 App 同时运行时都会去占 8487 端口，后启动的那个会静默失败，然后加载另一个 App 的内核。
**Affects:** `ExcalidrawZ.xcodeproj/project.pbxproj`、`ExcalidrawZ/ExcalidrawZ.entitlements`、`QuickLookPreviewExtension/QuickLookPreviewExtension.entitlements`、`ExcalidrawZ/Persistence/PersistenceController.swift`、`ExcalidrawZ/ExcalidrawZApp.swift`、`ExcalidrawZ/Utils/ExcalidrawServer.swift`（以及 4 个改用 `ExcalidrawServer.indexURL` 的文件）

## 2026-11-01 — feat-partial-text-color
**Decision（坑）:** 构建环境：
- 本机从 github.com 用 git 克隆会被中途断开（HTTP/2 和 HTTP/1.1 都会），但 codeload 的源码包下载正常。所以用 `scripts/fetch-packages.py` 下载源码包，生成 workspace 用本地包覆盖远程依赖。
- 本地包会被当成根包解析，它们只给测试用的依赖也要能解析到：`swift-snapshot-testing` 用一个只有同名产品的替身包。
- Xcode 26 把 `RECOMMENDED_MACOSX_DEPLOYMENT_TARGET` 解析成 11.0，低于 `ChocofordUI` 要求的 12.0，Quick Look 扩展会编不过：构建时传 `RECOMMENDED_MACOSX_DEPLOYMENT_TARGET=13.0`。
- `-project` 构建和 `-showBuildSettings` 都会触发 git 克隆然后卡住，要用 `-workspace build/ExcalidrawZPersonal.xcworkspace`。
- App 日志只写 stdout，排查问题时用 `open --stdout/--stderr` 启动。
**Affects:** `scripts/build-personal.sh`、`scripts/fetch-packages.py`

## 2026-11-01 — feat-arrowhead-size
**Decision:** `arrow` 箭头的两翼从 25px、20° 改成 15px、28°（`EXCALIDRAWZ_ARROW_ARROWHEAD_SIZE` / `EXCALIDRAWZ_ARROW_ARROWHEAD_ANGLE`）。只改渲染：不加新的箭头类型，也不改数据。
**Reason:** 用户觉得两翼太长，密集的图里会挡住别的元素。新箭头的宽度和原来差不多（半宽 7.0px，原来 8.6px），沿线往回只伸 13px（原来 23.5px）。加新箭头类型要改数据格式，官方客户端和 Swift 端可能读不了，已有文件也不会跟着变短。用内核真实渲染对比了 18/24、15/28、13/30 三档：15/28 在细线、粗线、短末段、折线、曲线上都清楚，并排的一对来回箭头也不再互相压住。
**Affects:** `excalidraw/packages/element/src/excalidrawZArrowheads.ts`（新）、`packages/element/src/bounds.ts`（两处挂接点）、`packages/element/tests/excalidrawZArrowheads.test.ts`（新）

## 2026-11-01 — feat-arrowhead-size
**Decision（坑）:** 箭头尺寸常量必须大于 10px。`getArrowheadAngle()` 让缩小的箭头在 10px（`ARROW_ARROWHEAD_WIDEST_SIZE`）时张到最大角度，分母是 `尺寸 - 10`：等于 10 会除零，所有箭头都画不出来。另外，尺寸小于约 12.2px 时，官方测试 "grows arrow arrowheads on a short last segment" 会失败。Quick Look 等预览用的原生渲染器自己画 10px、30° 的箭头，不受这个常量影响。
**Affects:** 同上；`ExcalidrawZ/ExcalidrawView/NativeRenderer/ExcalidrawRenderer.swift`（未改）

## 2026-11-01 — feat-arrowhead-size
**Decision:** 用户看了对比图后选 C：两翼 13px、30°（替代上面的 15px、28°）。
**Reason:** 用户偏好更短的箭头。新箭头半宽 6.5px（官方 8.6px），沿线往回伸 11.3px（官方 23.5px）。30° 正好是缩小箭头张开的上限，所以缩小时不再变宽；角度不能超过 30°，否则缩小时反而会合拢。13px 离"官方测试在约 12.2px 以下失败"的界限已经很近，不要再往下调。
**Affects:** `excalidraw/packages/element/src/excalidrawZArrowheads.ts`、`packages/element/tests/excalidrawZArrowheads.test.ts`

## 2026-11-01 — feat-match-size
**Decision:** 对齐面板加"统一宽度 / 统一高度 / 统一尺寸"三个按钮（对齐按钮下面单独一行）。以选中的框里最大的宽、高为准；每个框以自己的中心改尺寸；只改长方形、菱形、椭圆（箭头、文字、便签、图片不参与），不按组处理。实现直接调用手动拖拽改尺寸用的 `resizeSingleElement(..., { shouldResizeFromCenter: true })`。
**Reason:** 方案是用户选的。只变大不变小，框里的文字不会放不下；中心不动，已经居中对齐的框保持对齐，旋转过的框也没问题。复用 `resizeSingleElement`，标签重新换行、绑定箭头跟着走都和手动拖一样。面板内容宽 176px，一行只放得下 4 个 32px 按钮，所以单独一行；少于两个框时整行不渲染（只隐藏按钮会多出一行空白间距）。已知效果：框之间本来离得近、尺寸又差得多时，统一后会贴在一起，中间的箭头被压短（WebKit 实测：56→120 高，64px 的间距只剩 8px），再点等距分布或撤销即可。
**Affects:** 内核 `packages/excalidraw/actions/excalidrawZMatchSize.tsx`（新）及同名测试；挂接点 `actions/types.ts`、`actions/index.ts`、`components/Actions.tsx`；翻译 `locales/en.json`、`zh-CN.json`、`zh-TW.json` 的 `labels.matchWidth/matchHeight/matchSize`（JSON 不能写注释，同步上游时记得这 3 个 key 是自建版加的）

## 2026-11-01 — feat-match-size
**Decision（坑）:** 内核测试：
- 根目录 `tsc --noEmit` 也检查测试文件，vitest 不做类型检查：写完、改完测试要再跑一次 tsc，否则 `yarn build`（vite 的类型检查）会失败。这次就是先跑 tsc 后写测试，构建时才报错。
- `API.setElements` 不进撤销历史；拿同一批对象再调 `API.updateScene({ captureUpdate: IMMEDIATELY })` 也不会记录。要测撤销，元素要用 `updateScene` + `IMMEDIATELY` 加进场景，否则撤销会把元素一起删掉。
- `API.createTextContainer` 建的标签默认左对齐、顶部对齐，不是居中。
- 在 WebKit 里实测网页内核：`python3 -m http.server 8599 --directory excalidraw-app/build`，swiftc 编译一个加载它的 WKWebView 小程序，用 `excalidrawZHelper.createElements`（skeleton，可带标签和绑定箭头）、`_api.updateScene` 摆场景，`takeSnapshot` 截图。
**Affects:** 内核测试流程

## 2026-11-02 — align-evenly（未开发）
**Decision:** 用户想要"选中几个框，对齐并等距"。内核已有"水平 / 垂直等距分布"（选中 3 个以上才显示，快捷键 Alt+H / Alt+V），配合"垂直居中 / 水平居中"两步就能做到，用户决定不开发。
**Reason（坑）:** 等距分布（`packages/element/src/distribute.ts`）按 `getSelectedElementsByGroup` 分组，选中的箭头也算一个要分布的对象。框选一排连着箭头的框时，箭头填满了框之间的空隙，框几乎不动（vitest 实测：箭头首尾在框外时，间距 100/200 → 101/199；只选框时 → 150/150）。对齐不受影响，绑定的箭头都跟着框走。所以用等距分布时只选框（Shift+点击）。以后如果要做一键版：把绑定了的箭头排除在分布对象外，先移动所有框，再统一更新箭头（`updateBoundElements` 会同时重算箭头两端，这样不受处理顺序影响）。
**Affects:** 无代码改动

## 2026-11-02 — publish-to-fork
**Decision:** 自建版推到用户的 fork：App → denkensk/ExcalidrawZ，内核 → denkensk/excalidraw，两边都用 `feat/partial-text-color` 分支（remote 名 `fork`，`origin` 仍指上游）。内核按功能拆成 3 个提交（局部颜色 / 短箭头 / 统一尺寸）；App 分 3 个提交（自建配置 / 构建脚本 / 项目记忆）。`scripts/` 和项目记忆用 `git add -f` 提交；`Config/Overrides.xcconfig`、`Config/Secrets.plist` 不提交。
**Reason（坑）:** fork 默认只复制默认分支，denkensk/excalidraw 里没有 `ExcalidrawZ-core`；从浅克隆推送会被 GitHub 拒绝（远端没有浅克隆边界的提交）。所以先 `git fetch --unshallow git@github.com:chocoford/excalidraw.git`（SSH 能稳定拉完，https 克隆会断）再推。gh CLI 没登录，GitHub 操作走 SSH（`~/.ssh/id_ed25519_github`，身份 denkensk）。
**Affects:** 两个仓库的 git 远程；`.git/info/exclude` 去掉了 AGENTS.md / tasks / memory 三行

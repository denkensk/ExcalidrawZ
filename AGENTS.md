# ExcalidrawZ 自建版 — 项目记忆

---

## 一、项目知识
*（agent 可以在这一节补充新学到的、已确认的长期事实；保持精简）*

### 项目
- **ExcalidrawZ 自建版**：在官方 ExcalidrawZ（chocoford/ExcalidrawZ，Excalidraw 的 macOS/iOS 原生客户端）基础上，给自己用的 Mac 版。
- **目标**：自用改进：文字框内选中部分文字单独上色（局部颜色）、更短的箭头、对齐面板里一键统一框的尺寸。需求、进度见 `tasks/`。
- 用户用中文交流；免费 Apple ID（没有付费开发者账号）；只在自建版里打开这些文件。

### 两个仓库
| | 路径 | 说明 |
|---|---|---|
| App | `~/Documents/code/github/ExcalidrawZ`（本仓库） | Swift/SwiftUI。Xcode 26.6（作者用 Xcode 27）。远程：`origin`=chocoford/ExcalidrawZ（上游），`fork`=denkensk/ExcalidrawZ（用户的 fork，SSH 推送） |
| 内核 | `~/Documents/code/github/excalidraw` | chocoford/excalidraw 的 `ExcalidrawZ-core` 分支副本（已补全历史，不再是浅克隆）。远程：`origin`=chocoford/excalidraw，`fork`=denkensk/excalidraw（fork 里没有 `ExcalidrawZ-core` 分支，只有 `master`）。TypeScript/React monorepo，yarn 1.22（用 `corepack yarn`），vitest，Node 24 |

- 内核构建产物 `excalidraw-app/build` 要拷到本仓库 `ExcalidrawZ/Resources/excalidraw-latest`（git 忽略、仓库里没有）。没有它 App 就没有画布。
- 两个仓库同时升级：Swift 端调用的 `window.excalidrawZHelper` 接口必须在内核里存在。

### 运行结构
- App 内置 HTTP 服务（FlyingFox，`ExcalidrawZ/Utils/ExcalidrawServer.swift`）在 127.0.0.1 上提供内核网页，WKWebView 加载。地址统一用 `ExcalidrawServer.indexURL`。
- Swift ⇄ 网页：Swift 调 `window.excalidrawZHelper`（内核 `excalidraw-app/excalidrawZ/index.js`）；网页通过 `excalidrawZ` 消息通道回传，在 `ExcalidrawCore+ScriptMessage.swift` 里解码。解码失败会记 "Decode received message failed" 并弹出 "The data couldn't be read because it isn't in the correct format."。
- 元素 `customData` 在 Swift 端用自写的 `AnyCodable`（`ExcalidrawZ/Models/ExcalidrawElementBase.swift`）解码：**不支持对象组成的数组**。写进 `customData` 的新结构必须先过这个解码器。
- Quick Look、历史版本、备份预览用原生渲染器 `ExcalidrawZ/ExcalidrawView/NativeRenderer/ExcalidrawRenderer.swift`（系统字体近似预览，不走网页内核）。

### 关键目录
- App：`ExcalidrawZ/ExcalidrawView/Engine`（网页桥接）、`ExcalidrawZ/Models`（元素模型）、`ExcalidrawZ/Persistence`（Core Data、FileStorage、同步）、`QuickLookPreviewExtension`。
- 内核：`packages/element/src`（元素模型、画布渲染）、`packages/excalidraw`（编辑器、actions、`wysiwyg/` 文字编辑框）、`excalidraw-app`（ExcalidrawZ 加载的网页应用）。
- 局部颜色代码：内核 `packages/element/src/excalidrawZTextColors.ts`、`packages/excalidraw/wysiwyg/textColorEditor.ts`（及同名测试）。
- 短箭头：内核 `packages/element/src/excalidrawZArrowheads.ts`（尺寸常量，挂接点在 `bounds.ts`）及同名测试。
- 统一尺寸：内核 `packages/excalidraw/actions/excalidrawZMatchSize.tsx`（三个动作、按钮行、图标；挂接点在 `components/Actions.tsx` 的 `AlignFieldset`）及同名测试。

### 构建与运行
- **一键构建**：`./scripts/build-personal.sh` → 编译内核 → 拷进 App → 下载 Swift 包 → 编译 Release（本地签名）→ 装到 `~/Applications/ExcalidrawZ Personal.app`。`SKIP_CORE=1` 跳过内核。安装前先退出正在运行的 App。App 正在运行时，可以先用 `DEST=<临时目录>/ExcalidrawZ\ Personal.app` 构建，经用户同意后用 `osascript -e 'tell application id "com.qingcan.excalidrawz" to quit'` 正常退出，再替换安装。
- **Swift 包**：本机从 github.com 用 git 克隆会被中途断开。`scripts/fetch-packages.py` 按 `Package.resolved` 从 codeload 下载源码包到 `build/LocalPackages`，生成 `build/ExcalidrawZPersonal.xcworkspace`，用本地包覆盖远程依赖。不要用 `-project` 直接构建，也不要跑 `-showBuildSettings`：都会去 git 克隆，然后卡住。
- **看 App 日志**：info 以上自动写到 `~/Library/Containers/com.qingcan.excalidrawz/Data/Library/Logs/ExcalidrawZ.log`（fix-local-save 起）。要 debug 级别：`open --env EXCALIDRAWZ_LOG_LEVEL=debug --stdout /tmp/xz-app.log --stderr /tmp/xz-app.log ~/Applications/"ExcalidrawZ Personal.app"`。
- **安全备份**：画布内容每 ≥30 秒另存一份到容器 `Application Support/SafetyBackups/<文件名>-<哈希>/`（独立于保存流程）；用户丢数据时先查这里。App 数据在容器 `Application Support/`（`ExcalidrawZ/*.sqlite`、`FileStorage/`、`backups/`）。
- **内核常用命令**（在内核目录）：`corepack yarn build`；`corepack yarn -s tsc --noEmit`；`corepack yarn -s vitest run <文件>`；`corepack yarn -s eslint <文件>`。格式化用 `node_modules/.bin/prettier --write <文件>`。**不要用 `yarn prettier`**：那是仓库脚本，会格式化整个仓库。
- 自建用到的本地文件（git 忽略、不提交）：`Config/Secrets.plist`、`build/`、`ExcalidrawZ/Resources/excalidraw-latest`。`Config/Overrides.xcconfig`、`scripts/`、`AGENTS.md`、`CLAUDE.md`、`tasks/`、`memory/` 虽在 .gitignore 里，但已用 `git add -f` 提交到 fork，之后的修改照常 `git add` 即可（新文件要 `-f`）。

### 自建版相对官方版的配置差异
- Release Bundle ID `com.qingcan.excalidrawz`；Quick Look 扩展 `com.qingcan.excalidrawz.QLPreviewExt`。
- entitlements 去掉 iCloud、推送、钥匙串共享组、App Group（免费账号用不了）；ad-hoc 签名，关闭 Hardened Runtime。
- CloudKit 关闭（`PersistenceController.swift` 强制关闭，并把 `DisableCloudSync` 默认值设为 true）；Sparkle 不启动；Release 端口 8497（避免和官方版的 8487 冲突）。
- 构建参数 `RECOMMENDED_MACOSX_DEPLOYMENT_TARGET=13.0`：Xcode 26 默认解析成 11.0，Quick Look 扩展会编不过。
- 已知日志、不用处理：`SyncCoordinator ... Local storage is not available`（实际是 iCloud 上传失败，本地保存不受影响）；`IMKCFRunLoopWakeUpReliable`（输入法框架）。

### 约定
- **分支**：两个仓库的定制版主分支都是 `custom`，构建、安装都从它来；只在用户要求时提交，推到 `fork/custom`，不推 `origin`。
  - 小改动直接提交到 `custom`；大功能先从 `custom` 开临时 `feat/<名字>`，做完合并回 `custom`、删掉临时分支（本地和 fork）。
  - 上游基准：App 是 `main`，内核是 `ExcalidrawZ-core`（fork 里是 `master`）。同步官方更新时把上游合并进 `custom`。
- ExcalidrawZ 特有的内核改动：逻辑放新文件，原有文件只加挂接点，并用 `// ExcalidrawZ:` 注释标记，方便以后同步上游。
- 内核代码风格：prettier + eslint（含 import/order），改完对改动的文件跑 tsc、eslint 和相关测试。tsc 也检查测试文件（vitest 不查）：写完测试要再跑一次，否则 `yarn build` 会失败。
- 网页侧的测试（jsdom、WebKit 截图）覆盖不到 Swift 解码：改了数据结构要单独验证 Swift 端能读。
- 看渲染效果、出对比图：写个临时 vitest 测试，用 `exportScene` 导出 SVG（`vi.mock` 可以替换常量；jsdom 量不了文字宽度，文字位置要自己算），再用 Chrome headless 截图。用完把测试文件移出仓库。
- 在 WebKit（App 用的引擎）里实测界面和交互：本地服务 `excalidraw-app/build`，用 WKWebView 小程序驱动 `excalidrawZHelper` 并截图（做法见 decisions.md 2026-11-01 feat-match-size）。

---

## 二、运行规则
# DO NOT MODIFY — human only
*（agent 只读、不改这一节）*

### 每次会话开始
1. 读 `AGENTS.md`。
2. 列出 `tasks/`（或运行 `scripts/status.sh`），看哪些工作是 `active` / `paused` / `blocked`。
3. 读要继续的那项工作的任务文件。
4. 浏览 `memory/decisions.md` 最近的几条。

### 工作记忆（`tasks/`）
- 每项工作一个文件：`tasks/<id>.md`。
- 保持 `status`、`updated` 最新；`## Next` 必须准确——它决定下次能不能直接接着做。
- 进度原地覆盖更新；任务文件反映现在，不记历史。

### 长期记忆（`memory/decisions.md`）
- **只追加**，不修改、不删除已有条目。
- 每条写：日期、工作 id、决定、原因、影响的文件。

### 什么时候写记忆
- 做了架构或设计决定 → 追加到 `decisions.md`。
- 发现隐藏依赖、坑、不明显的约束 → 追加到 `decisions.md`。
- 有实质进展 → 更新任务文件的进度和 `## Next`。
- 学到长期成立的项目事实（约定、结构）→ 提升进 `AGENTS.md` 第一节。

### 结束会话前
确认当前工作的任务文件里 `## Next` 准确写明了下一步，下一次会话不用猜。

### 控制体积
- `AGENTS.md` 保持在约 300 行以内；第一节变长时精简，把细节下沉到 `memory/`。
- `decisions.md` 太长时，把旧条目归档到带日期的文件（如 `memory/decisions-2026H2.md`）。
- `done` 的任务文件，在其决定都写进 `decisions.md` 后归档或删除。

### 禁止
- 修改本节（运行规则）。
- 修改或覆盖 `decisions.md` 里的已有条目。
- 让 `AGENTS.md` 无限增长——有选择地提升，定期精简。

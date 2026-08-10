# NextN UI 变更理由台账

这个台账记录可见 UI 的**理由和可追溯性**，不是静态合同、自动验收或视觉完成声明。
每次改动必须在代码改动前建立一条记录，并与该项 UI 提交一起提交。

## 必填字段

- 触发依据：明确的用户指令，或同状态、同视口的真实参考与设备证据。
- 父树边界：滚动宿主、固定/浮动层、节标题、容器、叶卡和状态转换的完整归属。
- 精确改动：原值/原树与新值/新树；不接受“调整一下”之类描述。
- 最小性理由：为什么不改相邻区域，以及 NH 不同的数据或能力边界。
- 验证计划：所需的当前设备和参考状态；构建或源码检查不能替代它。
- 若被否定：错误假设、忽略的证据、实际影响和禁止复发的约束。

## 计划中：Gallery Comments 的零评论首发入口

- 触发依据：当前用户目标要求应用可长期使用、按真实用户路径补齐未完成能力。当前 `GalleryCommentsPage` 的成功零评论分支直接渲染 `PageEmptyState`，而唯一的页面编辑器只在 `comments.length > 0` 时挂载；已登录用户因此无法发布该画廊的第一条评论。NextE 的完整 Comments 父树在空列表分支仍保留其页面编辑器；本轮已在选定设备对照已加载 Comments 页，未以该截图取代零评论状态的后续设备验收。
- 父树边界：`HdsNavDestination -> GalleryCommentsPage -> Column`。初始加载和初始错误继续保留原全页状态；成功已加载的滚动区继续由 `PullRefreshListScaffold` 拥有；现有已评论路径维持 `滚动区 + 固定页面底部 CommentComposer`。本改动只在“成功、当前 gallery、零条可见评论”状态下，把原空态放入可伸缩内容区并保留同一个固定底部编辑器。标题栏、顶层 Compose/Refresh 动作、卡片、List inset、键盘避让、评论提交、过滤、刷新和浮动 Read 均不改。
- 精确改动：原来 `comments.length === 0` 无条件进入没有 composer 的 `PageEmptyState`。改为仅在成功空态包裹 `PageEmptyState` 的可伸缩内容区后追加已有 `CommentComposer()`；首次加载或首次错误仍不显示 composer，避免在未解析当前讨论状态时提供写入入口。
- 最小性理由：不采用 NextE 的悬浮 composer，因为当前 NextN 的固定页面底部编辑器、无重复 in-page 标题均已有用户明确修正并冻结。只复用“讨论为空仍可发第一条”的能力语义，不移动既有编辑器或重组已评论的 List/card 父树。
- 验证计划：签名 Debug 构建后，用一个真实、已登录、成功返回零评论的 Gallery 路由验证：空态与固定编辑器同时可见，聚焦后编辑器仍位于键盘上方；不输入或提交评论。若当前设备没有该状态，不伪造响应、评论或本地数据，记录为未完成设备验收。
- 未决风险：内容过滤可将原始评论过滤为空；该状态不能错误地宣称是“可发表首条”的远端空讨论，因此编辑器只依据已成功加载当前 Gallery 与已发布账号会话，不根据 `rawComments.length` 推断远端数量。

## 回填：Gallery Detail / Comments 当前父树

## 已实施、待同状态参考对照：Browse Grid 极端比例封面 letterbox 背景

- 触发依据：2026-08-10 当前 Browse 设备画面中，极宽封面的固定 Grid cover 出现大块浅色空槽。NextE 的同一 `GalleryGridCard` 传入 `letterboxBackground: true`；其 `EhThumbnail` 在默认非模糊模式以封面主色渐变填充 Contain 留白，模糊只是可选替代。
- 父树边界：仅 `GalleryCollectionBody -> GalleryGridCard -> Cover` 的极端比例 Contain 分支。固定 Grid 几何、封面原图、角标、页数、标题、列表/滚动和全局“模糊背景”偏好不改变。
- 精确缺口：NextN 当前只在 `blurLetterboxBackground=true` 时画模糊底层；默认 `false` 时没有任何底层，露出 `COVER_PLACEHOLDER`。这把“背景样式选择”错误实现为“背景是否存在”。
- 最小改动理由：移植 NextE 默认主色渐变背景及现有可选模糊分支，不把 Contain 改为 Cover，不改变卡片尺寸或用户偏好含义。
- 当前设备观察：已构建、以 `install -r` 更新，并在同一 Browse Grid 的极宽封面上观察到 Contain 留白由封面主色背景层填充，不再是裸灰色；固定卡片尺寸、角标、页数和文字区域未变。原始截图保留在本地审计目录、排除在 Git 外。
- 未完成验证：尚缺同状态、同视口 NextE 参考画面对照，因此这不是完整视觉参考对齐声明。风险是主色提取失败时必须保持安全占位而不能阻塞封面或网络。
- 2026-08-10 19:35-19:36 +0800: an attempt to obtain a same-state NextE
  reference was made on the selected device. Launching the installed
  `com.erosteam.nexte` reference resumed its last Comments page; one native
  Back reached its Gallery category list (a different parent tree) rather
  than the same Browse root used by the NextN letterbox observation. No
  same-state extreme-ratio cover was obtainable without changing the
  reference app's visible or data state, and no such change was made.
  Therefore the same-state reference comparison remains unavailable and this
  item stays OPEN; the NextN device observation above is retained as-is.

## 计划中：Downloads 完成态全局动作可见性

- 触发依据：2026-08-10 当前 NextN Downloads 完成态设备画面显示“全部暂停”和“全部恢复”两个不可用的顶部菜单动作。NextE 的同一根标题菜单树固定保留搜索、排序和回到顶部，但仅当队列存在可恢复任务时插入恢复动作、仅当存在下载中任务时插入暂停动作（`NextE/entry/src/main/ets/pages/Index.ets:1141-1171,1200-1224`）。
- 父树边界：仅根 `Navigation -> HDS title bar -> Downloads title menu` 的菜单叶序列；下载页的 pinned group header、搜索、排序、任务卡、队列状态、批处理逻辑和滚动宿主不变。
- 精确改动：NextN 当前无条件把 Pause/Resume 两个 menu item 放进 `downloadMenuItems`，再以 `isEnabled=false` 表示无资格。改为始终保留 Search/Sort，仅在各自的 `pausableVisibleCount` 或 `resumableVisibleCount` 大于零时插入对应叶子，匹配 NextE 的条件插入树。
- 最小性理由：不改变可暂停/恢复的任务判定、桥接命令或可见任务过滤，只纠正无可执行操作时的标题菜单呈现；不触及下载卡片或导出入口。
- 验证计划：构建、`install -r` 后，在当前“仅完成任务”的同一 Downloads 状态打开菜单，确认无禁用的暂停/恢复项；之后仍需同状态 NextE 画面对照，才可宣称视觉参考对齐。
- 构建证据：2026-08-10 已完成签名 Debug 构建；构建通过不构成视觉验收。
- 未决风险：页面尚未报告最新 eligibility 时菜单必须保守地不显示批处理叶子；需要设备操作后确认正常下载/暂停状态仍会出现各自动作。
- 当前设备观察：已使用现成协作租约工具，仅在 `192.168.50.237:12345` 上 `install -r` 当前签名 Debug HAP。Downloads 完成态的实际 HDS 标题栏保留两个可用动作，未再出现禁用的 Pause/Resume 叶子。原始截图与原生布局保留在本地 `.hvigor/outputs/nextn-download-menu-20260810T1329+0800/`，未加入 Git。
- 未完成验证：尚未取得同状态、同视口的 NextE 画面对照，也没有在“存在可暂停或恢复任务”的真实状态下验证条件叶子重新出现；因此不得将此记录称为完整视觉参考验收。

## 计划中：Downloads 失败 bootstrap 的普通重入

- 触发依据：用户已明确指出普通页面切换不应自动重新加载。当前 `DownloadQueuePage.ensureQueueForAppearance()` 在 `queueBootstrapResolved=false` 时无条件调用 `bootstrapQueue()`；而失败 catch 会持续保留该 false 值，因此一次失败后的隐藏/显示会重复 durable restore。NextE 的 `DownloadQueuePage.aboutToAppear()` 只重建本地 projection，不发起 restore（`NextE/feature/download/src/main/ets/pages/DownloadQueuePage.ets:121-125`）。
- 父树边界：仅 `Root Downloads tab -> DownloadQueuePage` 的出现生命周期与既有错误重试入口。HDS 标题、pinned header、队列 ListItemGroup、任务卡、搜索/排序、导出和队列服务均不改。
- 精确改动：在现有 `resolved/inFlight/generation` 三个 bootstrap 字段之外增加“本页已尝试 bootstrap”状态。普通 `aboutToAppear` 只在从未尝试时启动 restore；失败后保持错误状态。用户显式 Error Retry 仍调用既有 `bootstrapQueue()`，允许一次新的 durable restore 尝试。
- 最小性理由：不改变 `DownloadQueueService.restore`、存储、任务状态或成功后的 projection；只移除普通重入对失败恢复的隐式重试。
- 验证计划：签名构建后，在不清数据的真实设备上制造不了的 queue restore 失败不予伪造；须等待真实失败状态，再验证 Browse→Downloads 普通返回不触发 loading/restore，而 Error Retry 才重试。构建或源码检查不构成该行为验收。
- 未决风险：当前设备有可用队列，不能安全地人为破坏持久化来覆盖失败支路；该边界在真实失败发生前保持未验收。
- 构建证据：2026-08-10 签名 Debug 构建成功，并以 `install -r` 更新唯一选定设备；未清数据。
- 当前设备观察：更新后从 Browse 正常进入原生 Downloads（标题“下载”、一个原生 List）。这仅排除了该更新对当前正常路由的即时破坏；失败 bootstrap 的普通重入边界仍未被真实设备触发。

### 6b816a2 — Detail 与 Comments 初始重组（未验收）

- 改动：引入 Detail 的 Related/评论预览 rail 与全评论页的局部布局重组。
- 当时问题：把“有参考可复用”错误地当作可以自行决定 rail 尺寸、卡片层级和评论呈现的授权；没有先完成每个可见区域的同状态对照。
- 影响：随后出现了 Related 高度、预览比例、评论预览卡与完整评论页多处反复改动。
- 约束：此父树仍为 OPEN；未来只可按单一用户指出区域和完整父树证据窄改，不能再用一项局部观感推导相邻区域的重构。

### 6ffafa3 / 99ca471 — Detail 横向评论预览卡高度

- 改动：6ffafa3 把原固定 `120vp` 改为按“两行文字”计算的 `82vp`；99ca471 已恢复为 `120vp`。
- 错误假设：把详情页外露评论误判为应该仅容纳两行文字的辅助信息，忽略了它仍是可阅读的横向评论卡，也没有对应的用户指令或参考证据。
- 影响：详情页评论预览显得被压扁。
- 防复发：评论 rail 的固定高度、宽度、字体和行数只能作为一个整体由同状态视觉证据调整；不得由文本行数公式单独压缩容器高度。
- 验证状态：99ca471 已构建并安装；当前设备复核仍 OPEN，且不把孤立截图称为参考对齐。

### 4bdd450 — Related rail 尺寸和卡面

- 改动：改变 Related 的 cover/card 尺寸与卡面容器，并让横向 rail 的视口穿过二级容器内部横向 inset。
- 依据与边界：用户明确要求横向 List 的中段延展感，且首尾留白归 List 首末项；标题和垂直间距不得跟随 List 扩展。
- 未完成处：卡片高度、标题可读性与封面比例必须由用户的当前视觉反馈和同状态参考共同决定；不得把“横向延展”误扩展成缩窄标题或压低卡片。
- 验证状态：当前设备已确认中段不被父容器内部横向 inset 裁断；完整视觉对齐仍 OPEN。

### ad136cb / 03ae7f2 — Compact Preview 高度

- 改动：ad136cb 曾把 compact preview 从 `150vp` 改为 `175vp`；03ae7f2 随后恢复 `150vp`。
- 错误假设：把 Related/Preview 的相对协调错误简化为增大 Preview；忽略了用户已经指出 Preview 不应与 hero/Related 同高。
- 防复发：Preview 的 `150vp` 是当前基线。没有新的明确用户指令和同状态对照，不得再修改它。

### 323b227 / f0db93b — Full Comments 卡片重构与回退

- 改动：323b227 对完整评论卡作了泛化重构；f0db93b 已完整回退该重构。
- 错误假设：在 NH DTO 不支持参考中的全部叶信息时，擅自用通用卡片树补齐视觉，而不是保留参考父树并仅替换不支持叶。
- 防复发：完整评论页只能按 NextE 的滚动宿主、标题、独立 CommentRow 和固定 composer 逐层复用；无 DTO 支持的 avatar/vote 等叶不能伪造。

### 14a3970 / f5826ed — Full Comments 内容 inset 与 composer 停靠

- 改动：14a3970 增加 CommentCard 内容 inset；f5826ed 将 composer 固定在 List 之后的页面底部，而非覆盖内容。
- 触发依据：用户明确指出文字贴近圆角；当前设备截图曾显示 composer 覆盖内容风险。
- 父树边界：全评论页为 `Column -> 可滚动评论区 -> 固定不透明 composer`；composer 不属于详情页 Read 浮层，也不改变 Detail 的浮动阅读按钮。
- 验证状态：当前设备已见固定 composer 未覆盖评论，但与 NextE 的同状态视觉对照仍 OPEN。

### 现行约束

- 详情页 Preview、Related、横向评论预览和 Read 浮动按钮视为四个独立边界；任何一项反馈不得顺带改动另外三项。
- 对可横向滚动的 rail：只允许 List 视口跨越二级容器的横向内部 inset；标题、父卡、上下间距、首尾空白不随之移除。首尾空白属于第一/最后一个 ListItem。
- 对浮动 Read：中途内容从下方经过是设计语义；只检查终端内容是否仍可滚到其上方，不得因为正常中途遮挡添加边距、移动或隐藏浮动按钮。

## 计划中：Gallery Comments 固定编辑器的键盘态底部 inset

- 触发依据：`61f0c7b` 的零评论首发入口已在选定设备的成功空态显示固定编辑器。随后聚焦该 TextArea 的最新本地证据显示，键盘出现后编辑器与发送按钮的原始底部有 36px 落入键盘：`after-focus.layout.json` 的可见 bounds 高度为 68px、原始高度为 104px。当前 `GalleryCommentsPage.composerBottomPadding()` 在 `KeyboardAvoidMode.RESIZE` 下返回 `0`；NextE 同一方法在键盘态返回 `COMMENT_COMPOSER_OUTER_GAP`，即其 `SPACE_SM`。
- 父树边界：`HdsNavDestination -> GalleryCommentsPage -> Column`。成功空态是一个可伸缩的 `PageEmptyState` 内容区，随后是固定、不透明的 `CommentComposer` 页面页脚；有评论时仍是 `PullRefreshListScaffold` 可滚动区加同一个固定页脚。系统键盘由窗口 `keyboardHeightChange` 发布，`KeyboardAvoidMode.RESIZE` 收缩这一根 Column 的可见高度。标题栏、评论 List、卡片、Detail Preview、Related、横向评论预览、Read 浮层、TextArea、发送动作和提交状态都不变。
- 精确改动：仅将 `composerBottomPadding()` 的键盘态返回值从 `0` 改为 `ThemeTokens.SPACE_SM`；无键盘时继续返回 `bottomAvoidHeight`。不读取或套用整个 `keyboardHeight`，避免在 RESIZE 已收缩窗口时重复避让。
- 最小性理由：36px 的实测截断与本设备 `SPACE_SM` 的物理高度相符，且与 NextE 的同一键盘态外间距一致。它只恢复固定页脚在已收缩可视区内的完整高度，不改变用户已冻结的“固定而非浮动”的 composer 树，也不改任何评论/详情几何。
- 验证计划：签名 Debug 构建并以 `install -r` 更新选定设备后，使用既有零评论直达路由，聚焦一次空 TextArea、不输入、不发送；保留新的本地截图和脱敏 bounds，确认输入与发送控件完整位于键盘上方。构建不构成此视觉验收。
- 未决风险：系统若在不同窗口模式报告不同的键盘缩放比例，`SPACE_SM` 可能不足或过量；该风险只通过同一路径的真实键盘状态判断，不扩展为 `keyboardHeight` 全量 padding 或重组页面树。
- 当前设备观察：签名 Debug 构建后已仅以 `install -r` 更新选定设备。零评论直达页加载完成后，空 TextArea 被聚焦一次；键盘显示时，输入框和发送控件均完整地处于键盘上方，TextArea 的 visible bounds 与 origBounds 均为完整的 104px 高度。没有输入文本、没有提交评论。该结果仅覆盖 NextN 这一个键盘态；同状态 NextE 参考画面尚未取得，因此不作为完整参考视觉对齐声明。

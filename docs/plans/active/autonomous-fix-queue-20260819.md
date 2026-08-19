# NextN 自主推进任务队列（2026-08-19 晚，用户入睡前下达）

> 用户指示：记录到文档、排好工作、期间不要确认，自主推进。
> 当前会话会按顺序执行；每个 UI 变更先登记 nextn-ui-change-ledger.md，
> 涉及设备验证的走 device-lease + AWAKE/OverrideTimeout 门禁。
>
> **状态符号（每次改动后必须立即更新，防止上下文压缩后重复验证）：**
> - ✅ VERIFIED = 已真机验证（含设备与证据）
> - 🔶 IMPLEMENTED = 代码已实现/构建通过，尚未真机验证
> - ⬜ TODO = 尚未实现

## 执行顺序（当前）

1. ✅ VERIFIED 搜索/快捷搜索翻译开关（56T0225315001128：默认开→译文显示、按钮 BRAND；点击→译文消失、按钮 tertiary；重启保持关闭）。
2. 🔶 IMPLEMENTED→当前任务 黑名单生效 + 标签高度/长标签（代码已改：GalleryTagStrip/WaterfallCard/WaterfallCompactCard lineHeight、NhTagSuggestionDisplay、ContentFilterService/NhApiClient blacklisted 过滤），待真机复核。
2. 🔶 IMPLEMENTED→部分验证 黑名单生效 + 标签高度/长标签：标签高度 ✅ 真机复核（⚣/💏/👓 芯片 66px 同高，见下方补充证据）；云端黑名单本地过滤已实现（NhCloudBlacklistService + /api/v2/blacklist/ids + 解析期与渲染链路双重过滤，构建通过），端到端验证被账号会话缺失阻塞（ArkWeb 401、收藏页未登录）。
3. ✅ VERIFIED 首页排序标签不随选项更新 + 语言条件标注 + “全时热门”文案（56T0225315001128：HomeSourceBar 今日热门（中文）；SubTabBar key 修复；zh_CN 全部热门）。
4. ⬜ TODO 跳页功能：照搬 NextE 排行榜翻页逻辑与 UI，应用到 NH 分页搜索/浏览。
5. 🔶 IMPLEMENTED 缩略图页标题文案去掉“页面”二字（title_pages 四语：缩略图/Thumbnails/サムネイル），未真机验证。
6. 🔶 IMPLEMENTED 全部缩略图页支持双指捏合改变密度（THUMBNAIL 独立密度槽、GalleryColumns base 112、BrowsePresentationState/Repository 持久化），构建通过，未真机验证。
7. ⬜ TODO 相关画廊封面加载前底色与详情页底色区分（避免看起来像没有封面）。
8. 🔶 IMPLEMENTED→待改 评论翻译并发数过低（已定位 GalleryCommentsPage.autoTranslateComments 串行 for+await，约 262-278 行；CommentTranslationService 无并发池）。
9. ⬜ TODO 历史进入详情页时标签区域闪英文再变中文：定位缓存/翻译时序。
10. ⬜ TODO 阅读器连续纵向模式对已下载画廊宽度不满屏（本地读取路径问题，用户明确必须处理；按顺序排在最后）。

## 各任务备注（用户原话摘录）

### 1. 搜索翻译开关
- 用户：“还有就是这个翻译不能切换的吗？默认是翻译的吗？没有完整的移植NextE的切换”
- 已实现：SearchTranslationState/Settings、SearchTranslationButton、快捷搜索译文行。
- ✅ 真机验证（2026-08-19，56T0225315001128）：默认开→译文显示、按钮 BRAND；点击→译文消失、按钮 tertiary；重启保持关闭持久化生效。

### 2. 黑名单 / 标签高度验证
- 用户：“验证好前面说的那些问题，包括黑名单，还有标签的高度这一些”。
- 黑名单：NH 云端黑名单 tag 屏蔽画廊（客户端已做 ContentFilterService，需真机确认生效）。
- 标签：长标签不截断、纯男性⚣/纯女性⚢ 不撑高（代码已改，需真机复核）。
- 代码状态：ContentFilterService 本地规则 + NhApiClient 云端 blacklisted 过滤；GalleryTagStrip/WaterfallCard/WaterfallCompactCard 已加 TAG_LINE_HEIGHT。
- 下一步：真机复核黑名单过滤 + 标签不撑高。

### 3. 首页排序标签 / 语言标注 / 全时热门文案（2026-08-19 夜间新反馈）
- 用户：“在首页我调整了排序为今日热门或者其他非最新的之后，标签上显示的还是最新，
  这样子根本就让用户看不出来有进行过选项切换，包括是否应该把语言条件也标注出来呢？
  体现在标签名字上，比如说不限语言就不显示，然后其他的日语、中语、英语、翻译，
  就带括号显示在名字后面。还有这一个全时热门，感觉有点拗口，是不是改一下更好”
- 目标：首页“最新/热门”标签随排序同步更新；语言非不限时在名字后括号标注；
  全时热门文案优化（参考 NextE/常用叫法，避免自创拗口词）。
- ✅ 真机验证（2026-08-19，56T0225315001128）：设置今日热门+中文后首页显示“今日热门（中文）”，冷启动恢复；SubTabBar ForEach key 追加 label 修复文字不刷新；zh_CN 全时热门→全部热门。

### 4. 跳页功能
- 用户：“NextE 因上游的缘故，非排行榜的跳页是通过日期跳转的，但排行榜是正常带有页码跳转的。
  而 NH 是可以正常通过页码跳转的。所以可以照搬 NextE 的翻页逻辑，也就是排行榜那边的翻页逻辑以及 UI。”
- 范围：搜索页/首页/收藏等所有 NH 分页面。

### 5. 缩略图页标题文案
- 用户：“缩略图页的标题文案写了页面两个字，我刚刚才发现怎么这么怪？”

### 6. 全部缩略图页双指捏合密度
- 用户：“全部缩略图页不支持通过双指捏合改变大小密度。”
- 需要参考 NextE 是否有缩略图密度手势，或沿用列表密度 Slider/手势体系。

### 7. 相关画廊封面底色
- 用户：“相关画廊的封面，加载前的底色似乎跟详情页的底色几乎一样，导致可能分不出来，
  看着就像一开始没有封面一样，只有那个加载图标。”

### 8. 评论翻译并发数
- 用户：“评论翻译的并发数，你到底是设置成多少啊？我这翻译速度超级超级慢啊，
  一个一个一个一个的请求啊。”
- 需要检查 CommentTranslationService 的并发限制并提高/并行化。
- 已定位：GalleryCommentsPage.autoTranslateComments 为串行 for+await（约 262-278 行），CommentTranslationService 本身无并发池。
- 方案：改为有界并发（如 3-5 个 Promise.allSettled 批次）。

### 9. 历史进详情页标签闪烁
- 用户：“从历史进入详情页，虽然标签翻译有效了，但是为什么标签区域会闪一下呢？
  看起来就像是会闪过英文的状态，然后才变成中文的标签。”
- 与 INC-001/002 同一链路，需确认历史路由 seed 标签是否带翻译。

### 10. 阅读器连续纵向宽度不满屏（2026-08-19 夜间新反馈，P0）
- 用户：“阅读页下的连续纵向这一个设计完全就是瞎写出来的，根本没有按照NextE的写法。
  我现在实测宽度莫名其妙的被限制在不满屏的状态，到底为什么会这样。好像是本地读取这一个路径有问题，
  对于已下载的画廊就会存在这一个问题，这个必须处理”
- 目标：对照 NextE 连续纵向布局与本地文件读取路径，修复已下载画廊宽度不满屏。
- 已初步定位：ReaderImagePage imageAspectRatio() 依赖 DTO imageWidth/imageHeight，失败回退 1；ReaderVerticalFlow/ReaderPagedFlow 传 localImageUri + width/height；DownloadQueueService.localPageUri 返回 file:// URI。待继续比对 NextE 几何并修复后真机验证两个模式。

## 约束
- 未获明确“提交”指令前不提交；用户已授权自主实施与真机操作。
- 不随意删减 NextE 功能；UI 变更先记账。
- 账号/凭据不出现在日志与文档。

### 2 补充证据（2026-08-19 06:1x-06:3x，56T0225315001128）

- 日志域 0x0000→0xE001 修复后 NextNAccount 日志可见（此前系统保留域静默丢弃）。
- 冷启动 account-preferred 读取 200，但 `/api/v2/galleries?page=` 与 `/api/v2/search?sort=popular-today` 解析均为 `blacklisted_skipped=0`；今日热门列表仍渲染含「纯男性⚣」标签的画廊（[酒ノ肴竿門] パワハラ美人上司♂…，tag 纯男性⚣/男同）。
- WebView DevTools（@webview_devtools_remote_34086，页面 https://nhentai.net/）实测：`/api/v2/user` 与 `/api/v2/blacklist/ids` 均 401；收藏页显示“请在设置中登录以查看收藏。”→ 账号会话缺失，服务端不标记、客户端也取不到云端黑名单。
- OpenAPI（https://nhentai.net/api/v2/openapi.json）确认 GET /api/v2/blacklist/ids 返回 `[int]`（与画廊 tag_ids 同 id 空间）。
- 落地实现：NhCloudBlacklistState/Repository/Service + NhApiClient.cloudBlacklistIds()（ACCOUNT_OWNED_NON_RETIRING，401 不退休账号）+ 10 分钟 TTL 后台刷新 + parseGalleryPage/popular 解析期过滤 + ContentFilterService.filterGalleries 追加黑名单谓词（覆盖缓存冷启动）。构建通过。
- 标签高度：固定高度 Column + clip 后，纯男性⚣/接吻💏/眼镜👓 芯片与普通标签同高（实测均 66px，修复前 ⚣ 为 69px）。✅ 真机验证。
- 黑名单端到端过滤验证被账号会话缺失阻塞（无凭据不能重登用户个人账号）；服务端标记在已登录 Browse 上 2026-08-18 已验收。账号会话问题属长期 P0，已另行记录。

# 共享阅读器：预处理与图片生命周期

## 缩略图到原图交接（2026-10-24，4bf42eb具名验证）

- **失败保留**：E022第120帧仍是放大低清图且进度已退；原4a4659d的交接接受结论撤回。它只修复请求等待期，解码回调时entry仍把原图opacity设为0。旧录屏与CI保留，不能抵消该反例。
- **共同修复**：4bf42eb由现有entry的匹配页/slot/load和原图透明度决定隐藏期；解码后仍隐藏时保留加载反馈，原有reveal放行原图时一同退出。没有新宿主遮罩、延时或转场/样式/缓存改动；保留可读旧图及终止错误的既有分支。反例检查先失败，修改后相关43项及全536项通过。
- **197普通入口**：N38202032B/1.0.7code10与E38178566B/1.3.6code42均明确安装。E027实际Non-H4277955全151帧/5联系表；N032实际Non-H686734全269帧/8联系表，均按顺序亲审并另看原91/92：91低清预览+原加载面板，92清晰原图且面板退出，正常返回同缩略图。E022误判不再沿用；只接受这两个具名入口。
- **构建与边界**：N/E/K签名Release完成；K没有entry preview输入，仅构建不称K缩略图验收。E现有CI preflight通过。其他模式、Legacy和自然异常未由本轮接受。原件沿NextN `.hvigor/outputs/reader-loading-background-20261011/.../shared-mutual/thumbnail-reveal-*`，命令/原始PTS/全部解码帧保留，哈希关闭。
- **状态**：共同Kit及N/E精确提交同步待收尾；唯一未完成队列仍是Koma CURRENT_STATUS.md。N033已普通返回原Downloads、原686744仍2/2；034已正常返回E画廊与Koma原书架，原4212986未操作。

## 缩略图加载反馈退化（2026-10-24，旧4a记录，交接结论已撤回）

下列旧帧判定已被用户反例否决；当前结果见上方4bf具名验证。

- 用户报告NextE/NextN缩略图进入无加载反馈，明确允许必要的共同状态重写。3a7b56d将预览可见误当成关闭加载的条件；其测试还要求`preview.loading=false`。旧普通Read样本不能接受缩略图入口，此错误预期已撤回。
- 共同4a4659d从`ReaderImagePresentation`移除预览输入及中间透传，原图请求/当前解码身份决定反馈；低清预览仍保留。指示器、背景、原图互斥、转场、系统栏、缓存和偏好保持。先复现旧方法失败，再修正，Kit全536项通过；N/E/K签名Release成功。
- 197（ALN-AL80，竖屏1260×2720）：旧N688588/009与旧E4277842/019实际等待均无提示。修复N686370/014全255帧、E4277864/022全189帧已按序亲审；N41–81、E85–119有原加载面板，N82/E120起原图无加载层，返回原缩略图正常。原始60/82及85/118/120另审；未清缓存或制造延迟。E源manifest预期4277811，实际列表更新后进入4277864，以运行日志和原片为准，保留原回执。
- N明确覆盖38202576B/1.0.7/code10，E38170923B/1.3.6/code42。N016恢复原686744的2/2；024再确认原7项下载及2/2并返回Koma原书架。023误写N包名只停在E，未作为恢复证据；024使用AppScope真实包名纠正。无偏好修改，E原4212986未读动。
- 本次只接受以上普通入口加载/原图/返回，不外推Legacy、其他布局、取消或错误分支；K无缩略图输入，移除此判断不改变其原行为，只有本次构建。范围推送及精确宿主CI继续，唯一队列仍为Koma CURRENT_STATUS.md。

## 当前重开：图片与加载显示必须互斥（2026-10-20）

- 用户当前明确要求：图片与加载进度在任何加载路径都不得同时显示；NextE 普通阅读按钮进入首图已出现反例，NextN 未观察到不能代替共同不变量。
- 已定位公共回归：`9791242` 抽出 `ReaderImagePlaceholder` 时移除了分页、连续流原有的当前解码身份判断，改等较晚的 session `displayed`；原生图片可先绘制。修复在共同 Kit，宿主不得各补遮挡层。解码回执与稳定呈现回执继续分工，资源、手势、进度、转场几何和用户偏好保持。
- 当前 owner 为 Root；先统一共享呈现决定及全部调用方，再做具名检查、适用宿主构建和197普通入口连续取证。已有 N/E 无关 WIP 保留。不以缓存区别限定此要求，不以旧有限通过覆盖当前反例。
- 当前共同实现：一个私有 `loading/preview/image/empty` 状态同时投影图片可见性与加载层；当前解码身份经过请求、槽、源页、切片及视觉代际匹配，稳定呈现回执不再延长加载层。保留旧图时不重开加载遮挡。入口目录阶段也抑制与已有预览并存的加载组件。
- `ReaderSurface.openingPlaceholder` 任意 Builder 已改为 `ReaderOpeningPreview` 借用像素、矩形及透明度数据；图片由共享层绘制。E/N仅改这一个现有消费输入，原几何、动作和所有权保持。七份共同生产文件在两个现有消费目录逐文本核对无差异，未做哈希。未创建工作树、源码副本、辅助脚本或报告。
- 首次构建阶段45项相关生命周期检查通过；E/N最终Debug签名构建通过，K当前最终构建亦完成进程退出0。V1扫描E632与N476文件均0项；N所引脚本本地缺失，采用E现有同一扫描器仅替换扫描根在内存运行，没有新增或改写检查器。该阶段只有源码和构建证据，后续安装及实机结果单列如下。
- 设备边界已更新：用户明确拒绝助手提出的“保持工具原样、实机暂缓”选项，不能再把该选择作为停止依据。当前 checked 执行器已有关闭摘要计算的设置；本次全程使用 `HARMONY_DEVICE_ARTIFACT_HASHES=0`，实际回执为 `artifactHashesEnabled:false`、摘要字段 null，保留 target、租约、manifest/action 校验。产物摘要不参与互斥判定，也不是验收标准。Koma 分类验收因任务切换暂停，末次错误落到电话应用，分类是否创建未核实，后续需正常入口核实及清理。

- 实现与部署：补上 `ReaderPagedSession.open` 保留旧帧时的目录层遗漏；分页目录层仅在空视图显示。六套相关生命周期检查135项通过，N/E/K Debug签名构建成功。Kit本地提交 `3a7b56d`，N/E消费同一提交；宿主检查点 N `7e6ad50a`、E `cdc03d52`。197正常保留数据覆盖安装 N1.0.7/code10、E1.3.6/code42，版本读回吻合。没有新分支、工作树或源码副本。K普通入口仍为自有ReaderPage，本次K构建不接受普通共享阅读路径。
- 197普通入口实证：设备ALN-AL80、竖屏1260×2720；E从已完成Non-H4212986封面进入详情，点“继续P13”，13→14→13后Back；N从已完成Non-H686744封面进入详情，点“继续P2”，2→1→2后Back。连续原片分别695帧/16.576秒及210帧/16.875秒；全区间按序审阅，进入边界另看原分辨率帧。E frame22/PTS0.368911只有中央准备层，frame23/0.385844正文已出现且准备层退出；N frame25/0.412678只有准备层，frame26/0.469正文出现且准备层退出。后续翻页、返回及稳定详情没有中央图片加载层覆盖正文。页码在翻页动画中稍后更新，未声称与运动中间帧逐帧一致。
- 原始证据：本仓 `.hvigor/outputs/reader-loading-background-20261011/device197__ALN-AL80/not-applicable/portrait-1260x2720/shared-mutual/` 下 `nexte-ordinary-read-roundtrip-001/` 与 `nextn-ordinary-read-roundtrip-001/`，各含原片、命令、原始PTS、全部解码帧及联系表。系统录像为890×1920，非原生1260×2720逐刷新捕获；未清缓存、不造延时、不上传翻译、不改偏好，不能冒称全无缓存、所有布局/Legacy/异常重入均已实机通过。
- 场景恢复：最终普通返回NextN下载页，仍为原7项已完成；未改阅读偏好或数据。`timeout -r`读回AWAKE、系统Timeout=120000ms且无OverrideTimeout，197租约已释放。恢复回执在同根 `shared-session-restored-001/`。
- 当前判定与下一动作：本次两个普通具名路径的中央图片准备层互斥通过；全局不变量由共同实现负责，未观察布局仍未获实机接受，不以次数填补。Root接回Koma当前工作单中的完整图标质量与App普通路径；本条局部通过不构成首版整体完成或发版许可。

## 2026-10-14 原 WIP 的本地保存

用户要求处理 N/E 未提交材料。原两份 geometry 源码字节保持，NextE Kit 保存为 `01ef0b0f`、宿主 pin 为 `7308e802`；b744 NextN Kit 保存为 `c5a9a48`、宿主为 `272d4229`。主 NextN Kit 仍 `842a5ea`，Koma 原 Kit WIP 未改。历史候选在独立 WIP 分支保存，具体基线、提交与精确 diff 见[处理记录](../../../.hvigor/outputs/uncommitted-review-20261014/review.md)。这些提交不接受未验证路径、不复活旧方案，也不改变下文原具名包的运行证据。

当前优先事项来自用户的新反馈：NextE 翻页时超分状态短暂回到原始状态；NextN 没有相同的超分预处理。共同处理链及N/E适配已实现，三份签名Release已实际部署197。N新Non-H686744、E4212986和K原图消费者取得下述有限原生证据；共同目标仍OPEN，未观察的服务/布局/在途取消不能由这些命名区间替代。

## 为什么这次只有 E 改动

NextE `fa6ee0f540e03359516b043c4aecbc44ac260050` 的十二个文件全在 E；[issue #12 记录](/Users/honjow/git/NextE/docs/plans/completed/reader-image-preprocessing-issue12.md:22)明确把 Kit、NextN、Koma 排除在实现变更外。它接受的是 E 命名页的提前处理和结果复用，不能接受整个翻页过程中图标不闪回，不能证明 N/K 获得该功能。历史记录说明当时的实施边界；无法据此推断隐藏意图或所有此前测试都无效。

| 当前层 | 已共享的职责 | 当前缺口与来源 |
| --- | --- | --- |
| reader-core / ReaderPagedSession | 页与单元身份、展示映射、请求代际、可见资源窗口、滚动预加载目标、变体 plan 与替换保护 | preload 是不透明的宿主回调；prepareVariantForSource 要求已有 displayed frame，未显示文件的处理和结果采用不在同一模型 |
| reader-ui / ReaderSurface | 分页/连续呈现、手势、占位、变体选择、共同控件 | displayed 后再异步选择 preferred variant；图标读取 anchor 下当前 frame.variant，处理缓存并不作为该帧首次绑定的输入 |
| E 宿主 | 原图获取、处理后端、配置/进度/平台桥接 | NextEReaderProcessingPreloadHost 另持 demand/revision/active/cancellation；Page 另持自动翻译队列状态；同类行为留在宿主 |
| N 宿主 | 原图获取、既有 SR/翻译后端、配置/进度/平台桥接 | 只把 adapter 作为 preloadHost；SR Provider 依赖已 load 的 sourcePaths；自动翻译等下一页 displayed，仍有宿主轮询 |
| K 宿主 | 当前原图、裁边、目录/下载/进度与平台桥接 | 没有 SR/翻译 Provider；不能显示或声称具有这些能力；共同原图/生命周期改动仍会影响 K |

处理服务也不等价：E SR 有当前/后台优先级、合并与提升；N SR 有结果缓存、in-flight owner 合并和释放，但没有这套优先队列。复制一段 preload 调用无法统一完整行为。

## 共同 owner 的具体设计

参考：Kit 当前 ReaderCancellation、ReaderAsset 的 release/information/crop 能力、ReaderVariantAssetPlan、ReaderPagedSession 资源窗口；保留 N/E 原后端与 Legacy API。
主信息：原图文件可用、处理结果可用、候选解码、当前请求实际呈现是不同状态，不能用其中一个代替其余状态。
动作：保留现有翻页、原图/处理图切换、设置、翻译会话确认、保存、进度与返回动作。
闭环：一个共同处理协调器从文件准备一路负责需求调度、结果保留/采用与退休；N/E 都注册已有能力，K 注册实际原图能力。
Harmony 表达：现有 ArkTS/V2、ReaderAsset 文件租约、既有处理服务及 native presented 回调；文件预处理不额外挂载屏外 Image，不扩大 native 窗口。

1. **统一输入与身份。** 共同文件准备接口取得有租约的 ReaderAsset，包含原文件 identity、保存来源及可读取的 header/crop 信息；不依赖已显示图片的 sourcePaths。任务身份由 unit/page、文件内容版本、processor/config revision 和目标 variant 构成。槽位/request/导航代际负责投影有效性，不能让同一页仅因换槽位重复处理，也不能把旧内容套给同编号新页。
2. **统一需求与任务生命周期。** reader-core 中的处理协调器消费现有滚动目标、当前页和已明确启用的下一页翻译需求；实现有界准备、相同任务合并、前台提升、撤出窗口与关闭/后台/配置变化的取消。一个任务可被多个 reader demand 持有，只释放本 owner；最后一个 owner 退出才退休任务。底层硬件/服务的串行与取消能力显式注册，保留 E 现有共享 Legacy 硬件队列，N 接同样的优先需求协议，不建立每个 App 各一套页级调度器。
3. **统一原文件到变体 plan 的准备。** 原图缓存/I/O、image-block 策略先确定可处理输入；裁边元数据可从文件读取；SR 与翻译是不同可选 variant，不擅自把翻译输入改为超分结果。保持当前各处理服务的输入语义、页归属、失败码与费用授权。E 的 file-header 获取、排队取消和 retained-file 释放纳入适配协议，N 也必须覆盖这些接口，不能保留 displayed 轮询作为预处理入口。
4. **统一结果采用。** 后台完成的 plan 保留在同一页级记录；展示槽位绑定时先核对当前 preference/config 和可用 plan。已准备好的所选变体直接作为本次候选，不先提交默认原图再补一次异步切换。若该页处理尚未完成，现有原图仍可读；处理结果成为新的候选，只有当前代际 presented 确认后才能接管。用户选择原图、换设置或离开时，晚到结果不得覆盖选择。
5. **统一状态投影。** 页级处理记录区分 unavailable/disabled、queued/processing、ready、binding 和实际 presented；ReaderSurface/Chrome 从同一个当前 page/request 记录取状态。HD applied 只表示当前实际增强呈现，ready 不能冒充 applied。待采用的增强候选不伪装成一次新的“未启用/原始”状态；不沿用上一页 applied，不用延时、定时器或图标隐藏掩盖错误。图片占位仍仅属于未呈现图片；处理活动不会复活图片占位或驱动其背景。
6. **明确宿主剩余职责。** N/E/K 保留数据获取、native/服务执行、配置持久化、翻译权限/费用确认、进度写入、宿主菜单和平台 Window/路由桥接。它们传配置与 activity/close 信号；共同组件自行管理内部 task/asset/selection 生命周期。移除 E 页级 PreloadHost 调度和 N/E 自动翻译 displayed 等待，只留下输入/执行适配。翻译设置和已确认的会话范围不扩展。

## 实施顺序与保留边界

先保留当前197普通阅读的真实反例，记录实际安装包、设置、当前页与未来请求；再按上述协议实现共同层，随后同时接入 N/E，而不是交付一个 E 专属候选后把 N 写成“间接无影响”。可形成多个 scoped checkpoint，但同一共同能力没有两个宿主采用和各自原生证据前保持 OPEN。

当前真实依赖：N host17a53314 / Kit3c7ffce且Kit干净；E hostb6afb695 / 同Kit3c7ffce并有 ContinuousSurface、PagedViewport 两份原 WIP；K host813cf765 / Kit05542ecf并有 ContinuousSurface、PagedViewport、PagerSurface 三份原 WIP。三者是不同目录，不是一个物理 checkout。共同候选按相同 commit/source slice 绑定，并逐份评审保留的 diff，不能用覆盖、reset 或更新 pin 吞掉已有修复。

K 不自动新增超分/翻译模型或设置；本次在共同协议中按真实 unavailable 能力运行原图，并审查共同加载、裁边、进度与保留原图影响。共享能力代码进入 K 不等于 K 的产品能力已实现。Legacy 和共享处理服务的调用者都纳入间接影响，不改已接受入口几何、菜单布局或持久化格式。

## 当前实施与证据（2026-10-12）

共同 `ReaderProcessingCoordinator` 已进入N/E/K相同六文件：有界页级准备、当前优先、相同任务合并/提升、配置与单位变化退休、独立文件/原生槽位租约、首次绑定采用ready plan。N/E宿主页级自动翻译调度已移除；N SR/翻译从租用原文件启动，未来页无需displayed；E私有ProcessingPreloadHost已删除，仅保留SourcePreloadHost文件适配。N native队列与Legacy共享执行，已运行任务不承诺立即抢占；E保留已有硬件服务行为。K只接实际原图能力，没有擅自新增SR/翻译。

本地Core原73、新5共同生命周期及N/E四Provider检查通过；N零catalog尺寸翻译从文件header读取，串行取消未调用服务。K055旧基线另缺两个现有公共占位生命周期方法，11行同源API补齐后Core78/78，未更改几何/状态策略。三签名Release成功；N `3ff06568`1.0.7/code9、E `4395e6be`1.3.6/code41、K `6703338b`0.1.0/code1均通过checked manifest实际安装和native readback。精确源/包绑定及六份原geometryWIP保护见ignored artifact root；K原AppWIP保持。K仅临时合入现有本地签名配置构建，公共build-profile已恢复，没有执行会改hook/index的setup脚本。

**NextN实际新样本**：自行普通搜索 `tag:non-h`，选择686744《My Invisible Childhood Friend Chapter06》，原生non-h及两页预览已核对；普通下载后29实际2/2完成，原六下载保留。30首次进入原片18.668589秒/381帧全部按顺序审阅，实际1→2→1；无正文上中央图片占位，增强采用后HD未闪回原始。两页真实nativeSystemSR执行及ready分别留证；未来source1于03:37:12.706已准备，03:37:22.913在翻页动画期间完成，早于03:37:23.945该页实际确认，但晚于22.543点击开始，不能说点击前完成。33/35原生Info两页均Enhanced/JPEG5120×7172。原图选择47的31帧全部审阅，50实际source/WEBP1280×1793，ready结果未在观察区间反写选择；51临时HD恢复，52正常返回下载。现有缓存/全族前置不存在性没有被冒称；在途处理取消未由这条ready路径接受。

**NextE实际候选**：21原片25.533522秒/299帧全部按顺序审阅，普通4212986实际13→14→15→16→15，HD始终橙色，正文后无中央图片占位。未来source13等ready早于后续翻页，但这些未来结果缓存复用；source11真实800×450→3200×1800处理1476ms是前邻页，不能说所有future无缓存。23原SR=false普通恢复，39同图册实际原body13/19/未应用HD，40正常返回。修复前旧E191帧HD也未复现人类所报闪回，frame114正文叠“正在准备图片”的失败事实保留；本次不声明唯一历史成因或所有闪回分支已修好。

**Koma实际受影响原图消费者**：41旧包原body3/145，42正常返回P3/2%；43当前共同候选升级后同Library保持。44原片20.096秒/235帧全部审阅，实际3→2→3，chrome及正常Back到LibraryP3/2%；原body3与同态41一致，无中央占位覆盖正文。只接受现有原图路径，不能冒充K已具超分/翻译或全阅读器通过。

**新观察的未闭环问题**：N两页增强Info和原图Info的大小都“未知”；文件header提供格式/尺寸，ReaderImageInformation.byteLength仍默认0，大小显示保持OPEN，未擅改可见信息。N新自动翻译现已按追加的人类两页Torii许可实际执行，有限证据如下；E本轮新服务路径仍未执行，不能由N替代。未观察布局/Legacy、native在途取消和配置晚到结果保持OPEN，不以构建、同源代码或有限无异常推广。

三份有限回执：`.hvigor/outputs/reader-preprocess-shared-20261012/device197__ALN-AL80/not-applicable/portrait-1260x2720/` 下 `30-nextn-final1-ordinary-new-nonh-entry-turns`、`21-nexte-final1-ordinary-entry-turns`、`44-k-common-original-entry-turns` 的 `finite-observation-receipt.json`。原片、全部帧时间线、raw hilog、命令账本和checked manifest保留。

精确diff复核及本地范围检查点已保存：共同Kit N/E同842a5ea、K旧基线91eb4f7；宿主N32ee03b6、E7557210e、K175cacda。原六geometry与K其他AppWIP精确保持，N遗留sequencer三文件未继续/删除。E仅移除类结尾一个空行，TS输出逐字节相同；实际原4395e6be安装绑定保留原EOF字节，不伪称新字节已部署。未推送/发版。

**追加NextN两页真实自动翻译**：197正常读取确认和当前Torii云端整图设置后，用户另明确允许686744最多两页上传/额度。72只开启一次，实际两次request/response；source0在04:44:19.455、source1在04:44:23.785 translated ready，第2页早于普通翻页命令04:44:44.574约20.789秒。原片35.690秒/304帧全部按顺序审阅，第一页面文字实际改变，随后普通1→2直接采用已准备的第2页译图；处理内联状态期间原正文可读，无中央图片准备占位覆盖。动画中HUD仍1/2，frame298/PTS32.038944后2/2，不宣称运动中每帧页码一致。75原生Info明确当前译图/PNG1280×1793，大小仍未知。正常关闭后77重入恢复原字/HDpink，79翻译当前页和auto未选中，80正常退出保留下载；81原KLibrary/P3/2%及原120000/86400000电源参数保持，租约已释放。只接受此两页服务准备/采用/会话退休，不接受翻译语言质量、E新服务、native在途取消或所有布局。回执为72目录finite-observation-receipt.json。

下一未验证动作：当前N许可两页路径已闭环且不重复上传；E新自动翻译需要独立当前配置/素材与上传额度范围，native在途取消/其他布局保持OPEN，不造状态/抢窗口补证。K独立安全App/源工作继续取当前工作单，Pixiv官方图标切片Root复核仍可执行；单个云服务分支不作为全产品停止条件。

## 普通用户观察与判定

从普通入口自然找内容、进入阅读、翻页、使用现有控件、退出再打开，完整连续录像覆盖点击前及首十秒、相邻页的真实处理/呈现。先按时间顺序看原片，记录全部异常，再对齐请求与配置代际；不从“修过了”倒推通过，不挑只支持结论的终点。选择另一尚未访问的内容并核实实际缓存证据；保留缓存和用户数据，不人为网络限速、加延时或反复打开同一本直到通过。

本次重点是用户已报现象和整个相关动作：N 未来页确有处理完成并由随后同页采用；E 已准备页翻页时没有原图/状态中间回退；若未准备完成，原图可读、处理状态与实际候选一致；关闭/返回/设置及原图切换不被旧结果反写。普通连续使用中发现的其他异常同样保留为失败，不用预设动作遮掉。翻译未获得新的服务资源范围前只检查本地/已授权缓存边界，不发送新的上传或消耗额度。

源码/任务状态运行检查、签名构建、安装、每个 App 的普通原生过程分别记录；同 Kit 或 E 一条接受不替代 N/K。以下旧占位路径有限接受保留，不通过本次设计或未执行的测试扩大。

<!-- reader-progress-snapshot
{
  "schemaVersion": 1,
  "title": "共享阅读器：预处理与图片生命周期",
  "state": "OPEN · N/E/K deployed; N bounded2page Torii native accepted",
  "updatedAt": "2026-10-12T04:54:06.414959+08:00",
  "activeId": "SHARED-IMAGE-PIPELINE-001",
  "outcome": "共同管理资源准备、预处理、结果采用及呈现状态；NextN获得同一超分预处理能力，NextE已准备页不闪回原图状态，Koma按真实可选能力接入。",
  "scope": "Same6files/N/Ebridges deployed; N381+31+304/E299/K235 all-frame finite evidence; E newservice/nativeinflightcancel/InfoBytes/otherlayouts remainOPEN",
  "nextAction": "N授权686744两页Torii准备/采用/退出已实际闭环，不重复上传；E新自动翻译取独立当前配置/素材与额度范围；native在途取消/其他布局保留OPEN。K安全独立App/源动作取当前K工作单，Pixiv官网图标切片Root复核仍可执行。",
  "items": [
    {
      "id": "SHARED-IMAGE-PIPELINE-001",
      "title": "共同资源准备、处理、采用及生命周期",
      "status": "OPEN · same6files and3consumers deployed; finite native evidence",
      "kind": "active",
      "detail": "共同六文件/三消费者部署；N真实两页Torii自动提前处理+译图采用/关闭已观察，304原帧全审；E新服务、native在途取消/其他布局及Info大小仍OPEN。",
      "action": "N授权686744两页Torii准备/采用/退出已实际闭环，不重复上传；E新自动翻译取独立当前配置/素材与额度范围；native在途取消/其他布局保留OPEN。K安全独立App/源动作取当前K工作单，Pixiv官网图标切片Root复核仍可执行。"
    },
    {
      "id": "N-SR-PREPROCESS-001",
      "title": "NextN未提前超分",
      "status": "ACCEPTED / named6867442P native preprocessing and adoption",
      "kind": "reported",
      "detail": "自行普通下载非成人6867442/2；未来页在page0已开始准备、翻页动画中ready、实际page1确认前完成；两页InfoEnhanced5120×7172；原图选择50实际1280×1793，51恢复。",
      "action": "冻结此有限命名证据；native在途取消/其他布局/翻译不由此接受。"
    },
    {
      "id": "N-AUTO-TRANSLATION-PREPROCESS-001",
      "title": "NextN自动翻译提前处理",
      "status": "ACCEPTED / bounded6867442P current native service/preparation/adoption/session retirement",
      "kind": "reported",
      "detail": "人类686744两页Torii追加授权；2次请求，future译图ready早于翻页20.789秒，304原帧全审+原生TranslatedInfo，正常退出/重入auto关闭；非语言质量接受。",
      "action": "冻结此有限路径，不重复上传；其他宿主/服务/在途取消不由此替代。"
    },
    {
      "id": "E-SR-STATUS-001",
      "title": "NextE翻页HD状态闪回原始状态",
      "status": "ACCEPTED / named4212986 prepared adoption interval; human other timing OPEN",
      "kind": "reported",
      "detail": "4395e6be候选299原帧实际13→14→15→16→15无HD回退或中央占位叠正文；旧包也未复现HDflash，不能确定唯一历史原因或所有分支。",
      "action": "保留原人类反馈及未命中边界；不重复已接受缓存命名区间或表面隐藏HD。"
    },
    {
      "id": "READER-INFO-BYTES-001",
      "title": "实际图片信息大小未知",
      "status": "OPEN · N enhanced andoriginal native observed",
      "kind": "reported",
      "detail": "33/35增强JPEG5120×7172与50原WEBP1280×1793均大小未知；当前文件information只读取header，byteLength未赋真实大小。 N75译图PNG1280x1793大小也未知。",
      "action": "保持可见信息问题OPEN；后续改动须有真实文件stat依据并遵循现有可见UI授权边界。"
    },
    {
      "id": "N-ENTRY-LOADING-001",
      "title": "加载未完，指示器背景半途消失",
      "status": "ACCEPTED / named NextN entry and ordinary reading interval",
      "detail": "197旧686630原112→113反例保留；5d6af7eb新686616首次337帧+后续329.104秒3603帧全部顺序审阅，正文首帧及重入不再叠图片占位。完整缓存族前置不存在性未证实；不推广连续/Legacy或全软件。",
      "action": "此命名路径冻结；未观察兄弟分支单独保持OPEN，不重复缓存重开或恢复旧矩阵。",
      "kind": "active"
    },
    {
      "id": "N-E-READER-NAMES",
      "title": "两种阅读器名称一致",
      "status": "N native ACCEPTED / E source and signed build only",
      "detail": "N中文旧版阅读器/新阅读器（默认）在197现有菜单已观察且保持原checkmark；E英文Legacy reader/New reader (default)两value已改并构建，未部署或原生英语观察。",
      "action": "N已接受名称冻结；E原生英文仅在实际英文使用路径核对，不为标签自行改系统语言/default。",
      "kind": "related"
    }
  ],
  "history": {
    "workOrder": "../archive/shared-reader-work-order-before-entry-loading-recheck-20261011.md",
    "sha256": "5851f1a3c75fde5b07d465b3cc7daea963e8a66003ba576794230b79c098116d",
    "authority": "仅保留历史事实和原证据；其规划、派发和待办全部退出执行队列。"
  },
  "commonKitCheckpoints": {
    "NextN": "842a5ea428ef542946636fab962ac7057c8865e3",
    "NextE": "842a5ea428ef542946636fab962ac7057c8865e3",
    "Koma-production-20261010": "91eb4f77252b7dcaeac9e421697b3b02c8dff45d"
  },
  "hostCheckpoints": {
    "N": {
      ".": "32ee03b61d21bcd3c8aa1ce6950bff300c6333dd",
      "third_party/reader-kit": "842a5ea428ef542946636fab962ac7057c8865e3"
    },
    "E": {
      ".": "7557210e79c87778237771cc5ae4f0e777980938",
      "third_party/reader-kit": "842a5ea428ef542946636fab962ac7057c8865e3"
    },
    "K": {
      ".": "175cacda7b91397808c25a65c2e5e552c81164b6",
      "third_party/reader-kit": "91eb4f77252b7dcaeac9e421697b3b02c8dff45d"
    },
    "sixOriginalGeometryWipExact": true,
    "originalKAppWipExceptOwnedStatusExact": true,
    "pushed": false
  },
  "nAutoTranslationReceipt": "/Users/honjow/git/NextN/.hvigor/outputs/reader-preprocess-shared-20261012/device197__ALN-AL80/not-applicable/portrait-1260x2720/72-nextn-authorized-auto-translation-two-pages/finite-observation-receipt.json"
}
-->

下面保留2026-10-11占位问题的旧事实与原观察流程；旧“下一步/Koma暂停”调度已被本次最新指令替代。已接受命名路径不重复，受共同改动影响时只重开具体依赖。

## 保留的占位问题观察流程（历史证据边界）

1. 先记录197两App实际安装版本、普通backend、当前窗口和入口。使用原有用户设置，不用Debug入口替代。
2. 从普通画廊点进阅读器，连续录像从点击前到进入后至少10秒；前台保持，不插入Home/后台动作。
3. 选择另一实际内容，核实实际获取/解码/呈现的区间，并明确缓存证据边界。加载状态已消失的缓存重开只能记录缓存路径，不能接受加载中背景。保留现有缓存，不清数据、不人为延时或限制网络。
4. 按完整时间顺序核对两App：原页面、缩略图飞行、指示器及其背景、加载百分比、正文首帧、系统栏和相邻内容。逐帧记录实际状态，不预设通过；原图可读仍显示图片占位、或占位未退而背景先退，均保留实际异常。正文最后出现不能抵消。
5. 用对应请求与原始视频时间定位失败，追踪共同Kit和两个宿主实际传入的入口/加载/交接状态；只改造成该现象的已证明状态变化，把共同决策放回共同owner。
6. 用修复版本在另一实际内容执行普通流程，并以实际加载区间判定；缓存族未核实就不声称全部无缓存。出现失败继续处理。然后按真实用户操作连续阅读5分钟：正常翻页、显隐阅读控件、退出和重新进入。没有观察到加载区间的场景不宣称加载通过；有限无异常不保证任意使用无bug。

## 已核实、不能推广的旧事实

- `c0ad970` 已改共同底板判定；2026-10-06 P20记录是普通未缓存加载，但取消运动UI分支未触发。
- `3468fa41` 修的是原图呈现后的旧底板残留；2026-10-07 N/P2是缓存原图与自动处理、Home/前台路线。
- 2026-10-08 N/P3未缓存样本在回前台前已存储完成；不能接受前台加载途中背景。
- 当前源码N的root原图交接仍用140ms淡入，E的root交接先提交不透明原图再等绘制帧。这是接入差异事实，尚未证明是本次背景消失的唯一原因。

本次命名路径接受来自当前实际完整原片，不来自代码/构建/历史接受。未观察分支不能用测试次数、源相似或相邻流程填补；已观察路径不重复执行。

当前完整因果及父树审查见 [图片占位生命周期审查](../../qa/reader-image-placeholder-lifecycle-20261011.md)。

当前197结果与限定范围见 [实机回执](/Users/honjow/git/NextN/.hvigor/outputs/reader-loading-background-20261011/nextn-placeholder-lifecycle-accepted-receipt-20261011.json)；首次原片337帧与后续329.104秒原片分别保留。

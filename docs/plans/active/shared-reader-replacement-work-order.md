# 共享阅读器：预处理与图片生命周期

当前优先事项来自用户的新反馈：NextE 翻页时超分状态短暂回到原始状态；NextN 没有相同的超分预处理。用户要求重新规划整个共同组件与宿主边界。两个问题均 OPEN。本次为当前源码审查和具体设计，尚未写产品代码、构建、安装或取得新的 N/E 运行接受。

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

## 普通用户观察与判定

从普通入口自然找内容、进入阅读、翻页、使用现有控件、退出再打开，完整连续录像覆盖点击前及首十秒、相邻页的真实处理/呈现。先按时间顺序看原片，记录全部异常，再对齐请求与配置代际；不从“修过了”倒推通过，不挑只支持结论的终点。选择另一尚未访问的内容并核实实际缓存证据；保留缓存和用户数据，不人为网络限速、加延时或反复打开同一本直到通过。

本次重点是用户已报现象和整个相关动作：N 未来页确有处理完成并由随后同页采用；E 已准备页翻页时没有原图/状态中间回退；若未准备完成，原图可读、处理状态与实际候选一致；关闭/返回/设置及原图切换不被旧结果反写。普通连续使用中发现的其他异常同样保留为失败，不用预设动作遮掉。翻译未获得新的服务资源范围前只检查本地/已授权缓存边界，不发送新的上传或消耗额度。

源码/任务状态运行检查、签名构建、安装、每个 App 的普通原生过程分别记录；同 Kit 或 E 一条接受不替代 N/K。以下旧占位路径有限接受保留，不通过本次设计或未执行的测试扩大。

<!-- reader-progress-snapshot
{
  "schemaVersion": 1,
  "title": "共享阅读器：预处理与图片生命周期",
  "state": "OPEN · N/E 新反馈；共同职责审查与重构设计",
  "updatedAt": "2026-10-12T02:31:28.021848+08:00",
  "activeId": "SHARED-IMAGE-PIPELINE-001",
  "outcome": "共同管理资源准备、预处理、结果采用及呈现状态；NextN获得同一超分预处理能力，NextE已准备页不闪回原图状态，Koma按真实可选能力接入。",
  "scope": "最新人类要求重新规划整个共同处理链；当前无新产品代码或新的 N/E 实机接受。Koma有限接受保留，其主代理下一动作随本次优先级调整保留。",
  "nextAction": "先在197保留当前已安装N/E普通阅读与翻页连续录像，核对设置、实际处理请求和当前页呈现时序；随后实现共同处理协议及N/E适配，Koma原图路径作受影响消费者审查。不得复制E宿主调度器到N作为最终架构。",
  "items": [
    {
      "id": "SHARED-IMAGE-PIPELINE-001",
      "title": "共同资源准备、处理、采用及生命周期",
      "status": "OPEN · source audit and design",
      "kind": "active",
      "detail": "NextE fa6ee0f 仅改E十二文件；现行Kit只共享滚动预加载目标与处理后变体选择。E宿主独有预处理Host；N仍直接传原图Adapter；K无SR/翻译Provider。",
      "action": "先在197保留当前已安装N/E普通阅读与翻页连续录像，核对设置、实际处理请求和当前页呈现时序；随后实现共同处理协议及N/E适配，Koma原图路径作受影响消费者审查。不得复制E宿主调度器到N作为最终架构。"
    },
    {
      "id": "N-SR-PREPROCESS-001",
      "title": "NextN未提前超分",
      "status": "OPEN · human report and missing source path confirmed",
      "kind": "reported",
      "detail": "NextNReaderLabPage将adapter传入preloadHost，adapter仅暖原图；NextNReaderSuperResolutionProvider无未来页文件处理入口。没有本次当前包的普通原生接受。",
      "action": "共同协议中注册N已有SR后端，不能把原图文件命中当作SR预处理完成。"
    },
    {
      "id": "E-SR-STATUS-001",
      "title": "NextE翻页HD状态闪回原始状态",
      "status": "OPEN · human report; exact native timing pending",
      "kind": "reported",
      "detail": "现有Surface等frame.displayed后异步selectVariant；图标从anchor对应frame.asset.variant推导。未来处理缓存不等于该页已被选中/呈现，这是源码时序风险，尚未用新录像确认本次实际闪回的唯一原因。",
      "action": "绑定同一page/request的原片与处理/呈现记录，修复共同结果采用时机，不保留上一页HD、不延时或表面隐藏图标。"
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
  }
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

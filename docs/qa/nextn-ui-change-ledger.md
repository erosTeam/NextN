# 当前界面记录

## 模式切换新原生图片的加载交接（2026-10-25，具名路径已观察）

- 修改依据：E075稳定Kit57在同11/19页切换分页/连续时无图且无反馈。Core保留displayed资源，而新原生Cell尚未解码；E078又证首次Pager测量前1×1子节点不能显示反馈。
- 保留边界：9791242真实尺寸传递、3a7b56d图片/加载互斥及4a4659d/4bf42eb缩略图/reveal理由保持。仅新Cell匹配解码前沿用既有反馈；首次测量由同一反馈接力，不改样式、读位、缓存、转场、retained旧图或Legacy。共同职责只见Kit Consumer contract。
- N197新包38223466B：145模式往返、147缓存缩略图飞行/原图/返回及148原历史1/34、另一原记录2/201、7下载/桌面已核。缓存命中快的入场不作自然网络等待验收；E/K结果分别记录。两级缓存候选未夹带。

## 上栏显示与安全区更新（2026-10-25，NextN具名成立）

- 允许差异：按用户要求先显示状态栏，再显示原上工具栏；无状态栏仍可用。外观、上下栏顺序、菜单、设置与转场效果保持，未采用普通入场动效候选。
- 原因：0e15ed7先画栏会早画；8248654只等setter与一帧仍失败。197113原19→20下移，117实录setter返回systemPx=0，上栏先按22.15vp画，随后37.85vp。官方Window接口明确返回不表示显隐完成；原反例保留。
- 共同57c65de：有实际状态区域且窗口未变才等原生area信号，随后现有帧边界提交；未知/零区域/悬浮、接口异常或信号缺失均不永久阻塞。隐藏/关闭退休等待，同一已开始的replay复用。未增加宿主准备门、缓存高度摆放、成功延时或临时日志。
- 实际：197安装38225452B Release1.0.7/code10；原686734的1/34，119全61编码帧及两组4/5/6、18/19/20原帧已亲审，两次先状态栏，上栏首帧即最终位置，无下移；正常返回同详情。120回原7项下载及桌面。只接受此路径；零区域实际窗口、快速取消和五入口入场总项未扩大。
- 原件：本仓`.hvigor/outputs/reader-loading-background-20261011/.../shared-mutual/chrome-{frame,geometry,native}197-*`。完整剩余队列仍在Koma CURRENT_STATUS.md；E/K与CI分别记录。

## 普通入场共用完成事件候选（2026-10-24，未采用）

- 授权：用户已允许为Koma普通入口与NextN默认入口制作一份共用可控转场候选，先看完整实机录屏后再决定采用。现有缩略图转场、Legacy、返回前恢复系统栏的规则保持。
- 原结构：N的私有HdsNavigation覆盖保留的root详情，Reader目的页与root proxy分别负责内容与缩略图飞行；普通入口原先没有真实原生完成门。K生产KomaReaderLabPage直接是根Navigation目的页，TrialWindow只依赖routeActive。
- 候选：仅两处普通PUSH使用共同300ms水平进入状态；animateTo.onFinish主动finishTransition，原生onTransitionEnd且真实动画回调已发生才放行现有Window控制器。取消/超时不视为成功。无新遮罩、固定延时或几何等待条件。
- 实测：共享549项检查及N/K签名Release构建完成；N074普通下载阅读入口72帧、K237-073普通继续阅读108帧均全段按序亲审。K记录了armed→animation_started→animation_finished→native_finished，N该次缺同等事件日志，不扩大结论。两段录像已展示，用户尚未采用。
- 恢复：两设备已装回稳定性能包；候选源码精确撤下，4份patch、HAP和candidate-state.json留在NextN `.hvigor/outputs/reader-route-candidate-20261025/`。采用后才恢复并接续取消/重入验证。N右侧黑区已核为源WebP固有135/1280px黑边；该视频未走缩略图缩放入口，缩放设置未改。完整队列继续Koma CURRENT_STATUS.md。

## 缩略图到原图交接（2026-10-24，4bf42eb具名验证）

- **失败保留**：E022第120帧仍是放大低清图且进度已退；原4a4659d的交接接受结论撤回。它只修复请求等待期，解码回调时entry仍把原图opacity设为0。旧录屏与CI保留，不能抵消该反例。
- **共同修复**：4bf42eb由现有entry的匹配页/slot/load和原图透明度决定隐藏期；解码后仍隐藏时保留加载反馈，原有reveal放行原图时一同退出。没有新宿主遮罩、延时或转场/样式/缓存改动；保留可读旧图及终止错误的既有分支。反例检查先失败，修改后相关43项及全536项通过。
- **197普通入口**：N38202032B/1.0.7code10与E38178566B/1.3.6code42均明确安装。E027实际Non-H4277955全151帧/5联系表；N032实际Non-H686734全269帧/8联系表，均按顺序亲审并另看原91/92：91低清预览+原加载面板，92清晰原图且面板退出，正常返回同缩略图。E022误判不再沿用；只接受这两个具名入口。
- **构建与边界**：N/E/K签名Release完成；K没有entry preview输入，仅构建不称K缩略图验收。E现有CI preflight通过。其他模式、Legacy和自然异常未由本轮接受。原件沿NextN `.hvigor/outputs/reader-loading-background-20261011/.../shared-mutual/thumbnail-reveal-*`，命令/原始PTS/全部解码帧保留，哈希关闭。
- **状态**：共同Kit及N/E精确提交同步待收尾；唯一未完成队列仍是Koma CURRENT_STATUS.md。N033已普通返回原Downloads、原686744仍2/2；034已正常返回E画廊与Koma原书架，原4212986未操作。

## 缩略图进入加载反馈退化（2026-10-24，旧4a记录，交接结论已撤回）

下列旧帧判定已被用户反例否决；当前结果见上方4bf具名验证。

- 当前用户授权恢复N/E缩略图进入的原加载反馈及必要共同状态重写。原参考为既有ReaderLoadingStage；保留进度、背景、原图互斥、转场及系统栏，不改样式。
- 3a7b56d以预览可见关闭加载，测试接受该错误预期；4a4659d移除预览对原图请求生命周期的输入。旧N688588真实等待已复现缺反馈，修复N686370普通入口全255帧显示等待面板→原图无覆盖→返回缩略图；原始60/82另审。
- N/E/K Release构建成功，N/E分别实际验证，未覆盖范围及完整证据见共同工作单。原“图片与加载互斥”记录的普通Read结果保留，但其preview分支预期不再有效。

执行规则只见 [执行规则](../controls/nextn-execution-integrity.md)。Reader 队列只见 [共同工作单](../plans/active/shared-reader-replacement-work-order.md)。本页就地更新，不按每次测试追加日志。

## 图片与加载互斥（2026-10-20，N/E普通具名路径已验证）

- 修改对象/有效授权：用户本会话明确要求共享阅读器在任何加载路径中图片与加载进度互斥；修复 N/E 的共享实现，不改变转场几何、手势、资源、进度或偏好。
- 历史来源/原理由：`9791242` 抽出图片占位时将原本依据当前解码身份的退出条件改为等待 session 的稳定呈现；`ReaderPagedViewport` 自 `07bc120` 另有独立目录加载层。目录打开会保留旧 slots（`ReaderPagedSession.open`），因此该层能叠在仍可读的旧图片上。
- 本次重开依据/允许差异：NextE 普通阅读首图出现用户反例。当前候选将图片可见性与加载反馈投影为同一互斥状态；入口只接收预览数据；目录层仅用于没有页内图片/反馈的空视图，禁止盖在保留页面上。E/N 现有消费目录同步，K 使用实际链接消费者。
- 验证路径与状态：Kit `3a7b56d`；六套相关生命周期检查135项和N/E/K Debug构建通过。197保留数据覆盖安装N1.0.7/code10、E1.3.6/code42，从普通下载封面进入详情，分别点击继续P2/P13，翻页往返后Back。N210帧、E695帧全区间按序审阅，准备层退出与正文出现的边界另看原帧，没有中央图片加载层覆盖正文，返回原详情正常。其他布局/Legacy及异常重入未由此接受；完整路径、PTS与证据见共同工作单。
- 工具边界：用户已明确拒绝助手提出的二选一，不能再引用其选择停止验收。实际checked执行回执已关闭摘要计算（`artifactHashesEnabled:false`，摘要null），target、租约、manifest/action校验保留；本次未计算或校验哈希。

## 关于页 Telegram 群组入口（2026-10-14）

- 用户授权：在 NextN 和 NextE 的关于页面添加 `https://t.me/erosTeamG`，点击打开链接加入 Telegram 群组；指定 192.168.50.103 验证。
- 原参考：当前 `AboutPage.AppInfoSection` 的共享列表行、分隔线及已有 `startAbility(viewData)` 外链方式。
- 具体差异：在平台信息之后增加“Telegram 群组”行，副标题显示完整链接；沿用已有控件和样式。打开失败使用独立提示，不影响更新入口。
- 验证路径：普通首页入口 → 关于 → Telegram 群组 → 系统处理链接 → 群组页面 → 返回关于。
- 实际结果：NextN 1.0.7/code9 与 NextE 1.3.6/code41 签名构建成功；MLR-AL00 竖屏1600×2560，经实时解析的 192.168.50.103:12345 从各自普通入口点击，均在浏览器显示 erosTeam 群组页及 VIEW IN TELEGRAM 按钮，随后返回关于。未执行加入群组的账号动作。
- 检查与恢复：两仓V1扫描均为0 file(s)，四语言key一致无重复；NextE使用DevEco自带Node24构建。已恢复原override10000ms（正常timeout600000ms），临时设备文件已接收留存后移除，租约已释放。
- 证据：`/Users/honjow/git/NextE/.hvigor/outputs/about-telegram-20261014/acceptance-summary.json`，原始manifest、layout和截图保留同目录。本次变更作本地提交，未推送。

## 当前问题：N/E 顶部渐变模糊（未完成）

- 用户要求：修复无状态栏、反复滚动时原渐变模糊背景消失及范围异常；保留原样式。
- 实际错误：把 `GRADIENT_BLUR` 换为 `COMMON_BLUR`，从一次测试扩展到两轮改动及重复验证。用户没有允许更改样式。
- 执行记录：8段、116个完成滚动动作、6个改效果的包。这些记录不证明原问题修好，也不授权保留改动。
- 错误判断：用“背景不透明了”“仍是原生 HDS”“只改枚举”推进换效果；这些都没有满足用户要求。条件切换还产生了旋转后的新退化，却继续改另一个非渐变版本。
- 原因边界（2026-10-13更新）：已从197实际HDS实现定位 `HideTitleDefaultStyle` 的零安全区分支，将动态遮罩高度写0，忽略仍显示的底部来源栏；随后 `Measure` 将0交给Mask/MaskBlur。N/E既有日志safeAreaTop=0及410→0→410的布局与该路径吻合。未做逐指令运行跟踪，不扩大为所有系统版本结论。
- 撤回：N/E helper 原字节恢复，Index 未改；本轮产品修改未提交/推送。03:15:52在197保留数据覆盖安装原渐变包 N `e1a393acbf9b`、E `526fa6afaffc`；竖屏1260×2720、override10000ms已读回，租约释放。
- 仍未完成：原渐变滚动缺陷；撤回和根因定位均不等于修复。公开接口复核未找到保留原效果/行为的修正入口；maskExtraHeight仅改变初始额外高度，不能阻止已定位的隐藏归零分支。仅本地读取系统文件的授权不包括修改系统库。2026-10-13用户要求记录前因后果并回到Koma，本专项保留OPEN，暂停主动调查。
- 完整记录：[问题前因后果](nextn-original-gradient-incident-20261013.md)。原始系统文件仅本地保留，不上传。
- 原始证据：`.hvigor/outputs/next-titlebar-recheck-20261013/`；执行统计 `/private/tmp/next-titlebar-recheck-20261013/comparison-execution-audit.json`；源码/设备撤回回执为同目录 `common-comparison-rejected-source-restoration.json`。

## 既有界面证据

[全部历史记录](nextn-ui-change-ledger-history-through-20261013.md)完整保留，SHA256：`9d202a5718d5d8e533ca56e6017927a124f78fdff160665d60c97b47030237da`。

历史中的“当前/下一步/OPEN”、设备和测试计划均描述当时情况，不调度现在的工作。已接受路径保留原范围和依赖，不扩大通过结论；历史已拒方案仍禁止，查 [拒绝记录](../controls/rejected-approaches.md)。新反馈或相关依赖变化才重开受影响部分。

新增可见修改只记录：用户允许改什么、原参考/设备事实、具体差异、实际结果和未完成动作。不得把历史长记录重新复制进当前入口。

## NextE 改进移植到 NextN（2026-10-15，胶囊分界线与收藏字重已验证）

- 用户授权：移植来源分析列出的八组改进，保留胶囊和下划线；胶囊作为未保存偏好时的默认。移植已集成；用户本次明确要求修好胶囊分界线后覆盖 v1.0.7 标签重新发布，版本号和更新日志不改。
- 原结构：Index 的 HDS bottomBuilder → HomeSourceBar → 原生水平 List/SubTabBar；SettingsPage 共享列表行；Index.galleryTitleBar 管理详情菜单，GalleryDetailPage 的内容滚动与底部 ReadFabRail 分离。翻译设置页及模型设置页继续沿用各自原列表结构。
- 差异：增加持久化页签样式选择和内置 Bing 开关；标签说明头增加复制原始 type:name 的动作及 Toast；已收藏再次点击直接取消；收藏从标题菜单移到阅读按钮内侧的圆形按钮，两种材质一致，同水平移动且阅读按钮仅在交叉运动时覆盖；移动状态属于独立 V2 子组件；评论入口改 topic_message。模型下载增加逐源失败切换及无字节停滞期限，保留流式写入和 SHA256 校验。
- 不移植：EH 配置和列表解析、EH 收藏分类/备注、只看上传者筛选；不修改共享 Reader、进度揭示时机、原渐变模糊或子模块指针。
- 验证路径：实际签名构建；103 普通设置入口切换样式并冷启动检查；普通画廊长按标签后复制；收藏增加/取消并还原；透明/实心按钮间距与左右移动全程；内置翻译评论及标题；模型下载失败恢复的运行测试。该列表是原移植验收范围；本轮按下述胶囊反例和收藏字重反馈重新验证相关路径，不重开未变能力。

- 补充授权（2026-10-15）：用户要求 NextN、NextE 悬浮收藏的空心心形加粗；只将未收藏图标字重从 400 调到 600，实心图标保留 400，两个材质共用同一内容。纳入本次 103 验收。

- 本次反例：103 实时 Connected，MLR-AL00、竖屏 1600×2560；原安装为 1.0.7/code9。普通详情返回首页后已观察到胶囊栏下方的灰色横向边界。当时的 `pr8-port-20261015/.../capsule-restored/screen.png` 也存在该现象，不能继续视为胶囊样式验收通过。
- 移植差异：NextE 对未选中胶囊传入 `applyShadow=false`，NextN 丢掉该参数且 helper 固定 true；样式切换后清空旧测量并重新居中的 V2 Monitor 也漏移植。本次仅补齐这两处参考行为，其他材质调用保留默认阴影。
- 受影响路径：当前首页胶囊完整父树、左右滚动及选中项、切换下划线后再切回胶囊、冷启动保留偏好。103 已验证普通设置入口切换下划线、切回胶囊、横向滚动与选中项保持；灰色边界消失。最终 500 包重新覆盖安装、启动后胶囊偏好和热门选中项保持，首页再次确认无灰色边界。
- 本次原始截图与状态：`.hvigor/outputs/capsule-divider-20261015/lab-tablet__MLR-AL00/not-applicable/portrait-1600x2560/home-before/`。

- 用户补充（2026-10-15）：空心收藏图标的 600 字重过重，NextN、NextE 同步改为 500；实心保持 400。只调整字重，其他尺寸、材质和布局不变。纳入本次 103 验证与当前标签覆盖发布，版本号及日志保持不变。

- 本轮实际结果：MLR-AL00、竖屏 1600×2560，签名 release 1.0.7/code10；最终包 SHA256 `3b99d15c549005510947f952ed81ad382202ba7f1cfc8ec4e0c4be2e5bcfaada`。从首页普通封面进入未收藏详情，空心心形显示正常，源码绑定为 500；UiTest 不暴露 SymbolGlyph 字重，不将布局数据误称为字重读回。未触发收藏远端写入。
- 证据边界：`underline-verified/`、`capsule-restored/`、`capsule-scrolled/` 验证胶囊修复；`final-500-home/`、`final-500-favorite/`、`final-restored/` 对应最终 500 包。目录均位于上面的场景产物根；返回首页并清理本轮设备临时文件，原胶囊偏好保留。动画帧率不在本次验证范围。


## 双 App 转场一致性修正（2026-10-16，具名路径已验证）

- 用户范围：两边列表到详情自定义主转场350ms、Reader缩略图主转场300ms；核查平板双栏回退和NextE缩略图重载。保留原曲线、样式、全局400ms及图像淡入时长。
- NextN改动：Index使用局部350ms，ReaderThumbnailTransitionCoordinator使用局部300ms，相关比例交接同步。没有修改共享reader-kit或画廊数据逻辑。
- 原因区分：NextE点击时重复syncDetailFirstPage替换缩略图，造成整页loading和source_snapshot_failed；改用已有幂等seed后已在103验证。NextN无同样批量重载，实机原缩略图转场开关为关闭；临时开启后，修改前的包已经能完成双栏缩放往返，因此不把关闭时的系统动画认定为双栏故障。
- NextN签名候选包已构建安装；103实时Connected、MLR-AL00、横屏2560×1600、系统1x。candidate-split同一gallery687770/page0完整101帧，源缩略图缩放进入和返回、邻图稳定；list350-roundtrip完整91帧，普通列表封面展开及返回，日志snapshots_ready且push/pop均isCustomAnimation:1。按时序审阅全部联系表并复核原帧；这是普通路径行为验证，不声称合成器精确耗时等于配置值。
- 检查：签名构建、生产Reader准入测试、V1扫描和diff检查通过。既有test_gallery_reader_transition_contract.mjs仍有一条直接readerImageOpacity表达式的正则断言失败；当前源码使用openingContentOpacity，未修改HEAD运行同一测试也失败，本次没有改该行为或放宽断言。
- 恢复：restore-preferences读回平板布局“仅横屏”、缩略图转场false（测试前原值）；final-restored回到浏览，保留原横屏和AWAKE/OverrideTimeout86400000ms，移除本轮设备临时JSON/PNG。录像已由runner接收并清理设备副本；租约已释放。未提交、推送、改版本或发布。
- 原始证据：`.hvigor/outputs/split-transition-20261016/`，冻结包nextn-split-fix-signed.hap；阶段证据位于lab-tablet__MLR-AL00/not-applicable/landscape-2560x1600/default-entry。NextE对应证据为其自身`.hvigor/outputs/default-reader-entry-20261015/acceptance.md`。

## 可选居中纵向悬浮按钮（2026-10-20）

- 修改对象/授权：用户在 NextE 四位数页码验证并提交后，明确要求将同一方案应用到 NextN。默认底部布局保留；新增可选纵向阅读胶囊及独立收藏圆按钮，46vp同宽、14fp原字号、16vp可见边距、安全移动区域2/3定位和屏外切换。
- 历史来源/原理由：`ec8b9765` 的 GalleryActionFabRail 隔离运动状态，`12ebc3fe` 的 Reader 续读所有权；不得恢复 REJ-READER-006 延迟页码显示。NextE 对应提交 `4015188c`，四位数实机发现 P9999 被拆为 P999/9，已修正为在 P 后换行。
- 本次重开依据/允许差异：用户明确要求移植该可选布局；不改 NextN 真实续读、收藏动作、原底部布局及缺阅读入口时的收藏按钮行为。NextN 仅适配主题 token、字符串及现有持久化方式。
- 验证路径：设置选择布局和材质 → 普通画廊详情 → 阅读/续读 → 返回；两种材质的比例、边距、左右完整切换。四位数使用临时显示样本，不写持久进度，结束后撤销样本并恢复正常包。
- 当前状态：移植、签名构建及 237 当前展开竖屏路径验证完成，作范围内本地提交；不推送、不发版。光感/实心的 P9999 显示样本均完整显示四位数字，保持 46vp 同宽、原字号、独立收藏与 16vp 可见边距；连续录像记录左右屏外切换。阅读进入/返回及收藏操作已验证。
- 源码/设备恢复：撤销显示样本，正常包 SHA-256 `448e6581670f084b7073b7b7b85029697048fb7d39f440a91155b2737b3c10ac` 已覆盖安装，普通入口冷启动；恢复底部导轨、光感材质、智感握姿及未收藏状态，`timeout -r` 读回系统 Timeout=120000ms、无 OverrideTimeout。未注入持久进度。
- 证据边界：`.hvigor/outputs/gallery-centered-fab/` 的四位数原图、两种材质连续录像，以及 `validation/final-production-restored-001` 安装/恢复回执。设备 lab-foldable / VDE-AL00，展开竖屏 1320×2120；短高度回退为源码边界核对，未宣称短窗口实机验收。

## 2026-10-25 共享默认菜单材质补漏

- **依据**：当前会话用户要求补齐菜单、半模态的新系统材质；唯一队列沿 Koma `APP_POPUP_SYSTEM_MATERIAL`。
- **范围**：Kit `9b94e98` 的两个 RuntimeMenu 补上另外三个菜单已采用的 API26 THICK 材质，五处共用内部解析；低版本仍 undefined。保菜单项、动作、开关状态和窗口生命周期，不触及未采用的入场候选。
- **验证边界**：NextN 签名 Release 构建成功；本轮未安装197、未重跑已冻结缩略图/入场路径，不称 NextN 新菜单实机验收。

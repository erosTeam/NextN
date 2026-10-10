# 图片占位组件生命周期审查（2026-10-11）

当前NextN命名普通入口及后续阅读区间已实际接受；未观察分支仍OPEN，Koma 保持暂停。修复对象是图片组件自身的占位生命周期，NextE 是调查对照，不是必须照搬的设计。

## 实际失败与因果

复现时197安装 NextN 1.0.5/code7，普通 Browse → 686630 → 第一张缩略图 → 前台阅读。原设置、缓存和网络保持，未插入 Home。录像 11.179 秒、374 帧，原 PTS 保留。第112帧（2.028867秒）灰色背景及“正在准备图片”仍在；第113帧（2.049789秒）正文可读，灰色背景消失，“正在解析图片”裸露在正文上。114、125、160、210原帧也有该叠加。最终正文出现不接受这段异常。

原视频：`/Users/honjow/git/NextN/.hvigor/outputs/reader-loading-background-20261011/nextn-ordinary-686630-entry-video-export/nextn-ordinary-686630-thumbnail-entry-20261011.mp4`。
原帧：`/private/tmp/nextn-ordinary-686630-entry-frames-20261011/frames/`；联排分辨率不足以发现113帧异常，必须看原帧。
日志 id13：03:47:00.489 原图217854字节存储；00.562 native presented success1061×1500；00.577 asset displayed；00.585 revealing；00.726 finished。04.514/679后续4244×6000资产呈现。完整缓存族的进入前不存在性未核实，不称全无缓存。

源证据：Paged/Continuous cell 的占位条件同时包含 `asset.isAssetLoading()` 和 `preparingSourceIndexes`；后者在已显示原图时继续成立。背景由 entry phase/decoder flag 单独决定，Stage 位于 zIndex2，因此指示器可以脱离背景并覆盖正文。`isAssetLoading` 本来还允许同页替换期间保留可读旧图，不等于容器没有可读图。

## 完整所有权及状态边界

| 边界 | 当前 owner/转换 | 本轮处置 |
| --- | --- | --- |
| 原图获取/解码/呈现 | ReaderSession/ReaderSnapshot；reportPresentation严格核对request/asset epoch，正向原生帧后转displayed | 以这个同一快照判断容器是否需要占位；不增加第二套布尔生命周期 |
| 替换、刷新 | 同页displayed原图保留；新资产decoding时retainedUri/retainedAssetRequestId保存旧可读图；成功ACK才清除/释放 | 有displayed或retained像素时不显示图片占位；资源取消、释放、身份门控保留 |
| 首次原图入场 | ReaderPagedImage原生onComplete及实际绘制帧ACK；Entry负责预览几何、运动、交接 | decode/entry phase不再单独撤占位背景；Entry只提供当前同一request的预览背景材料 |
| 分页/连续cell | notice → failed → image；外部preparing又独立覆盖Stage | 两种cell都声明同一个内部ReaderImagePlaceholder；出现/文案/进度/退出只取image snapshot |
| catalog空容器 | Paged全局Stage原先即使有旧frames也覆盖；Continuous只在displayCount0显示 | Paged限制为frames空，避免目录获取覆盖仍可读正文；Continuous现有空边界保留 |
| 图片后的翻译/超分 | ReaderPagedSession.preparingVariants；ReaderSurface已有enhancementProcessing/底部ReaderPageStatus | 不再控制图片占位；保留已有处理反馈和业务队列 |
| failure/notice/close | ReaderSession失败/关闭清retained，cells独立现有失败/提示面板 | 不增加占位覆盖；保留原重试、授权、文案及销毁流程 |
| host入口 | N140ms reveal，E root commit+postFrame；共同RootEntryHandoff | 源差异成立但不是本次裸指示器的必要原因；不修改宿主路由/窗口/运动 |

共同父树保持：ReaderSurface/canvas → entry preview + WithTheme → paged Swiper/viewport 或 continuous list → cell → native Image/retained replacement。chrome、页码、处理状态、失败/提示、菜单、手势、几何、间距、颜色与原动画不改。预存Paged/Continuous几何WIP已逐字节备份，不能一起提交。

## 相邻实现与历史结论

NextE当前普通4245150第一缩略图已实际进入Reader Kit（rkit-native-pager，原生production_part_presented id1/page0），不是只看Legacy源码。本次NextE原片11.264秒/113帧，全部联排已按时间审阅，但未显示持续Stage；日志原图disk_miss/network_start→211208字节stored→1280×1856呈现都在运动结束前发生。这不接受加载途中背景，也不证明所有处理阶段正确。调查开始时两App源码Kit05542ecf及两份预存WIP四个相关文件字节一致，独立git目录；共同修复必须同步相同切片，不能另写宿主特例。

N Legacy独立isLoading在URI获取finally结束，imageDecoded稍后才置true；存在占位生命周期分离的源风险，但不是本次当前Kit复现，保留OPEN源发现，不冒充已实机接受。E Legacy的cell条件是!imageLoaded，其parent另有originalImageResolving/jumping Stage，尚未证明所有parent状态互斥。本轮不凭静态差异重写旧版Reader。

旧c0ad P20原197帧实际清晰正文上仍有灰色“正在准备图片”面板；旧小联排/通过描述不能证明原图与占位互斥。3468仅增加assetLoading背景限制，没有删除preparing指示器条件，故背景修补不能作为生命周期修复。这不是已证实一次完整修好后才回归的结论。

反证边界：若此轮原113帧没有Stage，或当时original未呈现，则上述叠加原因不成立；实际原帧和native ACK均反证了该替代解释。修复后需要当前HAP绑定、完整普通进入原录像、实际加载区间及连续正常使用；编译或源断言不接受UI。

## 当前切片与实际候选观察

共同Kit生命周期提交 `3c7ffce857c34248420d696ac3c0d8ccd6aab6b8`（五文件，45增39删），N原两份geometry WIP在工作树仍为31增13删、未暂存/提交。E四个旧文件及新组件与N工作树字节相同；E保持原HEAD及既有issue12 WIP，未提交、未推送。N/E两消费者签名Release构建成功；Koma被用户暂停，不构建/安装/改pin，不能接受其新切片。

N安装 `5d6af7eb7ca58842396cc09dfa35d83bf387abf9903756b3675722b16f76ebec`（38080211字节），同bundle升级，不卸载或清数据；updateTime1791662721481。输入SHA及原WIP绑定：`/private/tmp/nextn-placeholder-release-binding-20261011.json`。

当前普通686616（另一真实27页内容）第一缩略图进入：原片11.328秒/337帧。全部10张联排按序审阅，原101、102、103、104帧核对；46–102灰底Stage在放大缩略预览上，103（1.885756秒）整个Stage退出，104（1.900956秒）开始清晰原图，后续图片稳定。已观察0–336整段没有裸Stage覆盖原图；不是靠终点图片出现判定。

原生id1：asset1/1280×1807 ACK04:07:49.051，displayed49.078，revealing49.078，finished49.220；后续asset2/5120×7228 ACK54.730/54.961。后续处理仍有底部圆形状态，正文上的图片占位没有重开。进入前完整缓存族仍未证实，不声称“全部无缓存”；实际前台asset→decoding→displayed和占位区间已经命中。

337原帧：`/private/tmp/nextn-fixed-ordinary-entry-frames-20261011/`；原MP4：`/Users/honjow/git/NextN/.hvigor/outputs/reader-loading-background-20261011/nextn-fixed-entry-video-export/nextn-fixed-ordinary-thumbnail-entry-20261011.mp4`，SHA`dec09243a0d6d6b93948e915616212d4b21935fe05596da1e1159beafa367c30`。编码890×1920为设备1260×2720的系统录屏缩放，未据此推导FPS或异内容定量几何接受。

## 当前普通用户区间的实际结果

197同一5d6af7eb HAP，686616：从首次普通进入后继续正常阅读，六次向前翻页、一次向后/向前、显隐chrome、Back→详情ContinueP7→ReaderP7→Back。checked链实际04:09:35.583–04:15:10.221，系统原片329.104秒；不是等待时间或命令结果构成接受。

原MP4：`/Users/honjow/git/NextN/.hvigor/outputs/reader-loading-background-20261011/nextn-fixed-reading-5min-video-export/nextn-fixed-ordinary-reading-5min-20261011.mp4`，56559274字节，SHA`afc2127b4fb54f1b46ac2000f8c4d6539ba1adc04d94e23d8841e0715c9291b0`。3603解码原帧/原PTS：`/private/tmp/nextn-fixed-reading-5min-frames-20261011/`。101张联排按原时间顺序全部审阅，0–3602无遗漏；另外原分辨率411、683、2512、3331、3355、3468–3473、3482核对处理、页码、chrome、重入占位/正文交界。337帧首次入口与这段后续原片各自保留，没有拼接假造一段视频。

实际页码依次P2→3→4→5→6→7→6→7，原生记录04:09:40.810、10:13.936、10:47.173、11:20.351、11:53.522、12:26.749、13:00.026、13:28.154，重入P7为14:35.047。滑动时正文连续，稳定后页码随对应页面改变；既有底部处理状态存在，中央图片占位没有随处理重新出现。chrome显隐保留正文。重入原3468/3469（297.789秒附近）黑色空图片容器仍有准备占位，3470（297.807111秒）正文首帧出现时整套占位已经退出；3471–3482仍无正文叠层。两次Back均回详情“继续P7”，最后0–3602区间没有用终态抵消中途异常。

**只接受此命名NextN普通分页路径**：首次缩略图加载、实际原图及后处理呈现、上述连续阅读/翻页/chrome/退出重入。完整缓存族的进入前不存在性仍未证实；不把此结果写成“全部无缓存”、任意操作无bug、连续模式/Legacy/native晚回调/FPS或全软件通过。失败/notice、连续模式与保留原图catalog等未自然命中的状态仍只有源审查，没有独立实机接受。连续模式采用同一组件，但不能用分页录像替代。

## 阅读器名称及收尾边界

N中文仅两value改为“旧版阅读器 / 新阅读器（默认）”；E英文仅两value改为“Legacy reader / New reader (default)”。键、顺序、backend身份、默认值、持久化及布局未改。N名称包`0a366a99def865e4f1981dfd042151dd7bbef8c37dc67e7b96e66b860ec7860e`，38080211字节；九份ABC/native入口与5d加载包逐字节相同（`/private/tmp/nextn-placeholder-names-binding-20261011.json`），两个包的实际证据仍分别绑定。

197普通My→阅读器设置→现有实现选项，原生`nextn-reader-implementation-row`与实际弹窗显示这两中文名称，checkmark仍为新阅读器；没有点击选项。终态截图`/Users/honjow/git/NextN/.hvigor/outputs/reader-loading-background-20261011/nextn-reader-names-native-options/screen.png`及layout已审阅；普通Back关闭→Back→Browse，`/Users/honjow/git/NextN/.hvigor/outputs/reader-loading-background-20261011/nextn-reader-names-normal-return/screen.png`显示Browse，layout确认com.erosteam.nextn/root原1260×2720。E英语资源/签名构建有证据，未切设备语言、未新安装E，故无英语原生接受。

原偏好、缓存、网络和数据未清除或重置；普通阅读会更新当前内容进度，N686616最终P7，E先前对照4245150从P9续读标签更新为P1，不能声称所有用户文件/进度逐字节不变。原24小时系统timeout override是本轮开始前既有值，未擅自改变；最后退出Reader，租约20261010-193701-e45ebcd7已正常release。四份本轮系统录屏保留原设备媒体和本地导出，不删除其它媒体。Koma始终保持用户暂停。

源切片/完整审查/实际区间/构建分层记录于`/Users/honjow/git/NextN/.hvigor/outputs/reader-loading-background-20261011/nextn-placeholder-lifecycle-accepted-receipt-20261011.json`。N接受HAP包含两份预存geometry WIP；全部构建输入SHA已留存，不将它说成干净commit可重现的整包，也不把这两份WIP纳入本轮提交。源/编译相同不推广为NextE或Koma运行接受。

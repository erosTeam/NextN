# 当前运行验收

更新时间：2026-10-14。此页记录实际证据，不能产生任务、授权或全产品通过结论。
用户已要求记录 N/E 原渐变问题后返回 Koma；当前持续任务为 Koma 首版 App 与中文源，唯一队列为 `/Users/honjow/git/Koma-production-20261010/docs/CURRENT_STATUS.md`。N/E 原渐变缺陷仍 OPEN 并暂停，旧自动唤醒和历史“下一步”不能恢复它。2026-10-14 用户新增要求检查并处理 NextE/NextN 未提交修改，已完成本地提交及历史 WIP 保存；此事不恢复原渐变设备调查。Reader 历史队列见 [共同工作单](../plans/active/shared-reader-replacement-work-order.md)。
用户禁止 DevEco IDE、工程信任/自动签名授权及独立诊断 App；已明确允许的现有 HDC 诊断和 Koma 现有命令行构建、签名、安装各限其原授权范围。原问题根因与未修复边界见下文及[事件记录](nextn-original-gradient-incident-20261013.md)。

## 关于页 Telegram 群组入口（2026-10-14，具名路径通过）

用户要求的 NextN / NextE 关于页 `https://t.me/erosTeamG` 入口已实现。指定设备实时解析为 `192.168.50.103:12345`；MLR-AL00，竖屏1600×2560，非折叠设备。

NextN 1.0.7/code9 与 NextE 1.3.6/code41 均签名构建成功并保留数据覆盖安装。普通路径分别为“我的 → 关于”和“设置 → 关于”：新增行显示完整链接，点击后系统浏览器实际显示 erosTeam 群组页面和 VIEW IN TELEGRAM 按钮，随后均返回对应关于页。仅验证群组页面与入口，未执行账号加入动作；安装HAP系统路径拒绝shell读取哈希，保留明确安装回执、版本读回和本地构建哈希，不声称取得安装包哈希。

两仓V1扫描均为0 file(s)，四套语言资源key一致无重复。测试结束已恢复原override10000ms，正常timeout600000ms未改；本轮设备临时文件在接收后移除，原始本地证据保留，租约释放。新增列表行沿用原样式，未改其他UI，本次变更作本地提交，未推送。

完整构建身份和原始证据：`/Users/honjow/git/NextE/.hvigor/outputs/about-telegram-20261014/acceptance-summary.json`。下方其他专项记录保留各自范围和状态，不代表本次任务范围。

## 原渐变模糊滚动缺陷（OPEN，按用户要求暂停）

用户要求保留原渐变效果，修复无状态栏反复滚动时背景消失/范围异常。本轮擅自换成非渐变模糊，已被用户拒绝；任何替换后的测试均不能接受原缺陷。

源码恢复原 SHA：N `58a45f2b33559cfb01bf32ecf9a934a54a121e1b1f6ba4f6885e725641731aff`，E `289bfe3a40a044eaab760a8fb5d916ab79117116122262f1f47d0888ef5f9bf9`；原 Index 保持，本轮产品 diff 已撤回、未提交/推送。

197 已实际保留数据覆盖安装原渐变包：N `e1a393acbf9b37caadcfefb26acd4a0763696a8d9518459438507ebbad210bea`，E `526fa6afaffc744ec33cbe0334fa922a2f1bcbe570b2434a9b6e131a009358f6`。03:15:52恢复竖屏及原 override10000ms，正常 timeout120000ms未变，租约释放。未清数据；本次撤回没有测全数据字节相等，也没有验证原缺陷修复。

恢复回执：`.hvigor/outputs/next-titlebar-recheck-20261013/device197__ALN-AL80/not-applicable/portrait-1260x2720/ne-titlebar-45-restore-original-apps-and-timeout/run-metadata.json`。
复盘和原始证据见 [界面记录](nextn-ui-change-ledger.md)。N/E/K规则精简已完成；当前调查原渐变生命周期，不再测试或保留非渐变替换。

只读调查：具名原渐变区间没有配置重发，已有trace只记录遮罩绘制/跳过测量，没有高度归零的写入函数。197当前系统`OpenHarmony-7.0.0.105`/API26；HDS包版本查询失败，系统库列举返回`Permission denied`，均不能因工具exit0判作成功。未读取系统代码、未改权限/设备设置。该读取分支停止，原缺陷仍OPEN，缺版本对应的高度写入依据；不猜参数、不换效果。细节：`/private/tmp/next-titlebar-recheck-20261013/original-gradient-readonly-review.json`。

本次原包调查（04:09–04:42，197横屏2720×1260）：N窗口400/PID18577、E窗口401/PID22300分别由普通列表上滑复现。实际原生 `MaskBlur`（N91/E102）高度410→0，下滑后回410；`HdsTitleBar` 仍为306高，固定来源栏仍显示。两次有限原生日志/trace未给出高度写入函数，HiLog均已恢复I。不能据此断言SDK根因已经证明，也不能称已修复。

E完整两次来回录像共257帧，已按时间顺序审阅。录屏指示器在第7–121帧带出状态栏，第一组不能作为无状态栏证据；指示器消失后的第二组仍出现渐变背景消失。N本轮只有原生读回及失败/恢复截图，没有新的连续录像。`ogc09` 的PNG取证失败，不接受整个场景；其实际原生/log/trace组件单独保留。早期 `hilog -x` 与 `-z` 组合报错属于命令参数不兼容，后来按公开CLI正常取得日志，不是安全拒绝。

独立原渐变复现工程 `/private/tmp/next-original-gradient-repro-20261013` 已编译未签名，尚未安装；仅用本地色块列表、ADAPTIVE材质和同一固定bottomBuilder/SCROLL_UP组合，不能代替N/E验收。DevEco“信任项目”被自动审批拒绝；安全预览实际不加载配置，运行/调试禁用。该路径已按最新人类禁止停止，不再申请其授权。当前接续仓库、既有取证和公开源码调查；原生高度写入依据仍缺失。

本轮未改、构建、安装、提交或推送N/E产品。E已恢复原订阅来源并用实际画面确认；04:42读回竖屏1260×2720/rotation0、正常timeout120000ms/override10000ms、HiLogI、原N窗口400前台。全部具名证据及录像边界：`.hvigor/outputs/original-gradient-cause-20261013/observed-facts.json`；此前原包覆盖安装回执与本次复现分别保留。

获准 HDC 后的新取证：`ogc26/28` 读取节点62时 N 两次 CppCrash，故障栈为 `DumpTreeById → RosenRenderContext::DumpAdvanceInfo → Gradient::ToString → OffsetT<float>::ToString` 空指针；原库 BuildID `892753bc0d7af42b5cd8d36ff2e699c7`。两次退出均发生于上滑之前，后续输入落在 E，不能计作 N 滚动证据。已停止节点62查询；该诊断崩溃与原模糊缺陷的因果关系未知。`ogc32` 保留具体调用栈；此前 runner 只保留输出末尾8000字符，未保留栈头，不能把那些末尾日志称为调用栈。

`ogc33` 同一 N1.0.7/code9、窗口400/PID53094、无状态栏横屏2720×1260普通上滑/下滑：只读已成功节点23/91/24/66，没有新的退出。标题文字及菜单 Alpha 变为0；MaskBlur 高410→0、位移Y182，而固定来源栏仍显示；下滑后高恢复410。三份原画面及原生结果已核对。这把故障收窄到动态隐藏时模糊覆盖与保留来源栏不一致，尚未定位实际高度写入函数，不是修复验收。官方 FAQ 的共享 Scroller/内容裁剪案例不证明本次高度归零原因，未据此改参数或父树。

本轮结束实际恢复：`ogc33` 读回竖屏1260×2720/rotation0、正常timeout120000ms/override10000ms、HiLogI、N窗口400前台；租约 `20261012-211100-8113bd37` 已释放。系统库目录列举已被设备拒绝，SDK预览实现为mock，独立App与IDE路径被用户禁止，这些限制只关闭对应调查路径，不能成为整个任务停止依据。保留 OPEN，不以回退、诊断崩溃定位或文档核对宣称原问题完成。

本次接口与调用链核对：SDK及官方文档把 `bottomBuilder.builder` 标为必填，N/E和原参考V2Next均只传缓存的 `builderComponent`；来源栏实际已经挂载，未取得遗漏字段会导致MaskBlur高度归零的运行实现依据，因此不补字段试错、不将其认定为根因。官方接口允许标题区域隐藏而底部区域保留；`showType`只在SCROLL_UP_TO生效，当前SCROLL_UP不受它控制。官方固定分类栏示例使用普通NavDestination，不能替代当前HDS父树。源码和文档未提供安装版本的高度写入分支；当前取证能力仍缺该依据。具体来源、源码摘要和未证实项保留于 `.hvigor/outputs/original-gradient-cause-20261013/hds-interface-audit.json`；本次未操作设备或改产品，问题仍OPEN。

本次接续：`ogc34`仅唤醒和读取状态，未滚动、未改设置、未构建/安装，租约已释放。用户指出重复成本后停止拟议的重复复现。重新分析既有`ogc09/17` trace：两者各117个滚动事件；E在同一上滑区间另有MaskBlur102 opacity从0到1的实际记录，最终高度仍为0。该证据不能给出高度赋值函数，但后续修复不能仅处理透明度而忽略几何高度。逐项消息和时间保留于 `.hvigor/outputs/original-gradient-cause-20261013/existing-trace-state-sequence-review.json`。

本次复用既有证据，未重复普通滚动：原 N/E HAP 摘要核对及离线字节码确认仍请求 GRADIENT_BLUR、hideBottomBuilder=false/hideStatusBar=false，排除恢复包丢失这些输入。原 Index 与旧诊断 v3 的精确差异只有日志、非响应式计数和只读查询；旧配置未重发观察仍限其具名区间。两份原包布局中，MaskBlur 的 min/max/percentReference/selfIdeal 高度均为0，外层标题仍306；缺少的是产生该约束的函数和输入。具体材料：`.hvigor/outputs/original-gradient-cause-20261013/current-investigation-review.md`。

新的只读取证能力核对 `ogc39`：measure/layout trace 参数均返回 errNum1002，虽exit0但读取失败。公开 OpenHarmony 参数定义将1002定义为SELINUX_RESULT_FORBIDED；未把它称为参数不存在或读取通过。没有写参数、重启App或启动新trace，租约已释放。公开测量源码虽提供parentConstraint日志，不能替代安装版本HDS实现；该被拒读取路径停止，其余证据原样保留。`ogc35`未获得HDS配置，`ogc37/38`仅返回后台窗口头，均不算配置或视觉验证。Hindsight纠正两次自动审批拒绝，没有写入成功。

新增准确文件调查：用户补充授权后，`ogc40` 通过普通HDC成功读回单份 `libace_compatible.z.so`（74,547,968字节，SHA256 `1166bd929a53a5cfbb5366fddf5a2903776935bb906f712ce097891ea5d14156`），BuildID与既有栈完全一致。展开压缩调试数据取得254,716个符号，但没有HDS命名符号或HdsTitleBar字面量，不能把普通TitleBar实现当作HDS原因。旧目录列举拒绝不等于准确单文件不可读，已由本次实际回执纠正；文件仅本地分析。

`ogc42` 从已有NextN故障事件Maps找到实际HDS模块；用户补充许可后，`ogc43` 已完整读回两份文件，仅本地分析。native库1,281,600字节，SHA256 `aefe7a42c60e29ee4877d9df958c26bfc28f39438702d10382c080550049947c`，BuildID `105436851bece37e34fcc35319e66004`；ABC 58,196字节，SHA256 `b4eab3c059201ad3a955fd8fed3ba9339305ab98421aed07f6720b3c0cf21e7c`。实际传输stdout与文件大小/文件头一致，租约已释放。未新增滚动或改产品/设备状态。此前“尚未取得系统实现”的调查限制已被本次证据解除。

**当前根因依据**：实际HDS库 `HdsTitleBarDynamicPattern::HideTitleDefaultStyle` 在 `0x8e320–0x8e368` 对 `safeAreaTop≈0` 写入动态遮罩目标高度0，未考虑仍保留的bottomBuilder。`HdsNavigationLayoutAlgorithm::Measure`随后将此高度送入Mask和MaskBlur两者的测量约束。已用实际libace函数表确认间接调用为MeasureNode；已有N/E日志分别记录safeAreaTop=0，既有布局记录来源栏保留、MaskBlur410→0，下滑恢复410，与同库ShowTitleDefaultStyle写回初始高度对应。这里是实际版本的静态写入分支与现场证据交叉核对，没有逐指令运行跟踪，也不是修复验收。

完整函数地址、字段来源、证据路径与修复边界：[HDS高度写入调查](../../.hvigor/outputs/original-gradient-cause-20261013/hds-native-height-cause.md)。原问题仍OPEN。需要修正的计算位于系统HDS私有实现，现有公开接口未找到直接覆盖该高度的受支持入口；未修改系统库、写私有运行内存、换样式或用参数试错。后续缺的是保留原样式/行为的可维护修改落点及其实际验收，不再重跑已证故障或沿用“系统代码未取得”的旧阻塞结论。用户现已要求返回Koma；本项保留OPEN，暂停接续。

本次公开修复接口复核已读取官方 HdsNavigation 全文及两份相似故障 FAQ。FAQ 的 Scroller 共用问题与当前 N/E 独立 Scroller、单个当前绑定不符；裁剪问题也不能纠正已确认的零高度测量。公开 `maskExtraHeight` 控制初始遮罩额外高度，实际 Measure 读取后，隐藏分支仍可直接将动态目标写0，不能靠增大参数修好。没有改参数或再跑设备。详见[公开接口核对](/private/tmp/next-original-gradient-exact-library-20261013/official-docs/repair-interface-review.md)。当前阻碍产品修复的是缺少保留原效果/行为的受支持修改落点；直接修改系统私有库不在用户仅本地分析授权内。官方检索未取得针对此分支的修复版本公告，不据此宣称所有版本无解。根因调查结果保留，原缺陷仍OPEN，用户现已要求返回Koma；本项保留OPEN，暂停接续。

## 共同 Reader 的有限证据

| 问题 | 已观察边界 | 未证明部分 |
| --- | --- | --- |
| N 进入阅读器时正文上叠裸指示器 | 2026-10-11修复后的686616普通分页进入、翻页、返回/重入具名录像 | 全无缓存、所有布局、失败/Legacy及所有入口 |
| 超分/变体预处理 | 2026-10-12 N686744、E4212986、K原图消费者具名区间 | 全布局、native在途取消、全 Reader |
| 自动翻译预处理 | N686744获准的两页 Torii 已实际请求并用于下一页 | E新服务、语言质量及其他页；不得重复消耗额度 |

完整包/源码绑定、原片、观察边界及下一动作在共同工作单。N大小信息显示“未知”仍OPEN。共享代码不替代各宿主验收。

## 历史证据与账号

[全部历史验收](nextn-acceptance-history-through-20261013.md)按原字节保留，SHA256：`b3da3c2a1021247e84f2369d6aea8b604e6f4f79598eef16c5df9f7595bd2533`。旧“当前安装”和旧下一步不调度现在的工作，既有接受仅覆盖各自原包/依赖/路径。

账号工作只有当前用户指令或当前原生 Account/Favorites 反例才能接续；按 [S0–S6](../device-protocols/nextn-account-login-acceptance.md) 和 [登录尝试记录](nextn-login-attempt-ledger.md)执行，不用旧账号担忧停止其他产品工作。

## 2026-10-13 用户切回 Koma

用户明确要求先记录本问题前因后果，再返回 Koma。完整[事件记录](nextn-original-gradient-incident-20261013.md)已保存，包含原始反馈、未经授权的样式替换与撤回、实际HDS根因、证据边界和未完成项。原渐变缺陷仍OPEN，本项暂停；不由旧自动唤醒自行恢复。

## 2026-10-14 未提交修改处理

用户检查后明确要求处理。主目录的规则/验收记录、两份原 geometry WIP 与 NextE 反向连线检查已作范围内本地提交；其他历史工作树分别保存为未重新验收的 WIP 检查点，原源码字节与原分支 HEAD 保持。25 个工作树及 Reader 子仓均读回无未提交改动。181 份旧本地输入/日志保持原路径和字节，仅精确本地 Git 排除，没有删除原材料或隐藏产品源码。

完整提交表、原 diff、文件哈希、原分支与读回见[处理记录](../../.hvigor/outputs/uncommitted-review-20261014/review.md)。NextE 现有完整 preflight/V1 零文件扫描通过；未重做 N/E 设备验收、未推送。原 geometry 仍限既有具名证据，Koma App/Kit WIP 未改变。本项完成后接续 Koma 原目标。

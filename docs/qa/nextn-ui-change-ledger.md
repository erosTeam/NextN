# 当前界面记录

执行规则只见 [执行规则](../controls/nextn-execution-integrity.md)。Reader 队列只见 [共同工作单](../plans/active/shared-reader-replacement-work-order.md)。本页就地更新，不按每次测试追加日志。

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

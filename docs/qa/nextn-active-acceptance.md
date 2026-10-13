# 当前运行验收

更新时间：2026-10-13。此页记录实际证据，不能产生任务、授权或全产品通过结论。
Reader 的下一动作只取 [共同工作单](../plans/active/shared-reader-replacement-work-order.md)；Koma App/源只取 `/Users/honjow/git/Koma-production-20261010/docs/CURRENT_STATUS.md`。

## 关于页 Telegram 群组入口（2026-10-14，具名路径通过）

用户要求的 NextN / NextE 关于页 `https://t.me/erosTeamG` 入口已实现。指定设备实时解析为 `192.168.50.103:12345`；MLR-AL00，竖屏1600×2560，非折叠设备。

NextN 1.0.7/code9 与 NextE 1.3.6/code41 均签名构建成功并保留数据覆盖安装。普通路径分别为“我的 → 关于”和“设置 → 关于”：新增行显示完整链接，点击后系统浏览器实际显示 erosTeam 群组页面和 VIEW IN TELEGRAM 按钮，随后均返回对应关于页。仅验证群组页面与入口，未执行账号加入动作；安装HAP系统路径拒绝shell读取哈希，保留明确安装回执、版本读回和本地构建哈希，不声称取得安装包哈希。

两仓V1扫描均为0 file(s)，四套语言资源key一致无重复。测试结束已恢复原override10000ms，正常timeout600000ms未改；本轮设备临时文件在接收后移除，原始本地证据保留，租约释放。新增列表行沿用原样式，未改其他UI，本次变更作本地提交，未推送。

完整构建身份和原始证据：`/Users/honjow/git/NextE/.hvigor/outputs/about-telegram-20261014/acceptance-summary.json`。下方其他专项记录保留各自范围和状态，不代表本次任务范围。

## 当前优先：原渐变模糊滚动缺陷（OPEN）

用户要求保留原渐变效果，修复无状态栏反复滚动时背景消失/范围异常。本轮擅自换成非渐变模糊，已被用户拒绝；任何替换后的测试均不能接受原缺陷。

源码恢复原 SHA：N `58a45f2b33559cfb01bf32ecf9a934a54a121e1b1f6ba4f6885e725641731aff`，E `289bfe3a40a044eaab760a8fb5d916ab79117116122262f1f47d0888ef5f9bf9`；原 Index 保持，本轮产品 diff 已撤回、未提交/推送。

197 已实际保留数据覆盖安装原渐变包：N `e1a393acbf9b37caadcfefb26acd4a0763696a8d9518459438507ebbad210bea`，E `526fa6afaffc744ec33cbe0334fa922a2f1bcbe570b2434a9b6e131a009358f6`。03:15:52恢复竖屏及原 override10000ms，正常 timeout120000ms未变，租约释放。未清数据；本次撤回没有测全数据字节相等，也没有验证原缺陷修复。

恢复回执：`.hvigor/outputs/next-titlebar-recheck-20261013/device197__ALN-AL80/not-applicable/portrait-1260x2720/ne-titlebar-45-restore-original-apps-and-timeout/run-metadata.json`。
复盘和原始证据见 [界面记录](nextn-ui-change-ledger.md)。N/E/K规则精简已完成；当前调查原渐变生命周期，不再测试或保留非渐变替换。

只读调查：具名原渐变区间没有配置重发，已有trace只记录遮罩绘制/跳过测量，没有高度归零的写入函数。197当前系统`OpenHarmony-7.0.0.105`/API26；HDS包版本查询失败，系统库列举返回`Permission denied`，均不能因工具exit0判作成功。未读取系统代码、未改权限/设备设置。该读取分支停止，原缺陷仍OPEN，缺版本对应的高度写入依据；不猜参数、不换效果。细节：`/private/tmp/next-titlebar-recheck-20261013/original-gradient-readonly-review.json`。

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

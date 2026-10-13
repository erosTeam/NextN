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
- 原因边界：原 MaskBlur 有高度0和位移182的实际观察；SDK内部原因仍未知。不能据此声称必须改效果。
- 撤回：N/E helper 原字节恢复，Index 未改；本轮产品修改未提交/推送。03:15:52在197保留数据覆盖安装原渐变包 N `e1a393acbf9b`、E `526fa6afaffc`；竖屏1260×2720、override10000ms已读回，租约释放。
- 仍未完成：原渐变滚动缺陷；不能把撤回说成修复。用户要求的N/E/K文档精简已完成，当前只调查保留原渐变效果的原因。
- 原始证据：`.hvigor/outputs/next-titlebar-recheck-20261013/`；执行统计 `/private/tmp/next-titlebar-recheck-20261013/comparison-execution-audit.json`；源码/设备撤回回执为同目录 `common-comparison-rejected-source-restoration.json`。

## 既有界面证据

[全部历史记录](nextn-ui-change-ledger-history-through-20261013.md)完整保留，SHA256：`9d202a5718d5d8e533ca56e6017927a124f78fdff160665d60c97b47030237da`。

历史中的“当前/下一步/OPEN”、设备和测试计划均描述当时情况，不调度现在的工作。已接受路径保留原范围和依赖，不扩大通过结论；历史已拒方案仍禁止，查 [拒绝记录](../controls/rejected-approaches.md)。新反馈或相关依赖变化才重开受影响部分。

新增可见修改只记录：用户允许改什么、原参考/设备事实、具体差异、实际结果和未完成动作。不得把历史长记录重新复制进当前入口。

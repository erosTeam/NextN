# NextN current acceptance evidence

当前 Reader 调度仅取 [唯一工作单](../plans/active/shared-reader-replacement-work-order.md)。
本文件记录当前事实与证据边界，不复制 nextAction，不按每次点击追加日志。
用户要求的执行约束整理已完成；Reader OPEN，独立 Koma 生产 Goal 保持 PAUSED。

## Reader 当前有效边界

| 接入 | 当前安装绑定与命名结论 | 未接受范围 |
| --- | --- | --- |
| N | HAP `a89534c2`：现有设置实现选择、普通入口及同源 Legacy 几何、显式 Debug 根飞行/无缩略图加载、显隐工具栏与隐藏后返回的命名区间 | 自然 pending/late-progress/stale/fallback、zero-top/landscape、所有布局/FPS/完全替换 |
| E | HAP `d7cdffba` / 四文件 checkpoint `f593e88e`：设置选择与命名 moving-cancelled 缩略图、无缩略图加载/显隐/隐藏后同 DetailP3 返回 | normal-finished 整段 chrome/hidden-Back 尚未接受；自然 pending/stale/fallback、全量几何/FPS/替换 |
| K | HAP `3a32ff76`：仅原目录/章节/自动阅读/按书设置/标题/媒体面板命名证据，依赖不变才沿用 | 全量布局/FPS/替换；文件夹实际导入移回暂停的 Koma 生产工作 |

完整 HAP/源码 SHA、原 MOV/PTS、失败样本及五个入场判定行在工作单快照和其 currentEntryReceipts。
`c09` 初始白图标闪现仍为失败证据，E `73af87d8` normal-finished 但操作不完整，不能当成整段通过。
两文件共同 geometry WIP 未提交且原字节保留；不存在全量替换或性能超越的接受结论。

本次 material physical result（2026-10-07 15:31+08）：文档前置提交后，实际恢复一次 E P3
入场→显栏→藏栏→隐藏后 Back，并连续录屏 `bc286415`。原生 id1 在 moving 后取消，
没有 finished，故 normal-finished 行仍未接受；整段联排及精确原始像素等价已审阅，不新增正常完成分支通过。
同 HAP/九份源码 SHA 已核对；原 Detail4203217/root `[0,117][1320,2232]`、ContinueP3 保留。
15:31:22.994 checked postflight 读回 AWAKE、两种 timeout=30000、keepScreenOn=false 已恢复，
租约随后正常释放。产物位于 ignored `.hvigor/outputs/reader-entry-statusbar-20261006/`，
`e-post-controls-normal-entry-result.json` 记录原 MOV/日志/协议、取消调用点未记录及审阅限制。
未改等待、缓存或产品；不能把这次命令执行成功推广为正常完成、所有入场或性能通过。

## 非 Reader 遗留边界（不自动启动）

文档整理不对无关产品作新的通过判断。账号 P0 的历史 2026-09-04 named candidate 已有
原生/cold/Favorites 接受记录；不能当作当前任意版本或新账号的证明。三个更广物理行仍未验收：
真实两账号切换/删除、空目标/跨设备加密导入、真实评论写入。没有新的 S0 反例，当前不启动账号 lane。

S0–S6 仍见 [账号协议](../device-protocols/nextn-account-login-acceptance.md)，授权/隐私/不重复提交
规则未改变。归档的旧 197/237 地址、小时观察与失败探针不授权当前重连。

另保留原记录中的便携恢复/会话所有权变更矩阵、API-key UI 人工确认、legacy transport regression、
本地 tags 清理及跨应用短动作/失败背景边界，不能因 Reader 文档清理默认为已完成或另开队列。
具体原始判定如下索引；更晚的同范围记录优先，历史 OPEN 标题不是新的 dispatch。

## 历史证据索引

原 9,163 行文件逐字节保存为 [历史快照](archive/nextn-acceptance-through-20261007.md)，SHA-256：
`e76ae070135476e8251ae6f95df333c3b605f4aa7a3df5e159d6279b2dba084f`。所有原图路径、用户引用、
失败及有限接受边界保留。旧“active/current/next physical action”标题已退出当前入口。
在相应 lane 重新被用户开启时，恢复最后有效证据与未验证动作，不能只按旧标题重跑。

| 原文件行号 | 需保留的非 Reader 判定 |
| --- | --- |
| 7468 | Local user tags — accepted on 197/103; cleanup pending — 2026-09-02 |
| 7605 | Dual authentication and portable-restore isolation — 197 accepted, 237 stateful acceptance pending — 2026-09-03 |
| 7700 | Portable-primary isolation and delayed API-key autofill — 197 accepted, broader matrix open — 2026-09-04 |
| 7765 | Web identity propagation and account ownership ordering — 197 accepted, multi-account physical matrix open — 2026-09-04 |
| 7802 | Portable backup merge ownership — 197 regression accepted, physical restore matrix open — 2026-09-04 |
| 7832 | Restore owner ordering — latest 197 regression accepted, restore matrix remains open — 2026-09-04 |
| 7861 | API-key confirmation status classification — 197 regression accepted, destructive and long-duration paths open — 2026-09-04 |
| 7892 | API-key action size and shared list-row suffix regression — 197 evidence, user visual confirmation open — 2026-09-04 |
| 7915 | Cross-device backup ownership audit — source gap removed, physical matrix open — 2026-09-04 |
| 8010 | Legacy refresh verification transport guard — source/build complete, device regression open — 2026-09-04 |
| 8028 | Atomic primary-session ownership — 237 single-account regression accepted, mutation matrix open — 2026-09-04 |
| 8729 | OPEN — Cross-app short actions and NextE failure material — 2026-09-05 |
| 9046 | 2026-10-03 — current shared-reader package5 / emulator boundary — OPEN |

冻结行为/重开条件仍由 [UI ledger](nextn-ui-change-ledger.md) 与
[execution integrity](../controls/nextn-execution-integrity.md) 管理；历史归档不决定当前设备或任务。

## 强制约束：未经用户明确允许，禁止创建工作树

- 默认在项目原主仓目录工作。创建任何 Git 工作树前必须取得用户明确允许，并遵守该允许限定的项目、用途和范围；没有明确允许，一律不得创建。
- 本约束适用于命令行、工具托管、临时路径和所有子代理；不得通过派工规避，也不得把旧计划、自动唤醒、代理建议或已有工作树当作新增许可。
- “保护 WIP”“并行开发”“隔离验证”“方便打包”等理由不构成允许。不得通过复制项目源码或额外克隆开发副本规避本约束；应在原主仓审查、整理并及时提交有效改动。
- 已获允许的工作树只用于获准范围；完成后及时将有效成果合回原主仓并退出工作树，未经新的明确允许不得扩展用途或长期保留为另一条开发主线。

# NextN agent controls

**未经用户明确允许，禁止更改样式；修 bug 也不例外。**

## 每次开始

- 先读 [执行规则](docs/controls/nextn-execution-integrity.md)，再进行计划、修改、验证、派工或汇报。
- 强制先读执行规则中的“禁止编造记忆与无依据确认”；回应纠正、历史要求或既定决定前再次阅读，不得用当前纠正冒充历史记忆。
- 最新用户指令优先；不从旧计划、自动唤醒或历史记录自行扩大任务。
- 修改已有行为前，用文件名和符号查询 [已拒绝方案](docs/controls/rejected-approaches.md)；禁止恢复被拒方案，除非用户明确重新允许。
- 查看当前工作区，保护用户数据和无关改动。未完成的问题保留结果、证据和下一动作。

## 按工作读取

| 工作 | 必读 |
| --- | --- |
| HarmonyOS 源码、构建 | `harmony-mandatory-preflight` 和 `harmony-next` 技能 |
| 设备、截图、日志、UI 操作 | 另读 `harmony-run-device-diagnostics` 和 [设备协议](docs/device-lease.md) |
| 共享 Reader | [共同职责](third_party/reader-kit/README.md#consumer-contract)、[唯一工作单](docs/plans/active/shared-reader-replacement-work-order.md) |
| 版本步进、发版 | [版本发布](docs/developer-guide.md#6-版本步进与发版) |
| 当前运行证据 | [验收状态](docs/qa/nextn-active-acceptance.md) |
| 可见界面修改 | [界面记录](docs/qa/nextn-ui-change-ledger.md)，以及当前参考页的完整父树 |
| 登录、凭据 | [S0–S6 协议](docs/device-protocols/nextn-account-login-acceptance.md)、[当前验收](docs/qa/nextn-active-acceptance.md)、[尝试记录](docs/qa/nextn-login-attempt-ledger.md) |

## 操作要点

- 签名构建入口：`scripts/build-hvigor-signed.sh`；没有下划线版本。
- 用户选择设备后，实时解析完整 target，使用有效租约。租约不产生授权。
- 状态操作和取证通过 `scripts/run-device-protocol --device <完整 target> --lease <ID> <项目 manifest>`；manifest 保留在忽略的产物目录。
- 直接租约包装 HDC 仅限发现/重连、`shell echo`、启动完成读回和文件接收。
- 参考 NextE/ErosN 时保留完整页面结构、滚动所有者、菜单、顺序、几何和动作；产品差异只能替换有依据的局部内容。
- 登录授权持续有效：按协议自主填写、处理挑战并提交，不重复索要同一许可；字段使用语义锚点，不用坐标输入凭据，不在同一次尝试中重复提交。
- 登录通过须证明原生 Account/Favorites 生效及不清数据冷启动保持；Web、CAPTCHA 或命令成功不算登录通过。秘密不写入消息或产物。
- 材料改动先审精确 diff，再作范围提交；不自动推送或发布。

## 汇报前

核对原目标是否仍未完成、下一动作是否实际执行。实质设备结果更新验收状态；只报告观察到的结果、未证实部分和下一安全动作。

# 全量隐患审计（2026-08-20 立项）

> 起因：scroller currentOffset() 未定义裸读在 200 设备闪退（2dcaf41 修复）。
> 该坑在 GalleryDetailPage 注释里早已自认，却只修过 ListScaffold 一处私有副本，
> 其余 13 处裸调用留存至今。本审计消灭三类结构性来源：已知不修、副本漂移、点状修复。
> 退化类事故仍登记 nextn-incident-register.md；本文档只收尚未爆雷的存量隐患。

状态符号：TODO / AUDITED(已登记未修) / IMPLEMENTED / VERIFIED。
每条修复合并同类并收口公共 helper，禁止点状修复；每批结束必须更新本文件状态。

## 摸底数据（2026-08-20，rg 全仓 shared/feature/entry）

- TODO/FIXME/HACK：0 处
- ArkUI 可空 API 裸链访问：0 处（2dcaf41 清零）
- 空 catch 体：164 处（未分级）
- Scaffold/PullRefresh 组件族：8 文件 2181 行
- 注释自认坑：关键词噪声多，精确关键词复核约 5-10 处（车道 A 负责核准）

## 车道 A（P0）：注释自认坑核对 AUDITED

查法：rg 精确关键词（undefined here / returns undefined / not yet attached /
raw runtime error / first frame）逐条验证两点：注释宣称的防御是否真的存在；
同模式调用点在其他文件是否共享该防御。
验收：每条给结论（已防御/防御缺失/防御存在但未传播），缺失项转修复。

## 车道 B（P0）：可空访问防回归机检 IMPLEMENTED

2dcaf41 已清零，缺防回归。新增 scripts/test_scroll_offset_contract.mjs：
全仓禁止 .currentOffset(). 直读（白名单仅 utils/ScrollUserInput.ets），
模式复用 test_settings_backup_contract.mjs。顺手扩查 getImageInfo()/getRectangle()
等返回可空对象的 ArkUI API 直读。

## 车道 C（P1）：164 处空 catch 分级 TODO

只读子代理分文件审计，分两类：
1. 关键链路吞错（网络请求/持久化/状态迁移/登录会话）必须补 stage 日志（模式照
   ReaderSuperResolutionService.recordProcessingFailure：固定阶段名，不泄敏感内容）；
2. 资源清理吞错（release/close/unlink/destroy）可保留，但变量名统一 _cleanupError
   表意，防止与关键吞错混淆。
验收：分类清单 + 关键链路补日志后构建通过。

## 车道 D（P1）：Scaffold 族收敛 TODO

8 个组件 2181 行是副本漂移温床（本次 3 处崩溃点全在其中）。两步：
1. 族内对称性审计：对 PullRefresh x3 / Secondary x3 逐能力对照（onDidScroll/
   onScrollIndex/pinch/nearEnd/refresh），不对称处要么对齐要么写明差异理由；
2. 评估抽取公共 ScrollScaffoldCore（密度/pinch/section 组装），消副本。
涉及可见结构变更的部分走 ui-change-ledger 登记。

## 车道 E（P1，分页批）：NextE 移植删减审计 TODO

用户最痛的私自精简来源。按页面/组件分批 diff NextE 源：每处删减必须有
代码注释理由 or NH 边界证据，二者皆无即为嫌疑项登记。嫌疑项不直接回加代码，
先列清单给用户决策（用户规则：精简必须多代理审核后由用户拍板）。
批次顺序：Reader（历史雷最多）→ Gallery 详情 → 搜索 → 设置 → 其余。

## 车道 F（P2，持续）：流程固化 VERIFIED

- 已建立：incident-register（退化登记）、本次修复即走同类 grep 防扩散模式
- 固化规则：任何 bug 修复提交前，必须 rg 同模式全仓扫描；修复采用公共 helper 收口

## 执行顺序

A → B → C → D → E（E 分批，可与 C/D 穿插）。每车道完成即更新状态并提交。

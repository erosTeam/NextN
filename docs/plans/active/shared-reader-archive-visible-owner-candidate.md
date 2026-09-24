# 共享阅读器 Archive 远跳：B 可见画面所有权候选

状态：**设计候选 / SOURCE 有因，VISUAL OPEN**（2026-09-24）。本文是
`shared-reader-architecture.md` 的一条 L0–L4 纵切说明，不另建执行队列，
不授权 NextE pin、197 装机或默认阅读器替换。

## 已证事实与不能跳过的边界

- NextE Legacy `ReaderPage.jumpToPage` 先等待 `ReaderViewModel.jumpTo`，再更新
  `currentIndex` 与 `Swiper`。本地 Archive 的 `ensureLoaded` 只验证已经种入的
  preview/page 条目，并不等待原图解码或 image-block 判定；旧路径不能被说成
  “同步解码”。
- Shared `ReaderSurface.seekWithPager` 对滑条及远跳设置 `directSelection`；
  `ReaderPagedSession.selectDisplay` 同步发布 B，随后 B slot 才经过
  `ReaderSession.openPrepared/load`。`immediatePages` 只缩短页目录，不提供可绘
  URI。NextE 原图链为 translation → super-resolution → image-block → adapter；
  本地 image-block 判定仍可异步，不能用文件路径绕过。
- 197 旧准备路径的日志已有 B slot `idle → asset → decoding(uri=true)` 与目标
  viewport 挂载，却无 Image leaf/complete；`bcc077b` 的响应式布局标志仅修
  叶挂载活性，尚无匹配设备帧证明。另一次 197 原帧显示“清楚 B（目标层）→
  模糊 B（原生第二节点）→清楚 B”；native-stable/应用帧回调不等于物理清晰
  帧栅栏。因此单改目录、provider 速度、回调顺序或固定等待均不足以宣布修复。

## 共用契约：一次 seek，一个票据，一个可见主画面

| 层 | 独占责任 | Archive B 票据必须携带 / 禁止事项 |
| --- | --- | --- |
| L0 资源 | 通过完整宿主 provider 策略链取得 B 每个 part 的 page、asset、notice/failure 与 lease | `unit/targetKey/part/assetRequestId/variantEpoch` 精确配对；metadata 不能直接变成可见 URI；取消只释放本票据的资源 |
| L1 会话 | `serial/topology/navigation`、`pendingTarget`、`logicalPosition`、旧已呈现 lease | B 的意图不得冒充 `presentedPosition`；连续 seek 只保留最后真正呈现的旧页，不把中间未呈现页当 A |
| L2 画面 | 单个 `VisualOwner`、每 part 实测几何/解码/稳定回执、原子可见提交 | 本候选让原生 Swiper 的 B Image 成为唯一 B 图像节点；A 的已呈现 cover 在它准备期间遮住加载，不能先显示另一张清楚 B 再退给独立解码的 B；失败/取消不可泄露未验 B |
| L3 UI | 读取 L2 `presentedPosition` 与单独的 `pendingTarget`，发送语义 seek、报告实际布局/图像观察 | 正文、页码、滑条已选刻度、缩略轨当前标记必须来自同一已呈现位置；预览 B 不标记为已呈现 B |
| L4 宿主 | NextE 本地 Archive 文件、image-block/翻译/超分策略、路由、系统栏与 Legacy 回退 | 不直接改共享页码、B 显隐或复制 L2 状态机；N/Koma 可用相同契约但不继承 Archive 策略 |

`idle/asset/decoding` 期间，B 的 `LoadingProgress` 只能存在于不可见的准备
子树，不能覆盖主画面。B 尚未通过全部 part 的同身份、实测几何、实际 Image
回执时，L2 仍只声明 A 为 `presentedPosition`；B 是可辨认的 pending 意图。
通过后，L2 退休 A cover，让同一个原生 B Image 成为唯一可见 owner，
并由同一次已呈现提交推进页码/轨道。`decoding + URI` 仅允许 B 在 cover
底下开始原生解码，不是可见提交；必须再有原生 B 每 part 的精确布局、
Image 稳定回执及后续应用帧。没有额外的目标 B overlay，因此不存在两个 B
Image 之间的可见转手。回执仍不是 RenderService 物理清晰帧证明。
下一次 C seek 应继承真正可见的 B owner 与 lease，而非复活旧 A。

失败、取消、旋转、Back 必须按票据身份撤销候选；可见主画面与小范围明确
失败状态由 L2 决定，不用黑画布、全屏加载层或模糊缩略图替代。`onComplete`、
`native-stable`、post-frame 只能作为准入信号；物理清晰连续性仍由匹配签名
HAP 的原始 PTS 帧和同窗身份日志判定。

## 不可隐藏的产品限制与证伪门

第一次 Click 某个未预热远页时，完整 image-block/provider 与原图解码有非零
耗时。若同时要求“点击后 A 一帧也不留、B 必须立刻清晰、且不用空白/加载/
缩略图”，在未缓存 B 的条件下无法保证。可在滑条 Moving 时提前准备真实 B，
但 Click 不一定有 Moving；因此本候选把 **B 已选中** 定义为 L2 可见提交，
pending 时如实保留 A 与明确的 B 预览。该 pending 体验尚未获用户或设备接受，
不得把语义定义当成已解决旧 A 停留问题。

验证必须先用真实方法测试逐段执行 full provider（包括 image-block 拒绝、
异步完成、取消及双 part），证明票据不会把 metadata/URI/decoded/visible
混为一谈；再在同一 197 普通已下载→归档路由比较 Legacy 与候选的整段原始
PTS 帧，查 B 首帧、清楚→模糊→清楚、A/正文与 chrome/滑条错位、失败/重试、
退出与重入。任一黑、模糊、全屏 LoadingProgress、A 回跳或选择错位均 FAIL。
NextN/Koma 与三端默认替换仍各自 OPEN；200 禁止操作。

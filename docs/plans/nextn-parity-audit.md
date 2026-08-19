# NextN 精简审计计划（v1.0.2 之后执行）

## 规模差异基线（2026-08-19）

| 模块 | NextE | NextN | 比率 |
|------|-------|-------|------|
| home | 3725 | 934 | 25% |
| gallery | 12056 | 5251 | 43% |
| reader | 9746 | 4510 | 46% |
| settings | 18590 | 9366 | 50% |
| user | 4893 | 2523 | 51% |
| download | 2161 | 1286 | 59% |
| shared | 87981 | 56469 | 64% |
| search | 2436 | 2526 | 103% |

注意：NH 与 EH 功能面差异（无论坛/标签投票/种子详情等）解释部分差异，但 reader/gallery/settings 的交互骨架是同构的，砍半即砍功能。

## 审计方法
1. 逐模块列出 NextE 顶层 struct/class 清单 vs NextN 实际拥有
2. 对每个缺失面分类：NH 不适用 / 已等价实现 / 被砍待补
3. 被砍待补项按用户影响排序，逐面补齐+真机验证

## 优先级（按用户使用频率）
1. reader（当前正在修，最高频）
2. gallery（详情+列表）
3. settings（已多次发现假功能）
4. home/user
5. download
6. shared 服务层

## 当前进度
- [进行中] reader P0 修复（缩放跳页/本地尺寸/手势误触/翻译按钮/点按指示器）
- [待启动] reader 剩余面审计
- [待启动] gallery 审计
- [待启动] settings 审计


## Reader 结构差异（2026-08-19 对比）

### NextE 独有（NextN 缺失）
- ReaderZoomCoordinator：完整缩放协调（动态最大缩放/锚点缩放/双击循环 1x→2x→native→1x/回弹阻力）
- ReaderInterpolatedImage + ReaderCacheWarmImage：插值渲染与缓存预热组件
- ReaderVerticalImage：独立竖排图片组件（NextN 混在 ReaderImagePage）
- ReaderLoadingBar + ReaderLoadingStage：分阶段加载指示（解析中/加载中/解码中）
- ReaderFailureOverlay：分类型失败覆盖层（含换源重试）
- model 层 6 个文件全部缺失：ReaderComicTranslationAutoPolicy / ReaderImageLoadPriority / ReaderImageLoadPresentation / ReaderThumbnailGeometry / ReaderSessionRequestGate / ReaderImageSourceRequestGate

### 已知影响（用户报告）
- 缩放后跳回入口页（.index 绑 stale resumeIndex）[已修]
- 本地图片尺寸错误（无 intrinsic 测量）[已修]
- 双击误触翻页（无 tap 抑制）[已修]
- 翻译按钮不可点（自作主张 enabled 门控）[已修]
- 点按区域指示器缺失 [已补]


## 审计进展（2026-08-19 第二批）

### Gallery 审计结论
NextE 独有组件多为 EH 特有：ArchiverPage（EH 归档）、TorrentsPage（NH 已在操作卡）、AddTagsSheet（EH 标签投票）、InfoPage（EH 元数据页）。NH 评论 API 无内联图片（GalleryCommentInlineImage 不适用）。NH 相关面（详情/评论/缩略图）全部存在且已修复（头像/翻译/缩略图比例/预览卡）。

### Settings 审计结论
NextE 28 页 vs NextN 15 页。独有页面分类：
- EH 特有（N/A）：EhSettings、EhProfileSettings、AccountCookiePage、AccountLoginPage（NH 用 BrowserSessionPage）
- 已合并进 SettingsPage：Reader、Download、Cache、Search、Layout 设置（rg 验证：reader 3 处、download 66 处、reader settings strings 118 处）
- 等价改名：ColumnDensityPage → BrowseDensitySettingsPage、LocalBlock+ImageBlock → ContentFiltersPage
- 开发者工具：SystemSymbolBrowserPage（暂缓）

### Reader 第二批修复（已提交）
- ReaderZoomCoordinator 完整移植（动态上限/锚点/三段双击/回弹）
- ReaderLoadingBar/ReaderLoadingStage（分阶段加载条）
- Torii 余额行常显（API Key 配置即显示，占位替代从无到有）
- 搜索建议命名空间前缀——代码验证已有（displayPrefix 含 ns:）


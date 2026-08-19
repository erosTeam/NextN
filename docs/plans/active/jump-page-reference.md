 # 跳页功能移植规格（NextE → NextN）
 
 > 来源：jump_page_reference 子代理调研（2026-08-19，只读）。实现时严格按此规格，禁止私自精简。
 
 ## NextE 结构（ToplistPeriodPage.ets）
 
 - 入口：标题栏菜单「跳转」→ 命令总线（HomeSourceState @Trace cmdKind/cmdSeq，单调 seq）→ 页面 @Monitor → openJumpDialog()
 - 对话框：CustomDialogController(CustomContentDialog) primaryTitle+contentBuilder+双 TEXTUAL 按钮；autoCancel:true, Center, customStyle:false
 - 内容树：Column(space SM) → Text(jumpHelpText) → TextInput(Number + inputFilter '^[0-9]*$' + defaultFocus(true)) + onChange(normalizeJumpInput) → 可选红色错误 Text
 - normalizeJumpInput: `(value || '').replace(/[^0-9]/g, '')`
 - jumpHelpText: pageCount<=0 ? help文案 : help文案 + " 1 - N"
 - confirm：jumpSubmitting 防重入 → NaN/<=0/>pageCount 校验 → vm.jumpToToplistPage → 成功 closeDialog + setTimeout(50ms) scrollToIndex(0)；失败 jumpError=load_failed
 - openJumpDialog 预填当前页（1-based），清错误
 - closeJumpDialog try/catch 容忍二次 close
 - VM jumpToToplistPage：0-based 换算 → beginFirstPageRun 取代令牌 → 清游标 → 替换首屏请求 → isCurrentFirstPageRun 防陈旧 → 提交 maxPage/currentPage
 - 文案键（NextE）：toplist_jump_page(跳转/Jump/移動), toplist_jump_help(输入排行榜页码。范围：), toplist_jump_placeholder(页码), toplist_jump_invalid(请输入有效的排行榜页码), common_cancel, common_load_failed
 
 ## NextN 落点
 
 - CustomContentDialog 已有先例：SettingsPage.ets L185-246（V1 形态，AppStrings.get 换 $r）
 - 三个页码分页面：HomePage LatestSourcePage（L73, currentPage/totalPages L85-86, requestBrowse L254, loadFirstPage 替换语义 L271-322, generation 防陈旧）、SearchPage（L101, 状态 L119-120, loadFirstPage L1172-1215, 自持标题栏 searchTitleBar L1880 菜单 L1898-1916）、FavoritesPage（L45, 状态 L66-67, loadMore L470, titleActions L174-187, canUseTitleActions L241）
 - 不适用：历史（游标）、Popular（bare 数组）、评论（无分页）
 - 入口桥：浏览走 HomeSourceState 新 seq（模仿 browseOptionsRequestSeq/layoutMenuRequestSeq）+ Index.ets L1200-1244 菜单项（注意现 4 项 maxCount 3，加第 5 项进溢出）；搜索自持标题栏直接加菜单项 action 调本页方法；收藏走 FavoritesActionState 加 OPEN_JUMP + Index.ets L1245-1274
 - 字符串：entry 资源 base/zh_CN/en_US/ja_JP 四目录新增 4 键；NextN 无 common_load_failed，需新增通用键或复用分面键
 - totalPages 替换首屏时直接取 result.totalPages（勿用 loadMore 的 Math.max(nextPage,...) 只增不减）
 
 ## 风险清单（NextE 已处理，移植必须保留）
 
 1. IME：defaultFocus(true) 打开即弹键盘；NextN 有 KeyboardAvoidMode.RESIZE 先例；落地后必须设备验证按钮 bounds
 2. 双层页码校验（UI NaN/<=0/>N + VM 越界）；helpText 在 N<=0 降级
 3. 跳页=替换首屏（loadFirstPage 语义 + generation 防陈旧），绝不能 appendUnique
 4. 滚动复位：closeDialog → 50ms → scrollToIndex(0)
 5. jumpSubmitting 静默防重入 + 入口 isEnabled 绑定 canLoadMore 类守卫（收藏叠 signedIn + actionsAvailable）
 6. onWillDismiss 清输入状态（SettingsPage 先例），防残留
 7. 收藏无认证 throw 路径要映射错误文案
 8. 浏览菜单容量：加项触发溢出决策，属可见 UI 变化，需同态对照
 9. zh-TW 缺口：两仓库均无 zh_TW 目录，回落 base（与 NextE 一致，不补）
 

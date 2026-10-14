# N/E 原渐变模糊问题与处理经过

记录日期：2026-10-13。状态：**根因分支已定位，缺陷未修复；用户明确转回 Koma，本专项暂停。**

## 原问题与此前结论失效

用户再次报告 NextN、NextE 在无状态栏时来回滚动，顶部原有渐变模糊会消失或范围异常。此前“已修好”的结论被用户实际反例否定，不能拿旧测试次数或其他场景通过抵消。此次目标是保留原有渐变效果、标题隐藏行为及固定来源栏修复此问题。

## 错误处理与撤回

助手把一次 COMMON_BLUR 对照扩大为两轮非渐变替换和重复验证：已核对的统计为8段、116个完成滚动动作、6个改效果的包。用户没有允许换样式。“仍是HDS”“只改枚举”“背景不透明了”都不构成修复依据。错误在于把现象消失当作原功能修复，未将用户明确禁止的样式变化作为停止该方向的条件。

后续又偏向 DevEco/工程信任/自动签名和独立诊断 App，超出原问题需要与用户允许范围；这些方向被用户明确禁止，不能因恢复其他工作而重新启用。独立诊断工程未被用作原缺陷通过证据。

N/E helper 已恢复原字节，Index未改；上述产品修改未提交或推送。03:15:52的197回执确认保留数据覆盖安装原渐变包：N `e1a393acbf9b`，E `526fa6afaffc`；竖屏1260×2720及屏幕override10000ms恢复，租约释放。撤回只纠正越界改动，不代表原缺陷修好。

执行统计和回退回执：`/private/tmp/next-titlebar-recheck-20261013/comparison-execution-audit.json`、`common-comparison-rejected-source-restoration.json`；原画面保留 `.hvigor/outputs/next-titlebar-recheck-20261013/`。

## 有效调查与技术原因

用户随后明确允许现有HDC诊断已安装N/E，以及三份准确系统文件仅本地读取分析。未由此获得系统写入、IDE、自动签名或新App授权。

现有原包N/E现场：外层标题306px，MaskBlur410px；标题隐藏时来源栏仍显示，MaskBlur位移182px且测量高度归零，下滑恢复410px。原包输入仍为GRADIENT_BLUR、hideBottomBuilder=false、hideStatusBar=false；现场原生日志safeAreaTop=0。

197实际HDS库BuildID `105436851bece37e34fcc35319e66004` 中，`HdsTitleBarDynamicPattern::HideTitleDefaultStyle` 在safeAreaTop约为0时直接写动态遮罩目标高度0，没有在该分支考虑保留的bottomBuilder。`HdsNavigationLayoutAlgorithm::Measure`随后把0送给Mask及MaskBlur。展开分支写回初始高度，吻合恢复现象。这里是实际版本静态实现与运行现场的交叉证据，不是私有内存逐帧跟踪，也不证明所有系统版本都相同。

公开接口复核中，相似FAQ处理Scroller共用或内容裁剪，不对应此写零分支。`maskExtraHeight`控制初始额外高度，不能阻止下一次隐藏写零；未通过改高度、安全区、模式或反复试参数制造通过。

完整函数地址、SHA256、字段来源和原始路径见[实际HDS高度写入调查](../../.hvigor/outputs/original-gradient-cause-20261013/hds-native-height-cause.md)；[官方接口复核](/private/tmp/next-original-gradient-exact-library-20261013/official-docs/repair-interface-review.md)保留官方全文及适用边界。三个系统文件均仅本地保留。

## 调查造成的独立异常

读取节点62的高级诊断两次使NextN退出，调用链为DumpTreeById → RosenRenderContext::DumpAdvanceInfo → Gradient::ToString → OffsetT<float>::ToString。两次均发生于上滑前，不能作为N的滚动证据，也不能冒充原渐变问题的根因。已停止节点62及递归触达它的高级查询；后续ogc33用已成功的其他节点取得同进程原滚动失败证据。

## 留存与恢复条件

原缺陷仍OPEN；当前缺保留原效果/行为的可维护修正落点。只有厂商修正、受支持应用侧方法的新依据或用户新的明确指令，才恢复这条调查。不会自行修改系统库、换效果、关闭功能或重复已证失败路径。原始失败及完整证据保留，规则沿用现有[执行规则](../controls/nextn-execution-integrity.md)和[拒绝记录](../controls/rejected-approaches.md)，不再另造复杂许可分类。

用户本次明确要求返回Koma，故后续调度为Koma首版App与中文源并行；本专项的未完成不再占用Koma队列。

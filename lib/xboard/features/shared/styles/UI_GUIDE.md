# XBoard UI 规范（项目内）

这份文档用于约束 XBoard 功能模块 UI 的统一实现方式，避免样式回退到散写状态。

## 1. 总原则

- 优先使用 `Theme.of(context).colorScheme` 与本目录 token。
- 禁止在业务页面中新增散落的硬编码样式（如重复 `Color(0xFFFAFBFD)`、`BorderRadius.circular(20)`、`*.styleFrom(...)`）。
- 新页面先套 token，再做局部差异化。

---

## 2. Token 入口

统一从以下文件使用样式 token：

- [ui_tokens.dart](/Users/pizihu/Downloads/Apex-clinet/lib/xboard/features/shared/styles/ui_tokens.dart)

对外导出：

- [styles.dart](/Users/pizihu/Downloads/Apex-clinet/lib/xboard/features/shared/styles/styles.dart)

---

## 3. 页面与容器规范

### 页面背景

- 浅色模式背景：`XbUiTokens.pageBackgroundLight`
- 用法：
  - `Scaffold(backgroundColor: isDark ? null : XbUiTokens.pageBackgroundLight)`

### 页面边距

- 主滚动区域统一：`XbUiTokens.pagePadding`
- 列表卡片底间距：`XbUiTokens.listCardGapBottom10`

---

## 4. 卡片规范

### 卡片形态

- 统一使用 `XbUiCardStyle.shape(context)`。
- 紧凑卡片（订单/列表项）使用：
  - `XbUiCardStyle.shape(context, radius: XbUiTokens.radiusCardCompact)`

### 避免项

- 不要重复写：
  - `const BorderSide(color: Color(0xFFEEF0F4))`
  - `RoundedRectangleBorder(borderRadius: BorderRadius.circular(...))`

---

## 5. 字体层级规范

统一用 `XbUiText`：

- 页面主标题：`XbUiText.pageTitle(context)`
- 区块标题：`XbUiText.sectionTitle(context)`
- 卡片标题：`XbUiText.cardTitle(context)`
- 辅助文案：`XbUiText.bodySmall(context, color: ...)`

禁止新增大面积 `TextStyle(...)` 散写，必要时只在 token 基础上 `copyWith(...)`。

---

## 6. 按钮规范

统一使用 `XbUiButton`：

- 主按钮：`XbUiButton.filledPrimary(context)`
- 危险按钮：`XbUiButton.filledDanger(context)`
- 次级描边按钮：`XbUiButton.outlinedNeutral(context)`
- 小型胶囊文本按钮（客服/官网）：`XbUiButton.textChipPrimary(context)`

> 业务页面允许通过 `.copyWith(...)` 调整最小高度、状态色，但不应回退到手写 `styleFrom`。

---

## 7. 弹窗规范

统一使用 `XbUiDialog`：

- 形状：`XbUiDialog.shape()`
- 背景：`XbUiDialog.background(context)`
- 取消按钮边框：`XbUiDialog.outlinedSide(context)`

弹窗标题建议使用：

- `XbUiText.sectionTitle(context)`

---

## 8. 状态色规范

统一使用 `XbUiStatusColor`：

- `pending`、`processing`、`success`、`error`、`info`、`offset`、`muted`

禁止在状态映射函数中直接返回 `Colors.red/orange/green/grey/...`。

---

## 9. 新功能页面落地清单（开发时自检）

- 页面背景是否用 `XbUiTokens.pageBackgroundLight`
- 列表 padding 是否用 `XbUiTokens.pagePadding`
- 卡片 shape 是否用 `XbUiCardStyle`
- 标题/正文是否用 `XbUiText`
- 主次按钮是否用 `XbUiButton`
- 弹窗是否用 `XbUiDialog`
- 状态色是否用 `XbUiStatusColor`

---

## 10. 渐进迁移策略

- 先改高频主路径（首页/套餐/支付/我的/邀请）
- 再改中频页面（工单/文档/工具）
- 最后清理遗留散写样式

每次只做一批可验证变更，避免一次性大改带来的回归风险。

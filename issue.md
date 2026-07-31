问题：编辑账单后点击保存，跳转主页面但是页面并未刷新数据

原因和解决方法：\
根本原因

不是刷新机制的问题，而是 ArkUI ForEach 的 key 值不变导致列表不更新 ：

操作 数组长度 Key ( bill.id ) ForEach 行为 添加 变长 新增 key 创建新行 ✅ 删除 变短 减少 key 移除旧行 ✅ 编辑 不变 不变 复用旧视图，不更新内容 ❌

### 修复

将 key 生成器从 String(bill.id ?? 0) 改为包含所有可变字段的组合键：

编辑后任一字段变化都会导致 key 变化， ForEach 会重新渲染该行。

请编译运行，测试编辑保存后主页面列表是否实时更新。

<br />

问题：在主页面的list下方，会自动留出一部分空间

原因和解决方法：

原因：使用Navigation组件，组件自带底部导航栏。

<br />

### 修复

设置组件属性hideTitleBar(true) + expandSafeArea() ，隐藏 Navigation 自带的导航栏区域，让内容全屏铺满。

<br />

问题：@Watch 装饰器与 @Prop / @StorageLink 组合使用报编译错误

原因和解决方法：
根本原因

当前项目版本的 ArkTS 中，@Watch 在 @Component（非 @Entry）上不能与其他状态管理装饰器同时使用，尝试跨组件传参触发子组件方法时编译报错：

@Prop @Watch(...)  → '@Watch' cannot be used with @Prop
@StorageLink(...) @Watch(...)  → '@Watch' cannot be used with @StorageLink

### 修复

不再依赖 @Watch 做跨组件方法调用，改为父组件直接处理逻辑：

父组件（Index.ets）持有整个添加流程（弹窗 + 保存），子组件（Plan.ets）仅通过 @StorageLink('planNeedRefresh') 接收刷新信号，用 aboutToAppear() 重新加载数据。

<br />

问题：自定义对话框中分类栏渲染为空

原因和解决方法：
根本原因

分类列表使用 getter 属性返回数组，ForEach 无法对 getter 每次返回的新数组建立响应式依赖，导致界面不渲染：

get categories(): string[] { ... }   // ForEach 渲染为空

### 修复

改用 @State 状态变量存储分类数组，与 AddBill.ets 的写法保持一致：

@State categories: string[] = getCategories(BillType.EXPENSE);

切换收支类型时调用 this.categories = getCategories(type) 重新赋值，ForEach 即可正常渲染并响应切换。

<br />

问题：ArkTS 不允许匿名对象字面量（编译错误 arkts-no-untyped-obj-literals）

原因和解决方法：
根本原因

ArkTS 要求对象字面量必须对应显式声明的 class 或 interface，使用内联对象类型声明数组会编译失败：

const INTERVAL_OPTIONS: { label: string; value: string }[] = [...]  // 报错

### 修复

先声明接口再定义数组：

interface IntervalOption { label: string; value: string; }
const INTERVAL_OPTIONS: IntervalOption[] = [...];

<br />

问题：DatePickerDialog / TimePickerDialog 回调 API 名称与参数类型不一致

原因和解决方法：
根本原因

API 版本差异导致以下编译错误：

onDateAccept 回调参数不是 DatePickerResult，而是 Callback<Date, void>
TimePickerDialog 没有 onTimeAccept，正确属性名为 onAccept
onAccept 回调无参数（不传 Date / TimePickerResult）
offset 属性类型为 Offset 对象，不能传 [0, 0] 数组

### 修复

统一使用无参 onAccept 回调，通过 selected 传入绑定对象，确认后用 new Date(date.getTime()) 触发状态刷新：

DatePickerDialog.show({
  selected: this.selectedDate,
  offset: { dx: 0, dy: 0 },
  onAccept: () => { ... }
});
TimePickerDialog.show({
  selected: this.selectedDate,
  offset: { dx: 0, dy: 0 },
  onAccept: () => { ... }
});

<br />

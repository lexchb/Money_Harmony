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

问题：当前定时计划任务存在的问题- 依赖前台运行 ： setInterval 挂载在 Index 页面生命周期，App 进后台/杀进程后定时器停止

\- 兜底机制 ：每次启动 aboutToAppear 会立即补检，所以错过的任务在下次打开 App 时仍会补记

\- 计划展示 ：定时任务创建时同步生成一条 plans 记录，计划列表即可看到该分类的目标金额与实际进度

<br />

**修复方案**

如果需要 真正后台自动执行 （App 关闭也能触发），需要改用 HarmonyOS WorkScheduler 注册系统级周期任务，这个方案是否可行？

<br />

问题：打开"目标详情"对话框时闪退，报错 Cannot read property toFixed of undefined

原因和解决方法：

根本原因

ArkUI 组件 struct 的 build 渲染阶段无法正确解析 getter 属性。在 @CustomDialog 组件中使用了 getter 语法：

```typescript
get total(): number { ... }
```

渲染时状态管理框架（stateMgmt）读取 `this.total` 得到 undefined，传入 `formatMoney(undefined)` 后调用 `undefined.toFixed()` 抛出 TypeError，导致应用闪退。

### 修复

将 getter 改为普通方法，在 build 中调用方法获取计算值：

```typescript
totalValue(): number { ... }
// build 中
Text(`¥${formatMoney(this.totalValue())}`)
```

方法调用在 build 中可以正常解析，规避了 getter 不被状态管理框架识别的问题。


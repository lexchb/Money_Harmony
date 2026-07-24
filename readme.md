# Money Harmony - 鸿蒙记账 App

一个基于 HarmonyOS 的简单记账应用，支持手动录入和管理账单信息。

---

## 开发步骤

### 1. 定义账单数据模型

创建 `entry/src/main/ets/model/Bill.ets`，定义账单数据结构：

- `id` — 唯一标识
- `amount` — 金额（分为收入/支出）
- `category` — 分类（餐饮、购物、交通等）
- `date` — 日期
- `note` — 备注
- `type` — 类型（income / expense）

### 2. 数据持久化

使用 `@ohos.data.preferences`（首选项）或 `@kit.ArkData` 的 `relationalStore`（关系型数据库）实现账单数据的增删改查。

推荐步骤：
- 创建 `entry/src/main/ets/model/DatabaseHelper.ets`，封装数据操作
- 实现方法：`addBill()`、`getAllBills()`、`updateBill()`、`deleteBill()`

### 3. 账单列表页（首页）

修改 `Index.ets`，展示账单列表：

- 使用 `List` 组件 + `ForEach` 循环渲染
- 每条账单显示：类别图标、金额、分类名称、日期
- 支持按日期分组展示
- 顶部显示当月总收入和总支出

### 4. 添加账单页

新建 `entry/src/main/ets/pages/AddBill.ets`：

- 金额输入框（`TextInput`）
- 类型选择（收入/支出，使用 `Radio` 或 `Toggle`）
- 分类选择（使用 `Select` 或自定义弹窗）
- 日期选择（使用 `DatePicker`）
- 备注输入框（`TextArea`）
- 保存按钮 → 调用数据层写入并返回首页

在 `main_pages.json` 中注册新增页面。

### 5. 编辑/删除账单

复用添加账单页，接收账单 `id` 作为参数实现编辑模式：

- 进入编辑页时回填已有数据
- 修改后保存更新
- 支持删除操作（弹窗确认）

### 6. 统计功能

新建 `entry/src/main/ets/pages/Statistics.ets`：

- 按月筛选
- 按分类统计支出占比
- 总收入/总支出/结余展示
- 使用 `PieChart` 或自定义 `Canvas` 绘制简易图表

### 7. UI 美化与体验优化

- 统一主题色和圆角风格
- 输入校验（金额必须大于 0、备注长度限制）
- 空数据占位图
- 下拉刷新
- 启动图标替换

---

## 项目结构（完成后）

```
entry/src/main/ets/
├── model/
│   ├── Bill.ets              # 账单数据模型
│   └── DatabaseHelper.ets    # 数据库操作封装
├── pages/
│   ├── Index.ets             # 账单列表首页
│   ├── AddBill.ets           # 添加/编辑账单
│   └── Statistics.ets        # 统计页面
└── entryability/
    └── EntryAbility.ets      # Ability 入口
```

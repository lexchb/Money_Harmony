# Money Harmony - 鸿蒙记账 App

一个基于 HarmonyOS（ArkTS / Stage 模型）的记账应用，支持账单管理、计划管理与定时自动记账。

---

## 功能特性

### 1. 账单管理（首页）
- 按月展示账单列表（顶部卡片显示当月支出 / 收入 / 结余）
- 月份切换（← 上月 / 下月 →）
- 添加账单：金额、类型（支出/收入）、分类、日期、备注
- 点击账单进入编辑页，修改后保存并自动刷新列表
- 长按账单进入多选删除模式，支持批量删除（带过渡动画）
- 列表项带有进入/退出过渡动画，底部 Dock 导航栏毛玻璃效果

### 2. 计划管理（计划页）
- 概述卡片：展示数据库中所有定时计划的支出 / 收入计划个数
- 计划列表：展示全部定时计划详情（分类、类型、执行间隔、金额、开始时间）
- 点击计划项 → 编辑定时计划（复用添加对话框，预填数据）
- 长按计划项 → 删除确认
- 列表项动画与账单列表一致

### 3. 定时记账（核心特色）
- 通过"添加计划"按钮创建定时任务，可设置：
  - 类型：支出 / 收入
  - 金额、分类（随类型动态切换）
  - 开始时间：日期选择器 + 24 小时制时间选择器
  - 执行间隔：每天 / 每周 / 每月 / 每季度 / 每年
  - 跳过周末：仅"每天"间隔可开启，周六日不执行
  - 备注
- 执行机制：主页面每 60 秒检查一次到期任务，自动创建对应账单；App 启动时立即补检（关闭期间错过的任务在下次打开时补记）
- 首次执行按 `startTime` 判断，之后按间隔自动推算下次执行时间

---

## 技术栈

- **语言/框架**：ArkTS（ArkUI 声明式 UI，Stage 模型）
- **数据存储**：`@kit.ArkData` 的 `relationalStore`（关系型数据库 RDB）
- **页面导航**：`Navigation` + `NavPathStack`，配合 `.hideTitleBar(true)` + `.expandSafeArea()` 全屏布局
- **跨页面通信**：`AppStorage` / `@StorageLink` + `@Watch`（@Entry 层）
- **金额规范**：所有金额以 `Math.round(parseFloat(x) * 100) / 100` 保留两位小数

---

## 项目结构

```
entry/src/main/ets/
├── components/
│   ├── AddBill.ets                # 添加账单页（NavDestination）
│   ├── AddScheduledTaskDialog.ets # 添加/编辑定时任务对话框（@CustomDialog）
│   ├── EditBill.ets               # 编辑账单页（NavDestination）
│   └── Plan.ets                   # 计划页内容（PlanContent）
├── entryability/
│   └── EntryAbility.ets           # Ability 入口（初始化数据库后再加载页面）
├── entrybackupability/
│   └── EntryBackupAbility.ets     # 备份能力
├── model/
│   ├── Bill.ets                   # 数据模型与工具函数
│   └── DatabaseHelper.ets         # 数据库操作封装（单例 dbHelper）
└── pages/
    └── Index.ets                  # 主页面：账单 Tab + 计划 Tab + 底部导航
```

---

## 数据模型（model/Bill.ets）

| 类型 | 说明 |
|------|------|
| `Bill` | 账单：`amount` / `type`(expense/income) / `category` / `date` / `note` / `createTime` |
| `ScheduledTask` | 定时任务：`type` / `amount` / `category` / `startTime` / `intervalType`(day/week/month/quarter/year) / `note` / `lastExecuted` / `isActive` / `skipWeekend` |
| `CategorySpent` | 分类统计：`category` / `amount` |

工具函数：
- `getCategories(type)` — 按类型返回分类列表（支出 9 类、收入 6 类）
- `formatMoney(amount)` / `todayString()` — 金额格式化、今日日期
- `isWeekend(ts)` / `nextExecutionTime(last, intervalType)` — 周末判断、下次执行时间推算

## 数据库（model/DatabaseHelper.ets）

数据库 `MoneyHarmony.db`，版本 v2，包含两张表：

| 表 | 用途 |
|----|------|
| `bills` | 账单记录 |
| `scheduled_tasks` | 定时任务（含 `lastExecuted`、`isActive`、`skipWeekend` 字段） |

关键方法：
- 账单：`addBill` / `getAllBills` / `getBillsByMonth` / `updateBill` / `deleteBill` / `getMonthlyStats` / `getCategorySpent`
- 定时任务：`addScheduledTask` / `getActiveScheduledTasks` / `getAllScheduledTasks` / `updateScheduledTask` / `updateScheduledTaskLastExecuted` / `deleteScheduledTask`
- 核心：`executeDueScheduledTasks()` — 检查并执行到期任务，返回本次创建的账单数量

初始化流程：`EntryAbility.onWindowStageCreate` 中先 `dbHelper.init()` 完成建表，成功后再 `loadContent` 加载首页，避免首屏空数据。老版本升级通过 `ALTER TABLE` 补充 `skipWeekend` 列。

---

## 页面说明

### Index.ets（主页面）
- 顶部标题栏随 Tab 切换：「账单」+ 记一笔 / 「计划」+ 添加计划
- 账单 Tab：月份切换 + 统计卡片 + 账单列表（多选删除、点击编辑、过渡动画）
- 计划 Tab：`ForEach([planRefreshKey])` 包裹 `PlanContent`，通过改变 key 强制重挂载实现保存后即时刷新
- 底部 Dock：首页 / 统计 / 计划 / 我的 / 设置（统计、我的、设置为占位）
- 生命周期：`aboutToAppear` 启动定时任务检查（立即一次 + `setInterval` 60s），`aboutToDisappear` 清除定时器

### Plan.ets（计划页内容）
- 概述卡片：支出计划数 / 收入计划数（统计全部定时任务）
- 列表：`dbHelper.getAllScheduledTasks()` 加载全部计划；点击编辑、长按删除
- 编辑对话框：动态创建 `CustomDialogController`，传入 `editTask` 复用 `AddScheduledTaskDialog`

### AddScheduledTaskDialog.ets（定时任务对话框）
- 添加 / 编辑双模式：`editTask` 非空时预填数据并更新，否则新增
- 时间选择：`DatePickerDialog`（`onDateAccept`）+ `TimePickerDialog`（`useMilitaryTime: true` 24 小时制）
- 跳过周末开关仅在选择"每天"间隔时显示

---

## 开发与运行

- 使用 DevEco Studio 打开项目，连接鸿蒙设备或模拟器后运行
- 编译产物位于 `entry/build`，构建命令见 hvigor 配置

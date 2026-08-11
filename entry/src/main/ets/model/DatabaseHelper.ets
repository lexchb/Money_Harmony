import { relationalStore } from '@kit.ArkData';
import { Context } from '@kit.AbilityKit';
import { Bill, BillType, CategorySpent, Goal, GoalType, ScheduledTask, nextExecutionTime, isWeekend, formatDate } from './Bill';

const DB_NAME = 'MoneyHarmony.db';
const TABLE_NAME = 'bills';
const SCHEDULED_TASKS_TABLE = 'scheduled_tasks';
const GOALS_TABLE = 'goals';
const GOAL_RECORDS_TABLE = 'goal_records';
const DB_VERSION = 2;

const CREATE_TABLE_SQL = `CREATE TABLE IF NOT EXISTS ${TABLE_NAME} (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  amount REAL NOT NULL,
  type TEXT NOT NULL,
  category TEXT NOT NULL,
  date TEXT NOT NULL,
  note TEXT DEFAULT '',
  goalId INTEGER DEFAULT 0,
  createTime INTEGER NOT NULL
)`;

const CREATE_SCHEDULED_TASKS_SQL = `CREATE TABLE IF NOT EXISTS ${SCHEDULED_TASKS_TABLE} (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  type TEXT NOT NULL,
  amount REAL NOT NULL,
  category TEXT DEFAULT '',
  startTime INTEGER NOT NULL,
  intervalType TEXT NOT NULL,
  note TEXT DEFAULT '',
  lastExecuted INTEGER DEFAULT 0,
  isActive INTEGER DEFAULT 1,
  skipWeekend INTEGER DEFAULT 0,
  createTime INTEGER NOT NULL
)`;

const CREATE_GOALS_SQL = `CREATE TABLE IF NOT EXISTS ${GOALS_TABLE} (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  name TEXT NOT NULL,
  type TEXT NOT NULL,
  targetAmount REAL NOT NULL,
  periodType TEXT NOT NULL,
  startTime INTEGER NOT NULL,
  manualAmount REAL DEFAULT 0,
  createTime INTEGER NOT NULL
)`;

const CREATE_GOAL_RECORDS_SQL = `CREATE TABLE IF NOT EXISTS ${GOAL_RECORDS_TABLE} (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  goalId INTEGER NOT NULL,
  amount REAL NOT NULL,
  createTime INTEGER NOT NULL
)`;

export interface MonthlyStats {
  totalIncome: number;
  totalExpense: number;
}

class DatabaseHelper {
  private store: relationalStore.RdbStore | null = null;

  async init(context: Context): Promise<void> {
    if (this.store) {
      return;
    }
    try {
      const config: relationalStore.StoreConfig = {
        name: DB_NAME,
        securityLevel: relationalStore.SecurityLevel.S1,
      };
      this.store = await relationalStore.getRdbStore(context, config);
      await this.store.executeSql(CREATE_TABLE_SQL);
      await this.store.executeSql(CREATE_SCHEDULED_TASKS_SQL);
      await this.store.executeSql(CREATE_GOALS_SQL);
      await this.store.executeSql(CREATE_GOAL_RECORDS_SQL);
      // 老版本数据库升级：补充 skipWeekend 列
      try {
        await this.store.executeSql(`ALTER TABLE ${SCHEDULED_TASKS_TABLE} ADD COLUMN skipWeekend INTEGER DEFAULT 0`);
      } catch (e) {
        // 列已存在，忽略
      }
      // 老版本数据库升级：补充 goalId 列
      try {
        await this.store.executeSql(`ALTER TABLE ${TABLE_NAME} ADD COLUMN goalId INTEGER DEFAULT 0`);
      } catch (e) {
        // 列已存在，忽略
      }
      // 旧版数据迁移：manualAmount 累计字段转为按周期统计的手动记录（记录时间戳为当前时刻，计入当前周期）
      await this.migrateLegacyManualAmount();
    } catch (e) {
      console.error('Database init failed:', (e as Error).message);
    }
  }

  async addBill(bill: Bill): Promise<number> {
    if (!this.store) {
      console.error('Database not initialized');
      return -1;
    }
    const valueBucket: relationalStore.ValuesBucket = {
      amount: bill.amount,
      type: bill.type,
      category: bill.category,
      date: bill.date,
      note: bill.note || '',
      goalId: bill.goalId ?? 0,
      createTime: Date.now(),
    };
    return this.store.insert(TABLE_NAME, valueBucket);
  }

  async getAllBills(): Promise<Bill[]> {
    if (!this.store) {
      console.error('Database not initialized');
      return [];
    }
    const predicates = new relationalStore.RdbPredicates(TABLE_NAME);
    predicates.orderByDesc('date');
    predicates.orderByDesc('createTime');
    const resultSet = await this.store.query(predicates, [
      'id', 'amount', 'type', 'category', 'date', 'note', 'goalId', 'createTime',
    ]);
    const bills: Bill[] = [];
    while (resultSet.goToNextRow()) {
      bills.push({
        id: resultSet.getLong(resultSet.getColumnIndex('id')),
        amount: resultSet.getDouble(resultSet.getColumnIndex('amount')),
        type: resultSet.getString(resultSet.getColumnIndex('type')) as BillType,
        category: resultSet.getString(resultSet.getColumnIndex('category')),
        date: resultSet.getString(resultSet.getColumnIndex('date')),
        note: resultSet.getString(resultSet.getColumnIndex('note')),
        goalId: resultSet.getLong(resultSet.getColumnIndex('goalId')),
        createTime: resultSet.getLong(resultSet.getColumnIndex('createTime')),
      });
    }
    resultSet.close();
    return bills;
  }

  async getBillsByMonth(yearMonth: string): Promise<Bill[]> {
    if (!this.store) {
      console.error('Database not initialized');
      return [];
    }
    const predicates = new relationalStore.RdbPredicates(TABLE_NAME);
    predicates.like('date', `${yearMonth}%`);
    predicates.orderByDesc('date');
    predicates.orderByDesc('createTime');
    const resultSet = await this.store.query(predicates, [
      'id', 'amount', 'type', 'category', 'date', 'note', 'goalId', 'createTime',
    ]);
    const bills: Bill[] = [];
    while (resultSet.goToNextRow()) {
      bills.push({
        id: resultSet.getLong(resultSet.getColumnIndex('id')),
        amount: resultSet.getDouble(resultSet.getColumnIndex('amount')),
        type: resultSet.getString(resultSet.getColumnIndex('type')) as BillType,
        category: resultSet.getString(resultSet.getColumnIndex('category')),
        date: resultSet.getString(resultSet.getColumnIndex('date')),
        note: resultSet.getString(resultSet.getColumnIndex('note')),
        goalId: resultSet.getLong(resultSet.getColumnIndex('goalId')),
        createTime: resultSet.getLong(resultSet.getColumnIndex('createTime')),
      });
    }
    resultSet.close();
    return bills;
  }

  async updateBill(bill: Bill): Promise<number> {
    if (!this.store) {
      console.error('Database not initialized');
      return 0;
    }
    const predicates = new relationalStore.RdbPredicates(TABLE_NAME);
    predicates.equalTo('id', bill.id);
    const valueBucket: relationalStore.ValuesBucket = {
      amount: bill.amount,
      type: bill.type,
      category: bill.category,
      date: bill.date,
      note: bill.note || '',
      goalId: bill.goalId ?? 0,
    };
    return this.store.update(valueBucket, predicates);
  }

  async deleteBill(id: number): Promise<number> {
    if (!this.store) {
      console.error('Database not initialized');
      return 0;
    }
    const predicates = new relationalStore.RdbPredicates(TABLE_NAME);
    predicates.equalTo('id', id);
    return this.store.delete(predicates);
  }

  async getMonthlyStats(yearMonth: string): Promise<MonthlyStats> {
    if (!this.store) {
      console.error('Database not initialized');
      return { totalIncome: 0, totalExpense: 0 } as MonthlyStats;
    }
    const sql = `SELECT
      COALESCE(SUM(CASE WHEN type = 'income' THEN amount ELSE 0 END), 0) AS totalIncome,
      COALESCE(SUM(CASE WHEN type = 'expense' THEN amount ELSE 0 END), 0) AS totalExpense
      FROM ${TABLE_NAME} WHERE date LIKE ?`;
    const resultSet = await this.store.querySql(sql, [`${yearMonth}%`]);
    let totalIncome = 0;
    let totalExpense = 0;
    if (resultSet.goToFirstRow()) {
      totalIncome = resultSet.getDouble(resultSet.getColumnIndex('totalIncome'));
      totalExpense = resultSet.getDouble(resultSet.getColumnIndex('totalExpense'));
    }
    resultSet.close();
    return { totalIncome: totalIncome, totalExpense: totalExpense } as MonthlyStats;
  }

  // ===== 定时任务相关方法 =====

  async getCategorySpent(month: string, type: BillType): Promise<CategorySpent[]> {
    if (!this.store) {
      return [];
    }
    const sql = `SELECT category, COALESCE(SUM(amount), 0) AS amount
      FROM ${TABLE_NAME}
      WHERE date LIKE ? AND type = ?
      GROUP BY category`;
    const resultSet = await this.store.querySql(sql, [`${month}%`, type]);
    const result: CategorySpent[] = [];
    while (resultSet.goToNextRow()) {
      result.push({
        category: resultSet.getString(resultSet.getColumnIndex('category')),
        amount: resultSet.getDouble(resultSet.getColumnIndex('amount')),
      });
    }
    resultSet.close();
    return result;
  }

  // ===== 定时任务相关方法 =====

  async addScheduledTask(task: ScheduledTask): Promise<number> {
    if (!this.store) {
      console.error('Database not initialized');
      return -1;
    }
    const valueBucket: relationalStore.ValuesBucket = {
      type: task.type,
      amount: task.amount,
      category: task.category || '',
      startTime: task.startTime,
      intervalType: task.intervalType,
      note: task.note || '',
      lastExecuted: task.lastExecuted ?? 0,
      isActive: task.isActive ? 1 : 0,
      skipWeekend: task.skipWeekend === true ? 1 : 0,
      createTime: Date.now(),
    };
    return this.store.insert(SCHEDULED_TASKS_TABLE, valueBucket);
  }

  async getActiveScheduledTasks(): Promise<ScheduledTask[]> {
    if (!this.store) {
      return [];
    }
    const predicates = new relationalStore.RdbPredicates(SCHEDULED_TASKS_TABLE);
    predicates.equalTo('isActive', 1);
    predicates.orderByAsc('startTime');
    const resultSet = await this.store.query(predicates, [
      'id', 'type', 'amount', 'category', 'startTime', 'intervalType', 'note', 'lastExecuted', 'isActive', 'skipWeekend', 'createTime',
    ]);
    const tasks: ScheduledTask[] = [];
    while (resultSet.goToNextRow()) {
      tasks.push(this.rowToScheduledTask(resultSet));
    }
    resultSet.close();
    return tasks;
  }

  async getAllScheduledTasks(): Promise<ScheduledTask[]> {
    if (!this.store) {
      return [];
    }
    const predicates = new relationalStore.RdbPredicates(SCHEDULED_TASKS_TABLE);
    predicates.orderByDesc('createTime');
    const resultSet = await this.store.query(predicates, [
      'id', 'type', 'amount', 'category', 'startTime', 'intervalType', 'note', 'lastExecuted', 'isActive', 'skipWeekend', 'createTime',
    ]);
    const tasks: ScheduledTask[] = [];
    while (resultSet.goToNextRow()) {
      tasks.push(this.rowToScheduledTask(resultSet));
    }
    resultSet.close();
    return tasks;
  }

  async updateScheduledTaskLastExecuted(id: number, lastExecuted: number): Promise<void> {
    if (!this.store) {
      return;
    }
    const predicates = new relationalStore.RdbPredicates(SCHEDULED_TASKS_TABLE);
    predicates.equalTo('id', id);
    await this.store.update({ lastExecuted: lastExecuted }, predicates);
  }

  /** 更新定时任务（不修改 lastExecuted，避免已执行任务被重复记账） */
  async updateScheduledTask(task: ScheduledTask): Promise<number> {
    if (!this.store) {
      return 0;
    }
    const predicates = new relationalStore.RdbPredicates(SCHEDULED_TASKS_TABLE);
    predicates.equalTo('id', task.id);
    const valueBucket: relationalStore.ValuesBucket = {
      type: task.type,
      amount: task.amount,
      category: task.category || '',
      startTime: task.startTime,
      intervalType: task.intervalType,
      note: task.note || '',
      isActive: task.isActive ? 1 : 0,
      skipWeekend: task.skipWeekend === true ? 1 : 0,
    };
    return this.store.update(valueBucket, predicates);
  }

  async deleteScheduledTask(id: number): Promise<number> {
    if (!this.store) {
      return 0;
    }
    const predicates = new relationalStore.RdbPredicates(SCHEDULED_TASKS_TABLE);
    predicates.equalTo('id', id);
    return this.store.delete(predicates);
  }

  private rowToScheduledTask(rs: relationalStore.ResultSet): ScheduledTask {
    return {
      id: rs.getLong(rs.getColumnIndex('id')),
      type: rs.getString(rs.getColumnIndex('type')) as BillType,
      amount: rs.getDouble(rs.getColumnIndex('amount')),
      category: rs.getString(rs.getColumnIndex('category')),
      startTime: rs.getLong(rs.getColumnIndex('startTime')),
      intervalType: rs.getString(rs.getColumnIndex('intervalType')),
      note: rs.getString(rs.getColumnIndex('note')),
      lastExecuted: rs.getLong(rs.getColumnIndex('lastExecuted')),
      isActive: rs.getLong(rs.getColumnIndex('isActive')) === 1,
      skipWeekend: rs.getLong(rs.getColumnIndex('skipWeekend')) === 1,
      createTime: rs.getLong(rs.getColumnIndex('createTime')),
    };
  }

  /**
   * 检查并执行到期的定时任务，返回本次执行的账单数量。
   *
   * 以 startTime 为锚点沿固定周期推算执行时间点（startTime、startTime+1周期、+2周期…），
   * 从上次已执行的时间点之后开始，直到当前时刻，逐个时间点执行；
   * App 关闭期间错过的周期在下次打开时补齐（补记账单日期使用对应的计划日期）。
   */
  async executeDueScheduledTasks(): Promise<number> {
    if (!this.store) {
      return 0;
    }
    const now = Date.now();
    const tasks = await this.getActiveScheduledTasks();
    let executedCount = 0;

    for (const task of tasks) {
      const lastExecuted = task.lastExecuted ?? 0;

      // 以 startTime 为锚点，先定位到第一个未执行过的计划时间点
      let scheduled = task.startTime;
      while (scheduled <= lastExecuted) {
        scheduled = nextExecutionTime(scheduled, task.intervalType);
      }

      // 逐个执行从上次之后到当前时刻之间所有到期的计划时间点（含补记）
      while (scheduled <= now) {
        // 每天任务且开启跳过周末：周六/周日到期的时间点跳过，不创建账单，仅推进 lastExecuted
        const isSkip = task.skipWeekend === true && task.intervalType === 'day' && isWeekend(scheduled);

        if (!isSkip) {
          const bill: Bill = {
            amount: task.amount,
            type: task.type,
            category: task.category,
            date: formatDate(scheduled),
            note: task.note || `[定时] ${task.intervalType === 'day' ? '每日' : task.intervalType === 'week' ? '每周' : task.intervalType === 'month' ? '每月' : task.intervalType === 'quarter' ? '每季度' : '每年'}记账`,
          };
          await this.addBill(bill);
          executedCount++;
        }

        await this.updateScheduledTaskLastExecuted(task.id!, scheduled);
        scheduled = nextExecutionTime(scheduled, task.intervalType);
      }
    }
    return executedCount;
  }

  // ===== 目标相关方法 =====

  async addGoal(goal: Goal): Promise<number> {
    if (!this.store) {
      console.error('Database not initialized');
      return -1;
    }
    const valueBucket: relationalStore.ValuesBucket = {
      name: goal.name,
      type: goal.type,
      targetAmount: goal.targetAmount,
      periodType: goal.periodType,
      startTime: goal.startTime,
      manualAmount: 0,
      createTime: Date.now(),
    };
    return this.store.insert(GOALS_TABLE, valueBucket);
  }

  async getGoals(): Promise<Goal[]> {
    if (!this.store) {
      return [];
    }
    const predicates = new relationalStore.RdbPredicates(GOALS_TABLE);
    predicates.orderByDesc('createTime');
    const resultSet = await this.store.query(predicates, [
      'id', 'name', 'type', 'targetAmount', 'periodType', 'startTime', 'createTime',
    ]);
    const goals: Goal[] = [];
    while (resultSet.goToNextRow()) {
      goals.push(this.rowToGoal(resultSet));
    }
    resultSet.close();
    return goals;
  }

  /** 更新目标基本信息（不改变手动记录） */
  async updateGoal(goal: Goal): Promise<number> {
    if (!this.store) {
      return 0;
    }
    const predicates = new relationalStore.RdbPredicates(GOALS_TABLE);
    predicates.equalTo('id', goal.id);
    const valueBucket: relationalStore.ValuesBucket = {
      name: goal.name,
      type: goal.type,
      targetAmount: goal.targetAmount,
      periodType: goal.periodType,
      startTime: goal.startTime,
    };
    return this.store.update(valueBucket, predicates);
  }

  /** 新增一条手动记录（攒钱目标），按时间戳计入对应周期 */
  async addGoalRecord(goalId: number, amount: number, createTime?: number): Promise<number> {
    if (!this.store) {
      return -1;
    }
    const valueBucket: relationalStore.ValuesBucket = {
      goalId: goalId,
      amount: amount,
      createTime: createTime ?? Date.now(),
    };
    return this.store.insert(GOAL_RECORDS_TABLE, valueBucket);
  }

  /** 查询某目标在时间区间 [start, end) 内手动记录的金额合计 */
  async getGoalManualTotalInRange(goalId: number, start: number, end: number): Promise<number> {
    if (!this.store) {
      return 0;
    }
    const sql = `SELECT COALESCE(SUM(amount), 0) AS total
      FROM ${GOAL_RECORDS_TABLE}
      WHERE goalId = ? AND createTime >= ? AND createTime < ?`;
    const resultSet = await this.store.querySql(sql, [goalId, start, end]);
    let total = 0;
    if (resultSet.goToFirstRow()) {
      total = resultSet.getDouble(resultSet.getColumnIndex('total'));
    }
    resultSet.close();
    return total;
  }

  async deleteGoal(id: number): Promise<number> {
    if (!this.store) {
      return 0;
    }
    const predicates = new relationalStore.RdbPredicates(GOALS_TABLE);
    predicates.equalTo('id', id);
    return this.store.delete(predicates);
  }

  /** 查询某目标在日期区间 [startDate, endDate) 内指定收支类型的账单金额合计 */
  async getGoalSpentInRange(goalId: number, type: BillType, startDate: string, endDate: string): Promise<number> {
    if (!this.store) {
      return 0;
    }
    const sql = `SELECT COALESCE(SUM(amount), 0) AS total
      FROM ${TABLE_NAME}
      WHERE goalId = ? AND type = ? AND date >= ? AND date < ?`;
    const resultSet = await this.store.querySql(sql, [goalId, type, startDate, endDate]);
    let total = 0;
    if (resultSet.goToFirstRow()) {
      total = resultSet.getDouble(resultSet.getColumnIndex('total'));
    }
    resultSet.close();
    return total;
  }

  private rowToGoal(rs: relationalStore.ResultSet): Goal {
    return {
      id: rs.getLong(rs.getColumnIndex('id')),
      name: rs.getString(rs.getColumnIndex('name')),
      type: rs.getString(rs.getColumnIndex('type')) as GoalType,
      targetAmount: rs.getDouble(rs.getColumnIndex('targetAmount')),
      periodType: rs.getString(rs.getColumnIndex('periodType')),
      startTime: rs.getLong(rs.getColumnIndex('startTime')),
      createTime: rs.getLong(rs.getColumnIndex('createTime')),
    };
  }

  /** 旧版数据迁移：将 goals 表的 manualAmount 累计值转为手动记录，避免升级后数据丢失 */
  private async migrateLegacyManualAmount(): Promise<void> {
    if (!this.store) {
      return;
    }
    try {
      const legacy = await this.store.querySql(`SELECT id, manualAmount FROM ${GOALS_TABLE} WHERE manualAmount > 0`);
      const items: { id: number; amount: number }[] = [];
      while (legacy.goToNextRow()) {
        items.push({
          id: legacy.getLong(legacy.getColumnIndex('id')),
          amount: legacy.getDouble(legacy.getColumnIndex('manualAmount')),
        });
      }
      legacy.close();
      for (const item of items) {
        await this.addGoalRecord(item.id, item.amount, Date.now());
      }
      if (items.length > 0) {
        await this.store.executeSql(`UPDATE ${GOALS_TABLE} SET manualAmount = 0`);
      }
    } catch (e) {
      // 新库不存在 manualAmount 列或已迁移完成，忽略
    }
  }
}

export const dbHelper = new DatabaseHelper();

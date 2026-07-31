import { relationalStore } from '@kit.ArkData';
import { Context } from '@kit.AbilityKit';
import { Bill, BillType, Plan, CategorySpent, ScheduledTask, nextExecutionTime, isWeekend } from './Bill';

const DB_NAME = 'MoneyHarmony.db';
const TABLE_NAME = 'bills';
const PLANS_TABLE = 'plans';
const SCHEDULED_TASKS_TABLE = 'scheduled_tasks';
const DB_VERSION = 2;

const CREATE_TABLE_SQL = `CREATE TABLE IF NOT EXISTS ${TABLE_NAME} (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  amount REAL NOT NULL,
  type TEXT NOT NULL,
  category TEXT NOT NULL,
  date TEXT NOT NULL,
  note TEXT DEFAULT '',
  createTime INTEGER NOT NULL
)`;

const CREATE_PLANS_SQL = `CREATE TABLE IF NOT EXISTS ${PLANS_TABLE} (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  type TEXT NOT NULL,
  category TEXT DEFAULT '',
  targetAmount REAL NOT NULL,
  month TEXT NOT NULL
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
      await this.store.executeSql(CREATE_PLANS_SQL);
      await this.store.executeSql(CREATE_SCHEDULED_TASKS_SQL);
      // 老版本数据库升级：补充 skipWeekend 列
      try {
        await this.store.executeSql(`ALTER TABLE ${SCHEDULED_TASKS_TABLE} ADD COLUMN skipWeekend INTEGER DEFAULT 0`);
      } catch (e) {
        // 列已存在，忽略
      }
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
      'id', 'amount', 'type', 'category', 'date', 'note', 'createTime',
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
      'id', 'amount', 'type', 'category', 'date', 'note', 'createTime',
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

  // ===== 计划相关方法 =====

  async addPlan(plan: Plan): Promise<number> {
    if (!this.store) {
      console.error('Database not initialized');
      return -1;
    }
    const valueBucket: relationalStore.ValuesBucket = {
      type: plan.type,
      category: plan.category || '',
      targetAmount: plan.targetAmount,
      month: plan.month,
    };
    return this.store.insert(PLANS_TABLE, valueBucket);
  }

  async getPlansByMonth(month: string): Promise<Plan[]> {
    if (!this.store) {
      console.error('Database not initialized');
      return [];
    }
    const predicates = new relationalStore.RdbPredicates(PLANS_TABLE);
    predicates.equalTo('month', month);
    const resultSet = await this.store.query(predicates, [
      'id', 'type', 'category', 'targetAmount', 'month',
    ]);
    const plans: Plan[] = [];
    while (resultSet.goToNextRow()) {
      plans.push({
        id: resultSet.getLong(resultSet.getColumnIndex('id')),
        type: resultSet.getString(resultSet.getColumnIndex('type')) as BillType,
        category: resultSet.getString(resultSet.getColumnIndex('category')),
        targetAmount: resultSet.getDouble(resultSet.getColumnIndex('targetAmount')),
        month: resultSet.getString(resultSet.getColumnIndex('month')),
      });
    }
    resultSet.close();
    return plans;
  }

  async deletePlan(id: number): Promise<number> {
    if (!this.store) {
      console.error('Database not initialized');
      return 0;
    }
    const predicates = new relationalStore.RdbPredicates(PLANS_TABLE);
    predicates.equalTo('id', id);
    return this.store.delete(predicates);
  }

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

  /** 检查并执行到期的定时任务，返回本次执行的账单数量 */
  async executeDueScheduledTasks(): Promise<number> {
    if (!this.store) {
      return 0;
    }
    const now = Date.now();
    const tasks = await this.getActiveScheduledTasks();
    let executedCount = 0;

    for (const task of tasks) {
      let shouldExecute = false;

      if (task.lastExecuted === 0) {
        // 从未执行过 → 检查 startTime
        if (now >= task.startTime) {
          shouldExecute = true;
        }
      } else {
        // 已执行过 → 计算下次执行时间
        const nextTime = nextExecutionTime(task.lastExecuted!, task.intervalType);
        if (now >= nextTime) {
          shouldExecute = true;
        }
      }

      if (shouldExecute) {
        // 本次应执行的时间点（首次为 startTime，之后按间隔推算）
        const dueTime = task.lastExecuted === 0 ? task.startTime : nextExecutionTime(task.lastExecuted!, task.intervalType);

        // 每天任务且开启跳过周末：周末到期的任务跳过本次，仅推进 lastExecuted 避免重复触发
        if (task.skipWeekend === true && task.intervalType === 'day' && isWeekend(dueTime)) {
          await this.updateScheduledTaskLastExecuted(task.id!, dueTime);
          continue;
        }

        // 创建账单
        const bill: Bill = {
          amount: task.amount,
          type: task.type,
          category: task.category,
          date: new Date(now).toISOString().substring(0, 10),
          note: task.note || `[定时] ${task.intervalType === 'day' ? '每日' : task.intervalType === 'week' ? '每周' : task.intervalType === 'month' ? '每月' : task.intervalType === 'quarter' ? '每季度' : '每年'}记账`,
        };
        await this.addBill(bill);
        await this.updateScheduledTaskLastExecuted(task.id!, now);
        executedCount++;
      }
    }
    return executedCount;
  }
}

export const dbHelper = new DatabaseHelper();

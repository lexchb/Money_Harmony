import { relationalStore } from '@kit.ArkData';
import { Context } from '@kit.AbilityKit';
import { Bill, BillType, Plan } from './Bill';

const DB_NAME = 'MoneyHarmony.db';
const TABLE_NAME = 'bills';
const PLANS_TABLE = 'plans';
const DB_VERSION = 1;

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

  async getCategorySpent(month: string, type: BillType): Promise<{ category: string; amount: number }[]> {
    if (!this.store) {
      return [];
    }
    const sql = `SELECT category, COALESCE(SUM(amount), 0) AS amount
      FROM ${TABLE_NAME}
      WHERE date LIKE ? AND type = ?
      GROUP BY category`;
    const resultSet = await this.store.querySql(sql, [`${month}%`, type]);
    const result: { category: string; amount: number }[] = [];
    while (resultSet.goToNextRow()) {
      result.push({
        category: resultSet.getString(resultSet.getColumnIndex('category')),
        amount: resultSet.getDouble(resultSet.getColumnIndex('amount')),
      });
    }
    resultSet.close();
    return result;
  }
}

export const dbHelper = new DatabaseHelper();

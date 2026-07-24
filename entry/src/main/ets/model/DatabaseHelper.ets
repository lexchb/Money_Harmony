import { relationalStore } from '@kit.ArkData';
import { Context } from '@kit.AbilityKit';
import { Bill, BillType } from './Bill';

const DB_NAME = 'MoneyHarmony.db';
const TABLE_NAME = 'bills';
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
    } catch (e) {
      console.error('Database init failed:', (e as Error).message);
      throw e;
    }
  }

  async addBill(bill: Bill): Promise<number> {
    if (!this.store) {
      throw new Error('Database not initialized');
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
      throw new Error('Database not initialized');
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
      throw new Error('Database not initialized');
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
      throw new Error('Database not initialized');
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
      throw new Error('Database not initialized');
    }
    const predicates = new relationalStore.RdbPredicates(TABLE_NAME);
    predicates.equalTo('id', id);
    return this.store.delete(predicates);
  }

  async getMonthlyStats(yearMonth: string): Promise<MonthlyStats> {
    if (!this.store) {
      throw new Error('Database not initialized');
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
}

export const dbHelper = new DatabaseHelper();

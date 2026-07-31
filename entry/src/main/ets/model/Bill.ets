export enum BillType {
  EXPENSE = 'expense',
  INCOME = 'income'
}

export interface Bill {
  id?: number;
  amount: number;
  type: BillType;
  category: string;
  date: string;
  note: string;
  createTime?: number;
}

export const EXPENSE_CATEGORIES: string[] = ['餐饮', '购物', '交通', '娱乐', '医疗', '教育', '理财', '生活','其他'];

export const INCOME_CATEGORIES: string[] = ['工资', '奖金', '理财', '兼职', '红包', '其他'];

export function getCategories(type: BillType): string[] {
  return type === BillType.EXPENSE ? EXPENSE_CATEGORIES : INCOME_CATEGORIES;
}

export function formatMoney(amount: number): string {
  return amount.toFixed(2);
}

export function todayString(): string {
  const now = new Date();
  const y = now.getFullYear();
  const m = String(now.getMonth() + 1).padStart(2, '0');
  const d = String(now.getDate()).padStart(2, '0');
  return `${y}-${m}-${d}`;
}

export interface Plan {
  id?: number;
  type: BillType;
  category: string;
  targetAmount: number;
  month: string;
}

export interface CategorySpent {
  category: string;
  amount: number;
}

export interface ScheduledTask {
  id?: number;
  type: BillType;
  amount: number;
  category: string;
  startTime: number;         // 首次执行时间戳(ms)
  intervalType: string;      // 'day' | 'week' | 'month' | 'quarter' | 'year'
  note: string;
  lastExecuted?: number;     // 上次执行时间戳(ms)
  isActive: boolean;
  createTime?: number;
}

export function nextExecutionTime(last: number, intervalType: string): number {
  const d = new Date(last);
  switch (intervalType) {
    case 'day':
      d.setDate(d.getDate() + 1);
      break;
    case 'week':
      d.setDate(d.getDate() + 7);
      break;
    case 'month':
      d.setMonth(d.getMonth() + 1);
      break;
    case 'quarter':
      d.setMonth(d.getMonth() + 3);
      break;
    case 'year':
      d.setFullYear(d.getFullYear() + 1);
      break;
  }
  return d.getTime();
}

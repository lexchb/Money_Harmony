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

export const EXPENSE_CATEGORIES: string[] = ['餐饮', '购物', '交通', '娱乐', '医疗', '教育', '日用品', '其他'];

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

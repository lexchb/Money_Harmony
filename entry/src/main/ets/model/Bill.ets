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
  goalId?: number;   // 关联的目标 id，0 表示不关联
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

/** 将时间戳格式化为本地日期 YYYY-MM-DD */
export function formatDate(ts: number): string {
  const d = new Date(ts);
  const y = d.getFullYear();
  const m = String(d.getMonth() + 1).padStart(2, '0');
  const day = String(d.getDate()).padStart(2, '0');
  return `${y}-${m}-${day}`;
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
  skipWeekend?: boolean;     // 每天任务是否跳过周六周日
  createTime?: number;
}

/** 判断时间戳是否为周末（0=周日, 6=周六） */
export function isWeekend(ts: number): boolean {
  const day = new Date(ts).getDay();
  return day === 0 || day === 6;
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

// ===== 目标 =====

export enum GoalType {
  EXPENSE = 'expense',   // 支出目标
  SAVING = 'saving'      // 攒钱目标
}

export interface Goal {
  id?: number;
  name: string;
  type: GoalType;
  targetAmount: number;   // 目标金额
  periodType: string;     // 'month' | 'quarter' | 'year' 统计周期
  startTime: number;      // 周期锚点（创建时间）
  manualAmount: number;   // 手动记录的金额（攒钱目标累计）
  createTime?: number;
}

export interface TimeRange {
  start: number;
  end: number;
}

/** 按统计周期推进时间点 */
export function nextPeriodTime(t: number, periodType: string): number {
  const d = new Date(t);
  switch (periodType) {
    case 'quarter':
      d.setMonth(d.getMonth() + 3);
      break;
    case 'year':
      d.setFullYear(d.getFullYear() + 1);
      break;
    case 'month':
    default:
      d.setMonth(d.getMonth() + 1);
      break;
  }
  return d.getTime();
}

/** 计算目标当前所处的统计周期 [start, end)，以 startTime 为锚点按周期推进 */
export function goalPeriodRange(goal: Goal, now: number): TimeRange {
  let start = goal.startTime;
  let end = nextPeriodTime(start, goal.periodType);
  while (end <= now) {
    start = end;
    end = nextPeriodTime(start, goal.periodType);
  }
  return { start: start, end: end } as TimeRange;
}

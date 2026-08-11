import { BillType, formatDate, formatMoney, Goal, GoalType, goalPeriodRange } from '../model/Bill';
import { dbHelper } from '../model/DatabaseHelper';
import { AddGoalDialog } from './AddGoalDialog';
import { GoalDetailDialog } from './GoalDetailDialog';

function periodLabel(p: string): string {
  switch (p) {
    case 'week':
      return '每周';
    case 'month':
      return '每月';
    case 'quarter':
      return '每季度';
    case 'year':
      return '每年';
    default:
      return p;
  }
}

interface GoalItem {
  goal: Goal;
  spent: number;      // 当前周期内关联账单金额
  manual: number;     // 当前周期内手动记录金额（攒钱目标）
  total: number;      // 合计
}

@Component
export struct GoalContent {
  @State goals: GoalItem[] = [];
  @State expenseGoalCount: number = 0;
  @State savingGoalCount: number = 0;
  @StorageLink('goalNeedRefresh') goalNeedRefresh: number = 0;
  private editDialogController: CustomDialogController | null = null;
  private detailDialogController: CustomDialogController | null = null;

  aboutToAppear(): void {
    this.loadGoals();
  }

  /** 点击目标项：打开目标详情对话框 */
  openDetail(item: GoalItem): void {
    this.detailDialogController = new CustomDialogController({
      builder: GoalDetailDialog({
        goal: item.goal,
        onChanged: () => {
          this.loadGoals();
        },
        onEdit: (g: Goal) => {
          this.openEditDialog(g);
        },
        onDelete: (g: Goal) => {
          this.confirmDeleteGoal(g);
        }
      }),
      autoCancel: true,
      alignment: DialogAlignment.Bottom,
      offset: { dx: 0, dy: 0 },
    });
    this.detailDialogController.open();
  }

  /** 打开编辑对话框（目标详情中点击编辑） */
  openEditDialog(goal: Goal): void {
    this.editDialogController = new CustomDialogController({
      builder: AddGoalDialog({
        editGoal: goal,
        onConfirm: () => {
          this.loadGoals();
        }
      }),
      autoCancel: true,
      alignment: DialogAlignment.Bottom,
      offset: { dx: 0, dy: 0 },
    });
    this.editDialogController.open();
  }

  async loadGoals(): Promise<void> {
    // 加载数据库中所有目标，并计算当前周期的已记录金额（账单 + 手动记录均按当前周期统计）
    const all = await dbHelper.getGoals();
    const now = Date.now();
    const items: GoalItem[] = [];
    for (const g of all) {
      const range = goalPeriodRange(g, now);
      const billType = g.type === GoalType.EXPENSE ? BillType.EXPENSE : BillType.INCOME;
      const spent = await dbHelper.getGoalSpentInRange(g.id!, billType, formatDate(range.start), formatDate(range.end));
      const manual = g.type === GoalType.SAVING ? await dbHelper.getGoalManualTotalInRange(g.id!, range.start, range.end) : 0;
      items.push({ goal: g, spent: spent, manual: manual, total: spent + manual } as GoalItem);
    }
    this.goals = items;

    let expenseCount = 0;
    let savingCount = 0;
    for (const item of items) {
      if (item.goal.type === GoalType.EXPENSE) {
        expenseCount++;
      } else {
        savingCount++;
      }
    }
    this.expenseGoalCount = expenseCount;
    this.savingGoalCount = savingCount;
  }

  confirmDeleteGoal(goal: Goal): void {
    AlertDialog.show({
      title: '删除目标',
      message: '确定要删除这个目标吗？关联的账单记录不会被删除。',
      primaryButton: {
        value: '取消',
        action: () => {}
      },
      secondaryButton: {
        value: '删除',
        fontColor: '#e74c3c',
        action: async () => {
          if (goal.id !== undefined) {
            await dbHelper.deleteGoal(goal.id);
            this.loadGoals();
          }
        }
      }
    });
  }

  build() {
    Column() {
      // ===== 概述卡片 =====
      Row() {
        Column() {
          Text('支出目标')
            .fontSize(13)
            .fontColor('#999')
          Text(`${this.expenseGoalCount} 个`)
            .fontSize(20)
            .fontWeight(FontWeight.Bold)
            .fontColor('#e74c3c')
            .animation({ duration: 300, curve: Curve.EaseInOut })
        }
        .layoutWeight(1)
        .alignItems(HorizontalAlign.Center)

        Column() {
          Text('攒钱目标')
            .fontSize(13)
            .fontColor('#999')
          Text(`${this.savingGoalCount} 个`)
            .fontSize(20)
            .fontWeight(FontWeight.Bold)
            .fontColor('#27ae60')
            .animation({ duration: 300, curve: Curve.EaseInOut })
        }
        .layoutWeight(1)
        .alignItems(HorizontalAlign.Center)
      }
      .width('100%')
      .padding({ left: 16, right: 16, top: 16, bottom: 16 })
      .backgroundColor(Color.White)
      .borderRadius(20)
      .shadow({ radius: 8, color: 'rgba(0,0,0,0.04)', offsetY: 2 })
      .margin({ top: 8, bottom: 16 })

      // ===== 列表 =====
      if (this.goals.length === 0) {
        Column() {
          Text('暂无目标')
            .fontSize(16)
            .fontColor('#ccc')
          Text('点击右上角 添加目标')
            .fontSize(14)
            .fontColor('#ddd')
            .margin({ top: 8 })
        }
        .layoutWeight(1)
        .justifyContent(FlexAlign.Center)
      } else {
        List() {
          ForEach(this.goals, (item: GoalItem) => {
            ListItem() {
              Column() {
                Row() {
                  Circle()
                    .width(40)
                    .height(40)
                    .fill(item.goal.type === GoalType.EXPENSE ? '#e74c3c' : '#27ae60')
                    .margin({ right: 12 })

                  Column() {
                    Text(item.goal.name)
                      .fontSize(16)
                      .fontWeight(FontWeight.Medium)
                    Text(`${item.goal.type === GoalType.EXPENSE ? '支出目标' : '攒钱目标'} · ${periodLabel(item.goal.periodType)}`)
                      .fontSize(12)
                      .fontColor('#999')
                      .margin({ top: 2 })
                  }
                  .alignItems(HorizontalAlign.Start)
                  .layoutWeight(1)

                  Column() {
                    Text(`¥${formatMoney(item.total)}`)
                      .fontSize(18)
                      .fontWeight(FontWeight.Bold)
                      .fontColor(item.goal.type === GoalType.EXPENSE ? '#e74c3c' : '#27ae60')
                    Text(`目标 ¥${formatMoney(item.goal.targetAmount)}`)
                      .fontSize(12)
                      .fontColor('#999')
                      .margin({ top: 2 })
                  }
                  .alignItems(HorizontalAlign.End)
                }
                .width('100%')
                .padding({ bottom: 10 })

                // ===== 进度条 =====
                Row() {
                  Stack({ alignContent: Alignment.Start }) {
                    Row()
                      .width('100%')
                      .height(6)
                      .backgroundColor('#f0f0f0')
                      .borderRadius(3)
                    Row()
                      .width(this.progressWidth(item.total, item.goal.targetAmount))
                      .height(6)
                      .backgroundColor(item.goal.type === GoalType.EXPENSE ? '#e74c3c' : '#27ae60')
                      .borderRadius(3)
                  }
                  .layoutWeight(1)
                  .height(6)

                  Text(`${this.progressPercent(item.total, item.goal.targetAmount)}%`)
                    .fontSize(12)
                    .fontColor('#999')
                    .margin({ left: 8 })
                }
                .width('100%')

                Text(`本周期已记录 ¥${formatMoney(item.spent)}${item.goal.type === GoalType.SAVING ? ` + 手动 ¥${formatMoney(item.manual)}` : ''}`)
                  .fontSize(11)
                  .fontColor('#bbb')
                  .margin({ top: 6 })
                  .width('100%')
              }
              .width('100%')
              .padding({ left: 16, right: 16, top: 14, bottom: 14 })
            }
            .borderRadius(16)
            .backgroundColor(Color.White)
            .shadow({ radius: 4, color: 'rgba(0,0,0,0.03)', offsetY: 1 })
            .margin({ bottom: 8 })
            .transition(
              TransitionEffect.asymmetric(
                TransitionEffect.translate({ y: 30 })
                  .combine(TransitionEffect.opacity(0))
                  .animation({ duration: 300 }),
                TransitionEffect.translate({ x: -30 })
                  .combine(TransitionEffect.opacity(0))
                  .animation({ duration: 200 })
              )
            )
            .gesture(
              GestureGroup(GestureMode.Exclusive,
                LongPressGesture({ duration: 500 })
                  .onAction(() => {
                    this.confirmDeleteGoal(item.goal);
                  }),
                TapGesture({})
                  .onAction(() => {
                    // 点击查看目标详情，可手动记录金额、编辑或删除
                    this.openDetail(item);
                  })
              )
            )
          }, (item: GoalItem): string => `${item.goal.id}_${item.goal.name}_${item.total}_${item.goal.targetAmount}`)
        }
        .width('100%')
        .height('100%')
        .layoutWeight(1)
        .edgeEffect(EdgeEffect.Spring)
      }

      Blank().height(16)
    }
    .width('100%')
    .height('100%')
    .padding({ left: 16, right: 16 })
  }

  private progressWidth(total: number, target: number): string {
    const pct = target > 0 ? Math.round(total / target * 100) : 0;
    return `${Math.min(100, pct)}%`;
  }

  private progressPercent(total: number, target: number): number {
    return target > 0 ? Math.min(100, Math.round(total / target * 100)) : 0;
  }
}

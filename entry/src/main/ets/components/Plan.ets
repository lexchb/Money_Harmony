import { BillType, formatMoney, ScheduledTask } from '../model/Bill';
import { dbHelper } from '../model/DatabaseHelper';
import { AddScheduledTaskDialog } from './AddScheduledTaskDialog';

function intervalLabel(intervalType: string): string {
  switch (intervalType) {
    case 'day':
      return '每天';
    case 'week':
      return '每周';
    case 'month':
      return '每月';
    case 'quarter':
      return '每季度';
    case 'year':
      return '每年';
    default:
      return intervalType;
  }
}

function formatDateTime(ts: number): string {
  const d = new Date(ts);
  return `${d.getFullYear()}-${String(d.getMonth() + 1).padStart(2, '0')}-${String(d.getDate()).padStart(2, '0')} ${String(d.getHours()).padStart(2, '0')}:${String(d.getMinutes()).padStart(2, '0')}`;
}

@Component
export struct PlanContent {
  @State tasks: ScheduledTask[] = [];
  @State expensePlanCount: number = 0;
  @State incomePlanCount: number = 0;
  @StorageLink('planNeedRefresh') planNeedRefresh: number = 0;
  private editDialogController: CustomDialogController | null = null;

  aboutToAppear(): void {
    this.loadPlans();
  }

  /** 点击计划项：打开详情编辑对话框 */
  openEditDialog(task: ScheduledTask): void {
    this.editDialogController = new CustomDialogController({
      builder: AddScheduledTaskDialog({
        editTask: task,
        onConfirm: () => {
          this.loadPlans();
        }
      }),
      autoCancel: true,
      alignment: DialogAlignment.Bottom,
      offset: { dx: 0, dy: 0 },
    });
    this.editDialogController.open();
  }

  async loadPlans(): Promise<void> {
    // 加载数据库中所有已设置的定时任务（不限月份）
    const allTasks = await dbHelper.getAllScheduledTasks();
    this.tasks = allTasks;

    let expenseCount = 0;
    let incomeCount = 0;
    for (const task of allTasks) {
      if (task.type === BillType.EXPENSE) {
        expenseCount++;
      } else {
        incomeCount++;
      }
    }
    this.expensePlanCount = expenseCount;
    this.incomePlanCount = incomeCount;
  }

  showDeleteConfirm(task: ScheduledTask): void {
    AlertDialog.show({
      title: '删除计划',
      message: '确定要删除这个定时计划吗？',
      primaryButton: {
        value: '取消',
        action: () => {}
      },
      secondaryButton: {
        value: '删除',
        fontColor: '#e74c3c',
        action: async () => {
          if (task.id !== undefined) {
            await dbHelper.deleteScheduledTask(task.id);
            this.loadPlans();
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
          Text('支出计划')
            .fontSize(13)
            .fontColor('#999')
          Text(`${this.expensePlanCount} 个`)
            .fontSize(20)
            .fontWeight(FontWeight.Bold)
            .fontColor('#e74c3c')
            .animation({ duration: 300, curve: Curve.EaseInOut })
        }
        .layoutWeight(1)
        .alignItems(HorizontalAlign.Center)

        Column() {
          Text('收入计划')
            .fontSize(13)
            .fontColor('#999')
          Text(`${this.incomePlanCount} 个`)
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
      if (this.tasks.length === 0) {
        Column() {
          Text('暂无计划')
            .fontSize(16)
            .fontColor('#ccc')
          Text('点击右上角 添加计划')
            .fontSize(14)
            .fontColor('#ddd')
            .margin({ top: 8 })
        }
        .layoutWeight(1)
        .justifyContent(FlexAlign.Center)
      } else {
        List() {
          ForEach(this.tasks, (task: ScheduledTask) => {
            ListItem() {
              Column() {
                Row() {
                  Circle()
                    .width(40)
                    .height(40)
                    .fill(task.type === BillType.EXPENSE ? '#e74c3c' : '#27ae60')
                    .margin({ right: 12 })

                  Column() {
                    Text(task.category)
                      .fontSize(16)
                      .fontWeight(FontWeight.Medium)
                    Text(`${task.type === BillType.EXPENSE ? '支出' : '收入'} · ${intervalLabel(task.intervalType)}`)
                      .fontSize(12)
                      .fontColor('#999')
                      .margin({ top: 2 })
                  }
                  .alignItems(HorizontalAlign.Start)
                  .layoutWeight(1)

                  Text(`¥${formatMoney(task.amount)}`)
                    .fontSize(18)
                    .fontWeight(FontWeight.Bold)
                    .fontColor(task.type === BillType.EXPENSE ? '#e74c3c' : '#27ae60')
                }
                .width('100%')
                .padding({ bottom: 8 })

                Row() {
                  Text(`开始 ${formatDateTime(task.startTime)}`)
                    .fontSize(12)
                    .fontColor('#bbb')
                }
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
                    this.showDeleteConfirm(task);
                  }),
                TapGesture({})
                  .onAction(() => {
                    // 点击查看并编辑计划详情
                    this.openEditDialog(task);
                  })
              )
            )
          }, (task: ScheduledTask): string => `${task.id}_${task.amount}_${task.category}_${task.intervalType}_${task.startTime}`)
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
}

import { BillType, formatMoney, todayString } from '../model/Bill';
import { Plan } from '../model/Bill';
import { dbHelper } from '../model/DatabaseHelper';

interface PlanWithSpent extends Plan {
  spent: number;
  progress: number;
}

@Component
export struct PlanPage {
  pageStack: NavPathStack = new NavPathStack();

  @State plans: PlanWithSpent[] = [];
  @State currentMonth: string = todayString().substring(0, 7);
  @State totalTarget: number = 0;
  @State totalSpent: number = 0;

  aboutToAppear(): void {
    this.loadPlans();
  }

  async loadPlans(): Promise<void> {
    const rawPlans = await dbHelper.getPlansByMonth(this.currentMonth);
    const expenseSpent = await dbHelper.getCategorySpent(this.currentMonth, BillType.EXPENSE);
    const incomeSpent = await dbHelper.getCategorySpent(this.currentMonth, BillType.INCOME);

    const planWithSpent: PlanWithSpent[] = [];
    let totalTarget = 0;
    let totalSpent = 0;

    for (const plan of rawPlans) {
      let spentAmount = 0;
      if (plan.category === '') {
        // 全部类别计划
        const spentList = plan.type === BillType.EXPENSE ? expenseSpent : incomeSpent;
        spentAmount = 0;
        for (const item of spentList) {
          spentAmount += item.amount;
        }
      } else {
        const spentList = plan.type === BillType.EXPENSE ? expenseSpent : incomeSpent;
        spentAmount = 0;
        for (const item of spentList) {
          if (item.category === plan.category) {
            spentAmount = item.amount;
            break;
          }
        }
      }

      totalTarget += plan.targetAmount;
      totalSpent += spentAmount;

      planWithSpent.push({
        ...plan,
        spent: spentAmount,
        progress: plan.targetAmount > 0 ? Math.min(spentAmount / plan.targetAmount, 1) : 0,
      });
    }

    this.plans = planWithSpent;
    this.totalTarget = totalTarget;
    this.totalSpent = totalSpent;
  }

  showAddPlanDialog(): void {
    AlertDialog.show({
      title: '添加计划',
      message: '选择计划类型',
      primaryButton: {
        value: '支出计划',
        action: () => this.showAmountSetting(BillType.EXPENSE)
      },
      secondaryButton: {
        value: '收入计划',
        action: () => this.showAmountSetting(BillType.INCOME)
      }
    });
  }

  showAmountSetting(type: BillType): void {
    // 三步选择：预设金额
    AlertDialog.show({
      title: type === BillType.EXPENSE ? '支出目标' : '收入目标',
      message: '选择目标金额',
      primaryButton: {
        value: '¥500',
        action: () => this.createPlan(type, 500)
      },
      secondaryButton: {
        value: '¥1000',
        action: () => this.createPlan(type, 1000)
      }
    });
  }

  async createPlan(type: BillType, targetAmount: number): Promise<void> {
    await dbHelper.addPlan({
      type: type,
      category: '',
      targetAmount: targetAmount,
      month: this.currentMonth
    });
    this.loadPlans();
  }

  showDeleteConfirm(plan: PlanWithSpent): void {
    AlertDialog.show({
      title: '删除计划',
      message: `确定要删除这个计划吗？`,
      primaryButton: {
        value: '取消',
        action: () => {}
      },
      secondaryButton: {
        value: '删除',
        fontColor: '#e74c3c',
        action: async () => {
          if (plan.id !== undefined) {
            await dbHelper.deletePlan(plan.id);
            this.loadPlans();
          }
        }
      }
    });
  }

  build() {
    NavDestination() {
      Column() {
        // ===== 标题栏 =====
        Row() {
          Text('计划')
            .fontSize(34)
            .fontWeight(FontWeight.Bold)
            .fontColor('#1a1a1a')

          Blank()

          Button('+ 添加计划')
            .type(ButtonType.Capsule)
            .backgroundColor('#007aff')
            .fontColor(Color.White)
            .fontSize(14)
            .height(36)
            .padding({ left: 16, right: 16 })
            .onClick(() => this.showAddPlanDialog())
        }
        .width('100%')
        .padding({ left: 20, right: 20, top: 16, bottom: 12 })

        // ===== 概述卡片 =====
        Row() {
          Column() {
            Text(this.totalTarget > 0 ? '计划总额' : '暂无计划')
              .fontSize(13)
              .fontColor('#999')
            Text(`¥${formatMoney(this.totalTarget)}`)
              .fontSize(20)
              .fontWeight(FontWeight.Bold)
              .fontColor('#333')
              .animation({ duration: 300, curve: Curve.EaseInOut })
          }
          .layoutWeight(1)
          .alignItems(HorizontalAlign.Center)

          Column() {
            Text('已使用')
              .fontSize(13)
              .fontColor('#999')
            Text(`¥${formatMoney(this.totalSpent)}`)
              .fontSize(20)
              .fontWeight(FontWeight.Bold)
              .fontColor('#007aff')
              .animation({ duration: 300, curve: Curve.EaseInOut })
          }
          .layoutWeight(1)
          .alignItems(HorizontalAlign.Center)

          Column() {
            Text('剩余')
              .fontSize(13)
              .fontColor('#999')
            Text(`¥${formatMoney(Math.max(this.totalTarget - this.totalSpent, 0))}`)
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
        .margin({ left: 16, right: 16, top: 8, bottom: 16 })

        // ===== 列表 =====
        if (this.plans.length === 0) {
          Column() {
            Text('暂无计划')
              .fontSize(16)
              .fontColor('#ccc')
            Text('点击右上角 + 添加计划')
              .fontSize(14)
              .fontColor('#ddd')
              .margin({ top: 8 })
          }
          .layoutWeight(1)
          .justifyContent(FlexAlign.Center)
        } else {
          List() {
            ForEach(this.plans, (plan: PlanWithSpent) => {
              ListItem() {
                Column() {
                  Row() {
                    // 类型图标
                    Circle()
                      .width(40)
                      .height(40)
                      .fill(plan.type === BillType.EXPENSE ? '#e74c3c' : '#27ae60')
                      .margin({ right: 12 })

                    Column() {
                      Text(plan.category || '全部')
                        .fontSize(16)
                        .fontWeight(FontWeight.Medium)
                      Text(plan.type === BillType.EXPENSE ? '支出' : '收入')
                        .fontSize(12)
                        .fontColor('#999')
                        .margin({ top: 2 })
                    }
                    .alignItems(HorizontalAlign.Start)
                    .layoutWeight(1)

                    Text(`¥${formatMoney(plan.targetAmount)}`)
                      .fontSize(18)
                      .fontWeight(FontWeight.Bold)
                      .fontColor(plan.type === BillType.EXPENSE ? '#e74c3c' : '#27ae60')
                  }
                  .width('100%')
                  .padding({ bottom: 8 })

                  // 进度条
                  Row() {
                    // 进度背景
                    Stack() {
                      Row()
                        .width('100%')
                        .height(6)
                        .backgroundColor('#f0f0f0')
                        .borderRadius(3)

                      Row()
                        .width(`${plan.progress * 100}%`)
                        .height(6)
                        .backgroundColor(plan.type === BillType.EXPENSE
                          ? (plan.progress >= 1 ? '#e74c3c' : '#ff9800')
                          : '#27ae60')
                        .borderRadius(3)
                        .alignSelf(ItemAlign.Start)
                        .animation({ duration: 300, curve: Curve.EaseOut })
                    }
                    .width('100%')
                    .height(6)
                  }
                  .width('100%')

                  // 进度文字
                  Row() {
                    Text(`已 ${plan.type === BillType.EXPENSE ? '支出' : '收入'} ¥${formatMoney(plan.spent)}`)
                      .fontSize(12)
                      .fontColor('#999')
                    Blank()
                    Text(`${Math.round(plan.progress * 100)}%`)
                      .fontSize(12)
                      .fontColor(plan.progress >= 1 ? '#e74c3c' : '#ff9800')
                      .fontWeight(FontWeight.Bold)
                  }
                  .width('100%')
                  .padding({ top: 4 })
                }
                .width('100%')
                .padding({ left: 16, right: 16, top: 14, bottom: 14 })
              }
              .borderRadius(16)
              .backgroundColor(Color.White)
              .shadow({ radius: 4, color: 'rgba(0,0,0,0.03)', offsetY: 1 })
              .margin({ bottom: 8 })
              .gesture(
                GestureGroup(GestureMode.Exclusive,
                  LongPressGesture({ duration: 500 })
                    .onAction(() => {
                      this.showDeleteConfirm(plan);
                    }),
                  TapGesture({})
                    .onAction(() => {})
                )
              )
            }, (plan: PlanWithSpent): string => `${plan.id}_${plan.category}_${plan.targetAmount}`)
          }
          .width('100%')
          .height('100%')
          .layoutWeight(1)
          .edgeEffect(EdgeEffect.Spring)
          .padding({ left: 16, right: 16 })
        }

        // ===== 底部间距 =====
        Blank().height(16)
      }
      .width('100%')
      .height('100%')
      .backgroundColor('#f5f6f8')
    }
    .hideTitleBar(true)
  }
}

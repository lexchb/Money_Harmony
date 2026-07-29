import { Bill, BillType, formatMoney, todayString } from '../model/Bill';
import { dbHelper } from '../model/DatabaseHelper';
import { AddBillPage } from '../components/AddBill';
import { EditBillPage } from '../components/EditBill';
import { PlanContent } from '../components/Plan';
import { AddScheduledTaskDialog } from '../components/AddScheduledTaskDialog';

interface EditBillParam {
  billId: number;
}

@Entry
@Component
struct Index {
  @StorageLink('needRefresh') @Watch('onRefresh') needRefresh: number = 0;
  @State bills: Bill[] = [];
  @State totalIncome: number = 0;
  @State totalExpense: number = 0;
  @State currentMonth: string = todayString().substring(0, 7);
  @State leftBtnFontSize: number = 40;
  @State rightBtnFontSize: number = 40;
  @State isSelectMode: boolean = false;
  @State selectedIds: number[] = [];
  @State activeTab: number = 0;

  private pageStack: NavPathStack = new NavPathStack();
  private scheduledTaskDialog: CustomDialogController = new CustomDialogController({
    builder: AddScheduledTaskDialog({
      onConfirm: () => {
        // 定时任务创建后刷新计划数据
        AppStorage.setOrCreate('planNeedRefresh', (AppStorage.get<number>('planNeedRefresh') ?? 0) + 1);
      }
    }),
    autoCancel: true,
    alignment: DialogAlignment.Bottom,
    offset: { dx: 0, dy: 0 },
  });
  private scheduledTaskTimer: number = -1;
  private readonly SCHEDULED_TASK_INTERVAL = 60000; // 每60秒检查一次

  aboutToAppear(): void {
    this.loadBills();
    // 启动定时任务检查
    this.checkScheduledTasks();
    this.scheduledTaskTimer = setInterval(() => {
      this.checkScheduledTasks();
    }, this.SCHEDULED_TASK_INTERVAL);
  }

  aboutToDisappear(): void {
    if (this.scheduledTaskTimer >= 0) {
      clearInterval(this.scheduledTaskTimer);
      this.scheduledTaskTimer = -1;
    }
  }

  async checkScheduledTasks(): Promise<void> {
    const count = await dbHelper.executeDueScheduledTasks();
    if (count > 0) {
      // 有账单被自动创建，刷新数据
      AppStorage.setOrCreate('needRefresh', (AppStorage.get<number>('needRefresh') ?? 0) + 1);
      this.loadBills();
    }
  }

  onRefresh(): void {
    this.loadBills();
  }

  async loadBills(): Promise<void> {
    this.exitSelectMode();
    this.bills = await dbHelper.getBillsByMonth(this.currentMonth);
    const stats = await dbHelper.getMonthlyStats(this.currentMonth);
    this.totalIncome = stats.totalIncome;
    this.totalExpense = stats.totalExpense;
  }

  prevMonth(): void {
    const parts = this.currentMonth.split('-');
    const y = parseInt(parts[0]);
    const m = parseInt(parts[1]);
    const d = new Date(y, m - 2, 1);
    this.currentMonth = `${d.getFullYear()}-${String(d.getMonth() + 1).padStart(2, '0')}`;
    this.loadBills();
  }

  nextMonth(): void {
    const parts = this.currentMonth.split('-');
    const y = parseInt(parts[0]);
    const m = parseInt(parts[1]);
    const d = new Date(y, m, 1);
    this.currentMonth = `${d.getFullYear()}-${String(d.getMonth() + 1).padStart(2, '0')}`;
    this.loadBills();
  }

  goToAdd(): void {
    this.pageStack.pushPath({ name: 'AddBill' });
  }

  enterSelectMode(bill: Bill): void {
    this.isSelectMode = true;
    const newIds: number[] = [];
    if (bill.id !== undefined) {
      newIds.push(bill.id);
    }
    this.selectedIds = newIds;
  }

  toggleSelection(bill: Bill): void {
    const newIds: number[] = [...this.selectedIds];
    if (bill.id !== undefined) {
      const idx = newIds.indexOf(bill.id);
      if (idx >= 0) {
        newIds.splice(idx, 1);
      } else {
        newIds.push(bill.id);
      }
    }
    this.selectedIds = newIds;
  }

  exitSelectMode(): void {
    this.isSelectMode = false;
    this.selectedIds = [];
  }

  confirmDelete(): void {
    AlertDialog.show({
      title: '确认删除',
      message: `确定要删除选中的 ${this.selectedIds.length} 条账单记录吗？`,
      primaryButton: {
        value: '取消',
        action: () => {}
      },
      secondaryButton: {
        value: '删除',
        fontColor: '#e74c3c',
        action: async () => {
          await this.deleteSelected();
        }
      }
    });
  }

  async deleteSelected(): Promise<void> {
    for (const id of this.selectedIds) {
      await dbHelper.deleteBill(id);
    }
    this.exitSelectMode();
    AppStorage.setOrCreate('needRefresh', (AppStorage.get<number>('needRefresh') ?? 0) + 1);
    this.loadBills();
  }

  goToEdit(bill: Bill): void {
    const editParam: EditBillParam = { billId: bill.id ?? 0 };
    this.pageStack.pushPath({
      name: 'EditBill',
      param: editParam
    });
  }

  @Builder
  NavPages(name: string, param?: Object) {
    if (name === 'AddBill') {
      AddBillPage({ pageStack: this.pageStack });
    } else if (name === 'EditBill') {
      EditBillPage({ pageStack: this.pageStack, param: param as Record<string, Object> });
    }
  }

  build() {
    Navigation(this.pageStack) {
      Column() {
        // ===== 标题栏（根据 Tab 切换） =====
        if (this.activeTab === 0) {
          Row() {
            Text('账单')
              .fontSize(34)
              .fontWeight(FontWeight.Bold)
              .fontColor('#1a1a1a')

            Blank()

            Button('+ 记一笔')
              .type(ButtonType.Capsule)
              .backgroundColor('#007aff')
              .fontColor(Color.White)
              .fontSize(14)
              .height(36)
              .padding({ left: 16, right: 16 })
              .onClick(() => this.goToAdd())
          }
          .width('100%')
          .padding({ left: 20, right: 20, top: 24, bottom: 12 })
        } else {
          Row() {
            Text('计划')
              .fontSize(34)
              .fontWeight(FontWeight.Bold)
              .fontColor('#1a1a1a')

            Blank()

            Button('添加计划')
              .type(ButtonType.Capsule)
              .backgroundColor('#007aff')
              .fontColor(Color.White)
              .fontSize(14)
              .height(36)
              .padding({ left: 16, right: 16 })
              .onClick(() => { this.scheduledTaskDialog.open(); })
          }
          .width('100%')
          .padding({ left: 20, right: 20, top: 24, bottom: 12 })
        }

        // ===== 内容区（根据 Tab 切换） =====
        if (this.activeTab === 0) {
          // ===== 首页：账单 =====
          Column() {
            // ===== 卡片：月份切换 + 统计汇总 =====
            Column() {
              Row() {
                if (this.isSelectMode) {
                  Button() { Text('取消').fontColor('#007aff') }
                    .backgroundColor(Color.Transparent)
                    .width(50)
                    .height(50)
                    .onClick(() => this.exitSelectMode())
                    .transition(
                      TransitionEffect.translate({ x: -30 })
                        .combine(TransitionEffect.opacity(0))
                        .animation({ duration: 250, curve: Curve.EaseOut })
                    )

                  Text(this.currentMonth)
                    .fontSize(18)
                    .fontWeight(FontWeight.Bold)
                    .layoutWeight(1)
                    .textAlign(TextAlign.Center)

                  Text(`已选 ${this.selectedIds.length} 项`)
                    .fontSize(14)
                    .fontColor('#e74c3c')
                    .animation({ duration: 200 })
                    .margin({ right: 8 })
                    .transition(
                      TransitionEffect.opacity(0)
                        .animation({ duration: 200 })
                    )

                  Button() { Text('删除').fontColor('#e74c3c') }
                    .backgroundColor(Color.Transparent)
                    .opacity(this.selectedIds.length > 0 ? 1 : 0.4)
                    .animation({ duration: 200 })
                    .enabled(this.selectedIds.length > 0)
                    .width(50)
                    .height(50)
                    .onClick(() => this.confirmDelete())
                    .transition(
                      TransitionEffect.translate({ x: 30 })
                        .combine(TransitionEffect.opacity(0))
                        .animation({ duration: 250, curve: Curve.EaseOut })
                    )
                } else {
                  Button() {
                    SymbolGlyph($r('sys.symbol.chevron_left'))
                      .fontSize(this.leftBtnFontSize)
                      .animation({ duration: 150, curve: Curve.EaseOut })
                      .fontColor(['#007aff'])
                  }
                  .backgroundColor(Color.Transparent)
                  .width(50)
                  .height(50)
                  .onTouch((e: TouchEvent) => {
                    if (e.type === TouchType.Down) {
                      this.leftBtnFontSize = 30;
                    } else if (e.type === TouchType.Up || e.type === TouchType.Cancel) {
                      this.leftBtnFontSize = 40;
                    }
                  })
                  .onClick(() => this.prevMonth())
                  .transition(
                    TransitionEffect.translate({ x: -30 })
                      .combine(TransitionEffect.opacity(0))
                      .animation({ duration: 250, curve: Curve.EaseOut })
                  )

                  Text(this.currentMonth)
                    .fontSize(18)
                    .fontWeight(FontWeight.Bold)
                    .margin({ left: 12, right: 12 })

                  Button() {
                    SymbolGlyph($r('sys.symbol.chevron_right'))
                      .fontSize(this.rightBtnFontSize)
                      .animation({ duration: 150, curve: Curve.EaseOut })
                      .fontColor(['#007aff'])
                  }
                  .backgroundColor(Color.Transparent)
                  .width(50)
                  .height(50)
                  .onTouch((e: TouchEvent) => {
                    if (e.type === TouchType.Down) {
                      this.rightBtnFontSize = 30;
                    } else if (e.type === TouchType.Up || e.type === TouchType.Cancel) {
                      this.rightBtnFontSize = 40;
                    }
                  })
                  .onClick(() => this.nextMonth())
                  .transition(
                    TransitionEffect.translate({ x: 30 })
                      .combine(TransitionEffect.opacity(0))
                      .animation({ duration: 250, curve: Curve.EaseOut })
                  )
                }
              }
              .justifyContent(FlexAlign.Center)
              .width('100%')
              .padding({ top: 8, bottom: 8 })

              Row() {
                Column() {
                  Text('支出')
                    .fontSize(13)
                    .fontColor('#999')
                  Text(`¥${formatMoney(this.totalExpense)}`)
                    .fontSize(20)
                    .fontWeight(FontWeight.Bold)
                    .fontColor('#e74c3c')
                    .animation({ duration: 300, curve: Curve.EaseInOut })
                }
                .layoutWeight(1)
                .alignItems(HorizontalAlign.Center)

                Column() {
                  Text('收入')
                    .fontSize(13)
                    .fontColor('#999')
                  Text(`¥${formatMoney(this.totalIncome)}`)
                    .fontSize(20)
                    .fontWeight(FontWeight.Bold)
                    .fontColor('#27ae60')
                    .animation({ duration: 300, curve: Curve.EaseInOut })
                }
                .layoutWeight(1)
                .alignItems(HorizontalAlign.Center)

                Column() {
                  Text('结余')
                    .fontSize(13)
                    .fontColor('#999')
                  Text(`¥${formatMoney(this.totalIncome - this.totalExpense)}`)
                    .fontSize(20)
                    .fontWeight(FontWeight.Bold)
                    .fontColor('#2980b9')
                    .animation({ duration: 300, curve: Curve.EaseInOut })
                }
                .layoutWeight(1)
                .alignItems(HorizontalAlign.Center)
              }
              .padding({ top: 4, bottom: 12 })
              .width('100%')
            }
            .width('100%')
            .padding({ left: 16, right: 16, top: 4, bottom: 4 })
            .backgroundColor(Color.White)
            .borderRadius(20)
            .shadow({ radius: 8, color: 'rgba(0,0,0,0.04)', offsetY: 2 })
            .padding({ left: 0, right: 0 })

            // ===== 账单列表头 =====
            Text('账单记录')
              .fontSize(14)
              .fontColor('#999')
              .margin({ top: 20, bottom: 8 })
              .width('100%')

            // ===== 账单列表 =====
            if (this.bills.length === 0) {
              Column() {
                Text('暂无账单记录')
                  .fontSize(16)
                  .fontColor('#ccc')
                Text('点击右上角 + 记一笔 添加')
                  .fontSize(14)
                  .fontColor('#ddd')
                  .margin({ top: 8 })
              }
              .layoutWeight(1)
              .justifyContent(FlexAlign.Center)
            } else {
              List() {
                ForEach(this.bills, (bill: Bill) => {
                  ListItem() {
                    Row() {
                      if (this.isSelectMode) {
                        Checkbox({ name: `cb_${bill.id}` })
                          .select(this.selectedIds.indexOf(bill.id!) >= 0)
                          .margin({ right: 8 })
                          .onChange((v: boolean) => {
                            const newIds: number[] = [...this.selectedIds];
                            if (bill.id !== undefined) {
                              if (v) {
                                newIds.push(bill.id);
                              } else {
                                const idx = newIds.indexOf(bill.id);
                                if (idx >= 0) {
                                  newIds.splice(idx, 1);
                                }
                              }
                            }
                            this.selectedIds = newIds;
                          })
                          .transition(
                            TransitionEffect.translate({ x: -20 })
                              .combine(TransitionEffect.opacity(0))
                              .animation({ duration: 200, curve: Curve.EaseOut })
                          )
                      }

                      Circle()
                        .width(40)
                        .height(40)
                        .fill(Color.Transparent)
                        .stroke(bill.type === BillType.EXPENSE ? '#e74c3c' : '#27ae60')
                        .strokeWidth(6)
                        .margin({ right: 12 })

                      Column() {
                        Text(bill.category)
                          .fontSize(16)
                          .fontWeight(FontWeight.Medium)
                        if (bill.note) {
                          Text(bill.note)
                            .fontSize(12)
                            .fontColor('#999')
                            .margin({ top: 2 })
                        }
                        Text(bill.date)
                          .fontSize(12)
                          .fontColor('#bbb')
                          .margin({ top: 2 })
                      }
                      .alignItems(HorizontalAlign.Start)
                      .layoutWeight(1)

                      Text(`${bill.type === BillType.EXPENSE ? '-' : '+'}¥${formatMoney(bill.amount)}`)
                        .fontSize(18)
                        .fontWeight(FontWeight.Bold)
                        .fontColor(bill.type === BillType.EXPENSE ? '#e74c3c' : '#27ae60')
                    }
                    .width('100%')
                    .padding({ left: 16, right: 16, top: 14, bottom: 14 })
                  }
                  .borderRadius(32)
                  .backgroundColor(Color.White)
                  .shadow({ radius: 4, color: 'rgba(0,0,0,0.03)', offsetY: 1 })
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
                          if (!this.isSelectMode) {
                            this.enterSelectMode(bill);
                          }
                        }),
                      TapGesture({})
                        .onAction(() => {
                          if (this.isSelectMode) {
                            this.toggleSelection(bill);
                          } else {
                            this.goToEdit(bill);
                          }
                        })
                    )
                  )
                }, (bill: Bill): string => `${bill.id}_${bill.amount}_${bill.category}_${bill.note}_${bill.date}`)
              }
              .width('100%')
              .height('100%')
              .layoutWeight(1)
              .edgeEffect(EdgeEffect.Spring)
              .divider(null)
              .padding({ right: 8 })
              .scrollBar(BarState.Auto)
              .scrollBarWidth(3)
            }
          }
          .layoutWeight(1)
          .width('100%')
          .padding({ left: 16, right: 16, top: 8, bottom: 8 })
        } else {
          // ===== 计划 Tab =====
          PlanContent()
            .layoutWeight(1)
            .width('100%')
            .padding({ top: 8, bottom: 8 })
        }

        // ===== 底部 Dock 导航栏（毛玻璃效果） =====
        Row() {
          // 首页
          Column() {
            SymbolGlyph($r('sys.symbol.house'))
              .fontSize(22)
              .fontColor([this.activeTab === 0 ? '#007aff' : '#999'])
            Text('首页')
              .fontSize(10)
              .fontColor(this.activeTab === 0 ? '#007aff' : '#999')
              .margin({ top: 2 })
          }
          .layoutWeight(1)
          .alignItems(HorizontalAlign.Center)
          .onClick(() => { this.activeTab = 0; })

          // 统计
          Column() {
            Text('≡')
              .fontSize(22)
              .fontColor('#999')
            Text('统计')
              .fontSize(10)
              .fontColor('#999')
              .margin({ top: 2 })
          }
          .layoutWeight(1)
          .alignItems(HorizontalAlign.Center)

          // 计划
          Column() {
            SymbolGlyph($r('sys.symbol.wallet'))
              .fontSize(22)
              .fontColor([this.activeTab === 1 ? '#007aff' : '#999'])
            Text('计划')
              .fontSize(10)
              .fontColor(this.activeTab === 1 ? '#007aff' : '#999')
              .margin({ top: 2 })
          }
          .layoutWeight(1)
          .alignItems(HorizontalAlign.Center)
          .onClick(() => { this.activeTab = 1; })

          // 我的
          Column() {
            SymbolGlyph($r('sys.symbol.person'))
              .fontSize(22)
              .fontColor(['#999'])
            Text('我的')
              .fontSize(10)
              .fontColor('#999')
              .margin({ top: 2 })
          }
          .layoutWeight(1)
          .alignItems(HorizontalAlign.Center)

          // 设置
          Column() {
            SymbolGlyph($r('sys.symbol.gearshape'))
              .fontSize(22)
              .fontColor(['#999'])
            Text('设置')
              .fontSize(10)
              .fontColor('#999')
              .margin({ top: 2 })
          }
          .layoutWeight(1)
          .alignItems(HorizontalAlign.Center)
        }
        .width('100%')
        .height(72)
        .padding({ left: 20, right: 20, top: 10, bottom: 10 })
        .backdropBlur(16)
        .backgroundColor('rgba(255,255,255,0.72)')
        .borderRadius({ topLeft: 24, topRight: 24 })
        .shadow({ radius: 12, color: 'rgba(0,0,0,0.06)', offsetY: -4 })
        .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.BOTTOM])
      }
      .width('100%')
      .height('100%')
      .backgroundColor('#f5f6f8')
    }
    .width('100%')
    .height('100%')
    .hideTitleBar(true)
    .backgroundColor('#f5f6f8')
    .expandSafeArea()
    .navDestination(this.NavPages)
  }
}

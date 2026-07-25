import { Bill, BillType, formatMoney, todayString } from '../model/Bill';
import { dbHelper } from '../model/DatabaseHelper';
import { AddBillPage } from '../components/AddBill';
import { EditBillPage } from '../components/EditBill';

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
  @State selectedIds: Set<number> = new Set();

  private pageStack: NavPathStack = new NavPathStack();

  aboutToAppear(): void {
    this.loadBills();
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
    const newSet = new Set<number>();
    if (bill.id !== undefined) {
      newSet.add(bill.id);
    }
    this.selectedIds = newSet;
  }

  toggleSelection(bill: Bill): void {
    const newSet = new Set(this.selectedIds);
    if (bill.id !== undefined) {
      if (newSet.has(bill.id)) {
        newSet.delete(bill.id);
      } else {
        newSet.add(bill.id);
      }
    }
    this.selectedIds = newSet;
  }

  exitSelectMode(): void {
    this.isSelectMode = false;
    this.selectedIds = new Set();
  }

  confirmDelete(): void {
    AlertDialog.show({
      title: '确认删除',
      message: `确定要删除选中的 ${this.selectedIds.size} 条账单记录吗？`,
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
        // ===== 顶部月切换 + 汇总 =====
        Column() {
          Row() {
            if (this.isSelectMode) {
              // ===== 多选模式：取消 + 月份 + 已选数量 + 删除 =====
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

              Text(`已选 ${this.selectedIds.size} 项`)
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
                .opacity(this.selectedIds.size > 0 ? 1 : 0.4)
                .animation({ duration: 200 })
                .enabled(this.selectedIds.size > 0)
                .width(50)
                .height(50)
                .onClick(() => this.confirmDelete())
                .transition(
                  TransitionEffect.translate({ x: 30 })
                    .combine(TransitionEffect.opacity(0))
                    .animation({ duration: 250, curve: Curve.EaseOut })
                )
            } else {
              // ===== 普通模式：左箭头 + 月份 + 右箭头 =====
              Button() {
                SymbolGlyph($r('sys.symbol.chevron_left'))
                  .fontSize(this.leftBtnFontSize)
                  .animation({ duration: 400, curve: Curve.EaseOut })
                  .fontColor(['#007aff'])
              }
              .backgroundColor(Color.Transparent)
              .width(50)
              .height(50)
              .onTouch((e: TouchEvent) => {
                if (e.type === TouchType.Down) {
                  this.leftBtnFontSize = 10;
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
                  .animation({ duration: 400, curve: Curve.EaseOut })
                  .fontColor(['#007aff'])
              }
              .backgroundColor(Color.Transparent)
              .width(50)
              .height(50)
              .onTouch((e: TouchEvent) => {
                if (e.type === TouchType.Down) {
                  this.rightBtnFontSize = 10;
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
          .padding({ top: 16, bottom: 8 })

          Row() {
            Column() {
              Text('支出')
                .fontSize(14)
                .fontColor('#999')
              Text(`¥${formatMoney(this.totalExpense)}`)
                .fontSize(22)
                .fontWeight(FontWeight.Bold)
                .fontColor('#e74c3c')
                .animation({ duration: 300, curve: Curve.EaseInOut })
            }
            .layoutWeight(1)
            .alignItems(HorizontalAlign.Center)

            Column() {
              Text('收入')
                .fontSize(14)
                .fontColor('#999')
              Text(`¥${formatMoney(this.totalIncome)}`)
                .fontSize(22)
                .fontWeight(FontWeight.Bold)
                .fontColor('#27ae60')
                .animation({ duration: 300, curve: Curve.EaseInOut })
            }
            .layoutWeight(1)
            .alignItems(HorizontalAlign.Center)

            Column() {
              Text('结余')
                .fontSize(14)
                .fontColor('#999')
              Text(`¥${formatMoney(this.totalIncome - this.totalExpense)}`)
                .fontSize(22)
                .fontWeight(FontWeight.Bold)
                .fontColor('#2980b9')
                .animation({ duration: 300, curve: Curve.EaseInOut })
            }
            .layoutWeight(1)
            .alignItems(HorizontalAlign.Center)
          }
          .padding({ top: 8, bottom: 16 })
          .width('100%')
        }
        .backgroundColor('#f8f9fa')
        .width('100%')

        // ===== 账单列表 =====
        if (this.bills.length === 0) {
          Column() {
            Text('暂无账单记录')
              .fontSize(16)
              .fontColor('#ccc')
            Text('点击下方 + 按钮添加第一笔账单')
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
                  // ===== 多选模式复选框（左侧） =====
                  Checkbox({ name: `cb_${bill.id}` })
                    .select(this.selectedIds.has(bill.id!))
                    .opacity(this.isSelectMode ? 1 : 0)
                    .scale({ x: this.isSelectMode ? 1 : 0, y: this.isSelectMode ? 1 : 0 })
                    .width(this.isSelectMode ? 24 : 0)
                    .height(this.isSelectMode ? 24 : 0)
                    .margin({ right: this.isSelectMode ? 8 : 0 })
                    .animation({ duration: 200, curve: Curve.EaseOut })
                    .onChange((v: boolean) => {
                      const newSet = new Set(this.selectedIds);
                      if (bill.id !== undefined) {
                        if (v) {
                          newSet.add(bill.id);
                        } else {
                          newSet.delete(bill.id);
                        }
                      }
                      this.selectedIds = newSet;
                    })

                  Circle()
                    .width(40)
                    .height(40)
                    .fill(Color.Transparent)
                    .stroke(bill.type === BillType.EXPENSE ? '#e74c3c' : '#27ae60')
                    .strokeWidth(8)
                    .margin({ right: 12 })
                    .animation({ duration: 300, curve: Curve.FastOutSlowIn })

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
                .padding({ left: 12, right: 16, top: 12, bottom: 12 })
              }
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
          .divider({ strokeWidth: 0.5, color: '#eee' })
          .edgeEffect(EdgeEffect.Spring)
        }

        // ===== 添加按钮 =====
        Button() {
          Text('+')
            .fontSize(28)
            .fontColor(Color.White)
        }
        .type(ButtonType.Circle)
        .width(56)
        .height(56)
        .backgroundColor('#007aff')
        .margin({ bottom: 24 })
        .onClick(() => this.goToAdd())
      }
      .width('100%')
      .height('100%')
      .backgroundColor(Color.White)
    }
    .width('100%')
    .height('100%')
    .hideTitleBar(true)
    .expandSafeArea()
    .navDestination(this.NavPages)
  }
}

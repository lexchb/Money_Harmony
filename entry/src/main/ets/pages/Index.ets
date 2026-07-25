import { MultiNavPathStack } from '@kit.ArkUI';
import { Bill, BillType, formatMoney, todayString } from '../model/Bill';
import { dbHelper } from '../model/DatabaseHelper';
import { AddBillPage } from '../components/AddBill';

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

  private pageStack: MultiNavPathStack = new MultiNavPathStack();

  aboutToAppear(): void {
    this.loadBills();
  }

  onRefresh(): void {
    this.loadBills();
  }

  async loadBills(): Promise<void> {
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

  goToEdit(bill: Bill): void {
    const editParam: EditBillParam = { billId: bill.id ?? 0 };
    this.pageStack.pushPath({
      name: 'AddBill',
      param: editParam
    });
  }

  @Builder
  NavPages(name: string, param?: Object) {
    if (name === 'AddBill') {
      AddBillPage({ pageStack: this.pageStack, param: param as Record<string, Object> });
    }
  }

  build() {
    Navigation(this.pageStack) {
      Column() {
        // ===== 顶部月切换 + 汇总 =====
        Column() {
          Row() {
            Button() {
              SymbolGlyph($r('sys.symbol.chevron_left'))
                .fontSize(30)
                .fontColor(['#007aff'])
            }
            .backgroundColor(Color.Transparent)
            .width(50)
            .height(50)
            .onClick(() => this.prevMonth())
            Text(this.currentMonth)
              .fontSize(18)
              .fontWeight(FontWeight.Bold)
              .margin({ left: 12, right: 12 })
            Button() {
              SymbolGlyph($r('sys.symbol.chevron_right'))
                .fontSize(30)
                .fontColor(['#007aff'])
            }
            .backgroundColor(Color.Transparent)
            .width(50)
            .height(50)
            .onClick(() => this.nextMonth())
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
                  Circle()
                    .width(40)
                    .height(40)
                    .fill(bill.type === BillType.EXPENSE ? '#e74c3c' : '#27ae60')
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
                  }
                  .alignItems(HorizontalAlign.Start)
                  .layoutWeight(1)

                  Text(`${bill.type === BillType.EXPENSE ? '-' : '+'}¥${formatMoney(bill.amount)}`)
                    .fontSize(18)
                    .fontWeight(FontWeight.Bold)
                    .fontColor(bill.type === BillType.EXPENSE ? '#e74c3c' : '#27ae60')
                }
                .width('100%')
                .padding({ left: 16, right: 16, top: 12, bottom: 12 })
              }
              .onClick(() => this.goToEdit(bill))
            }, (bill: Bill): string => String(bill.id ?? 0))
          }
          .width('100%')
          .height('100%')
          .layoutWeight(1)
          .divider({ strokeWidth: 0.5, color: '#eee' })
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
    .navDestination(this.NavPages)
    .hideNavBar(true)
  }
}

import { Bill, BillType, getCategories, todayString } from '../model/Bill';
import { dbHelper } from '../model/DatabaseHelper';

@Component
export struct AddBillPage {
  pageStack: NavPathStack = new NavPathStack();

  @State amount: string = '';
  @State billType: BillType = BillType.EXPENSE;
  @State category: string = '';
  @State date: string = todayString();
  @State note: string = '';
  @State categories: string[] = getCategories(BillType.EXPENSE);

  private shouldRefresh: boolean = false;

  aboutToAppear(): void {
    this.categories = getCategories(this.billType);
  }

  aboutToDisappear(): void {
    if (this.shouldRefresh) {
      AppStorage.setOrCreate('needRefresh', (AppStorage.get<number>('needRefresh') ?? 0) + 1);
    }
  }

  onTypeChange(type: BillType): void {
    this.billType = type;
    this.categories = getCategories(type);
    this.category = '';
  }

  async saveBill(): Promise<void> {
    const amountNum = Math.round(parseFloat(this.amount) * 100) / 100;
    if (isNaN(amountNum) || amountNum <= 0) {
      return;
    }
    if (!this.category) {
      return;
    }

    const bill: Bill = {
      amount: amountNum,
      type: this.billType,
      category: this.category,
      date: this.date,
      note: this.note,
    };

    await dbHelper.addBill(bill);
    this.shouldRefresh = true;
    this.pageStack.pop();
  }

  showDatePicker(): void {
    DatePickerDialog.show({
      start: new Date(2020, 0, 1),
      end: new Date(2030, 11, 31),
      selected: new Date(this.date),
      onDateAccept: (d: Date) => {
        const y = d.getFullYear();
        const m = String(d.getMonth() + 1).padStart(2, '0');
        const day = String(d.getDate()).padStart(2, '0');
        this.date = `${y}-${m}-${day}`;
      }
    });
  }

  build() {
    NavDestination() {
      Column() {
        // ===== 标题栏 =====
        Row() {
          Button() { Text('取消').fontColor('#007aff') }
            .backgroundColor(Color.Transparent)
            .onClick(() => this.pageStack.pop())

          Text('添加账单')
            .fontSize(18)
            .fontWeight(FontWeight.Bold)
            .layoutWeight(1)
            .textAlign(TextAlign.Center)

          Blank().width(50)
        }
        .width('100%')
        .padding({ left: 12, right: 12, top: 12, bottom: 12 })

        // ===== 类型切换 =====
        Row() {
          Button('支出')
            .type(ButtonType.Capsule)
            .backgroundColor(this.billType === BillType.EXPENSE ? '#e74c3c' : '#f0f0f0')
            .fontColor(this.billType === BillType.EXPENSE ? Color.White : '#333')
            .onClick(() => this.onTypeChange(BillType.EXPENSE))

          Button('收入')
            .type(ButtonType.Capsule)
            .backgroundColor(this.billType === BillType.INCOME ? '#27ae60' : '#f0f0f0')
            .fontColor(this.billType === BillType.INCOME ? Color.White : '#333')
            .onClick(() => this.onTypeChange(BillType.INCOME))
        }
        .justifyContent(FlexAlign.Center)
        .width('100%')
        .margin({ top: 16, bottom: 24 })

        // ===== 金额输入 =====
        Row() {
          Text('¥')
            .fontSize(28)
            .fontWeight(FontWeight.Bold)
          TextInput({ placeholder: '0.00', text: this.amount })
            .type(InputType.NUMBER_DECIMAL)
            .fontSize(28)
            .fontWeight(FontWeight.Bold)
            .height(48)
            .layoutWeight(1)
            .onChange((v) => { this.amount = v; })
        }
        .padding({ left: 24, right: 24, bottom: 20 })
        .border({ width: { bottom: 0.5 }, color: { bottom: '#eee' } })

        // ===== 分类选择 =====
        Column() {
          Text('分类').fontSize(14).fontColor('#999').margin({ bottom: 8 })
          Flex({ wrap: FlexWrap.Wrap, justifyContent: FlexAlign.SpaceBetween }) {
            ForEach(this.categories, (cat: string) => {
              Button(cat)
                .type(ButtonType.Capsule)
                .backgroundColor(this.category === cat ? '#007aff' : '#f0f0f0')
                .fontColor(this.category === cat ? Color.White : '#333')
                .margin({ bottom: 8 })
                .onClick(() => { this.category = cat; })
            }, (cat: string): string => cat)
          }
          .width('100%')
        }
        .padding({ left: 24, right: 24, top: 16, bottom: 16 })
        .border({ width: { bottom: 0.5 }, color: { bottom: '#eee' } })

        // ===== 日期选择 =====
        Row() {
          Text('日期').fontSize(16).fontColor('#333')
          Blank()
          Text(this.date).fontSize(16).fontColor('#007aff')
        }
        .padding({ left: 24, right: 24, top: 16, bottom: 16 })
        .border({ width: { bottom: 0.5 }, color: { bottom: '#eee' } })
        .onClick(() => this.showDatePicker())

        // ===== 备注输入 =====
        Row() {
          Text('备注').fontSize(16).fontColor('#333')
          Blank()
          TextInput({ placeholder: '添加备注...', text: this.note })
            .textAlign(TextAlign.End)
            .fontSize(16)
            .width('70%')
            .onChange((v) => { this.note = v; })
        }
        .padding({ left: 24, right: 24, top: 16, bottom: 16 })
        .border({ width: { bottom: 0.5 }, color: { bottom: '#eee' } })

        // ===== 保存按钮 =====
        Button('保存')
          .type(ButtonType.Capsule)
          .width('90%')
          .height(48)
          .backgroundColor('#007aff')
          .fontColor(Color.White)
          .fontSize(18)
          .margin({ top: 40 })
          .enabled(parseFloat(this.amount) > 0 && this.category !== '')
          .onClick(() => this.saveBill())

        Blank().layoutWeight(1)
      }
      .width('100%')
      .height('100%')
      .backgroundColor(Color.White)
    }
    .hideTitleBar(true)
  }
}

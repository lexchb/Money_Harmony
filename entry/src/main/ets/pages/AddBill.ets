import { router } from '@kit.ArkUI';
import { Bill, BillType, getCategories, todayString } from '../model/Bill';
import { dbHelper } from '../model/DatabaseHelper';

@Entry
@Component
struct AddBill {
  @State amount: string = '';
  @State billType: BillType = BillType.EXPENSE;
  @State category: string = '';
  @State date: string = todayString();
  @State note: string = '';
  @State categories: string[] = getCategories(BillType.EXPENSE);
  @State isEdit: boolean = false;

  private billId: number = 0;

  aboutToAppear(): void {
    const params = router.getParams() as Record<string, Object>;
    if (params && params['billId'] !== undefined) {
      this.isEdit = true;
      this.billId = params['billId'] as number;
      this.loadBill(this.billId);
    }
    this.categories = getCategories(this.billType);
  }

  async loadBill(id: number): Promise<void> {
    try {
      const all = await dbHelper.getAllBills();
      const bill = all.find(b => b.id === id);
      if (bill) {
        this.amount = String(bill.amount);
        this.billType = bill.type;
        this.category = bill.category;
        this.date = bill.date;
        this.note = bill.note;
        this.categories = getCategories(bill.type);
      }
    } catch (e) {
      console.error('loadBill error:', JSON.stringify(e));
    }
  }

  onTypeChange(type: BillType): void {
    this.billType = type;
    this.categories = getCategories(type);
    this.category = '';
  }

  async saveBill(): Promise<void> {
    const amountNum = parseFloat(this.amount);
    if (isNaN(amountNum) || amountNum <= 0) {
      return;
    }
    if (!this.category) {
      return;
    }

    try {
      const bill: Bill = {
        amount: amountNum,
        type: this.billType,
        category: this.category,
        date: this.date,
        note: this.note,
      };

      if (this.isEdit) {
        bill.id = this.billId;
        await dbHelper.updateBill(bill);
      } else {
        await dbHelper.addBill(bill);
      }

      router.back();
    } catch (e) {
      console.error('saveBill error:', JSON.stringify(e));
    }
  }

  deleteBill(): void {
    AlertDialog.show({
      title: '确认删除',
      message: '确定要删除这条账单记录吗？',
      primaryButton: {
        value: '取消',
        action: () => {}
      },
      secondaryButton: {
        value: '删除',
        fontColor: '#e74c3c',
        action: async () => {
          try {
            await dbHelper.deleteBill(this.billId);
            router.back();
          } catch (e) {
            console.error('deleteBill error:', JSON.stringify(e));
          }
        }
      }
    });
  }

  build() {
    Column() {
      // ===== 标题栏 =====
      Row() {
        Button() { Text('取消').fontColor('#007aff') }
          .backgroundColor(Color.Transparent)
          .onClick(() => router.back())

        Text(this.isEdit ? '编辑账单' : '添加账单')
          .fontSize(18)
          .fontWeight(FontWeight.Bold)
          .layoutWeight(1)
          .textAlign(TextAlign.Center)

        if (this.isEdit) {
          Button() { Text('删除').fontColor('#e74c3c') }
            .backgroundColor(Color.Transparent)
            .onClick(() => this.deleteBill())
        } else {
          Blank().width(50)
        }
      }
      .width('100%')
      .padding({ left: 12, right: 12, top: 12, bottom: 12 })

      // ===== 类型切换 =====
      Row() {
        Button('支出')
          .type(this.billType === BillType.EXPENSE ? ButtonType.Capsule : ButtonType.Normal)
          .backgroundColor(this.billType === BillType.EXPENSE ? '#e74c3c' : '#f0f0f0')
          .fontColor(this.billType === BillType.EXPENSE ? Color.White : '#333')
          .onClick(() => this.onTypeChange(BillType.EXPENSE))

        Button('收入')
          .type(this.billType === BillType.INCOME ? ButtonType.Capsule : ButtonType.Normal)
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
          .type(InputType.Number)
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
              .type(this.category === cat ? ButtonType.Capsule : ButtonType.Normal)
              .backgroundColor(this.category === cat ? '#007aff' : '#f0f0f0')
              .fontColor(this.category === cat ? Color.White : '#333')
              .margin({ bottom: 8 })
              .onClick(() => { this.category = cat; })
          })
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
        DatePicker({ start: new Date(2020, 0, 1), end: new Date(2030, 11, 31), selected: new Date(this.date) })
          .width(0)
          .height(0)
          .onDateChange((d: Date) => {
            const y = d.getFullYear();
            const m = String(d.getMonth() + 1).padStart(2, '0');
            const day = String(d.getDate()).padStart(2, '0');
            this.date = `${y}-${m}-${day}`;
          })
      }
      .padding({ left: 24, right: 24, top: 16, bottom: 16 })
      .border({ width: { bottom: 0.5 }, color: { bottom: '#eee' } })
      .onClick(() => {
        // Trigger date picker - in a real app use a dialog
      })

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
      Button(this.isEdit ? '保存修改' : '保存')
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
}

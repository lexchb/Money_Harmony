import { BillType, getCategories, ScheduledTask, Plan, todayString } from '../model/Bill';
import { dbHelper } from '../model/DatabaseHelper';

interface IntervalOption {
  label: string;
  value: string;
}

const INTERVAL_OPTIONS: IntervalOption[] = [
  { label: '每天', value: 'day' },
  { label: '每周', value: 'week' },
  { label: '每月', value: 'month' },
  { label: '每季度', value: 'quarter' },
  { label: '每年', value: 'year' },
];

@CustomDialog
export struct AddScheduledTaskDialog {
  controller: CustomDialogController;
  onConfirm?: () => void;
  editTask: ScheduledTask | null = null;   // 传入则进入编辑模式

  @State selectedType: BillType = BillType.EXPENSE;
  @State amount: string = '';
  @State selectedCategory: string = '餐饮';
  @State selectedDate: Date = new Date();
  @State selectedInterval: string = 'month';
  @State note: string = '';
  @State showDatePicker: boolean = false;
  @State skipWeekend: boolean = false;
  @State categories: string[] = getCategories(BillType.EXPENSE);

  aboutToAppear(): void {
    if (this.editTask !== null) {
      // 编辑模式：预填现有任务数据
      this.selectedType = this.editTask.type;
      this.categories = getCategories(this.editTask.type);
      this.selectedCategory = this.editTask.category;
      this.amount = String(this.editTask.amount);
      this.selectedDate = new Date(this.editTask.startTime);
      this.selectedInterval = this.editTask.intervalType;
      this.note = this.editTask.note;
      this.skipWeekend = this.editTask.skipWeekend === true;
    }
  }

  onTypeChange(type: BillType): void {
    this.selectedType = type;
    this.categories = getCategories(type);
    this.selectedCategory = this.categories[0];
  }

  async onConfirmClick(): Promise<void> {
    const amountNum = parseFloat(this.amount);
    if (isNaN(amountNum) || amountNum <= 0) {
      return;
    }

    const amount = Math.round(amountNum * 100) / 100;

    const task: ScheduledTask = {
      type: this.selectedType,
      amount: amount,
      category: this.selectedCategory,
      startTime: this.selectedDate.getTime(),
      intervalType: this.selectedInterval,
      note: this.note,
      isActive: true,
      skipWeekend: this.skipWeekend,
    };

    if (this.editTask !== null && this.editTask.id !== undefined) {
      // 编辑模式：更新现有任务
      task.id = this.editTask.id;
      await dbHelper.updateScheduledTask(task);
    } else {
      // 新增模式：保存定时任务
      await dbHelper.addScheduledTask(task);

      // 同步添加到计划列表
      const plan: Plan = {
        type: this.selectedType,
        category: this.selectedCategory,
        targetAmount: amount,
        month: todayString().substring(0, 7),
      };
      await dbHelper.addPlan(plan);
    }

    this.controller.close();
    this.onConfirm?.();
  }

  build() {
    Column() {
      // 标题
      Text(this.editTask !== null ? '编辑定时任务' : '添加定时任务')
        .fontSize(20)
        .fontWeight(FontWeight.Bold)
        .fontColor('#1a1a1a')
        .width('100%')
        .textAlign(TextAlign.Start)
        .padding({ bottom: 16 })

      Scroll() {
        Column() {
          // ===== 收支类型 =====
          Text('类型').fontSize(15).fontColor('#333').width('100%').padding({ bottom: 8 })
          Row() {
            Button('支出')
              .type(ButtonType.Capsule)
              .height(36)
              .layoutWeight(1)
              .backgroundColor(this.selectedType === BillType.EXPENSE ? '#e74c3c' : '#f0f0f0')
              .fontColor(this.selectedType === BillType.EXPENSE ? Color.White : '#666')
              .fontSize(14)
              .onClick(() => this.onTypeChange(BillType.EXPENSE))

            Button('收入')
              .type(ButtonType.Capsule)
              .height(36)
              .layoutWeight(1)
              .backgroundColor(this.selectedType === BillType.INCOME ? '#27ae60' : '#f0f0f0')
              .fontColor(this.selectedType === BillType.INCOME ? Color.White : '#666')
              .fontSize(14)
              .onClick(() => this.onTypeChange(BillType.INCOME))
          }
          .width('100%')
          .padding({ bottom: 16 })

          // ===== 金额 =====
          Text('金额').fontSize(15).fontColor('#333').width('100%').padding({ bottom: 8 })
          TextInput({ placeholder: '请输入金额', text: this.amount })
            .type(InputType.NUMBER_DECIMAL)
            .height(44)
            .backgroundColor('#f5f5f5')
            .borderRadius(10)
            .padding({ left: 16, right: 16 })
            .onChange((v: string) => { this.amount = v; })
            .width('100%')
            .padding({ bottom: 16 })

          // ===== 分类 =====
          Text('分类').fontSize(15).fontColor('#333').width('100%').padding({ bottom: 8 })
          Flex({ wrap: FlexWrap.Wrap, justifyContent: FlexAlign.Start }) {
            ForEach(this.categories, (cat: string) => {
              Button(cat)
                .type(ButtonType.Capsule)
                .height(32)
                .backgroundColor(this.selectedCategory === cat ? '#007aff' : '#f0f0f0')
                .fontColor(this.selectedCategory === cat ? Color.White : '#666')
                .fontSize(13)
                .padding({ left: 14, right: 14 })
                .margin({ right: 8, bottom: 8 })
                .onClick(() => { this.selectedCategory = cat; })
            }, (cat: string): string => cat)
          }
          .width('100%')
          .padding({ bottom: 16 })

          // ===== 开始日期 =====
          Text('开始时间').fontSize(15).fontColor('#333').width('100%').padding({ bottom: 8 })
          Button(`${this.selectedDate.getFullYear()}-${String(this.selectedDate.getMonth() + 1).padStart(2, '0')}-${String(this.selectedDate.getDate()).padStart(2, '0')} ${String(this.selectedDate.getHours()).padStart(2, '0')}:${String(this.selectedDate.getMinutes()).padStart(2, '0')}`)
            .type(ButtonType.Capsule)
            .height(40)
            .backgroundColor('#f5f5f5')
            .fontColor('#333')
            .fontSize(15)
            .width('100%')
            .onClick(() => {
              DatePickerDialog.show({
                start: new Date(this.selectedDate.getFullYear() - 1, 0, 1),
                end: new Date(this.selectedDate.getFullYear() + 5, 11, 31),
                selected: this.selectedDate,
                offset: { dx: 0, dy: 0 },
                onDateAccept: (value: Date) => {
                  // 合并：使用新选择的日期，保留原有时间
                  const old = this.selectedDate;
                  this.selectedDate = new Date(value.getFullYear(), value.getMonth(), value.getDate(), old.getHours(), old.getMinutes());
                  // 日期选定后弹出时间选择器
                  TimePickerDialog.show({
                    selected: this.selectedDate,
                    offset: { dx: 0, dy: 0 },
                    onAccept: (time: TimePickerResult) => {
                      // 合并：使用新选择的时间，保留已选日期
                      const cur = this.selectedDate;
                      this.selectedDate = new Date(cur.getFullYear(), cur.getMonth(), cur.getDate(), time.hour, time.minute);
                    }
                  });
                }
              });
            })
            .padding({ bottom: 16 })

          // ===== 执行间隔 =====
          Text('执行间隔').fontSize(15).fontColor('#333').width('100%').padding({ bottom: 8 })
          Flex({ wrap: FlexWrap.Wrap, justifyContent: FlexAlign.Start }) {
            ForEach(INTERVAL_OPTIONS, (opt: IntervalOption) => {
              Button(opt.label)
                .type(ButtonType.Capsule)
                .height(32)
                .backgroundColor(this.selectedInterval === opt.value ? '#007aff' : '#f0f0f0')
                .fontColor(this.selectedInterval === opt.value ? Color.White : '#666')
                .fontSize(13)
                .padding({ left: 14, right: 14 })
                .margin({ right: 8, bottom: 8 })
                .onClick(() => {
                  this.selectedInterval = opt.value;
                  if (opt.value !== 'day') {
                    this.skipWeekend = false;
                  }
                })
            })
          }
          .width('100%')
          .padding({ bottom: 16 })

          // ===== 跳过周末（仅每天间隔可用） =====
          if (this.selectedInterval === 'day') {
            Row() {
              Text('跳过周六周日')
                .fontSize(15)
                .fontColor('#333')
              Blank()
              Toggle({ type: ToggleType.Switch, isOn: this.skipWeekend })
                .selectedColor('#007aff')
                .onChange((isOn: boolean) => {
                  this.skipWeekend = isOn;
                })
            }
            .width('100%')
            .padding({ bottom: 16 })
          }

          // ===== 备注 =====
          Text('备注（可选）').fontSize(15).fontColor('#333').width('100%').padding({ bottom: 8 })
          TextInput({ placeholder: '添加备注', text: this.note })
            .height(44)
            .backgroundColor('#f5f5f5')
            .borderRadius(10)
            .padding({ left: 16, right: 16 })
            .onChange((v: string) => { this.note = v; })
            .width('100%')
            .padding({ bottom: 16 })
        }
        .width('100%')
      }
      .layoutWeight(1)
      .width('100%')

      // ===== 按钮 =====
      Row() {
        Button('取消')
          .type(ButtonType.Capsule)
          .height(44)
          .layoutWeight(1)
          .backgroundColor('#f0f0f0')
          .fontColor('#666')
          .fontSize(16)
          .onClick(() => { this.controller.close(); })

        Blank().width(12)

        Button('确定')
          .type(ButtonType.Capsule)
          .height(44)
          .layoutWeight(1)
          .backgroundColor('#007aff')
          .fontColor(Color.White)
          .fontSize(16)
          .enabled(this.amount.trim() !== '' && parseFloat(this.amount) > 0)
          .opacity(this.amount.trim() !== '' && parseFloat(this.amount) > 0 ? 1 : 0.5)
          .onClick(() => { this.onConfirmClick(); })
      }
      .width('100%')
      .padding({ top: 12 })
    }
    .width('100%')
    .padding(24)
  }
}

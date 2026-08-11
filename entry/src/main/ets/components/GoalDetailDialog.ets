import { BillType, formatDate, formatMoney, Goal, GoalType, goalPeriodRange } from '../model/Bill';
import { dbHelper } from '../model/DatabaseHelper';

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

@CustomDialog
export struct GoalDetailDialog {
  controller: CustomDialogController;
  goal: Goal | null = null;
  onChanged?: () => void;                      // 数据变化后刷新目标列表
  onEdit?: (goal: Goal) => void;               // 请求编辑
  onDelete?: (goal: Goal) => void;             // 请求删除

  @State manualInput: string = '';
  @State spentAmount: number = 0;              // 当前周期内关联账单金额
  @State manualAmount: number = 0;             // 手动记录金额
  @State rangeText: string = '';

  aboutToAppear(): void {
    this.loadDetail();
  }

  async loadDetail(): Promise<void> {
    if (this.goal === null || this.goal.id === undefined) {
      return;
    }
    const now = Date.now();
    const range = goalPeriodRange(this.goal, now);
    const billType = this.goal.type === GoalType.EXPENSE ? BillType.EXPENSE : BillType.INCOME;
    const spent = await dbHelper.getGoalSpentInRange(this.goal.id, billType, formatDate(range.start), formatDate(range.end));
    this.spentAmount = spent;
    // 手动记录按当前周期统计，周期结束后自动归零重计
    const manual = await dbHelper.getGoalManualTotalInRange(this.goal.id, range.start, range.end);
    this.manualAmount = manual;
    this.rangeText = `${formatDate(range.start)} ~ ${formatDate(range.end)}`;
  }

  /** 合计金额（支出目标=账单金额；攒钱目标=账单金额+手动金额） */
  totalValue(): number {
    if (this.goal === null) {
      return 0;
    }
    const manual = this.goal.type === GoalType.SAVING ? this.manualAmount : 0;
    return this.spentAmount + manual;
  }

  async onRecord(): Promise<void> {
    const num = Math.round(parseFloat(this.manualInput) * 100) / 100;
    if (isNaN(num) || num <= 0 || this.goal === null || this.goal.id === undefined) {
      return;
    }
    await dbHelper.addGoalRecord(this.goal.id, num, Date.now());
    this.manualAmount = Math.round((this.manualAmount + num) * 100) / 100;
    this.manualInput = '';
    this.onChanged?.();
  }

  onEditClick(): void {
    if (this.goal === null) {
      return;
    }
    this.controller.close();
    this.onEdit?.(this.goal);
  }

  onDeleteClick(): void {
    if (this.goal === null) {
      return;
    }
    this.controller.close();
    this.onDelete?.(this.goal);
  }

  build() {
    Column() {
      // 标题
      Text(this.goal !== null ? this.goal.name : '目标详情')
        .fontSize(20)
        .fontWeight(FontWeight.Bold)
        .fontColor('#1a1a1a')
        .width('100%')
        .textAlign(TextAlign.Start)
        .padding({ bottom: 12 })

      if (this.goal !== null) {
        // 基本信息
        Column() {
          Row() {
            Text('类型').fontSize(14).fontColor('#999')
            Blank()
            Text(this.goal.type === GoalType.EXPENSE ? '支出目标' : '攒钱目标')
              .fontSize(14)
              .fontColor(this.goal.type === GoalType.EXPENSE ? '#e74c3c' : '#27ae60')
          }
          .width('100%')
          .padding({ top: 8, bottom: 8 })

          Row() {
            Text('统计周期').fontSize(14).fontColor('#999')
            Blank()
            Text(`${periodLabel(this.goal.periodType)} · ${this.rangeText}`).fontSize(13).fontColor('#333')
          }
          .width('100%')
          .padding({ top: 8, bottom: 8 })

          Row() {
            Text('目标金额').fontSize(14).fontColor('#999')
            Blank()
            Text(`¥${formatMoney(this.goal.targetAmount)}`).fontSize(16).fontWeight(FontWeight.Bold).fontColor('#1a1a1a')
          }
          .width('100%')
          .padding({ top: 8, bottom: 8 })

          Row() {
            Text('账单已记录').fontSize(14).fontColor('#999')
            Blank()
            Text(`¥${formatMoney(this.spentAmount)}`).fontSize(16).fontWeight(FontWeight.Medium).fontColor('#007aff')
          }
          .width('100%')
          .padding({ top: 8, bottom: 8 })

          if (this.goal.type === GoalType.SAVING) {
            Row() {
              Text('手动记录').fontSize(14).fontColor('#999')
              Blank()
              Text(`¥${formatMoney(this.manualAmount)}`).fontSize(16).fontWeight(FontWeight.Medium).fontColor('#27ae60')
            }
            .width('100%')
            .padding({ top: 8, bottom: 8 })
          }

          Row() {
            Text('合计').fontSize(14).fontColor('#999')
            Blank()
            Text(`¥${formatMoney(this.totalValue())}`).fontSize(18).fontWeight(FontWeight.Bold).fontColor('#1a1a1a')
          }
          .width('100%')
          .padding({ top: 8, bottom: 8 })
        }
        .width('100%')
        .padding(16)
        .backgroundColor('#f8f9fb')
        .borderRadius(14)

        // 手动记录（攒钱目标记录收入）
        if (this.goal.type === GoalType.SAVING) {
          Column() {
            Text('手动记录金额').fontSize(15).fontColor('#333').width('100%').padding({ bottom: 8 })
            Row() {
              TextInput({ placeholder: '输入金额，例如存入 1000', text: this.manualInput })
                .type(InputType.NUMBER_DECIMAL)
                .height(44)
                .layoutWeight(1)
                .backgroundColor('#f5f5f5')
                .borderRadius(10)
                .padding({ left: 16, right: 16 })
                .onChange((v: string) => { this.manualInput = v; })

              Blank().width(12)

              Button('记录')
                .type(ButtonType.Capsule)
                .height(44)
                .backgroundColor('#27ae60')
                .fontColor(Color.White)
                .fontSize(15)
                .enabled(parseFloat(this.manualInput) > 0)
                .opacity(parseFloat(this.manualInput) > 0 ? 1 : 0.5)
                .onClick(() => { this.onRecord(); })
            }
            .width('100%')
          }
          .width('100%')
          .padding({ top: 16 })
        }

        // 操作按钮
        Row() {
          Button('编辑')
            .type(ButtonType.Capsule)
            .height(44)
            .layoutWeight(1)
            .backgroundColor('#007aff')
            .fontColor(Color.White)
            .fontSize(16)
            .onClick(() => { this.onEditClick(); })

          Blank().width(12)

          Button('删除')
            .type(ButtonType.Capsule)
            .height(44)
            .layoutWeight(1)
            .backgroundColor('#f0f0f0')
            .fontColor('#e74c3c')
            .fontSize(16)
            .onClick(() => { this.onDeleteClick(); })
        }
        .width('100%')
        .padding({ top: 16 })

        Button('关闭')
          .type(ButtonType.Capsule)
          .height(44)
          .width('100%')
          .backgroundColor('#f0f0f0')
          .fontColor('#666')
          .fontSize(16)
          .margin({ top: 12 })
          .onClick(() => { this.controller.close(); })
      }
    }
    .width('100%')
    .padding(24)
  }
}

import { Goal, GoalType } from '../model/Bill';
import { dbHelper } from '../model/DatabaseHelper';

interface PeriodOption {
  label: string;
  value: string;
}

const PERIOD_OPTIONS: PeriodOption[] = [
  { label: '每月', value: 'month' },
  { label: '每季度', value: 'quarter' },
  { label: '每年', value: 'year' },
];

@CustomDialog
export struct AddGoalDialog {
  controller: CustomDialogController;
  onConfirm?: () => void;
  editGoal: Goal | null = null;   // 传入则进入编辑模式

  @State name: string = '';
  @State goalType: GoalType = GoalType.EXPENSE;
  @State targetAmount: string = '';
  @State periodType: string = 'month';

  aboutToAppear(): void {
    if (this.editGoal !== null) {
      // 编辑模式：预填现有目标数据
      this.name = this.editGoal.name;
      this.goalType = this.editGoal.type;
      this.targetAmount = String(this.editGoal.targetAmount);
      this.periodType = this.editGoal.periodType;
    }
  }

  async onConfirmClick(): Promise<void> {
    const amountNum = Math.round(parseFloat(this.targetAmount) * 100) / 100;
    if (this.name.trim() === '' || isNaN(amountNum) || amountNum <= 0) {
      return;
    }

    const goal: Goal = {
      name: this.name.trim(),
      type: this.goalType,
      targetAmount: amountNum,
      periodType: this.periodType,
      startTime: this.editGoal !== null ? this.editGoal.startTime : Date.now(),
      manualAmount: this.editGoal !== null ? this.editGoal.manualAmount : 0,
    };

    if (this.editGoal !== null && this.editGoal.id !== undefined) {
      // 编辑模式：更新现有目标（保持周期锚点和手动金额不变）
      goal.id = this.editGoal.id;
      await dbHelper.updateGoal(goal);
    } else {
      // 新增模式：保存目标
      await dbHelper.addGoal(goal);
    }

    this.controller.close();
    this.onConfirm?.();
  }

  build() {
    Column() {
      // 标题
      Text(this.editGoal !== null ? '编辑目标' : '添加目标')
        .fontSize(20)
        .fontWeight(FontWeight.Bold)
        .fontColor('#1a1a1a')
        .width('100%')
        .textAlign(TextAlign.Start)
        .padding({ bottom: 16 })

      Scroll() {
        Column() {
          // ===== 目标名称 =====
          Text('目标名称').fontSize(15).fontColor('#333').width('100%').padding({ bottom: 8 })
          TextInput({ placeholder: '例如：本月餐饮预算 / 旅行基金', text: this.name })
            .height(44)
            .backgroundColor('#f5f5f5')
            .borderRadius(10)
            .padding({ left: 16, right: 16 })
            .onChange((v: string) => { this.name = v; })
            .width('100%')
            .padding({ bottom: 16 })

          // ===== 目标类型 =====
          Text('类型').fontSize(15).fontColor('#333').width('100%').padding({ bottom: 8 })
          Row() {
            Button('支出目标')
              .type(ButtonType.Capsule)
              .height(36)
              .layoutWeight(1)
              .backgroundColor(this.goalType === GoalType.EXPENSE ? '#e74c3c' : '#f0f0f0')
              .fontColor(this.goalType === GoalType.EXPENSE ? Color.White : '#666')
              .fontSize(14)
              .onClick(() => { this.goalType = GoalType.EXPENSE; })

            Blank().width(8)

            Button('攒钱目标')
              .type(ButtonType.Capsule)
              .height(36)
              .layoutWeight(1)
              .backgroundColor(this.goalType === GoalType.SAVING ? '#27ae60' : '#f0f0f0')
              .fontColor(this.goalType === GoalType.SAVING ? Color.White : '#666')
              .fontSize(14)
              .onClick(() => { this.goalType = GoalType.SAVING; })
          }
          .width('100%')
          .padding({ bottom: 16 })

          // ===== 目标金额 =====
          Text('目标金额').fontSize(15).fontColor('#333').width('100%').padding({ bottom: 8 })
          TextInput({ placeholder: '请输入目标金额', text: this.targetAmount })
            .type(InputType.NUMBER_DECIMAL)
            .height(44)
            .backgroundColor('#f5f5f5')
            .borderRadius(10)
            .padding({ left: 16, right: 16 })
            .onChange((v: string) => { this.targetAmount = v; })
            .width('100%')
            .padding({ bottom: 16 })

          // ===== 统计周期 =====
          Text('统计周期').fontSize(15).fontColor('#333').width('100%').padding({ bottom: 8 })
          Flex({ wrap: FlexWrap.Wrap, justifyContent: FlexAlign.Start }) {
            ForEach(PERIOD_OPTIONS, (opt: PeriodOption) => {
              Button(opt.label)
                .type(ButtonType.Capsule)
                .height(32)
                .backgroundColor(this.periodType === opt.value ? '#007aff' : '#f0f0f0')
                .fontColor(this.periodType === opt.value ? Color.White : '#666')
                .fontSize(13)
                .padding({ left: 14, right: 14 })
                .margin({ right: 8, bottom: 8 })
                .onClick(() => { this.periodType = opt.value; })
            }, (opt: PeriodOption): string => opt.value)
          }
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
          .enabled(this.name.trim() !== '' && parseFloat(this.targetAmount) > 0)
          .opacity(this.name.trim() !== '' && parseFloat(this.targetAmount) > 0 ? 1 : 0.5)
          .onClick(() => { this.onConfirmClick(); })
      }
      .width('100%')
      .padding({ top: 12 })
    }
    .width('100%')
    .padding(24)
  }
}

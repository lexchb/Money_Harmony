import { Goal } from '../model/Bill';
import { dbHelper } from '../model/DatabaseHelper';

/** 单个选项高度（含底部间距） */
const OPTION_ITEM_HEIGHT: number = 66;
/** 最多同时展示的选项个数（含"不关联"） */
const MAX_VISIBLE_OPTIONS: number = 3;

/**
 * 目标选择弹窗：底部弹出，选项文字居中、高度加大。
 * 固定最多展示 3 个选项，超出部分通过滚动条滚动查看。
 */
@CustomDialog
@Component
export struct GoalPickerDialog {
  controller: CustomDialogController;
  onSelect: (goalId: number, goalName: string) => void = () => {};
  @State goals: Goal[] = [];
  @State listHeight: number = OPTION_ITEM_HEIGHT;

  aboutToAppear(): void {
    this.loadGoals();
  }

  async loadGoals(): Promise<void> {
    this.goals = await dbHelper.getGoals();
    // 固定最多显示 3 个选项（含"不关联"），超出滚动
    const optionCount = Math.min(this.goals.length + 1, MAX_VISIBLE_OPTIONS);
    this.listHeight = optionCount * OPTION_ITEM_HEIGHT;
  }

  build() {
    Column() {
      // ===== 标题 =====
      Column() {
        Text('选择目标')
          .fontSize(18)
          .fontWeight(FontWeight.Bold)
          .fontColor('#1a1a1a')
        Text('将这笔账单计入目标（可选）')
          .fontSize(12)
          .fontColor('#999')
          .margin({ top: 4 })
      }
      .width('100%')
      .padding({ top: 24, bottom: 16 })

      // ===== 选项列表（固定高度，超出滚动） =====
      List() {
        ListItem() {
          this.OptionItem('不关联', 0)
        }
        ForEach(this.goals, (g: Goal) => {
          ListItem() {
            this.OptionItem(g.name, g.id ?? 0)
          }
        }, (g: Goal): string => `${g.id}`)
      }
      .width('100%')
      .height(this.listHeight)
      .scrollBar(BarState.Auto)
      .scrollBarWidth(4)

      // ===== 取消 =====
      Button('取消')
        .width('100%')
        .height(48)
        .backgroundColor('#f5f5f5')
        .fontColor('#666')
        .fontSize(16)
        .margin({ top: 8, bottom: 24 })
        .onClick(() => this.controller.close())
    }
    .width('100%')
    .padding({ left: 20, right: 20 })
    .backgroundColor(Color.White)
    .borderRadius({ topLeft: 24, topRight: 24 })
  }

  @Builder
  OptionItem(name: string, goalId: number) {
    Row() {
      Text(name)
        .fontSize(16)
        .fontColor('#333')
        .fontWeight(FontWeight.Medium)
    }
    .width('100%')
    .height(56)
    .justifyContent(FlexAlign.Center)
    .backgroundColor('#f5f6f8')
    .borderRadius(14)
    .margin({ bottom: 10 })
    .onClick(() => {
      this.onSelect(goalId, name);
      this.controller.close();
    })
  }
}

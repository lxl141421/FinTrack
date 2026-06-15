
import { Budget as BudgetModel } from '../models/Budget'
import { BudgetService } from '../services/BudgetService'
import { CurrencyUtils } from '../utils/CurrencyUtils'
import { Constants } from '../constants/Constants'
import { ThemeFont, ThemeRadius, ThemeSpacing } from '../theme/Theme'
import { promptAction } from '@kit.ArkUI'

@Entry
@Component
struct BudgetPage {
  @State budgets: BudgetModel[] = []
  @State overallStatus: { totalLimit: number; totalSpent: number; percent: number } = {
    totalLimit: 0, totalSpent: 0, percent: 0
  }
  @State alertBudgets: BudgetModel[] = []
  @State showAddDialog: boolean = false
  @State newCategory: string = ''
  @State newLimitAmount: string = ''

  private budgetService = new BudgetService()

  aboutToAppear(): void {
    this.loadData()
  }

  private async loadData(): Promise<void> {
    this.budgets = await this.budgetService.getCurrentBudgets()
    this.overallStatus = await this.budgetService.getOverallBudgetStatus()
    this.alertBudgets = await this.budgetService.getBudgetAlerts()
  }

  private async addBudget(): Promise<void> {
    if (this.newLimitAmount === '' || Number(this.newLimitAmount) <= 0) {
      promptAction.showToast({ message: '请输入预算金额' })
      return
    }

    await this.budgetService.setBudget(this.newCategory, '总预算', Number(this.newLimitAmount))
    this.showAddDialog = false
    this.newCategory = ''
    this.newLimitAmount = ''
    await this.loadData()
    promptAction.showToast({ message: '预算已设置' })
  }

  private getStatusColor(percent: number): string {
    if (percent >= Constants.BUDGET_DANGER_THRESHOLD) return '#FA2A2D'
    if (percent >= Constants.BUDGET_WARN_THRESHOLD) return '#FF8800'
    return '#00B578'
  }

  private getStatusText(budget: BudgetModel): string {
    if (budget.isExceeded()) return `已超支 ${CurrencyUtils.format(budget.spentAmount - budget.limitAmount)}`
    return `剩余 ${CurrencyUtils.format(budget.getRemaining())}`
  }

  build() {
    Column() {
      // 总览卡片
      Column({ space: ThemeSpacing.md }) {
        Row() {
          Text('本月预算')
            .fontSize(ThemeFont.lg)
            .fontWeight(ThemeFont.weightMedium)
            .fontColor('#181818')
          Blank()
          Button('+ 添加预算')
            .fontSize(ThemeFont.sm)
            .height(32)
            .borderRadius(ThemeRadius.full)
            .backgroundColor('#007DFF')
            .onClick(() => {
              this.showAddDialog = true
            })
        }
        .width('100%')

        // 总体进度
        Column({ space: ThemeSpacing.sm }) {
          Row() {
            Text(CurrencyUtils.format(this.overallStatus.totalSpent))
              .fontSize(ThemeFont.xl)
              .fontWeight(ThemeFont.weightBold)
              .fontColor(this.getStatusColor(this.overallStatus.percent))
            Text(` / ${CurrencyUtils.format(this.overallStatus.totalLimit)}`)
              .fontSize(ThemeFont.md)
              .fontColor('#999')
          }
          .width('100%')

          // 进度条
          Stack({ alignContent: Alignment.Start }) {
            Row()
              .width('100%')
              .height(8)
              .backgroundColor('#F0F0F0')
              .borderRadius(4)

            Row()
              .width(Math.min(this.overallStatus.percent, 1) * 100 + '%')
              .height(8)
              .backgroundColor(this.getStatusColor(this.overallStatus.percent))
              .borderRadius(4)
          }
          .width('100%')

          Row() {
            Text(`已使用 ${(this.overallStatus.percent * 100).toFixed(1)}%`)
              .fontSize(ThemeFont.xs)
              .fontColor('#999')
            Blank()
            Text(this.overallStatus.percent >= 1 ? '⚠️ 已超支' : this.overallStatus.percent >= 0.8 ? '⚠️ 即将超支' : '✅ 正常')
              .fontSize(ThemeFont.xs)
              .fontColor(this.getStatusColor(this.overallStatus.percent))
          }
          .width('100%')
        }
      }
      .width('100%')
      .padding(ThemeSpacing.lg)
      .backgroundColor('#FFFFFF')
      .borderRadius(ThemeRadius.md)
      .margin(ThemeSpacing.lg)
      .shadow({ radius: 4, color: '#00000008', offsetX: 0, offsetY: 2 })

      // 预警提示
      if (this.alertBudgets.length > 0) {
        ForEach(this.alertBudgets, (budget: BudgetModel) => {
          Row({ space: ThemeSpacing.sm }) {
            Text(budget.isExceeded() ? '🚨' : '⚠️')
              .fontSize(20)
            Text(budget.isExceeded()
              ? `${budget.categoryName} 预算已超支 ${CurrencyUtils.format(budget.spentAmount - budget.limitAmount)}`
              : `${budget.categoryName} 预算已使用 ${(budget.getUsagePercent() * 100).toFixed(0)}%`)
              .fontSize(ThemeFont.sm)
              .fontColor(budget.isExceeded() ? '#FA2A2D' : '#FF8800')
          }
          .width('100%')
          .padding(ThemeSpacing.md)
          .backgroundColor(budget.isExceeded() ? '#FA2A2D10' : '#FF880010')
          .borderRadius(ThemeRadius.md)
          .margin({ left: ThemeSpacing.lg, right: ThemeSpacing.lg })
        })
      }

      // 预算列表
      List({ space: ThemeSpacing.md }) {
        ForEach(this.budgets, (budget: BudgetModel) => {
          ListItem() {
            Column({ space: ThemeSpacing.sm }) {
              Row() {
                Text(budget.categoryName)
                  .fontSize(ThemeFont.md)
                  .fontWeight(ThemeFont.weightMedium)
                  .fontColor('#181818')
                Blank()
                Text(this.getStatusText(budget))
                  .fontSize(ThemeFont.sm)
                  .fontColor(this.getStatusColor(budget.getUsagePercent()))
              }
              .width('100%')

              // 进度条
              Stack({ alignContent: Alignment.Start }) {
                Row()
                  .width('100%')
                  .height(6)
                  .backgroundColor('#F0F0F0')
                  .borderRadius(3)

                Row()
                  .width(Math.min(budget.getUsagePercent(), 1) * 100 + '%')
                  .height(6)
                  .backgroundColor(this.getStatusColor(budget.getUsagePercent()))
                  .borderRadius(3)
              }
              .width('100%')

              Row() {
                Text(`已用 ${CurrencyUtils.format(budget.spentAmount)}`)
                  .fontSize(ThemeFont.xs)
                  .fontColor('#999')
                Blank()
                Text(`预算 ${CurrencyUtils.format(budget.limitAmount)}`)
                  .fontSize(ThemeFont.xs)
                  .fontColor('#999')
              }
              .width('100%')
            }
            .width('100%')
            .padding(ThemeSpacing.lg)
            .backgroundColor('#FFFFFF')
            .borderRadius(ThemeRadius.md)
            .shadow({ radius: 4, color: '#00000008', offsetX: 0, offsetY: 2 })
          }
          .padding({ left: ThemeSpacing.lg, right: ThemeSpacing.lg })
        })
      }
      .layoutWeight(1)
      .width('100%')

      // 添加预算对话框
      if (this.showAddDialog) {
        Column() {
          Column({ space: ThemeSpacing.lg }) {
            Text('添加预算')
              .fontSize(ThemeFont.xl)
              .fontWeight(ThemeFont.weightBold)

            TextInput({ placeholder: '预算金额', text: this.newLimitAmount })
              .type(InputType.Number)
              .height(44)
              .borderRadius(ThemeRadius.sm)
              .onChange((value: string) => { this.newLimitAmount = value })

            Row({ space: ThemeSpacing.md }) {
              Button('取消')
                .layoutWeight(1)
                .height(44)
                .backgroundColor('#F0F0F0')
                .fontColor('#666')
                .onClick(() => { this.showAddDialog = false })

              Button('确定')
                .layoutWeight(1)
                .height(44)
                .backgroundColor('#007DFF')
                .onClick(() => { this.addBudget() })
            }
          }
          .width('80%')
          .padding(ThemeSpacing.xl)
          .backgroundColor('#FFFFFF')
          .borderRadius(ThemeRadius.lg)
        }
        .width('100%')
        .height('100%')
        .backgroundColor('#00000060')
        .justifyContent(FlexAlign.Center)
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor('#F5F5F5')
  }
}


import { Budget as BudgetModel } from '../models/Budget'
import { BudgetService, BudgetStatus } from '../services/BudgetService'
import { CurrencyUtils } from '../utils/CurrencyUtils'
import { Constants } from '../constants/Constants'
import { ThemeFont, ThemeRadius, ThemeSpacing, ThemeManager } from '../theme/Theme'
import { promptAction } from '@kit.ArkUI'

@Entry
@Component
struct BudgetPage {
  @State budgets: BudgetModel[] = []
  @State overallStatus: BudgetStatus = new BudgetStatus()
  @State alertBudgets: BudgetModel[] = []
  @State showAddDialog: boolean = false
  @State newCategory: string = ''
  @State newLimitAmount: string = ''

  private budgetService = new BudgetService()
  private themeManager = ThemeManager.getInstance()

  aboutToAppear(): void {
    this.loadData()
  }

  onShow(): void {
    this.loadData()
  }

  private async loadData(): Promise<void> {
    try {
      this.budgets = await this.budgetService.getCurrentBudgets()
      const status = await this.budgetService.getOverallBudgetStatus()
      this.overallStatus.totalLimit = status.totalLimit
      this.overallStatus.totalSpent = status.totalSpent
      this.overallStatus.percent = status.percent
      this.alertBudgets = await this.budgetService.getBudgetAlerts()
    } catch (err) {
      promptAction.showToast({ message: '加载预算数据失败' })
    }
  }

  private async addBudget(): Promise<void> {
    if (this.newCategory === '' || this.newLimitAmount === '') {
      promptAction.showToast({ message: '请填写完整信息' })
      return
    }
    const amount = Number(this.newLimitAmount)
    if (isNaN(amount) || amount <= 0) {
      promptAction.showToast({ message: '请输入有效金额' })
      return
    }

    try {
      await this.budgetService.setBudget(this.newCategory, this.newCategory, amount)
      this.showAddDialog = false
      this.newCategory = ''
      this.newLimitAmount = ''
      await this.loadData()
      promptAction.showToast({ message: '预算已添加' })
    } catch (err) {
      promptAction.showToast({ message: '添加预算失败' })
    }
  }

  private getStatusColor(percent: number): string {
    if (percent >= 1) return '#FA2A2D'
    if (percent >= 0.8) return '#FF8800'
    return '#00B578'
  }

  build() {
    Column() {
      // 预算概览
      this.buildOverviewSection()

      // 预算列表
      this.buildBudgetList()

      // 添加预算按钮
      Button('添加预算')
        .width('90%')
        .height(48)
        .fontSize(ThemeFont.md)
        .borderRadius(ThemeRadius.lg)
        .backgroundColor('#007DFF')
        .margin({ top: ThemeSpacing.lg, bottom: ThemeSpacing.xxl })
        .onClick(() => {
          this.showAddDialog = true
        })
    }
    .width('100%')
    .height('100%')
    .backgroundColor(this.themeManager.isDark ? '#121212' : '#F5F5F5')
  }

  @Builder
  buildOverviewSection() {
    Column({ space: ThemeSpacing.md }) {
      Row() {
        Text('预算概览')
          .fontSize(ThemeFont.xl)
          .fontWeight(ThemeFont.weightBold)
          .fontColor(this.themeManager.isDark ? '#E0E0E0' : '#181818')
        Blank()
      }
      .width('100%')

      // 总体进度
      Column({ space: ThemeSpacing.sm }) {
        Row() {
          Text(CurrencyUtils.format(this.overallStatus.totalSpent))
            .fontSize(ThemeFont.lg)
            .fontWeight(ThemeFont.weightBold)
            .fontColor(this.getStatusColor(this.overallStatus.percent))
          Text(` / ${CurrencyUtils.format(this.overallStatus.totalLimit)}`)
            .fontSize(ThemeFont.md)
            .fontColor('#999')
        }
        .width('100%')

        // 进度条
        Stack({ alignContent: Alignment.Start }) {
          Row() {}
            .width('100%')
            .height(8)
            .borderRadius(4)
            .backgroundColor(this.themeManager.isDark ? '#333' : '#F0F0F0')
          Row() {}
            .width(Math.min(this.overallStatus.percent, 1) * 100 + '%')
            .height(8)
            .borderRadius(4)
            .backgroundColor(this.getStatusColor(this.overallStatus.percent))
        }
        .width('100%')

        Row() {
          Text(`已使用 ${(this.overallStatus.percent * 100).toFixed(1)}%`)
            .fontSize(ThemeFont.sm)
            .fontColor('#999')
          Blank()
          Text(this.overallStatus.percent >= 1 ? '⚠️ 已超支' : this.overallStatus.percent >= 0.8 ? '⚠️ 即将超支' : '✅ 正常')
            .fontSize(ThemeFont.sm)
            .fontColor(this.getStatusColor(this.overallStatus.percent))
        }
        .width('100%')
      }
      .width('100%')
      .padding(ThemeSpacing.lg)
      .backgroundColor(this.themeManager.isDark ? '#1E1E1E' : '#FFFFFF')
      .borderRadius(ThemeRadius.md)
      .shadow({ radius: 4, color: this.themeManager.isDark ? '#00000030' : '#00000008', offsetX: 0, offsetY: 2 })
    }
    .width('100%')
    .padding(ThemeSpacing.lg)
  }

  @Builder
  buildBudgetList() {
    Column({ space: ThemeSpacing.md }) {
      Row() {
        Text('分类预算')
          .fontSize(ThemeFont.lg)
          .fontWeight(ThemeFont.weightMedium)
          .fontColor(this.themeManager.isDark ? '#E0E0E0' : '#181818')
        Blank()
        Text(`共 ${this.budgets.length} 项`)
          .fontSize(ThemeFont.sm)
          .fontColor('#999')
      }
      .width('100%')

      if (this.budgets.length > 0) {
        List({ space: ThemeSpacing.sm }) {
          ForEach(this.budgets, (budget: BudgetModel) => {
            ListItem() {
              Column({ space: ThemeSpacing.sm }) {
                Row() {
                  Text(budget.categoryName || '总预算')
                    .fontSize(ThemeFont.md)
                    .fontWeight(ThemeFont.weightMedium)
                    .fontColor(this.themeManager.isDark ? '#E0E0E0' : '#181818')
                  Blank()
                  Text(CurrencyUtils.format(budget.spentAmount))
                    .fontSize(ThemeFont.md)
                    .fontWeight(ThemeFont.weightBold)
                    .fontColor(this.getStatusColor(budget.limitAmount > 0 ? budget.spentAmount / budget.limitAmount : 0))
                  Text(` / ${CurrencyUtils.format(budget.limitAmount)}`)
                    .fontSize(ThemeFont.sm)
                    .fontColor('#999')
                }
                .width('100%')

                // 进度条
                Stack({ alignContent: Alignment.Start }) {
                  Row() {}
                    .width('100%')
                    .height(6)
                    .borderRadius(3)
                    .backgroundColor(this.themeManager.isDark ? '#333' : '#F0F0F0')
                  Row() {}
                    .width(Math.min(budget.limitAmount > 0 ? budget.spentAmount / budget.limitAmount : 0, 1) * 100 + '%')
                    .height(6)
                    .borderRadius(3)
                    .backgroundColor(this.getStatusColor(budget.limitAmount > 0 ? budget.spentAmount / budget.limitAmount : 0))
                }
                .width('100%')

                Row() {
                  Text(`剩余 ${CurrencyUtils.format(Math.max(budget.limitAmount - budget.spentAmount, 0))}`)
                    .fontSize(ThemeFont.xs)
                    .fontColor('#999')
                  Blank()
                  Text(`${((budget.limitAmount > 0 ? budget.spentAmount / budget.limitAmount : 0) * 100).toFixed(1)}%`)
                    .fontSize(ThemeFont.xs)
                    .fontColor('#999')
                }
                .width('100%')
              }
              .width('100%')
              .padding(ThemeSpacing.lg)
              .backgroundColor(this.themeManager.isDark ? '#1E1E1E' : '#FFFFFF')
              .borderRadius(ThemeRadius.md)
              .shadow({ radius: 4, color: this.themeManager.isDark ? '#00000030' : '#00000008', offsetX: 0, offsetY: 2 })
            }
          })
        }
        .width('100%')
        .layoutWeight(1)
      } else {
        Column({ space: ThemeSpacing.sm }) {
          Text('📊')
            .fontSize(48)
          Text('还没有设置预算')
            .fontSize(ThemeFont.md)
            .fontColor('#999')
          Text('点击下方按钮添加')
            .fontSize(ThemeFont.sm)
            .fontColor('#CCC')
        }
        .width('100%')
        .padding(ThemeSpacing.xxl)
      }
    }
    .width('100%')
    .padding(ThemeSpacing.lg)
    .layoutWeight(1)
  }
}

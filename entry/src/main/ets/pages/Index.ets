
import { router } from '@kit.ArkUI'
import { SummaryCard } from '../components/common/SummaryCard'
import { AnimatedNumber } from '../components/common/AnimatedNumber'
import { TransactionCard } from '../components/common/TransactionCard'
import { LineChart } from '../components/charts/LineChart'
import { PieChart } from '../components/charts/PieChart'
import { Transaction } from '../models/Transaction'
import { StorageService } from '../services/StorageService'
import { BudgetService } from '../services/BudgetService'
import { Constants } from '../constants/Constants'
import { DateUtils } from '../utils/DateUtils'
import { CurrencyUtils } from '../utils/CurrencyUtils'
import { ThemeFont, ThemeRadius, ThemeSpacing } from '../theme/Theme'
import { hilog } from '@kit.PerformanceAnalysisKit'

@Entry
@Component
struct Index {
  @State totalAssets: number = 0
  @State monthlyIncome: number = 0
  @State monthlyExpense: number = 0
  @State monthlyBalance: number = 0
  @State recentTransactions: Transaction[] = []
  @State dailyTrend: number[] = []
  @State trendLabels: string[] = []
  @State expenseByCategory: Record<string, number> = {}
  @State pieColors: string[] = Constants.DEFAULT_CATEGORIES.map((_, i) =>
    ['#007DFF', '#00B578', '#FF8800', '#FA2A2D', '#9B59B6', '#3498DB',
     '#1ABC9C', '#F7CE46', '#E74C3C', '#2ECC71', '#34495E', '#95A5A6'][i % 12])
  @State isLoaded: boolean = false

  private storageService = StorageService.getInstance()
  private budgetService = new BudgetService()

  aboutToAppear(): void {
    this.loadData()
  }

  private async loadData(): Promise<void> {
    try {
      // 加载本月数据
      const monthStart = DateUtils.getMonthStart()
      const monthEnd = DateUtils.getMonthEnd()

      const incomeTxns = await this.storageService.queryTransactions(
        Constants.TYPE_INCOME, monthStart, monthEnd
      )
      const expenseTxns = await this.storageService.queryTransactions(
        Constants.TYPE_EXPENSE, monthStart, monthEnd
      )

      this.monthlyIncome = incomeTxns.reduce((sum, t) => sum + t.amount, 0)
      this.monthlyExpense = expenseTxns.reduce((sum, t) => sum + t.amount, 0)
      this.monthlyBalance = this.monthlyIncome - this.monthlyExpense
      this.totalAssets = this.monthlyBalance // 简化：实际应从账户汇总

      // 最近交易
      const allTxns = await this.storageService.queryTransactions(-1, 0, Date.now(), '', '', 5)
      this.recentTransactions = allTxns

      // 每日支出趋势
      this.dailyTrend = await this.budgetService.getDailyExpenseTrend()
      this.trendLabels = Array.from({ length: this.dailyTrend.length }, (_, i) => (i + 1).toString())

      // 分类支出
      const categoryMap: Record<string, number> = {}
      for (const txn of expenseTxns) {
        const key = txn.categoryName
        if (categoryMap[key] === undefined) {
          categoryMap[key] = 0
        }
        categoryMap[key] += txn.amount
      }
      this.expenseByCategory = categoryMap

      this.isLoaded = true
    } catch (err) {
      hilog.error(0x0000, 'FinTrack', 'Load data failed: %{public}s', JSON.stringify(err))
    }
  }

  build() {
    Navigation() {
      Scroll() {
        Column({ space: ThemeSpacing.lg }) {
          // 顶部资产总览
          this.buildHeader()

          // 收支摘要卡片
          this.buildSummaryCards()

          // 资产趋势折线图
          this.buildTrendChart()

          // 支出分类饼图
          this.buildCategoryPie()

          // 最近交易
          this.buildRecentTransactions()
        }
        .padding(ThemeSpacing.lg)
      }
      .width('100%')
      .height('100%')
      .backgroundColor('#F5F5F5')
    }
    .title('FinTrack')
    .titleMode(NavigationTitleMode.Mini)
  }

  @Builder
  buildHeader() {
    Column({ space: ThemeSpacing.sm }) {
      Row() {
        Column() {
          Text('总资产')
            .fontSize(ThemeFont.sm)
            .fontColor('#FFFFFF90')

          AnimatedNumber({
            value: this.totalAssets,
            fontSize: ThemeFont.hero,
            fontWeight: ThemeFont.weightBold,
            fontColor: '#FFFFFF',
            prefix: '¥'
          })
        }
        .alignItems(HorizontalAlign.Start)

        Blank()

        Button() {
          Text('+')
            .fontSize(ThemeFont.xl)
            .fontColor('#FFFFFF')
        }
        .width(48)
        .height(48)
        .borderRadius(ThemeRadius.full)
        .backgroundColor('#FFFFFF30')
        .onClick(() => {
          router.pushUrl({ url: 'pages/AddTransaction' })
        })
      }
      .width('100%')

      // 本月结余
      Text(`本月结余 ${CurrencyUtils.format(this.monthlyBalance)}`)
        .fontSize(ThemeFont.sm)
        .fontColor('#FFFFFF80')
    }
    .width('100%')
    .padding(ThemeSpacing.xl)
    .linearGradient({
      direction: GradientDirection.Right,
      colors: [['#007DFF', 0.0], ['#005BB5', 1.0]]
    })
    .borderRadius(ThemeRadius.lg)
  }

  @Builder
  buildSummaryCards() {
    Row({ space: ThemeSpacing.md }) {
      SummaryCard({
        title: '本月收入',
        amount: this.monthlyIncome,
        color: '#00B578',
        icon: '📈',
        compact: true
      })

      SummaryCard({
        title: '本月支出',
        amount: this.monthlyExpense,
        color: '#FA2A2D',
        icon: '📉',
        compact: true
      })
    }
    .width('100%')
  }

  @Builder
  buildTrendChart() {
    Column({ space: ThemeSpacing.md }) {
      Row() {
        Text('本月支出趋势')
          .fontSize(ThemeFont.lg)
          .fontWeight(ThemeFont.weightMedium)
          .fontColor('#181818')
        Blank()
      }
      .width('100%')

      if (this.dailyTrend.length > 0) {
        LineChart({
          data: this.dailyTrend,
          labels: this.trendLabels,
          width: 340,
          height: 180,
          lineColor: '#FA2A2D',
          fillColor: '#FA2A2D20'
        })
      }
    }
    .width('100%')
    .padding(ThemeSpacing.lg)
    .backgroundColor('#FFFFFF')
    .borderRadius(ThemeRadius.md)
    .shadow({ radius: 4, color: '#00000008', offsetX: 0, offsetY: 2 })
  }

  @Builder
  buildCategoryPie() {
    Column({ space: ThemeSpacing.md }) {
      Row() {
        Text('支出分类')
          .fontSize(ThemeFont.lg)
          .fontWeight(ThemeFont.weightMedium)
          .fontColor('#181818')
        Blank()
      }
      .width('100%')

      if (Object.keys(this.expenseByCategory).length > 0) {
        PieChart({
          slices: this.convertToPieSlices(),
          size: 180,
          totalLabel: '总支出',
          totalAmount: CurrencyUtils.format(this.monthlyExpense)
        })
      } else {
        Text('本月暂无支出记录')
          .fontSize(ThemeFont.md)
          .fontColor('#999')
          .width('100%')
          .textAlign(TextAlign.Center)
          .padding(ThemeSpacing.xxl)
      }
    }
    .width('100%')
    .padding(ThemeSpacing.lg)
    .backgroundColor('#FFFFFF')
    .borderRadius(ThemeRadius.md)
    .shadow({ radius: 4, color: '#00000008', offsetX: 0, offsetY: 2 })
  }

  @Builder
  buildRecentTransactions() {
    Column({ space: ThemeSpacing.md }) {
      Row() {
        Text('最近交易')
          .fontSize(ThemeFont.lg)
          .fontWeight(ThemeFont.weightMedium)
          .fontColor('#181818')
        Blank()
        Text('查看全部')
          .fontSize(ThemeFont.sm)
          .fontColor('#007DFF')
          .onClick(() => {
            router.pushUrl({ url: 'pages/Transactions' })
          })
      }
      .width('100%')

      if (this.recentTransactions.length > 0) {
        ForEach(this.recentTransactions, (txn: Transaction) => {
          TransactionCard({
            transaction: txn,
            showDate: true
          })
        })
      } else {
        Column({ space: ThemeSpacing.sm }) {
          Text('📝')
            .fontSize(48)
          Text('还没有交易记录')
            .fontSize(ThemeFont.md)
            .fontColor('#999')
          Text('点击 + 开始记账')
            .fontSize(ThemeFont.sm)
            .fontColor('#CCC')
        }
        .width('100%')
        .padding(ThemeSpacing.xxl)
      }
    }
    .width('100%')
  }

  private convertToPieSlices(): PieSlice[] {
    const slices: PieSlice[] = []
    let idx = 0
    for (const key in this.expenseByCategory) {
      slices.push(new PieSlice(key, this.expenseByCategory[key], this.pieColors[idx % this.pieColors.length]))
      idx++
    }
    return slices
  }
}

// Re-export PieSlice for local use
class PieSlice {
  label: string = ''
  value: number = 0
  color: string = '#007DFF'

  constructor(label: string, value: number, color: string) {
    this.label = label
    this.value = value
    this.color = color
  }

  get percent(): number {
    return 0 // Will be calculated by PieChart component
  }
}

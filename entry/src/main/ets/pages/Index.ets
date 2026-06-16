
import { router } from '@kit.ArkUI'
import { SummaryCard } from '../components/common/SummaryCard'
import { AnimatedNumber } from '../components/common/AnimatedNumber'
import { TransactionCard } from '../components/common/TransactionCard'
import { LineChart } from '../components/charts/LineChart'
import { PieChart } from '../components/charts/PieChart'
import { PieSlice } from '../utils/ChartUtils'
import { Transaction } from '../models/Transaction'
import { TransactionViewModel, LoadingState } from '../viewmodel/TransactionViewModel'
import { BudgetService } from '../services/BudgetService'
import { Constants } from '../constants/Constants'
import { DateUtils } from '../utils/DateUtils'
import { CurrencyUtils } from '../utils/CurrencyUtils'
import { ThemeFont, ThemeRadius, ThemeSpacing, ThemeManager, getLightColors, getDarkColors } from '../theme/Theme'
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
  @State pieColors: string[] = Constants.DEFAULT_CATEGORIES.map((_: string, i: number) =>
    ['#007DFF', '#00B578', '#FF8800', '#FA2A2D', '#9B59B6', '#3498DB',
     '#1ABC9C', '#F7CE46', '#E74C3C', '#2ECC71', '#34495E', '#95A5A6'][i % 12])
  @State isLoaded: boolean = false
  @State loadingState: LoadingState = LoadingState.IDLE
  @State errorMessage: string = ''
  @State isPrivacyMode: boolean = false
  @State gripOffset: number = 0

  private viewModel: TransactionViewModel = new TransactionViewModel()
  private budgetService = new BudgetService()
  private themeManager = ThemeManager.getInstance()

  aboutToAppear(): void {
    this.loadData()
  }

  onShow(): void {
    if (this.isLoaded) {
      this.loadData()
    }
    this.isPrivacyMode = this.themeManager.privacyMode
    this.gripOffset = this.themeManager.getActionButtonOffset()
  }

  private async loadData(): Promise<void> {
    this.loadingState = LoadingState.LOADING
    this.errorMessage = ''

    try {
      await this.viewModel.loadDashboardData()

      this.monthlyIncome = this.viewModel.monthlyIncome
      this.monthlyExpense = this.viewModel.monthlyExpense
      this.monthlyBalance = this.viewModel.monthlyBalance
      this.totalAssets = this.viewModel.totalAssets
      this.recentTransactions = this.viewModel.recentTransactions
      this.expenseByCategory = this.viewModel.expenseByCategory
      this.loadingState = this.viewModel.loadingState
      this.errorMessage = this.viewModel.errorMessage

      try {
        this.dailyTrend = await this.budgetService.getDailyExpenseTrend()
        const labels: string[] = []
        for (let i = 0; i < this.dailyTrend.length; i++) {
          labels.push((i + 1).toString())
        }
        this.trendLabels = labels
      } catch (trendErr) {
        hilog.error(0x0000, 'FinTrack', 'Load trend failed')
        this.dailyTrend = []
      }

      this.isLoaded = true
    } catch (err) {
      hilog.error(0x0000, 'FinTrack', 'Load data failed')
      this.errorMessage = '数据加载失败，请下拉刷新重试'
      this.loadingState = LoadingState.ERROR
    }
  }

  build() {
    Navigation() {
      if (this.loadingState === LoadingState.LOADING && !this.isLoaded) {
        Column() {
          LoadingProgress()
            .width(48)
            .height(48)
          Text('加载中...')
            .fontSize(ThemeFont.md)
            .fontColor(this.themeManager.isDark ? '#999' : '#666')
            .margin({ top: ThemeSpacing.md })
        }
        .width('100%')
        .height('100%')
        .justifyContent(FlexAlign.Center)
      } else if (this.loadingState === LoadingState.ERROR && !this.isLoaded) {
        Column({ space: ThemeSpacing.md }) {
          Text('😵')
            .fontSize(64)
          Text(this.errorMessage || '加载失败')
            .fontSize(ThemeFont.md)
            .fontColor('#999')
          Button('点击重试')
            .fontSize(ThemeFont.md)
            .height(40)
            .borderRadius(ThemeRadius.full)
            .backgroundColor('#007DFF')
            .onClick(() => {
              this.loadData()
            })
        }
        .width('100%')
        .height('100%')
        .justifyContent(FlexAlign.Center)
      } else {
        Scroll() {
          Column({ space: ThemeSpacing.lg }) {
            this.buildHeader()
            this.buildSummaryCards()
            this.buildTrendChart()
            this.buildCategoryPie()
            this.buildRecentTransactions()
          }
          .padding(ThemeSpacing.lg)
        }
        .width('100%')
        .height('100%')
        .backgroundColor(this.themeManager.isDark ? '#121212' : '#F5F5F5')
      }
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
            prefix: this.isPrivacyMode ? '' : '¥'
          })
        }
        .alignItems(HorizontalAlign.Start)

        // 股票行情入口
        Button() {
          Text('📈')
            .fontSize(18)
        }
        .width(40)
        .height(40)
        .borderRadius(ThemeRadius.full)
        .backgroundColor('#FFFFFF20')
        .onClick(() => {
          router.pushUrl({ url: 'pages/StockMarket' })
        })

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

      Text(this.isPrivacyMode ? '本月结余 ****' : `本月结余 ${CurrencyUtils.format(this.monthlyBalance)}`)
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
        compact: true,
        privacyMode: this.isPrivacyMode
      })
      SummaryCard({
        title: '本月支出',
        amount: this.monthlyExpense,
        color: '#FA2A2D',
        icon: '📉',
        compact: true,
        privacyMode: this.isPrivacyMode
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
          .fontColor(this.themeManager.isDark ? '#E0E0E0' : '#181818')
        Blank()
      }
      .width('100%')

      if (this.dailyTrend.length > 0) {
        LineChart({
          data: this.dailyTrend,
          labels: this.trendLabels,
          chartWidth: 340,
          chartHeight: 180,
          lineColor: '#FA2A2D',
          fillColor: '#FA2A2D20'
        })
      }
    }
    .width('100%')
    .padding(ThemeSpacing.lg)
    .backgroundColor(this.themeManager.isDark ? '#1E1E1E' : '#FFFFFF')
    .borderRadius(ThemeRadius.md)
    .shadow({ radius: 4, color: this.themeManager.isDark ? '#00000030' : '#00000008', offsetX: 0, offsetY: 2 })
  }

  @Builder
  buildCategoryPie() {
    Column({ space: ThemeSpacing.md }) {
      Row() {
        Text('支出分类')
          .fontSize(ThemeFont.lg)
          .fontWeight(ThemeFont.weightMedium)
          .fontColor(this.themeManager.isDark ? '#E0E0E0' : '#181818')
        Blank()
      }
      .width('100%')

      if (Object.keys(this.expenseByCategory).length > 0) {
        PieChart({
          slices: this.convertToPieSlices(),
          chartSize: 180,
          totalLabel: '总支出',
          totalAmount: this.isPrivacyMode ? '****' : CurrencyUtils.format(this.monthlyExpense)
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
    .backgroundColor(this.themeManager.isDark ? '#1E1E1E' : '#FFFFFF')
    .borderRadius(ThemeRadius.md)
    .shadow({ radius: 4, color: this.themeManager.isDark ? '#00000030' : '#00000008', offsetX: 0, offsetY: 2 })
  }

  @Builder
  buildRecentTransactions() {
    Column({ space: ThemeSpacing.md }) {
      Row() {
        Text('最近交易')
          .fontSize(ThemeFont.lg)
          .fontWeight(ThemeFont.weightMedium)
          .fontColor(this.themeManager.isDark ? '#E0E0E0' : '#181818')
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
            showDate: true,
            privacyMode: this.isPrivacyMode
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
    const keys = Object.keys(this.expenseByCategory)
    for (let idx = 0; idx < keys.length; idx++) {
      const key = keys[idx]
      slices.push(new PieSlice(key, this.expenseByCategory[key], this.pieColors[idx % this.pieColors.length]))
    }
    return slices
  }
}

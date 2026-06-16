import { StockService, StockQuote } from '../services/StockService'
import { CandlestickChart } from '../components/charts/CandlestickChart'
import { KLineData } from '../utils/ChartUtils'
import { ThemeFont, ThemeRadius, ThemeSpacing, ThemeManager } from '../theme/Theme'
import { hilog } from '@kit.PerformanceAnalysisKit'

/**
 * 股票行情看盘页
 *
 * 功能：
 * - 自选股实时行情列表
 * - K 线图展示（支持 MA 均线）
 * - 涨跌颜色标识
 * - 下拉刷新行情
 */
@Entry
@Component
struct StockMarket {
  @State quotes: StockQuote[] = []
  @State selectedStock: StockQuote | null = null
  @State kLineData: KLineData[] = []
  @State isLoading: boolean = false
  @State isRefreshing: boolean = false
  @State showDetail: boolean = false

  private stockService = StockService.getInstance()
  private themeManager = ThemeManager.getInstance()

  aboutToAppear(): void {
    this.loadQuotes()
  }

  private async loadQuotes(): Promise<void> {
    this.isLoading = true
    try {
      this.quotes = await this.stockService.getWatchlistQuotes()
    } catch (err) {
      hilog.error(0x0000, 'FinTrack', 'Load quotes failed')
    } finally {
      this.isLoading = false
    }
  }

  private async onRefresh(): Promise<void> {
    this.isRefreshing = true
    await this.loadQuotes()
    this.isRefreshing = false
  }

  private selectStock(quote: StockQuote): void {
    this.selectedStock = quote
    this.kLineData = this.stockService.generateDemoKLine(quote.current, 60)
    this.showDetail = true
  }

  build() {
    Column() {
      // 标题
      Row() {
        Text('股票行情')
          .fontSize(ThemeFont.xl)
          .fontWeight(ThemeFont.weightBold)
          .fontColor(this.themeManager.isDark ? '#E0E0E0' : '#181818')
        Blank()
        Text('数据来源: 新浪财经')
          .fontSize(ThemeFont.xs)
          .fontColor('#999')
      }
      .width('100%')
      .padding(ThemeSpacing.lg)

      if (this.showDetail && this.selectedStock !== null) {
        // K 线详情
        this.buildStockDetail()
      } else {
        // 自选股列表
        this.buildWatchlist()
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor(this.themeManager.isDark ? '#121212' : '#F5F5F5')
  }

  @Builder
  buildWatchlist() {
    Refresh({ refreshing: $$this.isRefreshing }) {
      if (this.isLoading && this.quotes.length === 0) {
        Column() {
          LoadingProgress().width(36).height(36)
          Text('加载行情数据...')
            .fontSize(ThemeFont.sm)
            .fontColor('#999')
            .margin({ top: ThemeSpacing.md })
        }
        .width('100%')
        .height('100%')
        .justifyContent(FlexAlign.Center)
      } else {
        List({ space: 2 }) {
          // 表头
          ListItem() {
            Row() {
              Text('名称/代码')
                .fontSize(ThemeFont.xs)
                .fontColor('#999')
                .layoutWeight(1)
              Text('最新价')
                .fontSize(ThemeFont.xs)
                .fontColor('#999')
                .width(70)
                .textAlign(TextAlign.End)
              Text('涨跌幅')
                .fontSize(ThemeFont.xs)
                .fontColor('#999')
                .width(80)
                .textAlign(TextAlign.End)
            }
            .width('100%')
            .padding({ left: ThemeSpacing.lg, right: ThemeSpacing.lg, top: ThemeSpacing.md, bottom: ThemeSpacing.sm })
          }

          // 股票列表
          ForEach(this.quotes, (quote: StockQuote) => {
            ListItem() {
              Row() {
                // 名称和代码
                Column({ space: 2 }) {
                  Text(quote.name)
                    .fontSize(ThemeFont.md)
                    .fontWeight(ThemeFont.weightMedium)
                    .fontColor(this.themeManager.isDark ? '#E0E0E0' : '#181818')
                  Text(quote.code)
                    .fontSize(ThemeFont.xs)
                    .fontColor('#999')
                }
                .alignItems(HorizontalAlign.Start)
                .layoutWeight(1)

                // 最新价
                Text(quote.formatPrice())
                  .fontSize(ThemeFont.lg)
                  .fontWeight(ThemeFont.weightBold)
                  .fontColor(quote.isUp() ? '#FA2A2D' : '#00B578')
                  .width(70)
                  .textAlign(TextAlign.End)

                // 涨跌幅
                Text(quote.formatChange())
                  .fontSize(ThemeFont.md)
                  .fontWeight(ThemeFont.weightMedium)
                  .fontColor('#FFFFFF')
                  .backgroundColor(quote.isUp() ? '#FA2A2D' : '#00B578')
                  .borderRadius(4)
                  .padding({ left: 8, right: 8, top: 4, bottom: 4 })
                  .width(80)
                  .textAlign(TextAlign.Center)
                  .margin({ left: ThemeSpacing.sm })
              }
              .width('100%')
              .padding({ left: ThemeSpacing.lg, right: ThemeSpacing.lg, top: ThemeSpacing.md, bottom: ThemeSpacing.md })
              .backgroundColor(this.themeManager.isDark ? '#1E1E1E' : '#FFFFFF')
              .onClick(() => {
                this.selectStock(quote)
              })
            }
          })

          // 提示
          ListItem() {
            Text('点击股票查看 K 线图 · 下拉刷新行情')
              .fontSize(ThemeFont.xs)
              .fontColor('#999')
              .width('100%')
              .textAlign(TextAlign.Center)
              .padding(ThemeSpacing.xl)
          }
        }
        .layoutWeight(1)
        .width('100%')
      }
    }
    .onRefreshing(() => { this.onRefresh() })
    .layoutWeight(1)
    .width('100%')
  }

  @Builder
  buildStockDetail() {
    Column({ space: ThemeSpacing.md }) {
      // 返回按钮 + 股票信息
      Row() {
        Text('< 返回')
          .fontSize(ThemeFont.md)
          .fontColor('#007DFF')
          .onClick(() => {
            this.showDetail = false
          })
        Blank()
        Text(this.selectedStock!.name)
          .fontSize(ThemeFont.lg)
          .fontWeight(ThemeFont.weightBold)
          .fontColor(this.themeManager.isDark ? '#E0E0E0' : '#181818')
        Blank()
      }
      .width('100%')
      .padding(ThemeSpacing.lg)

      // 价格信息
      Row({ space: ThemeSpacing.lg }) {
        Column({ space: 4 }) {
          Text(this.selectedStock!.formatPrice())
            .fontSize(32)
            .fontWeight(ThemeFont.weightBold)
            .fontColor(this.selectedStock!.isUp() ? '#FA2A2D' : '#00B578')
          Text(this.selectedStock!.formatChange())
            .fontSize(ThemeFont.md)
            .fontColor(this.selectedStock!.isUp() ? '#FA2A2D' : '#00B578')
        }

        Blank()

        Column({ space: 4 }) {
          this.buildDetailRow('今开', this.selectedStock!.open.toFixed(2))
          this.buildDetailRow('昨收', this.selectedStock!.close.toFixed(2))
          this.buildDetailRow('最高', this.selectedStock!.high.toFixed(2))
          this.buildDetailRow('最低', this.selectedStock!.low.toFixed(2))
        }
      }
      .width('100%')
      .padding({ left: ThemeSpacing.lg, right: ThemeSpacing.lg })

      // K 线图
      Column({ space: ThemeSpacing.sm }) {
        Text('日K线 · 近60日')
          .fontSize(ThemeFont.sm)
          .fontColor('#999')
          .width('100%')

        CandlestickChart({
          data: this.kLineData,
          chartWidth: 350,
          chartHeight: 280,
          showMA: true
        })
      }
      .width('100%')
      .padding(ThemeSpacing.lg)
      .backgroundColor(this.themeManager.isDark ? '#1E1E1E' : '#FFFFFF')
      .borderRadius(ThemeRadius.md)
      .margin({ left: ThemeSpacing.lg, right: ThemeSpacing.lg })
    }
    .width('100%')
    .layoutWeight(1)
  }

  @Builder
  buildDetailRow(label: string, value: string) {
    Row() {
      Text(label)
        .fontSize(ThemeFont.xs)
        .fontColor('#999')
        .width(40)
      Text(value)
        .fontSize(ThemeFont.sm)
        .fontColor(this.themeManager.isDark ? '#E0E0E0' : '#181818')
    }
  }
}

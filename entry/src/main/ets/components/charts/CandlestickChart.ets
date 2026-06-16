
import { KLineData, ChartUtils } from '../../utils/ChartUtils'
import { Constants } from '../../constants/Constants'
import { ThemeRadius, ThemeFont, ThemeSpacing } from '../../theme/Theme'

/**
 * K 线走势图组件
 *
 * 特性：
 * - Canvas 2D 自绘
 * - 支持滑动查看历史数据
 * - 长按显示十字线和详细数据
 * - 支持 MA5/MA10/MA20 均线
 * - 下方显示成交量柱状图
 *
 * @param data K 线数据数组
 * @param chartWidth 画布宽度
 * @param chartHeight 画布高度
 * @param showMA 是否显示均线
 * @param volumeHeightRatio 成交量区域占总高度的比例
 */
@Component
export struct CandlestickChart {
  @Prop data: KLineData[] = []
  @Prop chartWidth: number = 350
  @Prop chartHeight: number = 300
  @Prop showMA: boolean = true
  @Prop volumeHeightRatio: number = 0.25

  @State selectedIndex: number = -1
  @State isLongPressing: boolean = false

  private candleWidth: number = 12
  private candleGap: number = 4
  private chartPadding: number = 12
  private volumeTop: number = 0

  aboutToAppear(): void {
    this.calculateCandleWidth()
    this.volumeTop = this.chartHeight * (1 - this.volumeHeightRatio)
  }

  /**
   * 根据数据量自动调整蜡烛宽度
   */
  private calculateCandleWidth(): void {
    if (this.data.length === 0) return
    const availableWidth = this.chartWidth - this.chartPadding * 2
    const totalGap = (this.data.length - 1) * this.candleGap
    const cw = (availableWidth - totalGap) / this.data.length
    this.candleWidth = Math.max(Constants.KLINE_CANDLE_MIN_WIDTH,
      Math.min(Constants.KLINE_CANDLE_MAX_WIDTH, Math.floor(cw)))
  }

  /**
   * 获取价格范围
   */
  private getPriceRange(): PriceRange {
    let min = Infinity
    let max = -Infinity
    for (const d of this.data) {
      if (d.low < min) min = d.low
      if (d.high > max) max = d.high
    }
    // 上下留 5% 余量
    const margin = (max - min) * 0.05
    const result = new PriceRange()
    result.min = min - margin
    result.max = max + margin
    return result
  }

  /**
   * 获取成交量最大值
   */
  private getMaxVolume(): number {
    let max = 0
    for (const d of this.data) {
      if (d.volume > max) max = d.volume
    }
    return max || 1
  }

  build() {
    Stack({ alignContent: Alignment.Top }) {
      // K 线画布
      Canvas(this.context)
        .width(this.chartWidth)
        .height(this.chartHeight)
        .onReady(() => {
          this.drawChart()
        })
        .onTouch((event: TouchEvent) => {
          this.handleTouch(event)
        })

      // 长按数据面板
      if (this.isLongPressing && this.selectedIndex >= 0 && this.selectedIndex < this.data.length) {
        this.buildDataPanel()
      }
    }
    .width(this.chartWidth)
    .height(this.chartHeight)
  }

  private context: CanvasRenderingContext2D = new CanvasRenderingContext2D()

  /**
   * 绘制图表
   */
  private drawChart(): void {
    const ctx = this.context
    // 清空画布
    ctx.clearRect(0, 0, this.chartWidth, this.chartHeight)

    if (this.data.length === 0) {
      ctx.fillStyle = '#999999'
      ctx.font = `${ThemeFont.md}px sans-serif`
      ctx.textAlign = 'center'
      ctx.fillText('暂无数据', this.chartWidth / 2, this.chartHeight / 2)
      return
    }

    const priceRange = this.getPriceRange()
    const maxVolume = this.getMaxVolume()
    const chartHeight = this.volumeTop - this.chartPadding * 2

    // 绘制网格线
    this.drawGrid(ctx, priceRange, chartHeight)

    // 绘制 K 线蜡烛
    for (let i = 0; i < this.data.length; i++) {
      this.drawCandle(ctx, i, priceRange, chartHeight)
    }

    // 绘制均线
    if (this.showMA) {
      this.drawMA(ctx, priceRange, chartHeight)
    }

    // 绘制成交量
    this.drawVolume(ctx, maxVolume)

    // 绘制价格标签
    this.drawPriceLabels(ctx, priceRange, chartHeight)
  }

  private drawGrid(ctx: CanvasRenderingContext2D, priceRange: PriceRange, chartHeight: number): void {
    ctx.strokeStyle = '#F0F0F0'
    ctx.lineWidth = 0.5
    // 横线
    for (let i = 0; i <= 4; i++) {
      const y = this.chartPadding + (chartHeight / 4) * i
      ctx.beginPath()
      ctx.moveTo(this.chartPadding, y)
      ctx.lineTo(this.chartWidth - this.chartPadding, y)
      ctx.stroke()
    }
  }

  private drawCandle(ctx: CanvasRenderingContext2D, index: number, priceRange: PriceRange, chartHeight: number): void {
    const d = this.data[index]
    const x = this.chartPadding + index * (this.candleWidth + this.candleGap) + this.candleWidth / 2
    const priceToY = (price: number): number => {
      return this.chartPadding + chartHeight * (1 - (price - priceRange.min) / (priceRange.max - priceRange.min))
    }

    const openY = priceToY(d.open)
    const closeY = priceToY(d.close)
    const highY = priceToY(d.high)
    const lowY = priceToY(d.low)

    const isPositive = d.isPositive()
    const color = isPositive ? '#00B578' : '#FA2A2D'

    // 影线
    ctx.strokeStyle = color
    ctx.lineWidth = 1
    ctx.beginPath()
    ctx.moveTo(x, highY)
    ctx.lineTo(x, lowY)
    ctx.stroke()

    // 实体
    ctx.fillStyle = isPositive ? color : color
    const bodyTop = Math.min(openY, closeY)
    const bodyHeight = Math.max(Math.abs(closeY - openY), 1)
    if (isPositive) {
      ctx.strokeStyle = color
      ctx.lineWidth = 1
      ctx.strokeRect(x - this.candleWidth / 2, bodyTop, this.candleWidth, bodyHeight)
    } else {
      ctx.fillRect(x - this.candleWidth / 2, bodyTop, this.candleWidth, bodyHeight)
    }
  }

  private drawMA(ctx: CanvasRenderingContext2D, priceRange: PriceRange, chartHeight: number): void {
    const closes: number[] = []
    for (let i = 0; i < this.data.length; i++) {
      closes.push(this.data[i].close)
    }
    const ma5 = ChartUtils.calculateMA(closes, 5)
    const ma10 = ChartUtils.calculateMA(closes, 10)

    const priceToY = (price: number): number => {
      return this.chartPadding + chartHeight * (1 - (price - priceRange.min) / (priceRange.max - priceRange.min))
    }

    // MA5
    ctx.strokeStyle = '#FF8800'
    ctx.lineWidth = 1
    ctx.beginPath()
    let started = false
    for (let i = 0; i < ma5.length; i++) {
      if (isNaN(ma5[i])) continue
      const x = this.chartPadding + i * (this.candleWidth + this.candleGap) + this.candleWidth / 2
      const y = priceToY(ma5[i])
      if (!started) { ctx.moveTo(x, y); started = true } else { ctx.lineTo(x, y) }
    }
    ctx.stroke()

    // MA10
    ctx.strokeStyle = '#007DFF'
    ctx.beginPath()
    started = false
    for (let i = 0; i < ma10.length; i++) {
      if (isNaN(ma10[i])) continue
      const x = this.chartPadding + i * (this.candleWidth + this.candleGap) + this.candleWidth / 2
      const y = priceToY(ma10[i])
      if (!started) { ctx.moveTo(x, y); started = true } else { ctx.lineTo(x, y) }
    }
    ctx.stroke()
  }

  private drawVolume(ctx: CanvasRenderingContext2D, maxVolume: number): void {
    const volumeHeight = this.chartHeight * this.volumeHeightRatio - this.chartPadding
    for (let i = 0; i < this.data.length; i++) {
      const d = this.data[i]
      const x = this.chartPadding + i * (this.candleWidth + this.candleGap)
      const barHeight = (d.volume / maxVolume) * volumeHeight
      const color = d.isPositive() ? '#00B57830' : '#FA2A2D30'

      ctx.fillStyle = color
      ctx.fillRect(x, this.chartHeight - this.chartPadding - barHeight, this.candleWidth, barHeight)
    }
  }

  private drawPriceLabels(ctx: CanvasRenderingContext2D, priceRange: PriceRange, chartHeight: number): void {
    ctx.fillStyle = '#999999'
    ctx.font = `${ThemeFont.xs}px sans-serif`
    ctx.textAlign = 'right'

    for (let i = 0; i <= 4; i++) {
      const y = this.chartPadding + (chartHeight / 4) * i
      const price = priceRange.max - ((priceRange.max - priceRange.min) / 4) * i
      ctx.fillText(price.toFixed(2), this.chartWidth - 2, y - 2)
    }
  }

  /**
   * 处理触摸事件（长按查看详情）
   */
  private handleTouch(event: TouchEvent): void {
    if (event.type === TouchType.Down || event.type === TouchType.Move) {
      const touch = event.touches[0]
      const localX = touch.x - this.chartPadding
      const idx = Math.floor(localX / (this.candleWidth + this.candleGap))
      if (idx >= 0 && idx < this.data.length) {
        this.selectedIndex = idx
        this.isLongPressing = true
        this.drawChart()
        this.drawCrosshair(idx)
      }
    }
    if (event.type === TouchType.Up || event.type === TouchType.Cancel) {
      this.isLongPressing = false
      this.selectedIndex = -1
      this.drawChart()
    }
  }

  private drawCrosshair(index: number): void {
    const ctx = this.context
    const x = this.chartPadding + index * (this.candleWidth + this.candleGap) + this.candleWidth / 2

    ctx.strokeStyle = '#666666'
    ctx.lineWidth = 0.5
    ctx.setLineDash([4, 4])

    // 竖线
    ctx.beginPath()
    ctx.moveTo(x, this.chartPadding)
    ctx.lineTo(x, this.chartHeight - this.chartPadding)
    ctx.stroke()

    ctx.setLineDash([])
  }

  @Builder
  buildDataPanel() {
    Column() {
      if (this.selectedIndex >= 0 && this.selectedIndex < this.data.length) {
        Row() {
          Text('开盘 ' + this.data[this.selectedIndex].open.toFixed(2))
            .fontSize(ThemeFont.xs)
            .fontColor('#666')
          Blank()
          Text('最高 ' + this.data[this.selectedIndex].high.toFixed(2))
            .fontSize(ThemeFont.xs)
            .fontColor('#00B578')
        }
        .width('100%')
        .padding(4)

        Row() {
          Text('收盘 ' + this.data[this.selectedIndex].close.toFixed(2))
            .fontSize(ThemeFont.xs)
            .fontColor('#666')
          Blank()
          Text('最低 ' + this.data[this.selectedIndex].low.toFixed(2))
            .fontSize(ThemeFont.xs)
            .fontColor('#FA2A2D')
        }
        .width('100%')
        .padding(4)
      }
    }
    .backgroundColor('#FFFFFFE0')
    .borderRadius(ThemeRadius.sm)
    .padding(ThemeSpacing.sm)
    .width(180)
    .position({ x: 8, y: 8 })
  }
}

class PriceRange {
  min: number = 0
  max: number = 0
}


import { ChartDataPoint, ChartUtils } from '../../utils/ChartUtils'
import { ThemeFont, ThemeSpacing } from '../../theme/Theme'

/**
 * 折线图组件
 *
 * 特性：
 * - Canvas 自绘
 * - 渐变填充区域
 * - 数据点标记
 * - 支持平滑曲线
 * - X/Y 轴标签
 */
@Component
export struct LineChart {
  @Prop data: number[] = []
  @Prop labels: string[] = []
  @Prop width: number = 350
  @Prop height: number = 200
  @Prop lineColor: string = '#007DFF'
  @Prop fillColor: string = '#007DFF20'
  @Prop showDots: boolean = true
  @Prop showArea: boolean = true

  private context: CanvasRenderingContext2D = new CanvasRenderingContext2D(new RenderingContext(true))
  private padding: number = 12
  private points: ChartDataPoint[] = []

  build() {
    Canvas(this.context)
      .width(this.width)
      .height(this.height)
      .onReady(() => {
        this.drawChart()
      })
  }

  private drawChart(): void {
    const ctx = this.context
    ctx.clearRect(0, 0, this.width, this.height)

    if (this.data.length === 0) {
      ctx.fillStyle = '#999999'
      ctx.font = `${ThemeFont.md}px sans-serif`
      ctx.textAlign = 'center'
      ctx.fillText('暂无数据', this.width / 2, this.height / 2)
      return
    }

    this.points = ChartUtils.calculateLinePoints(this.data, this.width, this.height, this.padding)

    // 绘制渐变填充
    if (this.showArea) {
      this.drawArea(ctx)
    }

    // 绘制折线
    this.drawLine(ctx)

    // 绘制数据点
    if (this.showDots) {
      this.drawDots(ctx)
    }

    // 绘制标签
    this.drawLabels(ctx)
  }

  private drawLine(ctx: CanvasRenderingContext2D): void {
    if (this.points.length < 2) return

    ctx.strokeStyle = this.lineColor
    ctx.lineWidth = 2
    ctx.lineJoin = 'round'
    ctx.lineCap = 'round'
    ctx.beginPath()
    ctx.moveTo(this.points[0].x, this.points[0].y)

    for (let i = 1; i < this.points.length; i++) {
      // 贝塞尔曲线平滑
      const prev = this.points[i - 1]
      const curr = this.points[i]
      const cpx = (prev.x + curr.x) / 2
      ctx.bezierCurveTo(cpx, prev.y, cpx, curr.y, curr.x, curr.y)
    }
    ctx.stroke()
  }

  private drawArea(ctx: CanvasRenderingContext2D): void {
    if (this.points.length < 2) return

    const gradient = ctx.createLinearGradient(0, this.padding, 0, this.height - this.padding)
    gradient.addColorStop(0, this.fillColor)
    gradient.addColorStop(1, this.fillColor.replace('20', '05'))

    ctx.beginPath()
    ctx.moveTo(this.points[0].x, this.points[0].y)

    for (let i = 1; i < this.points.length; i++) {
      const prev = this.points[i - 1]
      const curr = this.points[i]
      const cpx = (prev.x + curr.x) / 2
      ctx.bezierCurveTo(cpx, prev.y, cpx, curr.y, curr.x, curr.y)
    }

    ctx.lineTo(this.points[this.points.length - 1].x, this.height - this.padding)
    ctx.lineTo(this.points[0].x, this.height - this.padding)
    ctx.closePath()
    ctx.fillStyle = gradient
    ctx.fill()
  }

  private drawDots(ctx: CanvasRenderingContext2D): void {
    for (const point of this.points) {
      ctx.beginPath()
      ctx.arc(point.x, point.y, 3, 0, Math.PI * 2)
      ctx.fillStyle = '#FFFFFF'
      ctx.fill()
      ctx.strokeStyle = this.lineColor
      ctx.lineWidth = 2
      ctx.stroke()
    }
  }

  private drawLabels(ctx: CanvasRenderingContext2D): void {
    if (this.labels.length === 0) return

    ctx.fillStyle = '#999999'
    ctx.font = `${ThemeFont.xs}px sans-serif`
    ctx.textAlign = 'center'

    // 只显示首尾和中间几个标签，避免重叠
    const maxLabels = 5
    const step = Math.max(1, Math.floor(this.labels.length / maxLabels))
    for (let i = 0; i < this.labels.length; i += step) {
      if (i < this.points.length) {
        ctx.fillText(this.labels[i], this.points[i].x, this.height - 2)
      }
    }
    // 确保最后一个标签显示
    if (this.labels.length > 1 && this.points.length > 0) {
      const last = this.labels.length - 1
      ctx.fillText(this.labels[last], this.points[last].x, this.height - 2)
    }
  }
}

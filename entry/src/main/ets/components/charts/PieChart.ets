
import { PieSlice } from '../../utils/ChartUtils'
import { ThemeFont, ThemeRadius, ThemeSpacing } from '../../theme/Theme'

/**
 * 饼图组件
 *
 * 特性：
 * - Canvas 自绘环形图
 * - 支持动画展开
 * - 中心显示总额
 * - 点击扇区高亮
 * - 底部图例
 */
@Component
export struct PieChart {
  @Prop slices: PieSlice[] = []
  @Prop chartSize: number = 200
  @Prop innerRadiusRatio: number = 0.55
  @Prop totalLabel: string = '总额'
  @Prop totalAmount: string = '¥0'

  @State selectedIndex: number = -1
  @State animationProgress: number = 0

  private context: CanvasRenderingContext2D = new CanvasRenderingContext2D()
  private center: number = 0
  private radius: number = 0
  private innerRadius: number = 0

  aboutToAppear(): void {
    this.center = this.chartSize / 2
    this.radius = this.chartSize / 2 - 8
    this.innerRadius = this.radius * this.innerRadiusRatio
    // 启动动画
    this.startAnimation()
  }

  private startAnimation(): void {
    // 使用定时器模拟动画进度
    let progress = 0
    const timer = setInterval(() => {
      progress += 0.05
      if (progress >= 1) {
        progress = 1
        clearInterval(timer)
      }
      this.animationProgress = progress
      this.drawChart()
    }, 16)
  }

  build() {
    Column({ space: ThemeSpacing.md }) {
      // 饼图
      Canvas(this.context)
        .width(this.chartSize)
        .height(this.chartSize)
        .onReady(() => {
          this.drawChart()
        })
        .onTouch((event: TouchEvent) => {
          if (event.type === TouchType.Down) {
            this.handleTap(event)
          }
        })

      // 图例
      if (this.slices.length > 0) {
        Flex({ wrap: FlexWrap.Wrap, justifyContent: FlexAlign.Center }) {
          ForEach(this.slices, (slice: PieSlice, index: number) => {
            Row({ space: 4 }) {
              Circle({ width: 8, height: 8 })
                .fill(slice.color)
              Text(slice.label)
                .fontSize(ThemeFont.xs)
                .fontColor('#666')
              Text((slice.percent * 100).toFixed(1) + '%')
                .fontSize(ThemeFont.xs)
                .fontColor('#999')
            }
            .margin({ right: ThemeSpacing.md, bottom: ThemeSpacing.xs })
          })
        }
        .width('100%')
        .padding({ left: ThemeSpacing.md, right: ThemeSpacing.md })
      }
    }
    .alignItems(HorizontalAlign.Center)
  }

  private drawChart(): void {
    const ctx = this.context
    ctx.clearRect(0, 0, this.chartSize, this.chartSize)

    if (this.slices.length === 0) {
      ctx.fillStyle = '#999999'
      ctx.font = `${ThemeFont.md}px sans-serif`
      ctx.textAlign = 'center'
      ctx.fillText('暂无数据', this.center, this.center)
      return
    }

    let startAngle = -Math.PI / 2
    const totalAngle = Math.PI * 2 * this.animationProgress

    for (let i = 0; i < this.slices.length; i++) {
      const slice = this.slices[i]
      const sweepAngle = slice.percent * totalAngle
      const isSelected = i === this.selectedIndex
      const actualRadius = isSelected ? this.radius + 4 : this.radius

      // 绘制扇区
      ctx.beginPath()
      ctx.arc(this.center, this.center, actualRadius, startAngle, startAngle + sweepAngle)
      ctx.arc(this.center, this.center, this.innerRadius, startAngle + sweepAngle, startAngle, true)
      ctx.closePath()
      ctx.fillStyle = slice.color
      ctx.fill()

      startAngle += sweepAngle
    }

    // 中心文字
    ctx.fillStyle = '#181818'
    ctx.font = `bold ${ThemeFont.xxl}px sans-serif`
    ctx.textAlign = 'center'
    ctx.textBaseline = 'middle'
    ctx.fillText(this.totalLabel, this.center, this.center - 16)

    ctx.fillStyle = '#333333'
    ctx.font = `bold ${ThemeFont.xl}px sans-serif`
    ctx.fillText(this.totalAmount, this.center, this.center + 16)
  }

  private handleTap(event: TouchEvent): void {
    const touch = event.touches[0]
    const dx = touch.x - this.center
    const dy = touch.y - this.center
    const distance = Math.sqrt(dx * dx + dy * dy)

    // 在环形区域内
    if (distance < this.innerRadius || distance > this.radius) {
      this.selectedIndex = -1
      this.drawChart()
      return
    }

    // 计算角度
    let angle = Math.atan2(dy, dx)
    if (angle < -Math.PI / 2) angle += Math.PI * 2
    angle += Math.PI / 2
    if (angle >= Math.PI * 2) angle -= Math.PI * 2

    // 查找对应的扇区
    let cumulative = 0
    for (let i = 0; i < this.slices.length; i++) {
      cumulative += this.slices[i].percent * Math.PI * 2
      if (angle <= cumulative) {
        this.selectedIndex = this.selectedIndex === i ? -1 : i
        this.drawChart()
        return
      }
    }
  }
}

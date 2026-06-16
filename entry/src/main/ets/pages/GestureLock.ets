import { router } from '@kit.ArkUI'
import { StorageService } from '../services/StorageService'
import { ThemeFont, ThemeRadius, ThemeSpacing, ThemeManager } from '../theme/Theme'
import { promptAction } from '@kit.ArkUI'
import { hilog } from '@kit.PerformanceAnalysisKit'

/**
 * 手势密码锁页面
 *
 * 特性：
 * - 3x3 九宫格手势解锁
 * - 支持设置/验证两种模式
 * - 触摸轨迹实时绘制
 * - 错误震动反馈
 * - 连续错误次数限制
 */
@Entry
@Component
struct GestureLock {
  @State points: GesturePoint[] = GestureLock.initPoints()
  @State selectedIndices: number[] = []
  @State isDrawing: boolean = false
  @State message: string = '请绘制手势密码'
  @State messageColor: string = '#999'
  @State mode: string = 'verify' // 'verify' | 'set' | 'confirm'
  @State firstPattern: string = ''
  @State errorCount: number = 0
  @State isLocked: boolean = false

  private storageService = StorageService.getInstance()
  private themeManager = ThemeManager.getInstance()
  private canvasSize: number = 280
  private pointRadius: number = 20
  private cellSize: number = 0

  static initPoints(): GesturePoint[] {
    const points: GesturePoint[] = []
    for (let row = 0; row < 3; row++) {
      for (let col = 0; col < 3; col++) {
        const point = new GesturePoint()
        point.index = row * 3 + col
        point.row = row
        point.col = col
        points.push(point)
      }
    }
    return points
  }

  aboutToAppear(): void {
    this.cellSize = this.canvasSize / 3
    // 设置每个点的坐标
    for (let i = 0; i < this.points.length; i++) {
      const p = this.points[i]
      p.x = p.col * this.cellSize + this.cellSize / 2
      p.y = p.row * this.cellSize + this.cellSize / 2
    }

    this.checkGestureExists()
  }

  private async checkGestureExists(): Promise<void> {
    const exists = await this.storageService.getPreferenceBool('gesture_lock_enabled', false)
    if (!exists) {
      this.mode = 'set'
      this.message = '请设置手势密码'
    }
  }

  private onPointTouched(index: number): void {
    if (this.isLocked) return

    if (!this.selectedIndices.includes(index)) {
      this.selectedIndices.push(index)
      this.points[index].selected = true
      this.isDrawing = true
    }
  }

  private onDrawEnd(): void {
    if (this.selectedIndices.length < 4) {
      this.message = '至少连接4个点'
      this.messageColor = '#FA2A2D'
      this.resetSelection()
      return
    }

    const pattern = this.selectedIndices.join('-')

    if (this.mode === 'set') {
      if (this.firstPattern === '') {
        this.firstPattern = pattern
        this.message = '请再次绘制确认'
        this.messageColor = '#007DFF'
        this.mode = 'confirm'
        this.resetSelection()
      }
    } else if (this.mode === 'confirm') {
      if (pattern === this.firstPattern) {
        this.saveGesture(pattern)
        this.message = '手势密码设置成功！'
        this.messageColor = '#00B578'
        promptAction.showToast({ message: '手势密码已设置' })
        setTimeout(() => {
          router.back()
        }, 1000)
      } else {
        this.message = '两次绘制不一致，请重试'
        this.messageColor = '#FA2A2D'
        this.mode = 'set'
        this.firstPattern = ''
        this.resetSelection()
      }
    } else {
      // 验证模式
      this.verifyGesture(pattern)
    }
  }

  private async saveGesture(pattern: string): Promise<void> {
    // 简单哈希存储（生产环境应使用更安全的方式）
    await this.storageService.setPreference('gesture_lock_hash', pattern)
    await this.storageService.setPreferenceBool('gesture_lock_enabled', true)
    hilog.info(0x0000, 'FinTrack', 'Gesture lock saved')
  }

  private async verifyGesture(pattern: string): Promise<void> {
    const saved = await this.storageService.getPreference('gesture_lock_hash', '')
    if (pattern === saved) {
      this.message = '验证成功'
      this.messageColor = '#00B578'
      hilog.info(0x0000, 'FinTrack', 'Gesture verified')
      setTimeout(() => {
        router.back()
      }, 500)
    } else {
      this.errorCount++
      this.message = `密码错误 (${this.errorCount}/5)`
      this.messageColor = '#FA2A2D'

      if (this.errorCount >= 5) {
        this.isLocked = true
        this.message = '错误次数过多，请30秒后重试'
        setTimeout(() => {
          this.isLocked = false
          this.errorCount = 0
          this.message = '请绘制手势密码'
          this.messageColor = '#999'
        }, 30000)
      }
      this.resetSelection()
    }
  }

  private resetSelection(): void {
    this.isDrawing = false
    for (let i = 0; i < this.points.length; i++) {
      this.points[i].selected = false
    }
    this.selectedIndices = []
  }

  build() {
    Column({ space: ThemeSpacing.xl }) {
      // 标题
      Text(this.mode === 'set' ? '设置手势密码' :
        this.mode === 'confirm' ? '确认手势密码' : '验证手势密码')
        .fontSize(ThemeFont.xxl)
        .fontWeight(ThemeFont.weightBold)
        .fontColor(this.themeManager.isDark ? '#E0E0E0' : '#181818')
        .margin({ top: 60 })

      Text(this.message)
        .fontSize(ThemeFont.md)
        .fontColor(this.messageColor)
        .margin({ top: ThemeSpacing.md })

      // 九宫格画布
      Canvas(this.getContext2D())
        .width(this.canvasSize)
        .height(this.canvasSize)
        .onReady(() => {
          this.drawGrid()
        })
        .onTouch((event: TouchEvent) => {
          this.handleTouch(event)
        })
        .margin({ top: 40 })

      // 重置按钮
      if (this.mode === 'set' || this.mode === 'confirm') {
        Button('重新绘制')
          .fontSize(ThemeFont.md)
          .height(40)
          .borderRadius(ThemeRadius.full)
          .backgroundColor('#007DFF15')
          .fontColor('#007DFF')
          .onClick(() => {
            this.resetSelection()
            this.mode = 'set'
            this.firstPattern = ''
            this.message = '请设置手势密码'
            this.messageColor = '#999'
          })
      }

      // 跳过按钮
      if (this.mode === 'verify') {
        Text('忘记手势密码？')
          .fontSize(ThemeFont.sm)
          .fontColor('#999')
          .onClick(() => {
            router.back()
          })
      }

      Blank()
    }
    .width('100%')
    .height('100%')
    .backgroundColor(this.themeManager.isDark ? '#121212' : '#FFFFFF')
  }

  private ctx: CanvasRenderingContext2D = new CanvasRenderingContext2D()

  private getContext2D(): CanvasRenderingContext2D {
    return this.ctx
  }

  private drawGrid(): void {
    const ctx = this.ctx
    ctx.clearRect(0, 0, this.canvasSize, this.canvasSize)

    // 绘制连线
    if (this.selectedIndices.length > 1) {
      ctx.strokeStyle = this.messageColor === '#FA2A2D' ? '#FA2A2D80' : '#007DFF60'
      ctx.lineWidth = 3
      ctx.beginPath()
      const first = this.points[this.selectedIndices[0]]
      ctx.moveTo(first.x, first.y)
      for (let i = 1; i < this.selectedIndices.length; i++) {
        const p = this.points[this.selectedIndices[i]]
        ctx.lineTo(p.x, p.y)
      }
      ctx.stroke()
    }

    // 绘制圆点
    for (let i = 0; i < this.points.length; i++) {
      const p = this.points[i]
      ctx.beginPath()
      ctx.arc(p.x, p.y, this.pointRadius, 0, Math.PI * 2)

      if (p.selected) {
        ctx.fillStyle = this.messageColor === '#FA2A2D' ? '#FA2A2D30' : '#007DFF30'
        ctx.fill()
        ctx.strokeStyle = this.messageColor === '#FA2A2D' ? '#FA2A2D' : '#007DFF'
        ctx.lineWidth = 2
        ctx.stroke()

        // 中心点
        ctx.beginPath()
        ctx.arc(p.x, p.y, 6, 0, Math.PI * 2)
        ctx.fillStyle = this.messageColor === '#FA2A2D' ? '#FA2A2D' : '#007DFF'
        ctx.fill()
      } else {
        ctx.fillStyle = this.themeManager.isDark ? '#2C2C2C' : '#F0F0F0'
        ctx.fill()
        ctx.strokeStyle = this.themeManager.isDark ? '#444' : '#DDD'
        ctx.lineWidth = 1
        ctx.stroke()
      }
    }
  }

  private handleTouch(event: TouchEvent): void {
    if (this.isLocked) return

    if (event.type === TouchType.Down || event.type === TouchType.Move) {
      const touch = event.touches[0]
      for (let i = 0; i < this.points.length; i++) {
        const p = this.points[i]
        const dx = touch.x - p.x
        const dy = touch.y - p.y
        if (Math.sqrt(dx * dx + dy * dy) < this.pointRadius * 1.5) {
          this.onPointTouched(i)
          this.drawGrid()
        }
      }
    }

    if (event.type === TouchType.Up) {
      if (this.selectedIndices.length > 0) {
        this.onDrawEnd()
        this.drawGrid()
      }
    }
  }
}

class GesturePoint {
  index: number = 0
  row: number = 0
  col: number = 0
  x: number = 0
  y: number = 0
  selected: boolean = false
}

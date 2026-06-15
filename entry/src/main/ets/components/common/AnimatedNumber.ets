
import { CurrencyUtils } from '../../utils/CurrencyUtils'
import { ThemeFont } from '../../theme/Theme'

/**
 * 数字滚动动画组件
 * 数值变化时带平滑过渡效果
 */
@Component
export struct AnimatedNumber {
  @Prop value: number = 0
  @Prop currency: string = 'CNY'
  @Prop fontSize: number = ThemeFont.xl
  @Prop fontWeight: number = ThemeFont.weightBold
  @Prop fontColor: string = '#181818'
  @Prop showSign: boolean = false
  @Prop prefix: string = ''
  @Prop suffix: string = ''

  @State displayValue: number = 0
  @State animating: boolean = false

  private stepCount: number = 30
  private animTimer: number = -1

  aboutToAppear(): void {
    this.displayValue = this.value
  }

  onPropertyChanged(name: string): void {
    if (name === 'value' && this.displayValue !== this.value) {
      this.animateTo(this.value)
    }
  }

  private animateTo(target: number): void {
    if (this.animTimer >= 0) {
      clearInterval(this.animTimer)
    }

    const startValue = this.displayValue
    const diff = target - startValue
    let step = 0
    this.animating = true

    this.animTimer = setInterval(() => {
      step++
      const progress = this.easeOutCubic(step / this.stepCount)
      this.displayValue = startValue + diff * progress

      if (step >= this.stepCount) {
        this.displayValue = target
        this.animating = false
        clearInterval(this.animTimer)
        this.animTimer = -1
      }
    }, 16)
  }

  private easeOutCubic(t: number): number {
    return 1 - Math.pow(1 - t, 3)
  }

  build() {
    Text(this.prefix + CurrencyUtils.format(this.displayValue, this.currency, this.showSign) + this.suffix)
      .fontSize(this.fontSize)
      .fontWeight(this.fontWeight)
      .fontColor(this.fontColor)
  }
}

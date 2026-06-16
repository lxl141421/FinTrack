import { ThemeRadius, ThemeSpacing, ThemeManager } from '../../theme/Theme'

/**
 * 骨架屏组件 - 加载占位动画
 */
@Component
export struct SkeletonLine {
  @Prop widthPercent: number = 100
  @Prop lineHeight: number = 16
  @Prop lineBorderRadius: number = 4
  @Prop isCircle: boolean = false

  @State animating: boolean = false

  private themeManager = ThemeManager.getInstance()

  aboutToAppear(): void {
    this.animating = true
  }

  build() {
    Row() {}
      .width(this.isCircle ? this.lineHeight : this.widthPercent + '%')
      .height(this.lineHeight)
      .borderRadius(this.isCircle ? this.lineHeight / 2 : this.lineBorderRadius)
      .backgroundColor(this.themeManager.isDark ? '#2C2C2C' : '#E8E8E8')
      .opacity(this.animating ? 0.6 : 1)
      .animation({
        duration: 1200,
        iterations: -1,
        curve: Curve.EaseInOut
      })
      .onAppear(() => {
        this.animating = false
      })
  }
}

/**
 * 交易卡片骨架屏
 */
@Component
export struct TransactionSkeleton {
  private themeManager = ThemeManager.getInstance()

  build() {
    Row() {
      SkeletonLine({ widthPercent: 44, lineHeight: 44, isCircle: true })
      Column({ space: 6 }) {
        SkeletonLine({ widthPercent: 40, lineHeight: 14 })
        SkeletonLine({ widthPercent: 70, lineHeight: 10 })
      }
      .layoutWeight(1)
      .margin({ left: ThemeSpacing.md })
      SkeletonLine({ widthPercent: 20, lineHeight: 16 })
    }
    .width('100%')
    .padding(ThemeSpacing.lg)
    .backgroundColor(this.themeManager.isDark ? '#1E1E1E' : '#FFFFFF')
    .borderRadius(ThemeRadius.md)
  }
}

/**
 * 摘要卡片骨架屏
 */
@Component
export struct SummarySkeleton {
  private themeManager = ThemeManager.getInstance()

  build() {
    Row({ space: ThemeSpacing.md }) {
      Column({ space: 8 }) {
        SkeletonLine({ widthPercent: 40, lineHeight: 12 })
        SkeletonLine({ widthPercent: 70, lineHeight: 20 })
      }
      .padding(ThemeSpacing.md)
      .backgroundColor(this.themeManager.isDark ? '#1E1E1E' : '#FFFFFF')
      .borderRadius(ThemeRadius.md)
      .layoutWeight(1)

      Column({ space: 8 }) {
        SkeletonLine({ widthPercent: 40, lineHeight: 12 })
        SkeletonLine({ widthPercent: 70, lineHeight: 20 })
      }
      .padding(ThemeSpacing.md)
      .backgroundColor(this.themeManager.isDark ? '#1E1E1E' : '#FFFFFF')
      .borderRadius(ThemeRadius.md)
      .layoutWeight(1)
    }
    .width('100%')
  }
}

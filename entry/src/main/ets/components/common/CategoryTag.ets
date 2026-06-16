
import { ThemeFont, ThemeRadius, ThemeSpacing } from '../../theme/Theme'

/**
 * 分类标签组件
 */
@Component
export struct CategoryTag {
  @Prop label: string = ''
  @Prop icon: string = ''
  @Prop color: string = '#007DFF'
  @Prop selected: boolean = false
  onClickTag: () => void = () => {}

  build() {
    Row({ space: ThemeSpacing.xs }) {
      if (this.icon !== '') {
        Text(this.icon)
          .fontSize(ThemeFont.sm)
      }
      Text(this.label)
        .fontSize(ThemeFont.sm)
        .fontColor(this.selected ? '#FFFFFF' : this.color)
    }
    .padding({
      left: ThemeSpacing.md,
      right: ThemeSpacing.md,
      top: ThemeSpacing.xs,
      bottom: ThemeSpacing.xs
    })
    .backgroundColor(this.selected ? this.color : this.color + '15')
    .borderRadius(ThemeRadius.full)
    .onClick(() => {
      this.onClickTag()
    })
  }
}

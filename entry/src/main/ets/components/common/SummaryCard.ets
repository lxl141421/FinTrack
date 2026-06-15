
import { CurrencyUtils } from '../../utils/CurrencyUtils'
import { ThemeFont, ThemeRadius, ThemeSpacing } from '../../theme/Theme'

/**
 * 数据摘要卡片组件
 * 展示一个指标（标题 + 数值 + 可选副标题）
 */
@Component
export struct SummaryCard {
  @Prop title: string = ''
  @Prop amount: number = 0
  @Prop currency: string = 'CNY'
  @Prop subtitle: string = ''
  @Prop color: string = '#007DFF'
  @Prop icon: string = ''
  @Prop showSign: boolean = false
  @Prop compact: boolean = false

  build() {
    Column() {
      Row({ space: ThemeSpacing.xs }) {
        if (this.icon !== '') {
          Text(this.icon)
            .fontSize(this.compact ? ThemeFont.sm : ThemeFont.md)
        }
        Text(this.title)
          .fontSize(this.compact ? ThemeFont.xs : ThemeFont.sm)
          .fontColor('#666666')
      }

      Text(CurrencyUtils.format(this.amount, this.currency, this.showSign))
        .fontSize(this.compact ? ThemeFont.lg : ThemeFont.xl)
        .fontWeight(ThemeFont.weightBold)
        .fontColor(this.color)
        .margin({ top: this.compact ? 2 : ThemeSpacing.xs })

      if (this.subtitle !== '') {
        Text(this.subtitle)
          .fontSize(ThemeFont.xs)
          .fontColor('#999')
          .margin({ top: 2 })
      }
    }
    .padding(this.compact ? ThemeSpacing.md : ThemeSpacing.lg)
    .backgroundColor('#FFFFFF')
    .borderRadius(ThemeRadius.md)
    .alignItems(HorizontalAlign.Start)
    .shadow({
      radius: 4,
      color: '#00000008',
      offsetX: 0,
      offsetY: 2
    })
    .layoutWeight(1)
  }
}

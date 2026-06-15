
import { Transaction } from '../../models/Transaction'
import { CurrencyUtils } from '../../utils/CurrencyUtils'
import { DateUtils } from '../../utils/DateUtils'
import { Constants } from '../../constants/Constants'
import { ThemeFont, ThemeRadius, ThemeSpacing } from '../../theme/Theme'

/**
 * 交易记录卡片组件
 * 展示单条交易记录，包含分类图标、金额、时间、备注
 */
@Component
export struct TransactionCard {
  @Prop transaction: Transaction = new Transaction()
  @Prop showDate: boolean = true
  onDelete: (id: string) => void = () => {}

  build() {
    Row() {
      // 分类图标
      Text(this.getCategoryEmoji())
        .fontSize(28)
        .width(44)
        .height(44)
        .textAlign(TextAlign.Center)
        .backgroundColor(this.transaction.isIncome() ? '#00B57815' : '#FA2A2D15')
        .borderRadius(ThemeRadius.md)

      // 交易信息
      Column() {
        Row() {
          Text(this.transaction.categoryName)
            .fontSize(ThemeFont.md)
            .fontWeight(ThemeFont.weightMedium)
            .fontColor('#181818')

          if (this.transaction.note !== '') {
            Text(this.transaction.note)
              .fontSize(ThemeFont.sm)
              .fontColor('#999')
              .margin({ left: ThemeSpacing.sm })
              .maxLines(1)
              .textOverflow({ overflow: TextOverflow.Ellipsis })
              .layoutWeight(1)
          } else {
            Blank()
          }
        }
        .width('100%')

        if (this.showDate) {
          Text(DateUtils.getRelativeTime(this.transaction.date))
            .fontSize(ThemeFont.xs)
            .fontColor('#999')
            .margin({ top: 2 })
        }
      }
      .layoutWeight(1)
      .margin({ left: ThemeSpacing.md })
      .alignItems(HorizontalAlign.Start)

      // 金额
      Text(this.getFormattedAmount())
        .fontSize(ThemeFont.lg)
        .fontWeight(ThemeFont.weightBold)
        .fontColor(this.transaction.isIncome() ? '#00B578' : '#FA2A2D')
    }
    .width('100%')
    .padding(ThemeSpacing.lg)
    .backgroundColor('#FFFFFF')
    .borderRadius(ThemeRadius.md)
    .shadow({
      radius: 4,
      color: '#00000008',
      offsetX: 0,
      offsetY: 2
    })
  }

  private getCategoryEmoji(): string {
    const emojiMap: Record<string, string> = {
      '餐饮': '🍜', '交通': '🚌', '购物': '🛍️', '娱乐': '🎮',
      '住房': '🏠', '医疗': '💊', '教育': '📚', '通讯': '📱',
      '工资': '💰', '投资': '📈', '红包': '🧧', '其他': '📌',
      '转账': '🔄'
    }
    return emojiMap[this.transaction.categoryName] ?? '📌'
  }

  private getFormattedAmount(): string {
    const sign = this.transaction.isIncome() ? '+' : '-'
    return sign + CurrencyUtils.format(this.transaction.amount)
  }
}

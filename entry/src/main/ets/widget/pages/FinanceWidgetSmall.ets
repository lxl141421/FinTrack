/**
 * FinTrack 桌面卡片 - 小尺寸 (2x2)
 * 显示本月收入、支出、结余概览
 */
@Component
struct FinanceWidgetSmall {
  @StorageProp('income') income: string = '0.00'
  @StorageProp('expense') expense: string = '0.00'
  @StorageProp('balance') balance: string = '0.00'
  @StorageProp('lastUpdate') lastUpdate: string = '--'

  build() {
    Column() {
      // 标题栏
      Row() {
        Text('💰 FinTrack')
          .fontSize(14)
          .fontWeight(FontWeight.Medium)
          .fontColor('#FFFFFF')
        Blank()
        Text(this.lastUpdate)
          .fontSize(10)
          .fontColor('#FFFFFF80')
      }
      .width('100%')
      .padding({ left: 12, right: 12, top: 8 })

      // 收支数据
      Column({ space: 6 }) {
        Row({ space: 4 }) {
          Text('收入')
            .fontSize(11)
            .fontColor('#FFFFFF90')
          Text(`¥${this.income}`)
            .fontSize(14)
            .fontWeight(FontWeight.Medium)
            .fontColor('#00E676')
        }
        .width('100%')
        .justifyContent(FlexAlign.SpaceBetween)

        Row({ space: 4 }) {
          Text('支出')
            .fontSize(11)
            .fontColor('#FFFFFF90')
          Text(`¥${this.expense}`)
            .fontSize(14)
            .fontWeight(FontWeight.Medium)
            .fontColor('#FF5252')
        }
        .width('100%')
        .justifyContent(FlexAlign.SpaceBetween)

        Divider()
          .color('#FFFFFF20')
          .margin({ top: 2, bottom: 2 })

        Row({ space: 4 }) {
          Text('结余')
            .fontSize(12)
            .fontColor('#FFFFFFCC')
            .fontWeight(FontWeight.Medium)
          Text(`¥${this.balance}`)
            .fontSize(16)
            .fontWeight(FontWeight.Bold)
            .fontColor('#FFFFFF')
        }
        .width('100%')
        .justifyContent(FlexAlign.SpaceBetween)
      }
      .width('100%')
      .padding({ left: 12, right: 12, top: 6, bottom: 10 })
    }
    .width('100%')
    .height('100%')
    .linearGradient({
      direction: GradientDirection.Right,
      colors: [['#1A237E', 0.0], ['#0D47A1', 1.0]]
    })
    .borderRadius(16)
  }
}

export default FinanceWidgetSmall

/**
 * FinTrack 桌面卡片 - 中尺寸 (2x4)
 * 显示本月收支概览 + 最近3笔交易记录
 */
@Component
struct FinanceWidgetMedium {
  @StorageProp('income') income: string = '0.00'
  @StorageProp('expense') expense: string = '0.00'
  @StorageProp('balance') balance: string = '0.00'
  @StorageProp('lastUpdate') lastUpdate: string = '--'
  @StorageLink('recentTxns') recentTxns: string = '[]'

  build() {
    Column() {
      // 标题栏
      Row() {
        Text('💰 FinTrack')
          .fontSize(15)
          .fontWeight(FontWeight.Bold)
          .fontColor('#FFFFFF')
        Blank()
        Text(this.lastUpdate)
          .fontSize(10)
          .fontColor('#FFFFFF70')
      }
      .width('100%')
      .padding({ left: 14, right: 14, top: 10 })

      // 收支概览
      Row({ space: 0 }) {
        this.buildStatItem('收入', `¥${this.income}`, '#00E676')
        Divider()
          .vertical(true)
          .height(30)
          .color('#FFFFFF20')
        this.buildStatItem('支出', `¥${this.expense}`, '#FF5252')
        Divider()
          .vertical(true)
          .height(30)
          .color('#FFFFFF20')
        this.buildStatItem('结余', `¥${this.balance}`, '#FFFFFF')
      }
      .width('100%')
      .justifyContent(FlexAlign.SpaceAround)
      .padding({ top: 8, bottom: 8 })

      Divider()
        .color('#FFFFFF15')
        .margin({ left: 14, right: 14 })

      // 最近交易
      Column({ space: 4 }) {
        Text('最近交易')
          .fontSize(11)
          .fontColor('#FFFFFF80')
          .width('100%')
          .padding({ left: 14, top: 6 })

        // 交易列表（静态展示，数据通过卡片更新）
        this.buildTxnRow('📝', '暂无交易记录', '', '')
      }
      .width('100%')
      .layoutWeight(1)
      .padding({ left: 14, right: 14, bottom: 8 })
    }
    .width('100%')
    .height('100%')
    .linearGradient({
      direction: GradientDirection.Right,
      colors: [['#1A237E', 0.0], ['#0D47A1', 1.0]]
    })
    .borderRadius(16)
  }

  @Builder
  buildStatItem(label: string, value: string, color: string) {
    Column({ space: 2 }) {
      Text(label)
        .fontSize(11)
        .fontColor('#FFFFFF80')
      Text(value)
        .fontSize(14)
        .fontWeight(FontWeight.Medium)
        .fontColor(color)
    }
    .width('33%')
    .alignItems(HorizontalAlign.Center)
  }

  @Builder
  buildTxnRow(icon: string, name: string, amount: string, date: string) {
    Row() {
      Text(icon)
        .fontSize(16)
      Text(name)
        .fontSize(12)
        .fontColor('#FFFFFFCC')
        .margin({ left: 8 })
        .layoutWeight(1)
      if (amount !== '') {
        Column({ space: 1 }) {
          Text(amount)
            .fontSize(12)
            .fontWeight(FontWeight.Medium)
            .fontColor('#FFFFFF')
          Text(date)
            .fontSize(9)
            .fontColor('#FFFFFF60')
        }
        .alignItems(HorizontalAlign.End)
      }
    }
    .width('100%')
    .padding({ left: 14, right: 14, top: 4, bottom: 4 })
  }
}

export default FinanceWidgetMedium

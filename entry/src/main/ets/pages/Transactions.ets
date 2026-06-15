
import { router } from '@kit.ArkUI'
import { TransactionCard } from '../components/common/TransactionCard'
import { CategoryTag } from '../components/common/CategoryTag'
import { Transaction } from '../models/Transaction'
import { Category } from '../models/Category'
import { StorageService } from '../services/StorageService'
import { Constants } from '../constants/Constants'
import { DateUtils } from '../utils/DateUtils'
import { CurrencyUtils } from '../utils/CurrencyUtils'
import { ThemeFont, ThemeRadius, ThemeSpacing } from '../theme/Theme'

@Entry
@Component
struct Transactions {
  @State transactions: Transaction[] = []
  @State filteredTransactions: Transaction[] = []
  @State categories: Category[] = []
  @State selectedType: number = -1  // -1: 全部, 0: 收入, 1: 支出, 2: 转账
  @State selectedCategory: string = ''
  @State searchText: string = ''
  @State totalIncome: number = 0
  @State totalExpense: number = 0

  private storageService = StorageService.getInstance()

  aboutToAppear(): void {
    this.loadData()
  }

  private async loadData(): Promise<void> {
    this.categories = Category.getDefaults()
    await this.refreshTransactions()
  }

  private async refreshTransactions(): Promise<void> {
    const startDate = DateUtils.getMonthStart()
    const endDate = DateUtils.getMonthEnd()

    this.transactions = await this.storageService.queryTransactions(
      this.selectedType, startDate, endDate, this.selectedCategory, this.searchText
    )

    this.totalIncome = this.transactions
      .filter(t => t.isIncome())
      .reduce((sum, t) => sum + t.amount, 0)
    this.totalExpense = this.transactions
      .filter(t => t.isExpense())
      .reduce((sum, t) => sum + t.amount, 0)

    this.applyFilter()
  }

  private applyFilter(): void {
    this.filteredTransactions = this.transactions
  }

  /**
   * 按日期分组交易记录
   */
  private getGroupedTransactions(): Map<string, Transaction[]> {
    const groups = new Map<string, Transaction[]>()
    for (const txn of this.filteredTransactions) {
      const dateKey = DateUtils.format(txn.date, 'MM-DD') + ' ' + DateUtils.getWeekdayName(txn.date)
      if (!groups.has(dateKey)) {
        groups.set(dateKey, [])
      }
      groups.get(dateKey)!.push(txn)
    }
    return groups
  }

  build() {
    Column() {
      // 搜索栏
      Row() {
        TextInput({ placeholder: '搜索交易记录...', text: this.searchText })
          .layoutWeight(1)
          .height(40)
          .borderRadius(ThemeRadius.full)
          .backgroundColor('#F5F5F5')
          .onChange((value: string) => {
            this.searchText = value
            this.refreshTransactions()
          })
      }
      .width('100%')
      .padding({ left: ThemeSpacing.lg, right: ThemeSpacing.lg, top: ThemeSpacing.md })

      // 类型筛选
      Row({ space: ThemeSpacing.sm }) {
        this.buildTypeTab('全部', -1)
        this.buildTypeTab('支出', Constants.TYPE_EXPENSE)
        this.buildTypeTab('收入', Constants.TYPE_INCOME)
        this.buildTypeTab('转账', Constants.TYPE_TRANSFER)
      }
      .width('100%')
      .padding({ left: ThemeSpacing.lg, right: ThemeSpacing.lg, top: ThemeSpacing.md })

      // 本月汇总
      Row({ space: ThemeSpacing.lg }) {
        Column() {
          Text('收入')
            .fontSize(ThemeFont.xs)
            .fontColor('#999')
          Text(CurrencyUtils.format(this.totalIncome))
            .fontSize(ThemeFont.md)
            .fontWeight(ThemeFont.weightMedium)
            .fontColor('#00B578')
        }

        Column() {
          Text('支出')
            .fontSize(ThemeFont.xs)
            .fontColor('#999')
          Text(CurrencyUtils.format(this.totalExpense))
            .fontSize(ThemeFont.md)
            .fontWeight(ThemeFont.weightMedium)
            .fontColor('#FA2A2D')
        }

        Column() {
          Text('结余')
            .fontSize(ThemeFont.xs)
            .fontColor('#999')
          Text(CurrencyUtils.format(this.totalIncome - this.totalExpense))
            .fontSize(ThemeFont.md)
            .fontWeight(ThemeFont.weightMedium)
            .fontColor('#007DFF')
        }
      }
      .width('100%')
      .justifyContent(FlexAlign.SpaceAround)
      .padding(ThemeSpacing.lg)
      .margin(ThemeSpacing.lg)
      .backgroundColor('#FFFFFF')
      .borderRadius(ThemeRadius.md)

      // 交易列表
      List({ space: ThemeSpacing.sm }) {
        ForEach(Array.from(this.getGroupedTransactions().entries()), (entry: [string, Transaction[]]) => {
          ListItemGroup() {
            // 日期标题
            ListItem() {
              Row() {
                Text(entry[0])
                  .fontSize(ThemeFont.sm)
                  .fontColor('#666')
                  .fontWeight(ThemeFont.weightMedium)
                Blank()
                Text(`收 ${CurrencyUtils.formatShort(entry[1].filter(t => t.isIncome()).reduce((s, t) => s + t.amount, 0))}  支 ${CurrencyUtils.formatShort(entry[1].filter(t => t.isExpense()).reduce((s, t) => s + t.amount, 0))}`)
                  .fontSize(ThemeFont.xs)
                  .fontColor('#999')
              }
              .width('100%')
              .padding({ left: ThemeSpacing.lg, right: ThemeSpacing.lg, top: ThemeSpacing.md, bottom: ThemeSpacing.xs })
            }

            // 交易卡片
            ForEach(entry[1], (txn: Transaction) => {
              ListItem() {
                TransactionCard({
                  transaction: txn,
                  showDate: false
                })
              }
              .padding({ left: ThemeSpacing.lg, right: ThemeSpacing.lg })
            })
          }
        })
      }
      .layoutWeight(1)
      .width('100%')
      .alignListItem(ListItemAlign.Center)
    }
    .width('100%')
    .height('100%')
    .backgroundColor('#F5F5F5')
  }

  @Builder
  buildTypeTab(label: string, type: number) {
    Text(label)
      .fontSize(ThemeFont.sm)
      .fontColor(this.selectedType === type ? '#FFFFFF' : '#666')
      .padding({
        left: ThemeSpacing.md,
        right: ThemeSpacing.md,
        top: ThemeSpacing.xs,
        bottom: ThemeSpacing.xs
      })
      .backgroundColor(this.selectedType === type ? '#007DFF' : '#F5F5F5')
      .borderRadius(ThemeRadius.full)
      .onClick(() => {
        this.selectedType = type
        this.refreshTransactions()
      })
  }
}

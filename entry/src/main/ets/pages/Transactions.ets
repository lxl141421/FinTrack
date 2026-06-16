import { router } from '@kit.ArkUI'
import { TransactionCard } from '../components/common/TransactionCard'
import { TransactionSkeleton } from '../components/common/Skeleton'
import { Transaction } from '../models/Transaction'
import { Category } from '../models/Category'
import { StorageService } from '../services/StorageService'
import { Constants } from '../constants/Constants'
import { DateUtils } from '../utils/DateUtils'
import { CurrencyUtils } from '../utils/CurrencyUtils'
import { ErrorHandler, ErrorType } from '../utils/ErrorHandler'
import { ThemeFont, ThemeRadius, ThemeSpacing, ThemeManager } from '../theme/Theme'

/**
 * LazyForEach 数据源 - 按需加载交易记录
 */
class TransactionDataSource implements IDataSource {
  private transactions: Transaction[] = []
  private listeners: DataChangeListener[] = []

  setItems(items: Transaction[]): void {
    this.transactions = items
    this.notifyDataReload()
  }

  totalCount(): number {
    return this.transactions.length
  }

  getData(index: number): Transaction {
    return this.transactions[index]
  }

  registerDataChangeListener(listener: DataChangeListener): void {
    this.listeners.push(listener)
  }

  unregisterDataChangeListener(listener: DataChangeListener): void {
    const index = this.listeners.indexOf(listener)
    if (index >= 0) this.listeners.splice(index, 1)
  }

  notifyDataReload(): void {
    for (let _idx1 = 0; _idx1 < this.listeners.length; _idx1++) {
      const listener = this.listeners[_idx1]
      listener.onDataReloaded()
    }
  }

  notifyDataAdd(index: number): void {
    for (let _idx2 = 0; _idx2 < this.listeners.length; _idx2++) {
      const listener = this.listeners[_idx2]
      listener.onDataAdd(index)
    }
  }
}

@Entry
@Component
struct Transactions {
  @State transactions: Transaction[] = []
  @State filteredTransactions: Transaction[] = []
  @State categories: Category[] = []
  @State selectedType: number = -1
  @State selectedCategory: string = ''
  @State searchText: string = ''
  @State totalIncome: number = 0
  @State totalExpense: number = 0
  @State isLoading: boolean = false
  @State isRefreshing: boolean = false
  @State errorMessage: string = ''
  @State currentPage: number = 0
  @State hasMore: boolean = true

  private storageService = StorageService.getInstance()
  private themeManager = ThemeManager.getInstance()
  private pageSize: number = 20
  private dataSource: TransactionDataSource = new TransactionDataSource()

  aboutToAppear(): void {
    this.loadData()
  }

  onShow(): void {
    if (this.transactions.length > 0) {
      this.refreshTransactions()
    }
  }

  private async loadData(): Promise<void> {
    this.categories = Category.getDefaults()
    await this.refreshTransactions()
  }

  /**
   * @Watch 监听器 - 搜索词变化时自动刷新
   */
  @Watch('onSearchChange')
  @State searchWatcher: string = ''

  onSearchChange(): void {
    this.refreshTransactions()
  }

  private async onRefresh(): Promise<void> {
    this.isRefreshing = true
    this.currentPage = 0
    this.hasMore = true
    await this.refreshTransactions()
    this.isRefreshing = false
  }

  private async loadMore(): Promise<void> {
    if (!this.hasMore || this.isLoading) return

    this.currentPage++
    const startDate = DateUtils.getMonthStart()
    const endDate = DateUtils.getMonthEnd()

    try {
      const moreTransactions = await this.storageService.queryTransactions(
        this.selectedType, startDate, endDate, this.selectedCategory, this.searchText,
        (this.currentPage + 1) * this.pageSize
      )

      if (moreTransactions.length <= this.transactions.length) {
        this.hasMore = false
      } else {
        this.transactions = moreTransactions
        this.applyFilter()
      }
    } catch (err) {
      ErrorHandler.handle(err as Object, ErrorType.DATABASE, '加载更多交易')
      this.currentPage--
    }
  }

  private async refreshTransactions(): Promise<void> {
    this.isLoading = true
    this.errorMessage = ''

    try {
      const startDate = DateUtils.getMonthStart()
      const endDate = DateUtils.getMonthEnd()

      this.transactions = await this.storageService.queryTransactions(
        this.selectedType, startDate, endDate, this.selectedCategory, this.searchText
      )

      this.totalIncome = 0
      this.totalExpense = 0
      for (let i = 0; i < this.transactions.length; i++) {
        if (this.transactions[i].isIncome()) {
          this.totalIncome += this.transactions[i].amount
        } else if (this.transactions[i].isExpense()) {
          this.totalExpense += this.transactions[i].amount
        }
      }

      this.applyFilter()
    } catch (err) {
      const appError = ErrorHandler.handle(err as Object, ErrorType.DATABASE, '刷新交易列表')
      this.errorMessage = appError.userMessage
    } finally {
      this.isLoading = false
    }
  }

  private applyFilter(): void {
    this.filteredTransactions = this.transactions
    this.dataSource.setItems(this.filteredTransactions)
  }

  build() {
    Column() {
      // 搜索栏
      Row() {
        TextInput({ placeholder: '搜索交易记录...', text: this.searchText })
          .layoutWeight(1)
          .height(40)
          .borderRadius(ThemeRadius.full)
          .backgroundColor(this.themeManager.isDark ? '#2C2C2C' : '#F5F5F5')
          .fontColor(this.themeManager.isDark ? '#E0E0E0' : '#181818')
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
      .backgroundColor(this.themeManager.isDark ? '#1E1E1E' : '#FFFFFF')
      .borderRadius(ThemeRadius.md)

      // 骨架屏加载态
      if (this.isLoading && this.transactions.length === 0) {
        Column({ space: ThemeSpacing.sm }) {
          ForEach([1, 2, 3, 4, 5], (_: number, index: number) => {
            TransactionSkeleton()
          })
        }
        .width('100%')
        .padding(ThemeSpacing.lg)
      }

      // 错误状态
      if (this.errorMessage !== '' && !this.isLoading) {
        Column({ space: ThemeSpacing.sm }) {
          Text(this.errorMessage)
            .fontSize(ThemeFont.sm)
            .fontColor('#999')
          Button('重试')
            .fontSize(ThemeFont.sm)
            .height(32)
            .borderRadius(ThemeRadius.full)
            .backgroundColor('#007DFF')
            .onClick(() => { this.refreshTransactions() })
        }
        .width('100%')
        .padding(ThemeSpacing.xl)
      }

      // 交易列表（下拉刷新 + LazyForEach）
      Refresh({ refreshing: $$this.isRefreshing }) {
        List({ space: ThemeSpacing.sm }) {
          // 按日期分组
          ForEach(this.getGroupedArray(), (group: GroupedTxn) => {
            ListItemGroup() {
              ListItem() {
                Row() {
                  Text(group.dateLabel)
                    .fontSize(ThemeFont.sm)
                    .fontColor(this.themeManager.isDark ? '#A0A0A0' : '#666')
                    .fontWeight(ThemeFont.weightMedium)
                  Blank()
                  Text(`收 ${CurrencyUtils.formatShort(group.income)}  支 ${CurrencyUtils.formatShort(group.expense)}`)
                    .fontSize(ThemeFont.xs)
                    .fontColor('#999')
                }
                .width('100%')
                .padding({ left: ThemeSpacing.lg, right: ThemeSpacing.lg, top: ThemeSpacing.md, bottom: ThemeSpacing.xs })
              }

              ForEach(group.transactions, (txn: Transaction) => {
                ListItem() {
                  TransactionCard({
                    transaction: txn,
                    showDate: false,
                    privacyMode: this.themeManager.privacyMode
                  })
                }
                .padding({ left: ThemeSpacing.lg, right: ThemeSpacing.lg })
              })
            }
          })

          // 底部加载更多
          if (this.hasMore && this.filteredTransactions.length > 0) {
            ListItem() {
              Row() {
                if (this.isLoading) {
                  LoadingProgress().width(24).height(24)
                } else {
                  Text('上拉加载更多')
                    .fontSize(ThemeFont.sm)
                    .fontColor('#999')
                }
              }
              .width('100%')
              .height(48)
              .justifyContent(FlexAlign.Center)
            }
            .onClick(() => { this.loadMore() })
          }

          // 空状态
          if (this.filteredTransactions.length === 0 && !this.isLoading) {
            ListItem() {
              Column({ space: ThemeSpacing.sm }) {
                Text('📋').fontSize(48)
                Text('暂无交易记录').fontSize(ThemeFont.md).fontColor('#999')
              }
              .width('100%')
              .padding(ThemeSpacing.xxl * 2)
            }
          }
        }
        .layoutWeight(1)
        .width('100%')
        .onReachEnd(() => { this.loadMore() })
      }
      .onRefreshing(() => { this.onRefresh() })
      .layoutWeight(1)
      .width('100%')
    }
    .width('100%')
    .height('100%')
    .backgroundColor(this.themeManager.isDark ? '#121212' : '#F5F5F5')
  }

  @Builder
  buildTypeTab(label: string, type: number) {
    Text(label)
      .fontSize(ThemeFont.sm)
      .fontColor(this.selectedType === type ? '#FFFFFF' :
        (this.themeManager.isDark ? '#A0A0A0' : '#666'))
      .padding({ left: ThemeSpacing.md, right: ThemeSpacing.md, top: ThemeSpacing.xs, bottom: ThemeSpacing.xs })
      .backgroundColor(this.selectedType === type ? '#007DFF' :
        (this.themeManager.isDark ? '#2C2C2C' : '#F5F5F5'))
      .borderRadius(ThemeRadius.full)
      .onClick(() => {
        this.selectedType = type
        this.refreshTransactions()
      })
  }

  /**
   * 将交易按日期分组，返回数组供 ForEach 使用
   */
  private getGroupedArray(): GroupedTxn[] {
    const groups: GroupedTxn[] = []
    const map = new Map<string, Transaction[]>()

    for (let i = 0; i < this.filteredTransactions.length; i++) {
      const txn = this.filteredTransactions[i]
      const dateKey = DateUtils.format(txn.date, 'MM-DD') + ' ' + DateUtils.getWeekdayName(txn.date)
      if (!map.has(dateKey)) {
        map.set(dateKey, [])
      }
      map.get(dateKey)!.push(txn)
    }

    map.forEach((txns: Transaction[], key: string) => {
      const group = new GroupedTxn()
      group.dateLabel = key
      group.transactions = txns
      group.income = 0
      group.expense = 0
      for (let i = 0; i < txns.length; i++) {
        if (txns[i].isIncome()) group.income += txns[i].amount
        if (txns[i].isExpense()) group.expense += txns[i].amount
      }
      groups.push(group)
    })

    return groups
  }
}

class GroupedTxn {
  dateLabel: string = ''
  transactions: Transaction[] = []
  income: number = 0
  expense: number = 0
}
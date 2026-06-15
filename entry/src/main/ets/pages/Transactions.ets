
import { router } from '@kit.ArkUI'
import { TransactionCard } from '../components/common/TransactionCard'
import { CategoryTag } from '../components/common/CategoryTag'
import { Transaction } from '../models/Transaction'
import { Category } from '../models/Category'
import { StorageService } from '../services/StorageService'
import { Constants } from '../constants/Constants'
import { DateUtils } from '../utils/DateUtils'
import { CurrencyUtils } from '../utils/CurrencyUtils'
import { ErrorHandler, ErrorType } from '../utils/ErrorHandler'
import { ThemeFont, ThemeRadius, ThemeSpacing, ThemeManager } from '../theme/Theme'

/**
 * LazyForEach 数据源
 * 实现 IDataSource 接口，支持按需加载
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
    if (index >= 0) {
      this.listeners.splice(index, 1)
    }
  }

  notifyDataReload(): void {
    for (const listener of this.listeners) {
      listener.onDataReloaded()
    }
  }

  notifyDataAdd(index: number): void {
    for (const listener of this.listeners) {
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
  @State selectedType: number = -1  // -1: 全部, 0: 收入, 1: 支出, 2: 转账
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

  /**
   * 页面显示时刷新数据
   */
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
   * 下拉刷新
   */
  private async onRefresh(): Promise<void> {
    this.isRefreshing = true
    this.currentPage = 0
    this.hasMore = true
    await this.refreshTransactions()
    this.isRefreshing = false
  }

  /**
   * 上拉加载更多
   */
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

      this.totalIncome = this.transactions
        .filter(t => t.isIncome())
        .reduce((sum, t) => sum + t.amount, 0)
      this.totalExpense = this.transactions
        .filter(t => t.isExpense())
        .reduce((sum, t) => sum + t.amount, 0)

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

      // 加载中指示器
      if (this.isLoading) {
        LoadingProgress()
          .width(36)
          .height(36)
          .margin({ top: ThemeSpacing.xl })
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

      // 交易列表（使用 LazyForEach 优化大数据量渲染）
      List({ space: ThemeSpacing.sm }) {
        // 使用 ForEach 遍历分组数据（分组数量通常有限，内部使用 LazyForEach 单项）
        ForEach(Array.from(this.getGroupedTransactions().entries()), (entry: [string, Transaction[]]) => {
          ListItemGroup() {
            // 日期标题
            ListItem() {
              Row() {
                Text(entry[0])
                  .fontSize(ThemeFont.sm)
                  .fontColor(this.themeManager.isDark ? '#A0A0A0' : '#666')
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

        // 底部加载更多指示器
        if (this.hasMore && this.filteredTransactions.length > 0) {
          ListItem() {
            Row() {
              if (this.isLoading) {
                LoadingProgress()
                  .width(24)
                  .height(24)
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
              Text('📋')
                .fontSize(48)
              Text(this.errorMessage !== '' ? '加载失败' : '暂无交易记录')
                .fontSize(ThemeFont.md)
                .fontColor('#999')
            }
            .width('100%')
            .padding(ThemeSpacing.xxl * 2)
          }
        }
      }
      .layoutWeight(1)
      .width('100%')
      .alignListItem(ListItemAlign.Center)
      .onReachEnd(() => {
        this.loadMore()
      })
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
      .padding({
        left: ThemeSpacing.md,
        right: ThemeSpacing.md,
        top: ThemeSpacing.xs,
        bottom: ThemeSpacing.xs
      })
      .backgroundColor(this.selectedType === type ? '#007DFF' :
        (this.themeManager.isDark ? '#2C2C2C' : '#F5F5F5'))
      .borderRadius(ThemeRadius.full)
      .onClick(() => {
        this.selectedType = type
        this.refreshTransactions()
      })
  }
}

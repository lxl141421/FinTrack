import { Transaction } from '../models/Transaction'
import { StorageService } from '../services/StorageService'
import { DistributedService } from '../services/DistributedService'
import { Constants } from '../constants/Constants'
import { DateUtils } from '../utils/DateUtils'
import { ErrorHandler, ErrorType } from '../utils/ErrorHandler'
import { hilog } from '@kit.PerformanceAnalysisKit'

/**
 * 加载状态枚举
 */
export enum LoadingState {
  IDLE = 'IDLE',
  LOADING = 'LOADING',
  SUCCESS = 'SUCCESS',
  ERROR = 'ERROR'
}

/**
 * 交易数据 ViewModel
 *
 * 使用 @ObservedV2 + @Trace 实现响应式状态管理
 * 将页面逻辑与数据层解耦，支持多页面共享同一份数据
 *
 * 设计决策：
 * 1. 单例模式 — 保证全局唯一数据源
 * 2. 内存缓存 — 减少 RDB 查询次数
 * 3. 自动同步 — 数据变更自动推送分布式存储
 * 4. 错误兜底 — 所有异步操作统一错误处理
 */
@ObservedV2
export class TransactionViewModel {
  /** 交易列表（带 @Trace 装饰器，UI 自动刷新） */
  @Trace transactions: Transaction[] = []
  /** 最近交易（首页用） */
  @Trace recentTransactions: Transaction[] = []
  /** 月度收入 */
  @Trace monthlyIncome: number = 0
  /** 月度支出 */
  @Trace monthlyExpense: number = 0
  /** 月度结余 */
  @Trace monthlyBalance: number = 0
  /** 总资产 */
  @Trace totalAssets: number = 0
  /** 分类支出 */
  @Trace expenseByCategory: Record<string, number> = {}
  /** 加载状态 */
  @Trace loadingState: LoadingState = LoadingState.IDLE
  /** 错误信息 */
  @Trace errorMessage: string = ''

  private static instance: TransactionViewModel | null = null
  private storageService = StorageService.getInstance()
  private distributedService = DistributedService.getInstance()
  /** 内存缓存：减少重复查询 */
  private cache: Map<string, Transaction[]> = new Map()
  private cacheExpiry: number = 0
  private static readonly CACHE_TTL: number = 30_000 // 30秒缓存

  static getInstance(): TransactionViewModel {
    if (TransactionViewModel.instance === null) {
      TransactionViewModel.instance = new TransactionViewModel()
    }
    return TransactionViewModel.instance
  }

  /**
   * 加载首页仪表盘数据
   * 包含月度摘要、最近交易、分类支出
   */
  async loadDashboardData(): Promise<void> {
    this.loadingState = LoadingState.LOADING
    this.errorMessage = ''

    try {
      const monthStart = DateUtils.getMonthStart()
      const monthEnd = DateUtils.getMonthEnd()

      // 并行查询收入和支出
      const [incomeTxns, expenseTxns, allTxns] = await Promise.all([
        this.storageService.queryTransactions(Constants.TYPE_INCOME, monthStart, monthEnd),
        this.storageService.queryTransactions(Constants.TYPE_EXPENSE, monthStart, monthEnd),
        this.storageService.queryTransactions(-1, 0, Date.now(), '', '', 5)
      ])

      // 计算月度摘要
      this.monthlyIncome = Number(incomeTxns.reduce((sum, t) => sum + t.amount, 0).toFixed(2))
      this.monthlyExpense = Number(expenseTxns.reduce((sum, t) => sum + t.amount, 0).toFixed(2))
      this.monthlyBalance = Number((this.monthlyIncome - this.monthlyExpense).toFixed(2))
      this.totalAssets = this.monthlyBalance

      // 最近交易
      this.recentTransactions = allTxns

      // 分类支出
      const categoryMap: Record<string, number> = {}
      for (const txn of expenseTxns) {
        const key = txn.categoryName
        if (categoryMap[key] === undefined) {
          categoryMap[key] = 0
        }
        categoryMap[key] += txn.amount
      }
      this.expenseByCategory = categoryMap

      this.loadingState = LoadingState.SUCCESS
    } catch (err) {
      const appError = ErrorHandler.handle(err as Object, ErrorType.DATABASE, '加载首页数据')
      this.errorMessage = appError.userMessage
      this.loadingState = LoadingState.ERROR
    }
  }

  /**
   * 加载当月全部交易
   */
  async loadCurrentMonth(): Promise<void> {
    this.loadingState = LoadingState.LOADING
    this.errorMessage = ''

    try {
      const monthStart = DateUtils.getMonthStart()
      const monthEnd = DateUtils.getMonthEnd()
      const cacheKey = `month_${DateUtils.getCurrentMonth()}`

      // 检查缓存
      if (this.isValidCache(cacheKey)) {
        const cached = this.cache.get(cacheKey)
        if (cached !== undefined) {
          this.transactions = cached
          this.calculateSummary(cached)
          this.loadingState = LoadingState.SUCCESS
          return
        }
      }

      const txns = await this.storageService.queryTransactions(-1, monthStart, monthEnd)
      this.transactions = txns
      this.calculateSummary(txns)

      // 更新缓存
      this.cache.set(cacheKey, txns)
      this.cacheExpiry = Date.now() + TransactionViewModel.CACHE_TTL

      // 后台同步到分布式存储（不阻塞UI）
      this.syncToDistributed(txns).catch((err) => {
        hilog.warn(0x0000, 'FinTrack', 'Background sync failed: %{public}s', JSON.stringify(err))
      })

      this.loadingState = LoadingState.SUCCESS
    } catch (err) {
      const appError = ErrorHandler.handle(err as Object, ErrorType.DATABASE, '加载交易数据')
      this.errorMessage = appError.userMessage
      this.loadingState = LoadingState.ERROR
    }
  }

  /**
   * 添加交易记录
   * 包含输入验证、数据库写入、分布式同步、缓存清除
   */
  async addTransaction(txn: Transaction): Promise<{ success: boolean; error?: string }> {
    // 输入验证
    if (txn.amount <= 0) {
      return { success: false, error: '金额必须大于0' }
    }
    if (txn.amount > 99_999_999.99) {
      return { success: false, error: '金额超出范围' }
    }
    if (txn.category.trim() === '') {
      return { success: false, error: '请选择分类' }
    }

    try {
      await this.storageService.insertTransaction(txn)
      this.invalidateCache()

      // 后台同步到分布式存储
      this.distributedService.putTransaction(txn).catch((err) => {
        hilog.warn(0x0000, 'FinTrack', 'Distributed sync failed: %{public}s', JSON.stringify(err))
      })

      hilog.info(0x0000, 'FinTrack', 'Transaction added: %{public}s', txn.id)
      return { success: true }
    } catch (err) {
      ErrorHandler.handle(err as Object, ErrorType.DATABASE, '添加交易')
      return { success: false, error: '保存失败，请重试' }
    }
  }

  /**
   * 删除交易记录
   */
  async deleteTransaction(id: string): Promise<boolean> {
    try {
      await this.storageService.deleteTransaction(id)
      this.distributedService.deleteTransaction(id).catch(() => {})
      this.invalidateCache()
      return true
    } catch (err) {
      ErrorHandler.handle(err as Object, ErrorType.DATABASE, '删除交易')
      return false
    }
  }

  /**
   * 搜索交易记录
   */
  async search(keyword: string): Promise<Transaction[]> {
    if (keyword.trim() === '') {
      return this.transactions
    }
    try {
      return await this.storageService.queryTransactions(
        -1, 0, Date.now(), '', keyword
      )
    } catch (err) {
      ErrorHandler.handle(err as Object, ErrorType.DATABASE, '搜索交易')
      return []
    }
  }

  /**
   * 计算月度收支摘要
   */
  private calculateSummary(txns: Transaction[]): void {
    this.monthlyIncome = 0
    this.monthlyExpense = 0

    for (const txn of txns) {
      if (txn.type === Constants.TYPE_INCOME) {
        this.monthlyIncome += txn.amount
      } else if (txn.type === Constants.TYPE_EXPENSE) {
        this.monthlyExpense += txn.amount
      }
    }

    this.monthlyIncome = Number(this.monthlyIncome.toFixed(2))
    this.monthlyExpense = Number(this.monthlyExpense.toFixed(2))
    this.monthlyBalance = Number((this.monthlyIncome - this.monthlyExpense).toFixed(2))
  }

  /**
   * 后台同步到分布式存储
   */
  private async syncToDistributed(txns: Transaction[]): Promise<void> {
    for (const txn of txns.slice(0, 10)) {
      await this.distributedService.putTransaction(txn)
    }
  }

  /**
   * 缓存有效性检查
   */
  private isValidCache(key: string): boolean {
    return this.cache.has(key) && Date.now() < this.cacheExpiry
  }

  /**
   * 清除缓存
   */
  private invalidateCache(): void {
    this.cache.clear()
    this.cacheExpiry = 0
  }
}

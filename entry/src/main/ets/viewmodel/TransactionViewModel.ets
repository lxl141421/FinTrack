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
 * 操作结果
 */
export class OperationResult {
  success: boolean
  error: string

  constructor(success: boolean, error: string = '') {
    this.success = success
    this.error = error
  }

  static ok(): OperationResult {
    return new OperationResult(true)
  }

  static fail(error: string): OperationResult {
    return new OperationResult(false, error)
  }
}

/**
 * 交易数据 ViewModel
 */
@ObservedV2
export class TransactionViewModel {
  @Trace transactions: Transaction[] = []
  @Trace recentTransactions: Transaction[] = []
  @Trace monthlyIncome: number = 0
  @Trace monthlyExpense: number = 0
  @Trace monthlyBalance: number = 0
  @Trace totalAssets: number = 0
  @Trace expenseByCategory: Record<string, number> = {}
  @Trace loadingState: LoadingState = LoadingState.IDLE
  @Trace errorMessage: string = ''

  private static instance: TransactionViewModel | null = null
  private storageService = StorageService.getInstance()
  private distributedService = DistributedService.getInstance()
  private cache: Map<string, Transaction[]> = new Map()
  private cacheExpiry: number = 0
  private static readonly CACHE_TTL: number = 30_000

  static getInstance(): TransactionViewModel {
    if (TransactionViewModel.instance === null) {
      TransactionViewModel.instance = new TransactionViewModel()
    }
    return TransactionViewModel.instance
  }

  async loadDashboardData(): Promise<void> {
    this.loadingState = LoadingState.LOADING
    this.errorMessage = ''

    try {
      const monthStart = DateUtils.getMonthStart()
      const monthEnd = DateUtils.getMonthEnd()

      const incomeTxns = await this.storageService.queryTransactions(Constants.TYPE_INCOME, monthStart, monthEnd)
      const expenseTxns = await this.storageService.queryTransactions(Constants.TYPE_EXPENSE, monthStart, monthEnd)
      const allTxns = await this.storageService.queryTransactions(-1, 0, Date.now(), '', '', 5)

      this.monthlyIncome = Number(incomeTxns.reduce((sum: number, t: Transaction) => sum + t.amount, 0).toFixed(2))
      this.monthlyExpense = Number(expenseTxns.reduce((sum: number, t: Transaction) => sum + t.amount, 0).toFixed(2))
      this.monthlyBalance = Number((this.monthlyIncome - this.monthlyExpense).toFixed(2))
      this.totalAssets = this.monthlyBalance
      this.recentTransactions = allTxns

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

  async loadCurrentMonth(): Promise<void> {
    this.loadingState = LoadingState.LOADING
    this.errorMessage = ''

    try {
      const monthStart = DateUtils.getMonthStart()
      const monthEnd = DateUtils.getMonthEnd()
      const cacheKey = `month_${DateUtils.getCurrentMonth()}`

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

      this.cache.set(cacheKey, txns)
      this.cacheExpiry = Date.now() + TransactionViewModel.CACHE_TTL

      this.syncToDistributed(txns)

      this.loadingState = LoadingState.SUCCESS
    } catch (err) {
      const appError = ErrorHandler.handle(err as Object, ErrorType.DATABASE, '加载交易数据')
      this.errorMessage = appError.userMessage
      this.loadingState = LoadingState.ERROR
    }
  }

  async addTransaction(txn: Transaction): Promise<OperationResult> {
    if (txn.amount <= 0) {
      return OperationResult.fail('金额必须大于0')
    }
    if (txn.amount > 99_999_999.99) {
      return OperationResult.fail('金额超出范围')
    }
    if (txn.category.trim() === '') {
      return OperationResult.fail('请选择分类')
    }

    try {
      await this.storageService.insertTransaction(txn)
      this.invalidateCache()

      this.distributedService.putTransaction(txn)

      hilog.info(0x0000, 'FinTrack', 'Transaction added: %{public}s', txn.id)
      return OperationResult.ok()
    } catch (err) {
      ErrorHandler.handle(err as Object, ErrorType.DATABASE, '添加交易')
      return OperationResult.fail('保存失败，请重试')
    }
  }

  async deleteTransaction(id: string): Promise<boolean> {
    try {
      await this.storageService.deleteTransaction(id)
      this.distributedService.deleteTransaction(id)
      this.invalidateCache()
      return true
    } catch (err) {
      ErrorHandler.handle(err as Object, ErrorType.DATABASE, '删除交易')
      return false
    }
  }

  async search(keyword: string): Promise<Transaction[]> {
    if (keyword.trim() === '') {
      return this.transactions
    }
    try {
      return await this.storageService.queryTransactions(-1, 0, Date.now(), '', keyword)
    } catch (err) {
      ErrorHandler.handle(err as Object, ErrorType.DATABASE, '搜索交易')
      return []
    }
  }

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

  private async syncToDistributed(txns: Transaction[]): Promise<void> {
    for (let i = 0; i < Math.min(txns.length, 10); i++) {
      await this.distributedService.putTransaction(txns[i])
    }
  }

  private isValidCache(key: string): boolean {
    return this.cache.has(key) && Date.now() < this.cacheExpiry
  }

  private invalidateCache(): void {
    this.cache.clear()
    this.cacheExpiry = 0
  }
}

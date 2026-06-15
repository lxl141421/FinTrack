
import { relationalStore } from '@kit.ArkData'
import { preferences } from '@kit.ArkData'
import { hilog } from '@kit.PerformanceAnalysisKit'
import { Constants } from '../constants/Constants'
import { Transaction } from '../models/Transaction'
import { Budget } from '../models/Budget'
import { Context } from '@kit.AbilityKit'

/**
 * 缓存条目
 */
class CacheEntry<T> {
  data: T
  timestamp: number
  ttl: number  // 缓存有效期（毫秒）

  constructor(data: T, ttl: number = 30000) {
    this.data = data
    this.timestamp = Date.now()
    this.ttl = ttl
  }

  isExpired(): boolean {
    return Date.now() - this.timestamp > this.ttl
  }
}
/**
 * 本地存储服务
 * 封装 RDB (关系型数据库) + Preferences (轻量偏好存储)
 * 内置 LRU 缓存层，减少重复查询
 */
export class StorageService {
  private static instance: StorageService | null = null
  private rdbStore: relationalStore.RdbStore | null = null
  private prefStore: preferences.Preferences | null = null
  private context: Context | null = null
  /** 查询缓存（key -> CacheEntry） */
  private queryCache: Map<string, CacheEntry<Object>> = new Map()
  /** 缓存最大条目数 */
  private static readonly MAX_CACHE_SIZE: number = 50
  /** 默认缓存 TTL：30秒 */
  private static readonly DEFAULT_TTL: number = 30000

  /**
   * 生成缓存键
   */
  private buildCacheKey(prefix: string, ...args: Object[]): string {
    return `${prefix}_${args.join('_')}`
  }

  /**
   * 从缓存获取数据
   */
  private getFromCache<T>(key: string): T | null {
    const entry = this.queryCache.get(key)
    if (entry !== undefined && !entry.isExpired()) {
      return entry.data as T
    }
    if (entry !== undefined) {
      this.queryCache.delete(key)
    }
    return null
  }

  /**
   * 写入缓存
   */
  private setCache<T>(key: string, data: T, ttl: number = StorageService.DEFAULT_TTL): void {
    // 超过最大条目时清理过期缓存
    if (this.queryCache.size >= StorageService.MAX_CACHE_SIZE) {
      this.evictExpiredCache()
    }
    this.queryCache.set(key, new CacheEntry(data, ttl))
  }

  /**
   * 清理过期缓存
   */
  private evictExpiredCache(): void {
    const keysToDelete: string[] = []
    this.queryCache.forEach((value: CacheEntry<Object>, key: string) => {
      if (value.isExpired()) {
        keysToDelete.push(key)
      }
    })
    for (const key of keysToDelete) {
      this.queryCache.delete(key)
    }
  }

  /**
   * 清空所有缓存
   */
  clearCache(): void {
    this.queryCache.clear()
    hilog.info(0x0000, 'FinTrack', 'Query cache cleared')
  }

  private constructor() {}
  /**
  /**
   * 获取单例
   */
  static getInstance(): StorageService {
    if (StorageService.instance === null) {
      StorageService.instance = new StorageService()
    }
    return StorageService.instance
  }

  /**
   * 初始化存储
   */
  async init(context: Context): Promise<void> {
    this.context = context
    await this.initRdb()
    await this.initPreferences()
  }

  /**
   * 初始化关系型数据库
   */
  private async initRdb(): Promise<void> {
    if (this.context === null) return

    const STORE_CONFIG: relationalStore.StoreConfig = {
      name: Constants.DB_NAME,
      securityLevel: relationalStore.SecurityLevel.S1
    }

    try {
      this.rdbStore = await relationalStore.getRdbStore(this.context, STORE_CONFIG)
      await this.createTables()
      hilog.info(0x0000, 'FinTrack', 'RDB initialized successfully')
    } catch (err) {
      hilog.error(0x0000, 'FinTrack', 'RDB init failed: %{public}s', JSON.stringify(err))
    }
  }

  /**
   * 创建数据表
   */
  private async createTables(): Promise<void> {
    if (this.rdbStore === null) return

    // 交易记录表
    const createTransactionSql = `
      CREATE TABLE IF NOT EXISTS ${Constants.TABLE_TRANSACTION} (
        id TEXT PRIMARY KEY,
        type INTEGER NOT NULL,
        amount REAL NOT NULL,
        category TEXT NOT NULL,
        categoryName TEXT NOT NULL,
        note TEXT DEFAULT '',
        date INTEGER NOT NULL,
        accountId TEXT DEFAULT 'default',
        toAccountId TEXT DEFAULT '',
        tags TEXT DEFAULT '[]',
        createdAt INTEGER NOT NULL,
        updatedAt INTEGER NOT NULL
      )
    `
    await this.rdbStore.executeSql(createTransactionSql)

    // 预算表
    const createBudgetSql = `
      CREATE TABLE IF NOT EXISTS ${Constants.TABLE_BUDGET} (
        id TEXT PRIMARY KEY,
        category TEXT DEFAULT '',
        categoryName TEXT DEFAULT '总预算',
        limitAmount REAL NOT NULL,
        spentAmount REAL DEFAULT 0,
        month TEXT NOT NULL,
        createdAt INTEGER NOT NULL
      )
    `
    await this.rdbStore.executeSql(createBudgetSql)

    // 创建索引
    await this.rdbStore.executeSql(
      `CREATE INDEX IF NOT EXISTS idx_txn_date ON ${Constants.TABLE_TRANSACTION}(date)`
    )
    await this.rdbStore.executeSql(
      `CREATE INDEX IF NOT EXISTS idx_txn_category ON ${Constants.TABLE_TRANSACTION}(category)`
    )
    await this.rdbStore.executeSql(
      `CREATE INDEX IF NOT EXISTS idx_txn_type ON ${Constants.TABLE_TRANSACTION}(type)`
    )
    await this.rdbStore.executeSql(
      `CREATE INDEX IF NOT EXISTS idx_budget_month ON ${Constants.TABLE_BUDGET}(month)`
    )
  }

  /**
   * 初始化偏好存储
   */
  private async initPreferences(): Promise<void> {
    if (this.context === null) return

    try {
      this.prefStore = await preferences.getPreferences(this.context, 'fintrack_prefs')
      hilog.info(0x0000, 'FinTrack', 'Preferences initialized successfully')
    } catch (err) {
      hilog.error(0x0000, 'FinTrack', 'Preferences init failed: %{public}s', JSON.stringify(err))
    }
  }

  // ==================== 偏好存储 ====================

  /**
   * 获取偏好设置
   */
  async getPreference(key: string, defaultValue: string = ''): Promise<string> {
    if (this.prefStore === null) return defaultValue
    try {
      const value = await this.prefStore.get(key, defaultValue)
      return value as string
    } catch {
      return defaultValue
    }
  }

  /**
   * 设置偏好
   */
  async setPreference(key: string, value: string): Promise<void> {
    if (this.prefStore === null) return
    try {
      await this.prefStore.put(key, value)
      await this.prefStore.flush()
    } catch (err) {
      hilog.error(0x0000, 'FinTrack', 'Set preference failed: %{public}s', JSON.stringify(err))
    }
  }

  /**
   * 获取整数偏好
   */
  async getPreferenceInt(key: string, defaultValue: number = 0): Promise<number> {
    const str = await this.getPreference(key, defaultValue.toString())
    return Number(str)
  }

  /**
   * 获取布尔偏好
   */
  async getPreferenceBool(key: string, defaultValue: boolean = false): Promise<boolean> {
    const str = await this.getPreference(key, defaultValue ? '1' : '0')
    return str === '1'
  }

  /**
   * 设置布尔偏好
   */
  async setPreferenceBool(key: string, value: boolean): Promise<void> {
    await this.setPreference(key, value ? '1' : '0')
  }

  // ==================== 交易记录 CRUD ====================

  /**
   * 插入交易记录
   */
  async insertTransaction(txn: Transaction): Promise<void> {
    if (this.rdbStore === null) return

    const bucket = new relationalStore.ValueBucket({
      'id': txn.id,
      'type': txn.type,
      'amount': txn.amount,
      'category': txn.category,
      'categoryName': txn.categoryName,
      'note': txn.note,
      'date': txn.date,
      'accountId': txn.accountId,
      'toAccountId': txn.toAccountId,
      'tags': JSON.stringify(txn.tags),
      'createdAt': txn.createdAt,
      'updatedAt': txn.updatedAt
    })

    await this.rdbStore.insert(Constants.TABLE_TRANSACTION, bucket)
    hilog.info(0x0000, 'FinTrack', 'Transaction inserted: %{public}s', txn.id)
    // 写入操作后清除缓存
    this.clearCache()
  }

  /**
   * 查询交易记录
   * @param type 交易类型 (-1 查全部)
   * @param startDate 起始时间戳
   * @param endDate 结束时间戳
   * @param category 分类 (空查全部)
   * @param keyword 搜索关键词
   * @param limit 限制条数
   */
  async queryTransactions(
    type: number = -1,
    startDate: number = 0,
    endDate: number = Date.now(),
    category: string = '',
    keyword: string = '',
    limit: number = 100
  ): Promise<Transaction[]> {
    if (this.rdbStore === null) return []

    // 检查缓存（仅无关键词查询命中缓存）
    if (keyword === '') {
      const cacheKey = this.buildCacheKey('txn', type, startDate, endDate, category, limit)
      const cached = this.getFromCache<Transaction[]>(cacheKey)
      if (cached !== null) {
        hilog.info(0x0000, 'FinTrack', 'Cache hit: %{public}s', cacheKey)
        return cached
      }
    }
    let whereClauses: string[] = ['date >= ?', 'date <= ?']
    let args: relationalStore.ValueType[] = [startDate, endDate]

    if (type >= 0) {
      whereClauses.push('type = ?')
      args.push(type)
    }
    if (category !== '') {
      whereClauses.push('category = ?')
      args.push(category)
    }
    if (keyword !== '') {
      whereClauses.push('(note LIKE ? OR categoryName LIKE ?)')
      args.push(`%${keyword}%`, `%${keyword}%`)
    }

    const predicates = new relationalStore.RdbPredicates(Constants.TABLE_TRANSACTION)
    predicates.equalTo('1', '1') // placeholder
    for (let i = 0; i < whereClauses.length; i++) {
      // Use the actual where clause building
    }

    try {
      // Simplified query approach
      let sql = `SELECT * FROM ${Constants.TABLE_TRANSACTION} WHERE ${whereClauses.join(' AND ')} ORDER BY date DESC LIMIT ${limit}`
      const resultSet = await this.rdbStore.querySql(sql, args)
      const transactions: Transaction[] = []

      while (resultSet.goToNextRow()) {
        const txn = new Transaction()
        txn.id = resultSet.getString(resultSet.getColumnIndex('id'))
        txn.type = resultSet.getLong(resultSet.getColumnIndex('type'))
        txn.amount = resultSet.getDouble(resultSet.getColumnIndex('amount'))
        txn.category = resultSet.getString(resultSet.getColumnIndex('category'))
        txn.categoryName = resultSet.getString(resultSet.getColumnIndex('categoryName'))
        txn.note = resultSet.getString(resultSet.getColumnIndex('note'))
        txn.date = resultSet.getLong(resultSet.getColumnIndex('date'))
        txn.accountId = resultSet.getString(resultSet.getColumnIndex('accountId'))
        txn.toAccountId = resultSet.getString(resultSet.getColumnIndex('toAccountId'))
        const tagsStr = resultSet.getString(resultSet.getColumnIndex('tags'))
        txn.tags = JSON.parse(tagsStr) as string[]
        txn.createdAt = resultSet.getLong(resultSet.getColumnIndex('createdAt'))
        txn.updatedAt = resultSet.getLong(resultSet.getColumnIndex('updatedAt'))
        transactions.push(txn)
      }
      resultSet.close()
      // 写入缓存
      if (keyword === '') {
        const cacheKey = this.buildCacheKey('txn', type, startDate, endDate, category, limit)
        this.setCache(cacheKey, transactions)
      }
      return transactions
    } catch (err) {
      hilog.error(0x0000, 'FinTrack', 'Query transactions failed: %{public}s', JSON.stringify(err))
      return []
    }
  }

  /**
   * 删除交易记录
   */
  async deleteTransaction(id: string): Promise<void> {
    if (this.rdbStore === null) return
    const predicates = new relationalStore.RdbPredicates(Constants.TABLE_TRANSACTION)
    predicates.equalTo('id', id)
    await this.rdbStore.delete(predicates)
  }

  /**
   * 更新交易记录
   */
  async updateTransaction(txn: Transaction): Promise<void> {
    if (this.rdbStore === null) return
    txn.updatedAt = Date.now()

    const bucket = new relationalStore.ValueBucket({
      'type': txn.type,
      'amount': txn.amount,
      'category': txn.category,
      'categoryName': txn.categoryName,
      'note': txn.note,
      'date': txn.date,
      'toAccountId': txn.toAccountId,
      'tags': JSON.stringify(txn.tags),
      'updatedAt': txn.updatedAt
    })

    const predicates = new relationalStore.RdbPredicates(Constants.TABLE_TRANSACTION)
    predicates.equalTo('id', txn.id)
    await this.rdbStore.update(bucket, predicates)
  }

  // ==================== 预算 CRUD ====================

  /**
   * 插入预算
   */
  async insertBudget(budget: Budget): Promise<void> {
    if (this.rdbStore === null) return

    const bucket = new relationalStore.ValueBucket({
      'id': budget.id,
      'category': budget.category,
      'categoryName': budget.categoryName,
      'limitAmount': budget.limitAmount,
      'spentAmount': budget.spentAmount,
      'month': budget.month,
      'createdAt': budget.createdAt
    })

    await this.rdbStore.insert(Constants.TABLE_BUDGET, bucket)
  }

  /**
   * 查询指定月份的预算
   */
  async queryBudgets(month: string): Promise<Budget[]> {
    if (this.rdbStore === null) return []

    try {
      const sql = `SELECT * FROM ${Constants.TABLE_BUDGET} WHERE month = ? ORDER BY createdAt ASC`
      const resultSet = await this.rdbStore.querySql(sql, [month])
      const budgets: Budget[] = []

      while (resultSet.goToNextRow()) {
        const budget = new Budget()
        budget.id = resultSet.getString(resultSet.getColumnIndex('id'))
        budget.category = resultSet.getString(resultSet.getColumnIndex('category'))
        budget.categoryName = resultSet.getString(resultSet.getColumnIndex('categoryName'))
        budget.limitAmount = resultSet.getDouble(resultSet.getColumnIndex('limitAmount'))
        budget.spentAmount = resultSet.getDouble(resultSet.getColumnIndex('spentAmount'))
        budget.month = resultSet.getString(resultSet.getColumnIndex('month'))
        budget.createdAt = resultSet.getLong(resultSet.getColumnIndex('createdAt'))
        budgets.push(budget)
      }
      resultSet.close()
      return budgets
    } catch (err) {
      hilog.error(0x0000, 'FinTrack', 'Query budgets failed: %{public}s', JSON.stringify(err))
      return []
    }
  }

  /**
   * 更新预算已用金额
   */
  async updateBudgetSpent(id: string, spentAmount: number): Promise<void> {
    if (this.rdbStore === null) return
    const bucket = new relationalStore.ValueBucket({ 'spentAmount': spentAmount })
    const predicates = new relationalStore.RdbPredicates(Constants.TABLE_BUDGET)
    predicates.equalTo('id', id)
    await this.rdbStore.update(bucket, predicates)
  }

  /**
   * 删除预算
   */
  async deleteBudget(id: string): Promise<void> {
    if (this.rdbStore === null) return
    const predicates = new relationalStore.RdbPredicates(Constants.TABLE_BUDGET)
    predicates.equalTo('id', id)
    await this.rdbStore.delete(predicates)
  }
}

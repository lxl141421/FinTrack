import { relationalStore } from '@kit.ArkData'
import { preferences } from '@kit.ArkData'
import { hilog } from '@kit.PerformanceAnalysisKit'
import { Constants } from '../constants/Constants'
import { Encryption } from '../utils/Encryption'
import { Transaction } from '../models/Transaction'
import { Budget } from '../models/Budget'
import { Context } from '@kit.AbilityKit'

/**
 * 缓存条目
 */
class CacheEntry {
  data: Object
  timestamp: number
  ttl: number

  constructor(data: Object, ttl: number = 30000) {
    this.data = data
    this.timestamp = Date.now()
    this.ttl = ttl
  }

  isExpired(): boolean {
    return Date.now() - this.timestamp > this.ttl
  }
}

/**
 * 本地存储服务 - RDB + Preferences + LRU 缓存
 */
export class StorageService {
  private static instance: StorageService | null = null
  private rdbStore: relationalStore.RdbStore | null = null
  private prefStore: preferences.Preferences | null = null
  private context: Context | null = null
  private queryCache: Map<string, CacheEntry> = new Map()
  private static readonly MAX_CACHE_SIZE: number = 50
  private static readonly DEFAULT_TTL: number = 30000

  private buildCacheKey(prefix: string, ...args: Object[]): string {
    return `${prefix}_${args.join('_')}`
  }

  private getFromCache(key: string): Object | null {
    const entry = this.queryCache.get(key)
    if (entry !== undefined && !entry.isExpired()) {
      return entry.data
    }
    if (entry !== undefined) {
      this.queryCache.delete(key)
    }
    return null
  }

  private setCache(key: string, data: Object, ttl: number = StorageService.DEFAULT_TTL): void {
    if (this.queryCache.size >= StorageService.MAX_CACHE_SIZE) {
      this.evictExpiredCache()
    }
    this.queryCache.set(key, new CacheEntry(data, ttl))
  }

  private evictExpiredCache(): void {
    const keysToDelete: string[] = []
    this.queryCache.forEach((value: CacheEntry, key: string) => {
      if (value.isExpired()) keysToDelete.push(key)
    })
    for (let _idx1 = 0; _idx1 < keysToDelete.length; _idx1++) {
      const key = keysToDelete[_idx1]
      this.queryCache.delete(key)
    }
  }

  clearCache(): void {
    this.queryCache.clear()
  }

  private constructor() {}

  static getInstance(): StorageService {
    if (StorageService.instance === null) {
      StorageService.instance = new StorageService()
    }
    return StorageService.instance
  }

  async init(context: Context): Promise<void> {
    this.context = context
    await this.initRdb()
    await this.initPreferences()
  }

  private async initRdb(): Promise<void> {
    if (this.context === null) return
    const STORE_CONFIG: relationalStore.StoreConfig = {
      name: Constants.DB_NAME,
      securityLevel: relationalStore.SecurityLevel.S1
    }
    try {
      this.rdbStore = await relationalStore.getRdbStore(this.context, STORE_CONFIG)
      await this.createTables()
      hilog.info(0x0000, 'FinTrack', 'RDB initialized')
    } catch (err) {
      hilog.error(0x0000, 'FinTrack', 'RDB init failed')
    }
  }

  private async createTables(): Promise<void> {
    if (this.rdbStore === null) return

    await this.rdbStore.executeSql(`
      CREATE TABLE IF NOT EXISTS ${Constants.TABLE_TRANSACTION} (
        id TEXT PRIMARY KEY, type INTEGER NOT NULL, amount REAL NOT NULL,
        category TEXT NOT NULL, categoryName TEXT NOT NULL, note TEXT DEFAULT '',
        date INTEGER NOT NULL, accountId TEXT DEFAULT 'default',
        toAccountId TEXT DEFAULT '', tags TEXT DEFAULT '[]',
        createdAt INTEGER NOT NULL, updatedAt INTEGER NOT NULL
      )
    `)

    await this.rdbStore.executeSql(`
      CREATE TABLE IF NOT EXISTS ${Constants.TABLE_BUDGET} (
        id TEXT PRIMARY KEY, category TEXT DEFAULT '', categoryName TEXT DEFAULT '总预算',
        limitAmount REAL NOT NULL, spentAmount REAL DEFAULT 0,
        month TEXT NOT NULL, createdAt INTEGER NOT NULL
      )
    `)

    await this.rdbStore.executeSql(`CREATE INDEX IF NOT EXISTS idx_txn_date ON ${Constants.TABLE_TRANSACTION}(date)`)
    await this.rdbStore.executeSql(`CREATE INDEX IF NOT EXISTS idx_txn_category ON ${Constants.TABLE_TRANSACTION}(category)`)
    await this.rdbStore.executeSql(`CREATE INDEX IF NOT EXISTS idx_txn_type ON ${Constants.TABLE_TRANSACTION}(type)`)
    await this.rdbStore.executeSql(`CREATE INDEX IF NOT EXISTS idx_budget_month ON ${Constants.TABLE_BUDGET}(month)`)
  }

  private async initPreferences(): Promise<void> {
    if (this.context === null) return
    try {
      this.prefStore = await preferences.getPreferences(this.context, 'fintrack_prefs')
    } catch (err) {
      hilog.error(0x0000, 'FinTrack', 'Preferences init failed')
    }
  }

  // ==================== 偏好存储 ====================

  async getPreference(key: string, defaultValue: string = ''): Promise<string> {
    if (this.prefStore === null) return defaultValue
    try {
      const value = await this.prefStore.get(key, defaultValue)
      return value as string
    } catch {
      return defaultValue
    }
  }

  async setPreference(key: string, value: string): Promise<void> {
    if (this.prefStore === null) return
    try {
      await this.prefStore.put(key, value)
      await this.prefStore.flush()
    } catch (err) {
      hilog.error(0x0000, 'FinTrack', 'Set preference failed')
    }
  }

  async getPreferenceInt(key: string, defaultValue: number = 0): Promise<number> {
    const str = await this.getPreference(key, defaultValue.toString())
    return Number(str)
  }

  async setPreferenceInt(key: string, value: number): Promise<void> {
    await this.setPreference(key, value.toString())
  }

  async getPreferenceBool(key: string, defaultValue: boolean = false): Promise<boolean> {
    const str = await this.getPreference(key, defaultValue ? '1' : '0')
    return str === '1'
  }

  async setPreferenceBool(key: string, value: boolean): Promise<void> {
    await this.setPreference(key, value ? '1' : '0')
  }

  // ==================== 交易记录 CRUD ====================

  async insertTransaction(txn: Transaction): Promise<void> {
    if (this.rdbStore === null) return

    const bucket: relationalStore.ValuesBucket = {
      'id': txn.id,
      'type': txn.type,
      'amount': txn.amount,
      'category': txn.category,
      'categoryName': txn.categoryName,
      'note': await Encryption.encrypt(txn.note),
      'date': txn.date,
      'accountId': txn.accountId,
      'toAccountId': txn.toAccountId,
      'tags': JSON.stringify(txn.tags),
      'createdAt': txn.createdAt,
      'updatedAt': txn.updatedAt
    }

    await this.rdbStore.insert(Constants.TABLE_TRANSACTION, bucket)
    this.clearCache()
  }

  async queryTransactions(
    type: number = -1,
    startDate: number = 0,
    endDate: number = Date.now(),
    category: string = '',
    keyword: string = '',
    limit: number = 100
  ): Promise<Transaction[]> {
    if (this.rdbStore === null) return []

    if (keyword === '') {
      const cacheKey = this.buildCacheKey('txn', type, startDate, endDate, category, limit)
      const cached = this.getFromCache(cacheKey)
      if (cached !== null) {
        return cached as Transaction[]
      }
    }

    const whereClauses: string[] = ['date >= ?', 'date <= ?']
    const args: relationalStore.ValueType[] = [startDate, endDate]

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

    try {
      const sql = `SELECT * FROM ${Constants.TABLE_TRANSACTION} WHERE ${whereClauses.join(' AND ')} ORDER BY date DESC LIMIT ${limit}`
      const resultSet = await this.rdbStore.querySql(sql, args)
      const transactions: Transaction[] = []

      while (resultSet.goToNextRow()) {
        const txn = new Transaction()
        txn.id = resultSet.getString(resultSet.getColumnIndex('id'))
        txn.type = resultSet.getLong(resultSet.getColumnIndex('type'))
        txn.amount = resultSet.getDouble(resultSet.getColumnIndex('amount'))
        txn.category = resultSet.getString(resultSet.getColumnIndex('category'))
        txn.categoryName = resultSet.getString(resultSet.getColumnIndex('categoryName'))
        txn.note = await Encryption.decrypt(resultSet.getString(resultSet.getColumnIndex('note')))
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

      if (keyword === '') {
        const cacheKey = this.buildCacheKey('txn', type, startDate, endDate, category, limit)
        this.setCache(cacheKey, transactions as Object)
      }
      return transactions
    } catch (err) {
      hilog.error(0x0000, 'FinTrack', 'Query transactions failed')
      return []
    }
  }

  async deleteTransaction(id: string): Promise<void> {
    if (this.rdbStore === null) return
    const predicates = new relationalStore.RdbPredicates(Constants.TABLE_TRANSACTION)
    predicates.equalTo('id', id)
    await this.rdbStore.delete(predicates)
    this.clearCache()
  }

  async updateTransaction(txn: Transaction): Promise<void> {
    if (this.rdbStore === null) return
    txn.updatedAt = Date.now()

    const bucket: relationalStore.ValuesBucket = {
      'type': txn.type,
      'amount': txn.amount,
      'category': txn.category,
      'categoryName': txn.categoryName,
      'note': await Encryption.encrypt(txn.note),
      'date': txn.date,
      'toAccountId': txn.toAccountId,
      'tags': JSON.stringify(txn.tags),
      'updatedAt': txn.updatedAt
    }

    const predicates = new relationalStore.RdbPredicates(Constants.TABLE_TRANSACTION)
    predicates.equalTo('id', txn.id)
    await this.rdbStore.update(bucket, predicates)
    this.clearCache()
  }

  // ==================== 预算 CRUD ====================

  async insertBudget(budget: Budget): Promise<void> {
    if (this.rdbStore === null) return

    const bucket: relationalStore.ValuesBucket = {
      'id': budget.id,
      'category': budget.category,
      'categoryName': budget.categoryName,
      'limitAmount': budget.limitAmount,
      'spentAmount': budget.spentAmount,
      'month': budget.month,
      'createdAt': budget.createdAt
    }

    await this.rdbStore.insert(Constants.TABLE_BUDGET, bucket)
  }

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
      hilog.error(0x0000, 'FinTrack', 'Query budgets failed')
      return []
    }
  }

  async updateBudgetSpent(id: string, spentAmount: number): Promise<void> {
    if (this.rdbStore === null) return
    const bucket: relationalStore.ValuesBucket = { 'spentAmount': spentAmount }
    const predicates = new relationalStore.RdbPredicates(Constants.TABLE_BUDGET)
    predicates.equalTo('id', id)
    await this.rdbStore.update(bucket, predicates)
  }

  async deleteBudget(id: string): Promise<void> {
    if (this.rdbStore === null) return
    const predicates = new relationalStore.RdbPredicates(Constants.TABLE_BUDGET)
    predicates.equalTo('id', id)
    await this.rdbStore.delete(predicates)
  }
}
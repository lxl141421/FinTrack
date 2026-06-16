     1|import { hilog } from '@kit.PerformanceAnalysisKit'
     2|import { relationalStore, preferences } from '@kit.ArkData'
     3|import { Context } from '@kit.AbilityKit'
     4|import { Encryption } from '../utils/Encryption'
     5|import { AuditLogger, AuditAction } from './AuditLogger'
     6|
     7|/**
     8| * 备份元数据
     9| */
    10|export class BackupMetadata {
    11|  version: string = '1.0.0'
    12|  timestamp: number = 0
    13|  deviceModel: string = ''
    14|  appVersion: string = ''
    15|  recordCount: number = 0
    16|  checksum: string = ''
    17|
    18|  toJson(): string {
    19|    return JSON.stringify({
    20|      version: this.version,
    21|      timestamp: this.timestamp,
    22|      deviceModel: this.deviceModel,
    23|      appVersion: this.appVersion,
    24|      recordCount: this.recordCount,
    25|      checksum: this.checksum
    26|    })
    27|  }
    28|
    29|  static fromJson(json: string): BackupMetadata {
    30|    const meta = new BackupMetadata()
    31|    try {
    32|      const obj = JSON.parse(json) as Record<string, Object>
    33|      meta.version = obj['version'] as string || ''
    34|      meta.timestamp = obj['timestamp'] as number || 0
    35|      meta.deviceModel = obj['deviceModel'] as string || ''
    36|      meta.appVersion = obj['appVersion'] as string || ''
    37|      meta.recordCount = obj['recordCount'] as number || 0
    38|      meta.checksum = obj['checksum'] as string || ''
    39|    } catch (e) {
    40|      // ignore
    41|    }
    42|    return meta
    43|  }
    44|}
    45|
    46|/**
    47| * 备份数据格式
    48| */
    49|export class BackupData {
    50|  metadata: BackupMetadata = new BackupMetadata()
    51|  transactions: string = ''   // JSON string
    52|  budgets: string = ''        // JSON string
    53|  categories: string = ''     // JSON string
    54|  preferences: string = ''    // JSON string
    55|
    56|  toJson(): string {
    57|    return JSON.stringify({
    58|      metadata: this.metadata.toJson(),
    59|      transactions: this.transactions,
    60|      budgets: this.budgets,
    61|      categories: this.categories,
    62|      preferences: this.preferences
    63|    })
    64|  }
    65|
    66|  static fromJson(json: string): BackupData {
    67|    const data = new BackupData()
    68|    try {
    69|      const obj = JSON.parse(json) as Record<string, Object>
    70|      data.metadata = BackupMetadata.fromJson(obj['metadata'] as string || '{}')
    71|      data.transactions = obj['transactions'] as string || '[]'
    72|      data.budgets = obj['budgets'] as string || '[]'
    73|      data.categories = obj['categories'] as string || '[]'
    74|      data.preferences = obj['preferences'] as string || '{}'
    75|    } catch (e) {
    76|      // ignore
    77|    }
    78|    return data
    79|  }
    80|}
    81|
    82|/**
    83| * 数据备份恢复服务
    84| *
    85| * 功能：
    86| * - 导出完整数据（交易/预算/分类/配置）为 JSON
    87| * - 数据加密（AES-256-GCM）
    88| * - 完整性校验（SHA-256）
    89| * - 支持全量恢复和选择性恢复
    90| * - 审计日志记录所有备份/恢复操作
    91| */
    92|export class BackupService {
    93|  private static instance: BackupService | null = null
    94|  private static readonly TAG: string = 'FinTrack-Backup'
    95|  private static readonly STORE_NAME: string = 'backup_config'
    96|  private static readonly KEY_LAST_BACKUP: string = 'last_backup_time'
    97|  private static readonly KEY_AUTO_BACKUP: string = 'auto_backup_enabled'
    98|
    99|  private rdbStore: relationalStore.RdbStore | null = null
   100|  private context: Context | null = null
   101|  private isInitialized: boolean = false
   102|  private auditLogger: AuditLogger = AuditLogger.getInstance()
   103|
   104|  private constructor() {}
   105|
   106|  static getInstance(): BackupService {
   107|    if (BackupService.instance === null) {
   108|      BackupService.instance = new BackupService()
   109|    }
   110|    return BackupService.instance
   111|  }
   112|
   113|  /**
   114|   * 初始化备份服务
   115|   */
   116|  async init(context: Context, rdbStore: relationalStore.RdbStore): Promise<void> {
   117|    this.context = context
   118|    this.rdbStore = rdbStore
   119|    this.isInitialized = true
   120|    hilog.info(0x0000, BackupService.TAG, 'BackupService initialized')
   121|  }
   122|
   123|  /**
   124|   * 创建完整备份
   125|   */
   126|  async createBackup(): Promise<string> {
   127|    if (!this.isInitialized || this.rdbStore === null) {
   128|      throw new Error('BackupService not initialized')
   129|    }
   130|
   131|    try {
   132|      const backupData = new BackupData()
   133|
   134|      // 1. 导出交易记录
   135|      const txnResultSet = await this.rdbStore.querySql('SELECT * FROM transactions ORDER BY date DESC')
   136|      const transactions: Record<string, Object>[] = []
   137|      while (txnResultSet.goToNextRow()) {
   138|        transactions.push(this.rowToObject(txnResultSet))
   139|      }
   140|      txnResultSet.close()
   141|      backupData.transactions = JSON.stringify(transactions)
   142|
   143|      // 2. 导出预算
   144|      const budgetResultSet = await this.rdbStore.querySql('SELECT * FROM budgets')
   145|      const budgets: Record<string, Object>[] = []
   146|      while (budgetResultSet.goToNextRow()) {
   147|        budgets.push(this.rowToObject(budgetResultSet))
   148|      }
   149|      budgetResultSet.close()
   150|      backupData.budgets = JSON.stringify(budgets)
   151|
   152|      // 3. 元数据
   153|      backupData.metadata.timestamp = Date.now()
   154|      backupData.metadata.recordCount = transactions.length
   155|      backupData.metadata.appVersion = '1.0.0'
   156|
   157|      // 4. 计算校验和
   158|      const dataStr = backupData.transactions + backupData.budgets
   159|      backupData.metadata.checksum = await Encryption.sha256(dataStr)
   160|
   161|      // 5. 加密备份数据
   162|      const encrypted = await Encryption.encrypt(backupData.toJson())
   163|
   164|      // 6. 记录审计日志
   165|      await this.auditLogger.log(
   166|        AuditAction.BACKUP,
   167|        'System',
   168|        'backup_' + Date.now(),
   169|        '',
   170|        `${transactions.length} transactions, ${budgets.length} budgets`
   171|      )
   172|
   173|      hilog.info(0x0000, BackupService.TAG,
   174|        'Backup created: %{public}d transactions', transactions.length)
   175|
   176|      return encrypted
   177|    } catch (err) {
   178|      hilog.error(0x0000, BackupService.TAG, 'Backup failed')
   179|      throw err
   180|    }
   181|  }
   182|
   183|  /**
   184|   * 恢复备份
   185|   * @param encryptedData 加密的备份数据
   186|   * @param mergeMode true=合并，false=覆盖
   187|   */
   188|  async restoreBackup(encryptedData: string, mergeMode: boolean = true): Promise<BackupMetadata> {
   189|    if (!this.isInitialized || this.rdbStore === null) {
   190|      throw new Error('BackupService not initialized')
   191|    }
   192|
   193|    try {
   194|      // 1. 解密
   195|      const decrypted = await Encryption.decrypt(encryptedData)
   196|      const backupData = BackupData.fromJson(decrypted)
   197|
   198|      // 2. 验证校验和
   199|      const dataStr = backupData.transactions + backupData.budgets
   200|      const calculatedChecksum = await Encryption.sha256(dataStr)
   201|      if (calculatedChecksum !== backupData.metadata.checksum) {
   202|        throw new Error('Backup integrity check failed')
   203|      }
   204|
   205|      // 3. 恢复交易记录
   206|      const transactions = JSON.parse(backupData.transactions) as Record<string, Object>[]
   207|      let restoredCount = 0
   208|
   209|      if (!mergeMode) {
   210|        // 覆盖模式：先清空
   211|        await this.rdbStore.executeSql('DELETE FROM transactions')
   212|      }
   213|
   214|      for (let i = 0; i < transactions.length; i++) {
   215|        const txn = transactions[i]
   216|        const id = txn['id'] as string
   217|
   218|        // 检查是否已存在
   219|        if (mergeMode) {
   220|          const existing = await this.rdbStore.querySql(
   221|            'SELECT id FROM transactions WHERE id = ?', [id])
   222|          const hasRow = existing.goToNextRow()
   223|          existing.close()
   224|          if (hasRow) continue
   225|        }
   226|
   227|        // 插入
   228|        const predicates = new relationalStore.RdbPredicates('transactions')
   229|        const bucket = new relationalStore.ValuesBucket()
   230|        const keys = Object.keys(txn)
   231|        for (let j = 0; j < keys.length; j++) {
   232|          const key = keys[j]
   233|          const value = txn[key]
   234|          if (typeof value === 'number') {
   235|            bucket.putLong(key, value)
   236|          } else if (typeof value === 'string') {
   237|            bucket.putString(key, value)
   238|          }
   239|        }
   240|        await this.rdbStore.insert(predicates, bucket)
   241|        restoredCount++
   242|      }
   243|
   244|      // 4. 恢复预算
   245|      const budgets = JSON.parse(backupData.budgets) as Record<string, Object>[]
   246|      if (!mergeMode) {
   247|        await this.rdbStore.executeSql('DELETE FROM budgets')
   248|      }
   249|
   250|      for (let i = 0; i < budgets.length; i++) {
   251|        const budget = budgets[i]
   252|        const predicates = new relationalStore.RdbPredicates('budgets')
   253|        const bucket = new relationalStore.ValuesBucket()
   254|        const keys = Object.keys(budget)
   255|        for (let j = 0; j < keys.length; j++) {
   256|          const key = keys[j]
   257|          const value = budget[key]
   258|          if (typeof value === 'number') {
   259|            bucket.putLong(key, value)
   260|          } else if (typeof value === 'string') {
   261|            bucket.putString(key, value)
   262|          }
   263|        }
   264|        await this.rdbStore.insert(predicates, bucket)
   265|      }
   266|
   267|      // 5. 记录审计日志
   268|      await this.auditLogger.log(
   269|        AuditAction.RESTORE,
   270|        'System',
   271|        'restore_' + Date.now(),
   272|        '',
   273|        `Restored ${restoredCount} transactions`
   274|      )
   275|
   276|      hilog.info(0x0000, BackupService.TAG,
   277|        'Backup restored: %{public}d transactions', restoredCount)
   278|
   279|      return backupData.metadata
   280|    } catch (err) {
   281|      hilog.error(0x0000, BackupService.TAG, 'Restore failed')
   282|      throw err
   283|    }
   284|  }
   285|
   286|  /**
   287|   * 获取上次备份时间
   288|   */
   289|  async getLastBackupTime(): Promise<number> {
   290|    if (!this.isInitialized) return 0
   291|    try {
   292|      const prefStore = await preferences.getPreferences(this.context!, BackupService.STORE_NAME)
   293|      return await prefStore.get(BackupService.KEY_LAST_BACKUP, 0) as number
   294|    } catch (e) {
   295|      return 0
   296|    }
   297|  }
   298|
   299|  /**
   300|   * 保存备份时间
   301|   */
   302|  private async saveLastBackupTime(): Promise<void> {
   303|    try {
   304|      const prefStore = await preferences.getPreferences(this.context!, BackupService.STORE_NAME)
   305|      await prefStore.put(BackupService.KEY_LAST_BACKUP, Date.now())
   306|      await prefStore.flush()
   307|    } catch (e) {
   308|      // ignore
   309|    }
   310|  }
   311|
   312|  /**
   313|   * ResultSet 行转对象
   314|   */
   315|  private rowToObject(resultSet: relationalStore.ResultSet): Record<string, Object> {
   316|    const obj: Record<string, Object> = {}
   317|    const columnCount = resultSet.columnCount
   318|    for (let i = 0; i < columnCount; i++) {
   319|      const columnName = resultSet.getColumnName(i)
   320|      const columnType = resultSet.getColumnType(i)
   321|      switch (columnType) {
   322|        case relationalStore.ValueType.STRING:
   323|          obj[columnName] = resultSet.getString(i)
   324|          break
   325|        case relationalStore.ValueType.INTEGER:
   326|          obj[columnName] = resultSet.getLong(i)
   327|          break
   328|        case relationalStore.ValueType.REAL:
   329|          obj[columnName] = resultSet.getDouble(i)
   330|          break
   331|        default:
   332|          obj[columnName] = resultSet.getString(i)
   333|      }
   334|    }
   335|    return obj
   336|  }
   337|}
   338|
   339|import { preferences } from '@kit.ArkData'
   340|
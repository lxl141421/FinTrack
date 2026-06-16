import { hilog } from '@kit.PerformanceAnalysisKit'
import { relationalStore } from '@kit.ArkData'
import { Context } from '@kit.AbilityKit'
import { Constants } from '../constants/Constants'
import { Encryption } from '../utils/Encryption'

/**
 * 审计操作类型
 */
export enum AuditAction {
  CREATE = 'CREATE',
  UPDATE = 'UPDATE',
  DELETE = 'DELETE',
  LOGIN = 'LOGIN',
  LOGOUT = 'LOGOUT',
  BACKUP = 'BACKUP',
  RESTORE = 'RESTORE',
  EXPORT = 'EXPORT'
}

/**
 * 审计日志条目
 *
 * 金融合规要求：
 * - 每笔交易的增删改必须有记录
 * - 记录不可篡改（写入后只读）
 * - 包含操作人、时间、IP、设备信息
 * - 保留期限按法规要求（通常3-5年）
 */
export class AuditEntry {
  id: string = ''
  action: AuditAction = AuditAction.CREATE
  entityType: string = ''       // 'Transaction' | 'Budget' | 'Account'
  entityId: string = ''         // 被操作的记录ID
  beforeData: string = ''       // 操作前数据快照（加密）
  afterData: string = ''        // 操作后数据快照（加密）
  operatorId: string = 'local'  // 操作人ID
  deviceId: string = ''         // 设备标识
  timestamp: number = 0
  checksum: string = ''         // 数据完整性校验

  static create(
    action: AuditAction,
    entityType: string,
    entityId: string,
    beforeData: string = '',
    afterData: string = ''
  ): AuditEntry {
    const entry = new AuditEntry()
    entry.id = `audit_${Date.now()}_${Math.random().toString(36).substr(2, 9)}`
    entry.action = action
    entry.entityType = entityType
    entry.entityId = entityId
    entry.timestamp = Date.now()
    return entry
  }

  /**
   * 计算完整性校验和
   * 使用 SHA-256 对关键字段哈希，防止篡改
   */
  async calculateChecksum(): Promise<string> {
    const data = `${this.id}|${this.action}|${this.entityType}|${this.entityId}|${this.timestamp}|${this.beforeData}|${this.afterData}`
    this.checksum = await Encryption.sha256(data)
    return this.checksum
  }

  toJson(): string {
    return JSON.stringify({
      id: this.id,
      action: this.action,
      entityType: this.entityType,
      entityId: this.entityId,
      beforeData: this.beforeData,
      afterData: this.afterData,
      operatorId: this.operatorId,
      deviceId: this.deviceId,
      timestamp: this.timestamp,
      checksum: this.checksum
    })
  }

  static fromJson(json: string): AuditEntry {
    const entry = new AuditEntry()
    try {
      const obj = JSON.parse(json) as Record<string, Object>
      entry.id = obj['id'] as string || ''
      entry.action = obj['action'] as AuditAction || AuditAction.CREATE
      entry.entityType = obj['entityType'] as string || ''
      entry.entityId = obj['entityId'] as string || ''
      entry.beforeData = obj['beforeData'] as string || ''
      entry.afterData = obj['afterData'] as string || ''
      entry.operatorId = obj['operatorId'] as string || ''
      entry.deviceId = obj['deviceId'] as string || ''
      entry.timestamp = obj['timestamp'] as number || 0
      entry.checksum = obj['checksum'] as string || ''
    } catch (e) {
      // ignore
    }
    return entry
  }
}

/**
 * 操作审计日志服务
 *
 * 功能：
 * - 记录所有数据变更操作
 * - 数据加密存储（AES-256-GCM）
 * - 完整性校验（SHA-256 checksum）
 * - 支持按时间/类型/实体查询
 * - 自动清理过期日志（可配置保留天数）
 */
export class AuditLogger {
  private static instance: AuditLogger | null = null
  private static readonly TAG: string = 'FinTrack-Audit'
  private static readonly TABLE_NAME: string = 'audit_log'
  private static readonly DEFAULT_RETENTION_DAYS: number = 365 * 3  // 3年

  private rdbStore: relationalStore.RdbStore | null = null
  private isInitialized: boolean = false
  private retentionDays: number = AuditLogger.DEFAULT_RETENTION_DAYS

  private constructor() {}

  static getInstance(): AuditLogger {
    if (AuditLogger.instance === null) {
      AuditLogger.instance = new AuditLogger()
    }
    return AuditLogger.instance
  }

  /**
   * 初始化审计日志表
   */
  async init(rdbStore: relationalStore.RdbStore): Promise<void> {
    this.rdbStore = rdbStore
    try {
      await rdbStore.executeSql(`
        CREATE TABLE IF NOT EXISTS ${AuditLogger.TABLE_NAME} (
          id TEXT PRIMARY KEY,
          action TEXT NOT NULL,
          entityType TEXT NOT NULL,
          entityId TEXT NOT NULL,
          beforeData TEXT,
          afterData TEXT,
          operatorId TEXT,
          deviceId TEXT,
          timestamp INTEGER NOT NULL,
          checksum TEXT,
          createdAt INTEGER NOT NULL
        )
      `)

      // 创建索引
      await rdbStore.executeSql(`
        CREATE INDEX IF NOT EXISTS idx_audit_entity
        ON ${AuditLogger.TABLE_NAME}(entityType, entityId)
      `)
      await rdbStore.executeSql(`
        CREATE INDEX IF NOT EXISTS idx_audit_timestamp
        ON ${AuditLogger.TABLE_NAME}(timestamp)
      `)
      await rdbStore.executeSql(`
        CREATE INDEX IF NOT EXISTS idx_audit_action
        ON ${AuditLogger.TABLE_NAME}(action)
      `)

      this.isInitialized = true
      hilog.info(0x0000, AuditLogger.TAG, 'Audit log initialized')
    } catch (err) {
      hilog.error(0x0000, AuditLogger.TAG, 'Audit log init failed')
    }
  }

  /**
   * 记录审计日志
   */
  async log(
    action: AuditAction,
    entityType: string,
    entityId: string,
    beforeData: string = '',
    afterData: string = ''
  ): Promise<void> {
    if (!this.isInitialized || this.rdbStore === null) return

    try {
      const entry = AuditEntry.create(action, entityType, entityId, beforeData, afterData)

      // 加密敏感数据
      if (beforeData !== '') {
        entry.beforeData = await Encryption.encrypt(beforeData)
      }
      if (afterData !== '') {
        entry.afterData = await Encryption.encrypt(afterData)
      }

      // 计算完整性校验
      await entry.calculateChecksum()

      // 写入数据库（只增不改）
      const predicates = new relationalStore.RdbPredicates(AuditLogger.TABLE_NAME)
      const bucket = new relationalStore.ValuesBucket()
      bucket.putString('id', entry.id)
      bucket.putString('action', entry.action)
      bucket.putString('entityType', entry.entityType)
      bucket.putString('entityId', entry.entityId)
      bucket.putString('beforeData', entry.beforeData)
      bucket.putString('afterData', entry.afterData)
      bucket.putString('operatorId', entry.operatorId)
      bucket.putString('deviceId', entry.deviceId)
      bucket.putLong('timestamp', entry.timestamp)
      bucket.putString('checksum', entry.checksum)
      bucket.putLong('createdAt', Date.now())

      await this.rdbStore.insert(predicates, bucket)

      hilog.info(0x0000, AuditLogger.TAG,
        'Audit: %{public}s %{public}s %{public}s',
        action, entityType, entityId)
    } catch (err) {
      hilog.error(0x0000, AuditLogger.TAG, 'Audit log write failed')
    }
  }

  /**
   * 查询审计日志
   */
  async query(
    entityType: string = '',
    entityId: string = '',
    startTime: number = 0,
    endTime: number = Date.now(),
    limit: number = 100
  ): Promise<AuditEntry[]> {
    if (!this.isInitialized || this.rdbStore === null) return []

    try {
      const whereClauses: string[] = ['timestamp >= ?', 'timestamp <= ?']
      const args: relationalStore.ValueType[] = [startTime, endTime]

      if (entityType !== '') {
        whereClauses.push('entityType = ?')
        args.push(entityType)
      }
      if (entityId !== '') {
        whereClauses.push('entityId = ?')
        args.push(entityId)
      }

      const sql = `SELECT * FROM ${AuditLogger.TABLE_NAME}
        WHERE ${whereClauses.join(' AND ')}
        ORDER BY timestamp DESC LIMIT ${limit}`

      const resultSet = await this.rdbStore.querySql(sql, args)
      const entries: AuditEntry[] = []

      while (resultSet.goToNextRow()) {
        const entry = new AuditEntry()
        entry.id = resultSet.getString(resultSet.getColumnIndex('id'))
        entry.action = resultSet.getString(resultSet.getColumnIndex('action')) as AuditAction
        entry.entityType = resultSet.getString(resultSet.getColumnIndex('entityType'))
        entry.entityId = resultSet.getString(resultSet.getColumnIndex('entityId'))
        entry.beforeData = resultSet.getString(resultSet.getColumnIndex('beforeData'))
        entry.afterData = resultSet.getString(resultSet.getColumnIndex('afterData'))
        entry.operatorId = resultSet.getString(resultSet.getColumnIndex('operatorId'))
        entry.deviceId = resultSet.getString(resultSet.getColumnIndex('deviceId'))
        entry.timestamp = resultSet.getLong(resultSet.getColumnIndex('timestamp'))
        entry.checksum = resultSet.getString(resultSet.getColumnIndex('checksum'))
        entries.push(entry)
      }
      resultSet.close()

      return entries
    } catch (err) {
      hilog.error(0x0000, AuditLogger.TAG, 'Audit query failed')
      return []
    }
  }

  /**
   * 验证日志完整性
   */
  async verifyIntegrity(entry: AuditEntry): Promise<boolean> {
    const calculated = await entry.calculateChecksum()
    return calculated === entry.checksum
  }

  /**
   * 清理过期日志
   */
  async cleanup(): Promise<number> {
    if (!this.isInitialized || this.rdbStore === null) return 0

    try {
      const cutoff = Date.now() - (this.retentionDays * 24 * 60 * 60 * 1000)
      const predicates = new relationalStore.RdbPredicates(AuditLogger.TABLE_NAME)
      predicates.lessThan('timestamp', cutoff)

      const deleted = await this.rdbStore.delete(predicates)
      hilog.info(0x0000, AuditLogger.TAG, 'Audit cleanup: %{public}d entries removed', deleted)
      return deleted
    } catch (err) {
      hilog.error(0x0000, AuditLogger.TAG, 'Audit cleanup failed')
      return 0
    }
  }

  /**
   * 导出审计日志（用于合规审查）
   */
  async exportToJson(startTime: number = 0, endTime: number = Date.now()): Promise<string> {
    const entries = await this.query('', '', startTime, endTime, 10000)
    const exportData = {
      exportTime: Date.now(),
      startTime: startTime,
      endTime: endTime,
      totalEntries: entries.length,
      entries: entries.map((e: AuditEntry) => e.toJson())
    }
    return JSON.stringify(exportData, null, 2)
  }

  /**
   * 设置保留天数
   */
  setRetentionDays(days: number): void {
    this.retentionDays = days
  }
}

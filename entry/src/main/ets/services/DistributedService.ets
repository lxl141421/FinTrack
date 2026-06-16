import { distributedKVStore } from '@kit.ArkData'
import { hilog } from '@kit.PerformanceAnalysisKit'
import { Constants } from '../constants/Constants'
import { Transaction } from '../models/Transaction'
import { Context } from '@kit.AbilityKit'

/**
 * 冲突解决策略枚举
 */
export enum ConflictStrategy {
  LAST_WRITE_WIN = 'LAST_WRITE_WIN',   // 最后写入胜出（默认）
  VERSION_CHECK = 'VERSION_CHECK',      // 版本号检查
  MANUAL = 'MANUAL'                      // 手动合并
}

/**
 * 冲突记录
 */
export class ConflictRecord {
  key: string = ''
  localVersion: number = 0
  remoteVersion: number = 0
  localData: string = ''
  remoteData: string = ''
  resolvedBy: string = ''
  timestamp: number = 0

  toJson(): string {
    return JSON.stringify({
      key: this.key,
      localVersion: this.localVersion,
      remoteVersion: this.remoteVersion,
      resolvedBy: this.resolvedBy,
      timestamp: this.timestamp
    })
  }
}

/**
 * 分布式数据同步服务
 *
 * 冲突解决策略：
 * 1. 版本号检查：每次修改递增 version，高版本覆盖低版本
 * 2. Last Write Win：版本号相同时，updatedAt 更新的胜出
 * 3. 冲突日志：记录所有冲突用于审计
 */
export class DistributedService {
  private static instance: DistributedService | null = null
  private kvStore: distributedKVStore.SingleKVStore | null = null
  private context: Context | null = null
  private isInitialized: boolean = false
  private conflictStrategy: ConflictStrategy = ConflictStrategy.VERSION_CHECK
  private conflictLog: ConflictRecord[] = []
  private static readonly MAX_CONFLICT_LOG: number = 50
  private onDataChanged: ((transactions: Transaction[]) => void) | null = null

  private constructor() {}

  static getInstance(): DistributedService {
    if (DistributedService.instance === null) {
      DistributedService.instance = new DistributedService()
    }
    return DistributedService.instance
  }

  async init(context: Context): Promise<void> {
    this.context = context
    try {
      const kvManager = distributedKVStore.createKVManager({
        context: context,
        bundleName: Constants.BUNDLE_NAME
      })

      const options: distributedKVStore.Options = {
        createIfMissing: true,
        encrypt: false,
        backup: false,
        autoSync: true,
        kvStoreType: distributedKVStore.KVStoreType.SINGLE_VERSION,
        securityLevel: distributedKVStore.SecurityLevel.S1
      }

      this.kvStore = await kvManager.getKVStore(Constants.STORE_ID, options)
      this.registerDataChangeListener()
      this.isInitialized = true
      hilog.info(0x0000, 'FinTrack', 'Distributed KV store initialized')
    } catch (err) {
      hilog.error(0x0000, 'FinTrack', 'Distributed init failed')
    }
  }

  /**
   * 设置冲突解决策略
   */
  setConflictStrategy(strategy: ConflictStrategy): void {
    this.conflictStrategy = strategy
  }

  private registerDataChangeListener(): void {
    if (this.kvStore === null) return

    const callback = (changeData: distributedKVStore.ChangeNotification) => {
      hilog.info(0x0000, 'FinTrack', 'Distributed data changed')
      if (this.onDataChanged !== null) {
        this.syncTransactions().then((txns: Transaction[]) => {
          if (this.onDataChanged !== null) {
            this.onDataChanged(txns)
          }
        })
      }
    }

    this.kvStore.on('dataChange', distributedKVStore.SubscribeType.SUBSCRIBE_TYPE_ALL, callback)
  }

  setDataChangedCallback(callback: (transactions: Transaction[]) => void): void {
    this.onDataChanged = callback
  }

  /**
   * 写入交易记录（带版本控制）
   */
  async putTransaction(txn: Transaction): Promise<void> {
    if (this.kvStore === null || !this.isInitialized) return

    try {
      // 检查远程版本
      const remoteValue = await this.kvStore.get(txn.id)
      if (remoteValue !== null && typeof remoteValue === 'string') {
        const remoteTxn = Transaction.fromJson(remoteValue)
        const conflict = this.resolveConflict(txn, remoteTxn)
        if (conflict !== null) {
          this.logConflict(conflict)
          if (conflict.resolvedBy === 'remote') {
            hilog.info(0x0000, 'FinTrack',
              'Conflict resolved: remote wins for %{public}s', txn.id)
            return  // 远程版本更新，不覆盖
          }
        }
      }

      // 递增版本号
      txn.version++
      txn.updatedAt = Date.now()
      await this.kvStore.put(txn.id, txn.toJson())
    } catch (err) {
      hilog.error(0x0000, 'FinTrack', 'Distributed put failed')
    }
  }

  /**
   * 解决冲突
   * @returns ConflictRecord 如果有冲突，null 如果无冲突
   */
  private resolveConflict(local: Transaction, remote: Transaction): ConflictRecord | null {
    // 无冲突：本地版本更高
    if (local.version > remote.version) {
      return null
    }

    // 有冲突
    const record = new ConflictRecord()
    record.key = local.id
    record.localVersion = local.version
    record.remoteVersion = remote.version
    record.localData = local.toJson()
    record.remoteData = remote.toJson()
    record.timestamp = Date.now()

    switch (this.conflictStrategy) {
      case ConflictStrategy.VERSION_CHECK:
        if (local.version < remote.version) {
          record.resolvedBy = 'remote'
        } else {
          // 版本号相同，比较 updatedAt
          record.resolvedBy = local.updatedAt >= remote.updatedAt ? 'local' : 'remote'
        }
        break

      case ConflictStrategy.LAST_WRITE_WIN:
        record.resolvedBy = local.updatedAt >= remote.updatedAt ? 'local' : 'remote'
        break

      case ConflictStrategy.MANUAL:
        // 手动模式：记录冲突，由用户决定
        record.resolvedBy = 'pending'
        break
    }

    return record
  }

  /**
   * 记录冲突日志
   */
  private logConflict(record: ConflictRecord): void {
    this.conflictLog.push(record)
    if (this.conflictLog.length > DistributedService.MAX_CONFLICT_LOG) {
      this.conflictLog.splice(0, 1)
    }
    hilog.warn(0x0000, 'FinTrack',
      'Conflict detected: key=%{public}s local_v=%{public}d remote_v=%{public}d resolved=%{public}s',
      record.key, record.localVersion, record.remoteVersion, record.resolvedBy)
  }

  /**
   * 获取冲突日志
   */
  getConflictLog(): ConflictRecord[] {
    return this.conflictLog
  }

  /**
   * 清除冲突日志
   */
  clearConflictLog(): void {
    this.conflictLog = []
  }

  async deleteTransaction(id: string): Promise<void> {
    if (this.kvStore === null || !this.isInitialized) return
    try {
      await this.kvStore.delete(id)
    } catch (err) {
      hilog.error(0x0000, 'FinTrack', 'Distributed delete failed')
    }
  }

  async syncTransactions(): Promise<Transaction[]> {
    if (this.kvStore === null || !this.isInitialized) return []

    try {
      const entries = await this.kvStore.getEntries('')
      const transactions: Transaction[] = []

      for (let _idx1 = 0; _idx1 < entries.length; _idx1++) {
        const entry = entries[_idx1]
        try {
          if (typeof entry.value === 'string') {
            const txn = Transaction.fromJson(entry.value)
            if (txn.id.startsWith('txn_')) {
              transactions.push(txn)
            }
          }
        } catch {
          // Skip invalid entries
        }
      }

      transactions.sort((a: Transaction, b: Transaction) => b.date - a.date)
      return transactions
    } catch (err) {
      hilog.error(0x0000, 'FinTrack', 'Distributed sync failed')
      return []
    }
  }
}

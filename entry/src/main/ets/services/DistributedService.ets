
import { distributedKVStore } from '@kit.ArkData'
import { hilog } from '@kit.PerformanceAnalysisKit'
import { Constants } from '../constants/Constants'
import { Transaction } from '../models/Transaction'
import { Context } from '@kit.AbilityKit'

/**
 * 分布式数据同步服务
 * 基于 distributedKVStore 实现鸿蒙多设备数据同步
 *
 * 核心能力：
 * - 自动发现局域网内的同应用设备
 * - 数据变更实时推送到其他设备
 * - 支持数据冲突解决策略
 */
export class DistributedService {
  private static instance: DistributedService | null = null
  private kvStore: distributedKVStore.SingleKVStore | null = null
  private context: Context | null = null
  private isInitialized: boolean = false

  /** 数据变更回调 */
  private onDataChanged: ((transactions: Transaction[]) => void) | null = null

  private constructor() {}

  static getInstance(): DistributedService {
    if (DistributedService.instance === null) {
      DistributedService.instance = new DistributedService()
    }
    return DistributedService.instance
  }

  /**
   * 初始化分布式存储
   */
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
        kvStoreType: distributedKVStore.KvStoreType.SINGLE_VERSION,
        securityLevel: distributedKVStore.SecurityLevel.S1
      }

      this.kvStore = await kvManager.getKVStore(Constants.STORE_ID, options)
      this.registerDataChangeListener()
      this.isInitialized = true
      hilog.info(0x0000, 'FinTrack', 'Distributed KV store initialized')
    } catch (err) {
      hilog.error(0x0000, 'FinTrack', 'Distributed init failed: %{public}s', JSON.stringify(err))
    }
  }

  /**
   * 注册数据变更监听
   */
  private registerDataChangeListener(): void {
    if (this.kvStore === null) return

    const observer: distributedKVStore.SubscribeCallback = {
      onChange: (changeData: distributedKVStore.ChangeNotification) => {
        hilog.info(0x0000, 'FinTrack', 'Distributed data changed, entries: %{public}d',
          changeData.insertEntries.length + changeData.updateEntries.length + changeData.deleteEntries.length)

        // 触发数据刷新
        if (this.onDataChanged !== null) {
          this.syncTransactions().then((txns) => {
            if (this.onDataChanged !== null) {
              this.onDataChanged(txns)
            }
          })
        }
      }
    }

    this.kvStore.on('dataChange', distributedKVStore.SubscribeType.SUBSCRIBE_TYPE_ALL, observer)
  }

  /**
   * 设置数据变更回调
   */
  setDataChangedCallback(callback: (transactions: Transaction[]) => void): void {
    this.onDataChanged = callback
  }

  /**
   * 同步交易记录到分布式存储
   */
  async putTransaction(txn: Transaction): Promise<void> {
    if (this.kvStore === null || !this.isInitialized) return

    try {
      await this.kvStore.put(txn.id, txn.toJson())
      hilog.info(0x0000, 'FinTrack', 'Transaction synced to distributed store: %{public}s', txn.id)
    } catch (err) {
      hilog.error(0x0000, 'FinTrack', 'Distributed put failed: %{public}s', JSON.stringify(err))
    }
  }

  /**
   * 从分布式存储删除交易记录
   */
  async deleteTransaction(id: string): Promise<void> {
    if (this.kvStore === null || !this.isInitialized) return

    try {
      await this.kvStore.delete(id)
    } catch (err) {
      hilog.error(0x0000, 'FinTrack', 'Distributed delete failed: %{public}s', JSON.stringify(err))
    }
  }

  /**
   * 从分布式存储同步所有交易记录
   */
  async syncTransactions(): Promise<Transaction[]> {
    if (this.kvStore === null || !this.isInitialized) return []

    try {
      const entries = await this.kvStore.getEntries('')
      const transactions: Transaction[] = []

      for (const entry of entries) {
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

      transactions.sort((a, b) => b.date - a.date)
      return transactions
    } catch (err) {
      hilog.error(0x0000, 'FinTrack', 'Distributed sync failed: %{public}s', JSON.stringify(err))
      return []
    }
  }

  /**
   * 获取在线设备 ID 列表
   */
  async getOnlineDevices(): Promise<string[]> {
    if (this.kvStore === null) return []

    try {
      const devices = await this.kvStore.getDeviceId()
      return [devices]
    } catch {
      return []
    }
  }
}

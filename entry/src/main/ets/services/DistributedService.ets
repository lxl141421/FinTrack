import { distributedKVStore } from '@kit.ArkData'
import { hilog } from '@kit.PerformanceAnalysisKit'
import { Constants } from '../constants/Constants'
import { Transaction } from '../models/Transaction'
import { Context } from '@kit.AbilityKit'

/**
 * 分布式数据同步服务
 */
export class DistributedService {
  private static instance: DistributedService | null = null
  private kvStore: distributedKVStore.SingleKVStore | null = null
  private context: Context | null = null
  private isInitialized: boolean = false
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

  async putTransaction(txn: Transaction): Promise<void> {
    if (this.kvStore === null || !this.isInitialized) return
    try {
      await this.kvStore.put(txn.id, txn.toJson())
    } catch (err) {
      hilog.error(0x0000, 'FinTrack', 'Distributed put failed')
    }
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

      transactions.sort((a: Transaction, b: Transaction) => b.date - a.date)
      return transactions
    } catch (err) {
      hilog.error(0x0000, 'FinTrack', 'Distributed sync failed')
      return []
    }
  }
}

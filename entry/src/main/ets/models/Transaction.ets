
import { Constants } from '../constants/Constants'

/**
 * 交易记录数据模型
 */
export class Transaction {
  id: string = ''
  type: number = Constants.TYPE_EXPENSE  // 0: 收入, 1: 支出, 2: 转账
  amount: number = 0
  category: string = ''
  categoryName: string = ''
  note: string = ''
  date: number = Date.now()  // 时间戳
  accountId: string = 'default'
  toAccountId: string = ''   // 转账目标账户
  tags: string[] = []
  createdAt: number = Date.now()
  updatedAt: number = Date.now()

  /**
   * 生成唯一 ID
   */
  static generateId(): string {
    return `txn_${Date.now()}_${Math.random().toString(36).substr(2, 9)}`
  }

  /**
   * 创建新的交易记录
   */
  static create(
    type: number,
    amount: number,
    category: string,
    categoryName: string,
    note: string = '',
    date: number = Date.now()
  ): Transaction {
    const txn = new Transaction()
    txn.id = Transaction.generateId()
    txn.type = type
    txn.amount = Math.abs(amount)
    txn.category = category
    txn.categoryName = categoryName
    txn.note = note
    txn.date = date
    txn.createdAt = Date.now()
    txn.updatedAt = Date.now()
    return txn
  }

  /**
   * 序列化为 JSON 字符串（用于存储）
   */
  toJson(): string {
    return JSON.stringify({
      id: this.id,
      type: this.type,
      amount: this.amount,
      category: this.category,
      categoryName: this.categoryName,
      note: this.note,
      date: this.date,
      accountId: this.accountId,
      toAccountId: this.toAccountId,
      tags: this.tags,
      createdAt: this.createdAt,
      updatedAt: this.updatedAt
    })
  }

  /**
   * 从 JSON 反序列化
   */
  static fromJson(json: string): Transaction {
    const obj = JSON.parse(json) as Record<string, Object>
    const txn = new Transaction()
    txn.id = obj['id'] as string ?? ''
    txn.type = obj['type'] as number ?? 0
    txn.amount = obj['amount'] as number ?? 0
    txn.category = obj['category'] as string ?? ''
    txn.categoryName = obj['categoryName'] as string ?? ''
    txn.note = obj['note'] as string ?? ''
    txn.date = obj['date'] as number ?? Date.now()
    txn.accountId = obj['accountId'] as string ?? 'default'
    txn.toAccountId = obj['toAccountId'] as string ?? ''
    txn.tags = obj['tags'] as string[] ?? []
    txn.createdAt = obj['createdAt'] as number ?? Date.now()
    txn.updatedAt = obj['updatedAt'] as number ?? Date.now()
    return txn
  }

  /**
   * 判断是否为收入
   */
  isIncome(): boolean {
    return this.type === Constants.TYPE_INCOME
  }

  /**
   * 判断是否为支出
   */
  isExpense(): boolean {
    return this.type === Constants.TYPE_EXPENSE
  }

  /**
   * 获取带符号的金额（收入为正，支出为负）
   */
  getSignedAmount(): number {
    return this.isIncome() ? this.amount : -this.amount
  }
}

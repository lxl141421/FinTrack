
/**
 * 账户数据模型
 */
export class Account {
  id: string = 'default'
  name: string = '默认账户'
  type: string = 'cash'      // cash, bank, credit, investment
  balance: number = 0
  icon: string = '💰'
  color: string = '#007DFF'
  currency: string = 'CNY'
  isDefault: boolean = true

  static create(name: string, type: string, balance: number = 0): Account {
    const account = new Account()
    account.id = `acc_${Date.now()}_${Math.random().toString(36).substr(2, 6)}`
    account.name = name
    account.type = type
    account.balance = balance
    return account
  }

  toJson(): string {
    return JSON.stringify({
      id: this.id,
      name: this.name,
      type: this.type,
      balance: this.balance,
      icon: this.icon,
      color: this.color,
      currency: this.currency,
      isDefault: this.isDefault
    })
  }

  static fromJson(json: string): Account {
    const obj = JSON.parse(json) as Record<string, Object>
    const account = new Account()
    account.id = obj['id'] as string ?? 'default'
    account.name = obj['name'] as string ?? '默认账户'
    account.type = obj['type'] as string ?? 'cash'
    account.balance = obj['balance'] as number ?? 0
    account.icon = obj['icon'] as string ?? '💰'
    account.color = obj['color'] as string ?? '#007DFF'
    account.currency = obj['currency'] as string ?? 'CNY'
    account.isDefault = obj['isDefault'] as boolean ?? true
    return account
  }
}

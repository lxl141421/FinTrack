
import { Constants } from '../constants/Constants'

/**
 * 预算数据模型
 */
export class Budget {
  id: string = ''
  category: string = ''       // 空字符串表示总预算
  categoryName: string = '总预算'
  limitAmount: number = 0
  spentAmount: number = 0
  month: string = ''          // 格式: "2026-06"
  createdAt: number = Date.now()

  static create(category: string, categoryName: string, limitAmount: number, month: string): Budget {
    const budget = new Budget()
    budget.id = `budget_${Date.now()}_${Math.random().toString(36).substr(2, 6)}`
    budget.category = category
    budget.categoryName = categoryName
    budget.limitAmount = limitAmount
    budget.month = month
    return budget
  }

  /**
   * 剩余金额
   */
  getRemaining(): number {
    return this.limitAmount - this.spentAmount
  }

  /**
   * 使用百分比 (0-1+)
   */
  getUsagePercent(): number {
    if (this.limitAmount <= 0) return 0
    return this.spentAmount / this.limitAmount
  }

  /**
   * 是否已超支
   */
  isExceeded(): boolean {
    return this.spentAmount > this.limitAmount
  }

  /**
   * 是否接近超支（超过阈值）
   */
  isWarning(): boolean {
    return this.getUsagePercent() >= Constants.BUDGET_WARN_THRESHOLD && !this.isExceeded()
  }

  toJson(): string {
    return JSON.stringify({
      id: this.id,
      category: this.category,
      categoryName: this.categoryName,
      limitAmount: this.limitAmount,
      spentAmount: this.spentAmount,
      month: this.month,
      createdAt: this.createdAt
    })
  }

  static fromJson(json: string): Budget {
    const obj = JSON.parse(json) as Record<string, Object>
    const budget = new Budget()
    budget.id = obj['id'] as string ?? ''
    budget.category = obj['category'] as string ?? ''
    budget.categoryName = obj['categoryName'] as string ?? '总预算'
    budget.limitAmount = obj['limitAmount'] as number ?? 0
    budget.spentAmount = obj['spentAmount'] as number ?? 0
    budget.month = obj['month'] as string ?? ''
    budget.createdAt = obj['createdAt'] as number ?? Date.now()
    return budget
  }
}


import { StorageService } from './StorageService'
import { Budget } from '../models/Budget'
import { Transaction } from '../models/Transaction'
import { Constants } from '../constants/Constants'
import { DateUtils } from '../utils/DateUtils'
import { hilog } from '@kit.PerformanceAnalysisKit'

/**
 * 预算管理服务
 * 负责预算的创建、查询、更新和超支预警
 */
export class BudgetService {
  private storageService: StorageService

  constructor() {
    this.storageService = StorageService.getInstance()
  }

  /**
   * 获取当月所有预算，并自动计算已用金额
   */
  async getCurrentBudgets(): Promise<Budget[]> {
    const currentMonth = DateUtils.getCurrentMonth()
    const budgets = await this.storageService.queryBudgets(currentMonth)

    // 计算每个预算的已用金额
    const monthStart = DateUtils.getMonthStart()
    const monthEnd = DateUtils.getMonthEnd()

    for (const budget of budgets) {
      const txns = await this.storageService.queryTransactions(
        Constants.TYPE_EXPENSE,
        monthStart,
        monthEnd,
        budget.category
      )

      budget.spentAmount = 0
      for (const txn of txns) {
        budget.spentAmount += txn.amount
      }
      budget.spentAmount = Number(budget.spentAmount.toFixed(2))

      // 更新数据库中的 spentAmount
      await this.storageService.updateBudgetSpent(budget.id, budget.spentAmount)
    }

    return budgets
  }

  /**
   * 创建或更新预算
   */
  async setBudget(category: string, categoryName: string, limitAmount: number): Promise<Budget> {
    const currentMonth = DateUtils.getCurrentMonth()

    // 检查是否已存在该分类的预算
    const existing = await this.storageService.queryBudgets(currentMonth)
    const found = existing.find(b => b.category === category)

    if (found !== undefined) {
      // 更新
      found.limitAmount = limitAmount
      await this.storageService.updateBudgetSpent(found.id, found.spentAmount)
      return found
    } else {
      // 新建
      const budget = Budget.create(category, categoryName, limitAmount, currentMonth)
      await this.storageService.insertBudget(budget)
      return budget
    }
  }

  /**
   * 删除预算
   */
  async deleteBudget(id: string): Promise<void> {
    await this.storageService.deleteBudget(id)
  }

  /**
   * 获取预算预警列表（超支或接近超支）
   */
  async getBudgetAlerts(): Promise<Budget[]> {
    const budgets = await this.getCurrentBudgets()
    return budgets.filter(b => b.isExceeded() || b.isWarning())
  }

  /**
   * 计算本月总预算使用情况
   */
  async getOverallBudgetStatus(): Promise<{ totalLimit: number; totalSpent: number; percent: number }> {
    const budgets = await this.getCurrentBudgets()

    let totalLimit = 0
    let totalSpent = 0

    for (const budget of budgets) {
      if (budget.category === '') {
        // 总预算
        totalLimit += budget.limitAmount
        totalSpent += budget.spentAmount
      }
    }

    // 如果没有总预算，汇总各分类预算
    if (totalLimit === 0) {
      for (const budget of budgets) {
        totalLimit += budget.limitAmount
        totalSpent += budget.spentAmount
      }
    }

    const percent = totalLimit > 0 ? totalSpent / totalLimit : 0
    return { totalLimit, totalSpent, percent: Number(percent.toFixed(4)) }
  }

  /**
   * 获取本月每日支出趋势数据
   */
  async getDailyExpenseTrend(): Promise<number[]> {
    const now = new Date()
    const year = now.getFullYear()
    const month = now.getMonth()
    const daysInMonth = DateUtils.getDaysInMonth(year, month + 1)
    const dailyTotals: number[] = new Array(daysInMonth).fill(0)

    const monthStart = DateUtils.getMonthStart()
    const monthEnd = DateUtils.getMonthEnd()

    const txns = await this.storageService.queryTransactions(
      Constants.TYPE_EXPENSE,
      monthStart,
      monthEnd
    )

    for (const txn of txns) {
      const day = new Date(txn.date).getDate() - 1
      if (day >= 0 && day < daysInMonth) {
        dailyTotals[day] += txn.amount
      }
    }

    return dailyTotals.map(v => Number(v.toFixed(2)))
  }
}

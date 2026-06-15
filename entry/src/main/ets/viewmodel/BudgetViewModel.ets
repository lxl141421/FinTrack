import { Budget as BudgetModel } from '../models/Budget'
import { BudgetService } from '../services/BudgetService'
import { Validator, ValidationResult } from '../utils/Validator'
import { ErrorHandler, ErrorType } from '../utils/ErrorHandler'
import { LoadingState } from './TransactionViewModel'

/**
 * 预算 ViewModel
 * 使用 @ObservedV2 + @Trace 模式管理预算相关的响应式状态
 */
@ObservedV2
export class BudgetViewModel {
  /** 当前月份预算列表 */
  @Trace budgets: BudgetModel[] = []
  /** 总体预算状态 */
  @Trace overallStatus: { totalLimit: number; totalSpent: number; percent: number } = {
    totalLimit: 0, totalSpent: 0, percent: 0
  }
  /** 预警预算列表 */
  @Trace alertBudgets: BudgetModel[] = []
  /** 加载状态 */
  @Trace loadingState: LoadingState = LoadingState.IDLE
  /** 错误消息 */
  @Trace errorMessage: string = ''
  /** 是否显示添加对话框 */
  @Trace showAddDialog: boolean = false

  private budgetService = new BudgetService()

  /**
   * 加载预算数据
   */
  async loadBudgetData(): Promise<void> {
    this.loadingState = LoadingState.LOADING
    this.errorMessage = ''

    try {
      const [budgets, status, alerts] = await Promise.all([
        this.budgetService.getCurrentBudgets(),
        this.budgetService.getOverallBudgetStatus(),
        this.budgetService.getBudgetAlerts()
      ])

      this.budgets = budgets
      this.overallStatus = status
      this.alertBudgets = alerts
      this.loadingState = LoadingState.SUCCESS
    } catch (err) {
      const appError = ErrorHandler.handle(err as Object, ErrorType.DATABASE, '加载预算数据')
      this.errorMessage = appError.userMessage
      this.loadingState = LoadingState.ERROR
    }
  }

  /**
   * 验证并添加预算
   */
  async addBudget(category: string, categoryName: string, limitAmountStr: string): Promise<boolean> {
    // 验证金额
    const amountResult = Validator.validateBudgetAmount(limitAmountStr)
    if (!amountResult.valid) {
      ErrorHandler.handleWithToast(
        new Error(amountResult.errorMessage), ErrorType.VALIDATION, '预算金额验证')
      return false
    }

    try {
      await this.budgetService.setBudget(category, categoryName, Number(limitAmountStr))
      await this.loadBudgetData()
      return true
    } catch (err) {
      ErrorHandler.handleWithToast(err as Object, ErrorType.DATABASE, '添加预算')
      return false
    }
  }

  /**
   * 删除预算
   */
  async deleteBudget(id: string): Promise<boolean> {
    try {
      await this.budgetService.deleteBudget(id)
      this.budgets = this.budgets.filter(b => b.id !== id)
      return true
    } catch (err) {
      ErrorHandler.handleWithToast(err as Object, ErrorType.DATABASE, '删除预算')
      return false
    }
  }
}

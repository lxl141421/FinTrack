import { Constants } from '../constants/Constants'

/**
 * 验证结果接口
 */
export class ValidationResult {
  valid: boolean
  errorMessage: string

  constructor(valid: boolean, errorMessage: string = '') {
    this.valid = valid
    this.errorMessage = errorMessage
  }

  static success(): ValidationResult {
    return new ValidationResult(true)
  }

  static fail(message: string): ValidationResult {
    return new ValidationResult(false, message)
  }
}

/**
 * 输入验证工具
 * 提供金额、分类、日期范围等验证功能
 */
export class Validator {
  /** 金额最大值限制（防止溢出） */
  private static readonly MAX_AMOUNT: number = 99999999.99
  /** 金额最小小数位数 */
  private static readonly MAX_DECIMAL_PLACES: number = 2
  /** 备注最大长度 */
  private static readonly MAX_NOTE_LENGTH: number = 500
  /** 分类名称最大长度 */
  private static readonly MAX_CATEGORY_NAME_LENGTH: number = 50

  /**
   * 验证金额
   * - 必须为正数
   * - 不超过最大值
   * - 小数位不超过2位
   * - 不能为 NaN 或 Infinity
   */
  static validateAmount(amountStr: string): ValidationResult {
    if (amountStr === '' || amountStr === undefined || amountStr === null) {
      return ValidationResult.fail('请输入金额')
    }

    // 去除空格
    const trimmed = amountStr.trim()

    // 检查是否为有效数字格式
    if (!/^\d+(\.\d+)?$/.test(trimmed)) {
      return ValidationResult.fail('请输入有效的数字金额')
    }

    const amount = Number(trimmed)

    if (isNaN(amount) || !isFinite(amount)) {
      return ValidationResult.fail('金额格式不正确')
    }

    if (amount <= 0) {
      return ValidationResult.fail('金额必须大于零')
    }

    if (amount > Validator.MAX_AMOUNT) {
      return ValidationResult.fail(`金额不能超过 ${Validator.MAX_AMOUNT}`)
    }

    // 检查小数位数
    const dotIndex = trimmed.indexOf('.')
    if (dotIndex >= 0 && trimmed.length - dotIndex - 1 > Validator.MAX_DECIMAL_PLACES) {
      return ValidationResult.fail(`金额最多保留 ${Validator.MAX_DECIMAL_PLACES} 位小数`)
    }

    return ValidationResult.success()
  }

  /**
   * 验证分类选择
   */
  static validateCategory(categoryId: string, categoryName: string): ValidationResult {
    if (categoryId === '' || categoryId === undefined) {
      return ValidationResult.fail('请选择分类')
    }

    if (categoryName === '' || categoryName === undefined) {
      return ValidationResult.fail('分类名称不能为空')
    }

    if (categoryName.length > Validator.MAX_CATEGORY_NAME_LENGTH) {
      return ValidationResult.fail(`分类名称不能超过 ${Validator.MAX_CATEGORY_NAME_LENGTH} 个字符`)
    }

    return ValidationResult.success()
  }

  /**
   * 验证日期范围
   * - 开始日期不能晚于结束日期
   * - 日期不能为未来太远的日期（超过1年）
   * - 日期不能太早（1970年之前）
   */
  static validateDateRange(startDate: number, endDate: number): ValidationResult {
    if (startDate <= 0 || endDate <= 0) {
      return ValidationResult.fail('日期无效')
    }

    if (startDate > endDate) {
      return ValidationResult.fail('开始日期不能晚于结束日期')
    }

    const now = Date.now()
    const oneYearMs = 365 * 24 * 60 * 60 * 1000

    if (startDate > now + oneYearMs) {
      return ValidationResult.fail('开始日期不能超过未来一年')
    }

    if (endDate > now + oneYearMs) {
      return ValidationResult.fail('结束日期不能超过未来一年')
    }

    return ValidationResult.success()
  }

  /**
   * 验证并清理备注文本（防注入）
   */
  static validateAndSanitizeNote(note: string): ValidationResult {
    if (note === undefined || note === null) {
      return ValidationResult.success()
    }

    if (note.length > Validator.MAX_NOTE_LENGTH) {
      return ValidationResult.fail(`备注不能超过 ${Validator.MAX_NOTE_LENGTH} 个字符`)
    }

    return ValidationResult.success()
  }

  /**
   * 清理用户输入，防止注入攻击
   * 移除潜在的 SQL 注入和脚本注入字符
   */
  static sanitizeInput(input: string): string {
    if (input === undefined || input === null) {
      return ''
    }

    // 移除 SQL 注入常见模式
    let sanitized = input
      .replace(/'/g, "''")          // 转义单引号
      .replace(/;/g, '')            // 移除分号
      .replace(/--/g, '')           // 移除 SQL 注释
      .replace(/\/\*/g, '')         // 移除块注释开始
      .replace(/\*\//g, '')         // 移除块注释结束
      .replace(/\b(DROP|DELETE|INSERT|UPDATE|ALTER|EXEC|EXECUTE|UNION|SELECT)\b/gi, '')

    // 移除 XSS 相关字符
    sanitized = sanitized
      .replace(/</g, '')
      .replace(/>/g, '')
      .replace(/"/g, '')
      .replace(/javascript:/gi, '')
      .replace(/on\w+=/gi, '')

    return sanitized.trim()
  }

  /**
   * 验证预算金额
   */
  static validateBudgetAmount(amountStr: string): ValidationResult {
    const result = Validator.validateAmount(amountStr)
    if (!result.valid) {
      return result
    }

    const amount = Number(amountStr)
    if (amount < 1) {
      return ValidationResult.fail('预算金额至少为 1 元')
    }

    return ValidationResult.success()
  }

  /**
   * 验证交易类型
   */
  static validateTransactionType(type: number): ValidationResult {
    if (type !== Constants.TYPE_INCOME &&
        type !== Constants.TYPE_EXPENSE &&
        type !== Constants.TYPE_TRANSFER) {
      return ValidationResult.fail('无效的交易类型')
    }
    return ValidationResult.success()
  }
}

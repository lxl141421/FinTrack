import { hilog } from '@kit.PerformanceAnalysisKit'
import { promptAction } from '@kit.ArkUI'

/**
 * 错误类型枚举
 */
export enum ErrorType {
  /** 数据库操作错误 */
  DATABASE = 'DATABASE',
  /** 网络请求错误 */
  NETWORK = 'NETWORK',
  /** 数据验证错误 */
  VALIDATION = 'VALIDATION',
  /** 认证错误 */
  AUTH = 'AUTH',
  /** 分布式同步错误 */
  SYNC = 'SYNC',
  /** 未知错误 */
  UNKNOWN = 'UNKNOWN'
}

/**
 * 应用错误类
 * 封装错误类型、用户友好消息和原始错误信息
 */
export class AppError {
  type: ErrorType
  code: string
  message: string
  userMessage: string
  originalError: Object | null

  constructor(type: ErrorType, code: string, message: string, userMessage: string,
    originalError: Object | null = null) {
    this.type = type
    this.code = code
    this.message = message
    this.userMessage = userMessage
    this.originalError = originalError
  }
}

/**
 * 集中错误处理器
 * 提供统一的错误处理、日志记录和用户提示
 */
export class ErrorHandler {
  private static readonly TAG: string = 'FinTrack'
  private static errorLog: AppError[] = []
  private static readonly MAX_LOG_SIZE: number = 100

  /**
   * 处理错误：记录日志并返回用户友好消息
   * @param err 原始错误对象
   * @param type 错误类型
   * @param context 错误上下文描述
   * @returns AppError 包装后的错误
   */
  static handle(err: Object, type: ErrorType = ErrorType.UNKNOWN, context: string = ''): AppError {
    const appError = this.wrapError(err, type, context)

    // 记录到 hilog
    hilog.error(0x0000, this.TAG,
      '[%{public}s] %{public}s: %{public}s',
      appError.type, appError.message, context)

    // 存入内存日志
    this.addToLog(appError)

    return appError
  }

  /**
   * 处理错误并显示 Toast 提示
   */
  static handleWithToast(err: Object, type: ErrorType = ErrorType.UNKNOWN, context: string = ''): AppError {
    const appError = this.handle(err, type, context)
    promptAction.showToast({ message: appError.userMessage })
    return appError
  }

  /**
   * 将原始错误包装为 AppError
   */
  private static wrapError(err: Object, type: ErrorType, context: string): AppError {
    const errStr = this.safeStringify(err)

    switch (type) {
      case ErrorType.DATABASE:
        return new AppError(type, 'DB_ERR',
          `数据库错误: ${errStr}`, '数据操作失败，请稍后重试', err)
      case ErrorType.NETWORK:
        return new AppError(type, 'NET_ERR',
          `网络错误: ${errStr}`, '网络连接异常，请检查网络', err)
      case ErrorType.VALIDATION:
        return new AppError(type, 'VAL_ERR',
          `验证错误: ${errStr}`, errStr, err)
      case ErrorType.AUTH:
        return new AppError(type, 'AUTH_ERR',
          `认证错误: ${errStr}`, '认证失败，请重新验证', err)
      case ErrorType.SYNC:
        return new AppError(type, 'SYNC_ERR',
          `同步错误: ${errStr}`, '数据同步失败，请稍后重试', err)
      default:
        return new AppError(ErrorType.UNKNOWN, 'UNKNOWN',
          `未知错误: ${errStr}`, '操作失败，请稍后重试', err)
    }
  }

  /**
   * 安全序列化错误对象
   */
  private static safeStringify(err: Object): string {
    try {
      if (err instanceof Error) {
        return err.message || err.toString()
      }
      return JSON.stringify(err)
    } catch {
      return String(err)
    }
  }

  /**
   * 添加到内存错误日志
   */
  private static addToLog(error: AppError): void {
    this.errorLog.push(error)
    if (this.errorLog.length > this.MAX_LOG_SIZE) {
      this.errorLog.splice(0, this.errorLog.length - this.MAX_LOG_SIZE)
    }
  }

  /**
   * 获取最近的错误日志
   */
  static getRecentErrors(count: number = 10): AppError[] {
    return this.errorLog.slice(-count)
  }

  /**
   * 清空错误日志
   */
  static clearLog(): void {
    this.errorLog = []
  }

  /**
   * 包装异步操作，自动处理错误
   * @param fn 异步操作函数
   * @param type 错误类型
   * @param context 错误上下文
   * @param showToast 是否显示 Toast
   * @returns 操作结果，失败时返回 null
   */
  static async wrapAsync<T>(
    fn: () => Promise<T>,
    type: ErrorType = ErrorType.UNKNOWN,
    context: string = '',
    showToast: boolean = true
  ): Promise<T | null> {
    try {
      return await fn()
    } catch (err) {
      if (showToast) {
        this.handleWithToast(err as Object, type, context)
      } else {
        this.handle(err as Object, type, context)
      }
      return null
    }
  }
}

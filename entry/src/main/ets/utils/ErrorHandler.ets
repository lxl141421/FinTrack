import { hilog } from '@kit.PerformanceAnalysisKit'
import { promptAction } from '@kit.ArkUI'

/**
 * 错误类型枚举
 */
export enum ErrorType {
  DATABASE = 'DATABASE',
  NETWORK = 'NETWORK',
  VALIDATION = 'VALIDATION',
  AUTH = 'AUTH',
  SYNC = 'SYNC',
  UNKNOWN = 'UNKNOWN'
}

/**
 * 应用错误类
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
 */
export class ErrorHandler {
  private static readonly TAG: string = 'FinTrack'
  private static errorLog: AppError[] = []
  private static readonly MAX_LOG_SIZE: number = 100

  static handle(err: Object, type: ErrorType = ErrorType.UNKNOWN, context: string = ''): AppError {
    const appError = ErrorHandler.wrapError(err, type, context)
    hilog.error(0x0000, ErrorHandler.TAG,
      '[%{public}s] %{public}s: %{public}s',
      appError.type, appError.message, context)
    ErrorHandler.addToLog(appError)
    return appError
  }

  static handleWithToast(err: Object, type: ErrorType = ErrorType.UNKNOWN, context: string = ''): AppError {
    const appError = ErrorHandler.handle(err, type, context)
    promptAction.showToast({ message: appError.userMessage })
    return appError
  }

  private static wrapError(err: Object, type: ErrorType, context: string): AppError {
    const errStr = ErrorHandler.safeStringify(err)

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

  private static addToLog(error: AppError): void {
    ErrorHandler.errorLog.push(error)
    if (ErrorHandler.errorLog.length > ErrorHandler.MAX_LOG_SIZE) {
      ErrorHandler.errorLog.splice(0, ErrorHandler.errorLog.length - ErrorHandler.MAX_LOG_SIZE)
    }
  }

  static getRecentErrors(count: number = 10): AppError[] {
    return ErrorHandler.errorLog.slice(-count)
  }

  static clearLog(): void {
    ErrorHandler.errorLog = []
  }

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
        ErrorHandler.handleWithToast(err as Object, type, context)
      } else {
        ErrorHandler.handle(err as Object, type, context)
      }
      return null
    }
  }
}

import { hilog } from '@kit.PerformanceAnalysisKit'
import { preferences } from '@kit.ArkData'
import { deviceInfo } from '@kit.BasicServicesKit'
import { Context } from '@kit.AbilityKit'

/**
 * 崩溃报告条目
 */
export class CrashReport {
  timestamp: number = 0
  errorType: string = ''
  errorMessage: string = ''
  stackTrace: string = ''
  deviceModel: string = ''
  osVersion: string = ''
  appVersion: string = ''
  pageName: string = ''
  userAgent: string = ''

  toJson(): string {
    return JSON.stringify({
      timestamp: this.timestamp,
      errorType: this.errorType,
      errorMessage: this.errorMessage,
      stackTrace: this.stackTrace,
      deviceModel: this.deviceModel,
      osVersion: this.osVersion,
      appVersion: this.appVersion,
      pageName: this.pageName
    })
  }

  static fromJson(json: string): CrashReport {
    const report = new CrashReport()
    try {
      const obj = JSON.parse(json) as Record<string, Object>
      report.timestamp = obj['timestamp'] as number || 0
      report.errorType = obj['errorType'] as string || ''
      report.errorMessage = obj['errorMessage'] as string || ''
      report.stackTrace = obj['stackTrace'] as string || ''
      report.deviceModel = obj['deviceModel'] as string || ''
      report.osVersion = obj['osVersion'] as string || ''
      report.appVersion = obj['appVersion'] as string || ''
      report.pageName = obj['pageName'] as string || ''
    } catch (e) {
      // ignore parse errors
    }
    return report
  }
}

/**
 * 崩溃上报服务
 *
 * 功能：
 * - 全局异常捕获
 * - 崩溃日志持久化（Preferences）
 * - 设备信息采集
 * - 崩溃统计与查询
 */
export class CrashReporter {
  private static instance: CrashReporter | null = null
  private static readonly TAG: string = 'FinTrack'
  private static readonly STORE_NAME: string = 'crash_reports'
  private static readonly KEY_REPORTS: string = 'crash_log'
  private static readonly MAX_REPORTS: number = 20
  private static readonly APP_VERSION: string = '1.0.0'

  private context: Context | null = null
  private prefStore: preferences.Preferences | null = null
  private isInitialized: boolean = false
  private crashCount: number = 0

  private constructor() {}

  static getInstance(): CrashReporter {
    if (CrashReporter.instance === null) {
      CrashReporter.instance = new CrashReporter()
    }
    return CrashReporter.instance
  }

  /**
   * 初始化崩溃上报服务
   */
  async init(context: Context): Promise<void> {
    this.context = context
    try {
      this.prefStore = await preferences.getPreferences(context, CrashReporter.STORE_NAME)
      this.isInitialized = true

      // 检查是否有未上报的崩溃
      const reports = await this.loadReports()
      this.crashCount = reports.length
      if (reports.length > 0) {
        hilog.warn(CrashReporter.TAG, 'Found %{public}d unreported crashes', reports.length)
      }
    } catch (err) {
      hilog.error(CrashReporter.TAG, 'CrashReporter init failed')
    }
  }

  /**
   * 记录崩溃报告
   */
  async report(error: Error, pageName: string = ''): Promise<void> {
    const report = new CrashReport()
    report.timestamp = Date.now()
    report.errorType = error.name || 'Error'
    report.errorMessage = error.message || 'Unknown error'
    report.stackTrace = error.stack || ''
    report.pageName = pageName
    report.appVersion = CrashReporter.APP_VERSION

    // 采集设备信息
    try {
      report.deviceModel = deviceInfo.productModel
      report.osVersion = deviceInfo.osReleaseType
    } catch (e) {
      report.deviceModel = 'Unknown'
      report.osVersion = 'Unknown'
    }

    hilog.error(CrashReporter.TAG,
      'CRASH: [%{public}s] %{public}s at %{public}s',
      report.errorType, report.errorMessage, report.pageName)

    await this.saveReport(report)
  }

  /**
   * 保存崩溃报告到 Preferences
   */
  private async saveReport(report: CrashReport): Promise<void> {
    if (!this.isInitialized || this.prefStore === null) return

    try {
      const reports = await this.loadReports()
      reports.push(report)

      // 只保留最近的报告
      while (reports.length > CrashReporter.MAX_REPORTS) {
        reports.splice(0, 1)
      }

      const jsonArr: string[] = []
      for (let i = 0; i < reports.length; i++) {
        jsonArr.push(reports[i].toJson())
      }
      await this.prefStore.put(CrashReporter.KEY_REPORTS, JSON.stringify(jsonArr))
      await this.prefStore.flush()
      this.crashCount = reports.length
    } catch (err) {
      hilog.error(CrashReporter.TAG, 'Failed to save crash report')
    }
  }

  /**
   * 加载所有崩溃报告
   */
  async loadReports(): Promise<CrashReport[]> {
    if (!this.isInitialized || this.prefStore === null) return []

    try {
      const json = await this.prefStore.get(CrashReporter.KEY_REPORTS, '[]') as string
      const arr = JSON.parse(json) as string[]
      const reports: CrashReport[] = []
      for (let i = 0; i < arr.length; i++) {
        reports.push(CrashReport.fromJson(arr[i]))
      }
      return reports
    } catch (err) {
      return []
    }
  }

  /**
   * 清除所有崩溃报告
   */
  async clearReports(): Promise<void> {
    if (!this.isInitialized || this.prefStore === null) return

    try {
      await this.prefStore.put(CrashReporter.KEY_REPORTS, '[]')
      await this.prefStore.flush()
      this.crashCount = 0
    } catch (err) {
      hilog.error(CrashReporter.TAG, 'Failed to clear crash reports')
    }
  }

  /**
   * 获取崩溃统计
   */
  getCrashCount(): number {
    return this.crashCount
  }

  /**
   * 包装异步函数，捕获异常并上报
   */
  async wrapAsync<T>(
    fn: () => Promise<T>,
    pageName: string = '',
    fallback: T | null = null
  ): Promise<T | null> {
    try {
      return await fn()
    } catch (err) {
      await this.report(err as Error, pageName)
      return fallback
    }
  }
}

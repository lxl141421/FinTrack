import { hilog } from '@kit.PerformanceAnalysisKit'

/**
 * 性能监控工具
 *
 * 监控指标：
 * - 页面加载时间（首屏渲染耗时）
 * - 帧率（FPS）
 * - 内存占用
 * - 接口响应时间
 *
 * 用于面试展示性能优化数据
 */
export class PerformanceMonitor {
  private static instance: PerformanceMonitor | null = null
  private static readonly TAG: string = 'FinTrack-Perf'

  /** 页面加载时间记录 */
  private pageLoadTimes: Map<string, number> = new Map()
  /** 接口耗时记录 */
  private apiTimes: Map<string, number[]> = new Map()
  /** 帧率采样 */
  private frameTimestamps: number[] = []
  private fpsMonitoring: boolean = false

  /** 性能报告 */
  private reports: PerformanceReport[] = []

  private constructor() {}

  static getInstance(): PerformanceMonitor {
    if (PerformanceMonitor.instance === null) {
      PerformanceMonitor.instance = new PerformanceMonitor()
    }
    return PerformanceMonitor.instance
  }

  // ==================== 页面加载监控 ====================

  /**
   * 标记页面开始加载
   * @param pageName 页面名称
   */
  markPageStart(pageName: string): void {
    this.pageLoadTimes.set(`start_${pageName}`, Date.now())
    hilog.info(0x0000, PerformanceMonitor.TAG, 'Page start: %{public}s', pageName)
  }

  /**
   * 标记页面加载完成
   * @param pageName 页面名称
   * @returns 加载耗时 (ms)
   */
  markPageEnd(pageName: string): number {
    const startTime = this.pageLoadTimes.get(`start_${pageName}`)
    if (startTime === undefined) return -1

    const duration = Date.now() - startTime
    this.pageLoadTimes.set(`duration_${pageName}`, duration)

    hilog.info(0x0000, PerformanceMonitor.TAG,
      'Page loaded: %{public}s in %{public}dms', pageName, duration)

    this.addReport({
      type: 'page_load',
      name: pageName,
      value: duration,
      unit: 'ms',
      timestamp: Date.now()
    })

    return duration
  }

  // ==================== 接口耗时监控 ====================

  /**
   * 包装异步接口，自动监控耗时
   * @param apiName 接口名称
   * @param fn 异步函数
   * @returns 原始返回值
   */
  async measureApi<T>(apiName: string, fn: () => Promise<T>): Promise<T> {
    const start = Date.now()
    try {
      const result = await fn()
      const duration = Date.now() - start
      this.recordApiTime(apiName, duration)
      return result
    } catch (err) {
      const duration = Date.now() - start
      this.recordApiTime(apiName, duration)
      throw err
    }
  }

  private recordApiTime(apiName: string, duration: number): void {
    if (!this.apiTimes.has(apiName)) {
      this.apiTimes.set(apiName, [])
    }
    this.apiTimes.get(apiName)!.push(duration)

    hilog.info(0x0000, PerformanceMonitor.TAG,
      'API %{public}s: %{public}dms', apiName, duration)
  }

  /**
   * 获取接口平均耗时
   */
  getApiAvgTime(apiName: string): number {
    const times = this.apiTimes.get(apiName)
    if (times === undefined || times.length === 0) return 0
    let sum = 0
    for (let i = 0; i < times.length; i++) {
      sum += times[i]
    }
    return Math.round(sum / times.length)
  }

  // ==================== 帧率监控 ====================

  /**
   * 记录一帧（每帧调用一次）
   */
  recordFrame(): void {
    const now = Date.now()
    this.frameTimestamps.push(now)

    // 只保留最近 60 帧
    if (this.frameTimestamps.length > 60) {
      this.frameTimestamps.shift()
    }
  }

  /**
   * 计算当前 FPS
   * @returns 帧率 (0-120)
   */
  getCurrentFPS(): number {
    if (this.frameTimestamps.length < 2) return 0

    const first = this.frameTimestamps[0]
    const last = this.frameTimestamps[this.frameTimestamps.length - 1]
    const duration = last - first

    if (duration <= 0) return 0

    const fps = Math.round((this.frameTimestamps.length - 1) * 1000 / duration)
    return Math.min(fps, 120)
  }

  // ==================== 内存监控 ====================

  /**
   * 获取内存使用信息
   * 注意：鸿蒙 NEXT 不直接暴露内存 API，这里记录 GC 事件
   */
  logMemoryInfo(context: string): void {
    hilog.info(0x0000, PerformanceMonitor.TAG, 'Memory check at: %{public}s', context)
    this.addReport({
      type: 'memory',
      name: context,
      value: 0,
      unit: 'info',
      timestamp: Date.now()
    })
  }

  // ==================== 报告生成 ====================

  private addReport(report: PerformanceReport): void {
    this.reports.push(report)
    // 只保留最近 100 条
    if (this.reports.length > 100) {
      this.reports.splice(0, this.reports.length - 100)
    }
  }

  /**
   * 生成性能报告摘要
   */
  getSummary(): PerformanceSummary {
    const pageLoads: Record<string, number> = {}
    for (const entry of this.pageLoadTimes.entries()) {
      const key = entry[0]
      const value = entry[1]
      if (key.startsWith('duration_')) {
        const pageName = key.replace('duration_', '')
        pageLoads[pageName] = value
      }
    }

    const apiSummary: Record<string, number> = {}
    for (const entry of this.apiTimes.entries()) {
      apiSummary[entry[0]] = this.getApiAvgTime(entry[0])
    }

    return {
      pageLoads: pageLoads,
      apiAvgTimes: apiSummary,
      currentFPS: this.getCurrentFPS(),
      totalReports: this.reports.length
    }
  }

  /**
   * 打印性能报告到日志
   */
  printReport(): void {
    const summary = this.getSummary()
    hilog.info(0x0000, PerformanceMonitor.TAG, '=== Performance Report ===')
    hilog.info(0x0000, PerformanceMonitor.TAG, 'Page loads: %{public}s', JSON.stringify(summary.pageLoads))
    hilog.info(0x0000, PerformanceMonitor.TAG, 'API avg: %{public}s', JSON.stringify(summary.apiAvgTimes))
    hilog.info(0x0000, PerformanceMonitor.TAG, 'FPS: %{public}d', summary.currentFPS)
  }

  /**
   * 重置所有数据
   */
  reset(): void {
    this.pageLoadTimes.clear()
    this.apiTimes.clear()
    this.frameTimestamps = []
    this.reports = []
  }
}

interface PerformanceReport {
  type: string  // 'page_load' | 'api' | 'memory'
  name: string
  value: number
  unit: string
  timestamp: number
}

export interface PerformanceSummary {
  pageLoads: Record<string, number>
  apiAvgTimes: Record<string, number>
  currentFPS: number
  totalReports: number
}

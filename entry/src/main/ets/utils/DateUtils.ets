
/**
 * 日期工具类
 */
export class DateUtils {
  /**
   * 获取当月第一天的时间戳
   */
  static getMonthStart(date: Date = new Date()): number {
    const d = new Date(date.getFullYear(), date.getMonth(), 1)
    return d.getTime()
  }

  /**
   * 获取当月最后一天的时间戳
   */
  static getMonthEnd(date: Date = new Date()): number {
    const d = new Date(date.getFullYear(), date.getMonth() + 1, 0, 23, 59, 59, 999)
    return d.getTime()
  }

  /**
   * 格式化日期
   * @param timestamp 时间戳
   * @param format 格式字符串 (YYYY-MM-DD HH:mm:ss)
   */
  static format(timestamp: number, format: string = 'YYYY-MM-DD'): string {
    const date = new Date(timestamp)
    const year = date.getFullYear().toString()
    const month = (date.getMonth() + 1).toString().padStart(2, '0')
    const day = date.getDate().toString().padStart(2, '0')
    const hours = date.getHours().toString().padStart(2, '0')
    const minutes = date.getMinutes().toString().padStart(2, '0')
    const seconds = date.getSeconds().toString().padStart(2, '0')

    return format
      .replace('YYYY', year)
      .replace('MM', month)
      .replace('DD', day)
      .replace('HH', hours)
      .replace('mm', minutes)
      .replace('ss', seconds)
  }

  /**
   * 获取本月的字符串标识 (如 "2026-06")
   */
  static getCurrentMonth(): string {
    const now = new Date()
    return `${now.getFullYear()}-${(now.getMonth() + 1).toString().padStart(2, '0')}`
  }

  /**
   * 判断时间戳是否在本月
   */
  static isCurrentMonth(timestamp: number): boolean {
    const now = new Date()
    const date = new Date(timestamp)
    return date.getFullYear() === now.getFullYear() && date.getMonth() === now.getMonth()
  }

  /**
   * 判断时间戳是否在今天
   */
  static isToday(timestamp: number): boolean {
    const now = new Date()
    const date = new Date(timestamp)
    return date.getFullYear() === now.getFullYear() &&
      date.getMonth() === now.getMonth() &&
      date.getDate() === now.getDate()
  }

  /**
   * 获取友好的时间描述
   */
  static getRelativeTime(timestamp: number): string {
    if (DateUtils.isToday(timestamp)) {
      return DateUtils.format(timestamp, 'HH:mm')
    }

    const now = new Date()
    const date = new Date(timestamp)
    const diffDays = Math.floor((now.getTime() - timestamp) / (1000 * 60 * 60 * 24))

    if (diffDays === 1) return '昨天'
    if (diffDays === 2) return '前天'
    if (diffDays < 7) return `${diffDays}天前`
    if (now.getFullYear() === date.getFullYear()) {
      return DateUtils.format(timestamp, 'MM-DD')
    }
    return DateUtils.format(timestamp, 'YYYY-MM-DD')
  }

  /**
   * 获取最近 N 个月的月份列表
   */
  static getRecentMonths(n: number): string[] {
    const months: string[] = []
    const now = new Date()
    for (let i = 0; i < n; i++) {
      const d = new Date(now.getFullYear(), now.getMonth() - i, 1)
      months.push(`${d.getFullYear()}-${(d.getMonth() + 1).toString().padStart(2, '0')}`)
    }
    return months
  }

  /**
   * 获取指定月份的天数
   */
  static getDaysInMonth(year: number, month: number): number {
    return new Date(year, month, 0).getDate()
  }

  /**
   * 获取星期几的中文名
   */
  static getWeekdayName(timestamp: number): string {
    const names = ['日', '一', '二', '三', '四', '五', '六']
    return '周' + names[new Date(timestamp).getDay()]
  }
}

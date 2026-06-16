import { notificationManager } from '@kit.NotificationKit'
import { hilog } from '@kit.PerformanceAnalysisKit'

/**
 * 通知服务 - 预算预警、交易提醒、月度报告
 */

export enum NotificationLevel {
  LOW = 0,
  DEFAULT = 1,
  HIGH = 2
}

interface NotificationOptions {
  title: string
  body: string
  channelId: string
  channelName: string
  priority: NotificationLevel
}

export class NotificationService {
  private static instance: NotificationService | null = null
  private static nextId: number = 1000
  private sentBudgetAlerts: Set<string> = new Set()

  private constructor() {}

  static getInstance(): NotificationService {
    if (NotificationService.instance === null) {
      NotificationService.instance = new NotificationService()
    }
    return NotificationService.instance
  }

  async requestPermission(): Promise<boolean> {
    try {
      await notificationManager.requestEnableNotification()
      return true
    } catch (err) {
      hilog.warn(0x0000, 'FinTrack', 'Notification permission denied')
      return false
    }
  }

  async sendBudgetAlert(
    categoryName: string,
    spent: number,
    limit: number,
    percent: number
  ): Promise<void> {
    const alertKey = `${categoryName}_${new Date().getMonth()}`
    if (this.sentBudgetAlerts.has(alertKey)) return

    const title = percent >= 100 ? '预算超支！' : '预算预警'
    const body = percent >= 100
      ? `${categoryName}本月已超支 ${( spent - limit).toFixed(2)}元`
      : `${categoryName}本月已使用 ${percent.toFixed(0)}%`

    await this.sendNotification({
      title: title,
      body: body,
      channelId: 'budget_alert',
      channelName: '预算预警',
      priority: percent >= 100 ? NotificationLevel.HIGH : NotificationLevel.DEFAULT
    })

    this.sentBudgetAlerts.add(alertKey)
  }

  async sendLargeTransactionAlert(
    amount: number,
    category: string,
    isExpense: boolean
  ): Promise<void> {
    const type = isExpense ? '支出' : '收入'
    await this.sendNotification({
      title: `大额${type}提醒`,
      body: `已记录一笔 ${amount.toFixed(2)} 元的${category}${type}`,
      channelId: 'transaction_alert',
      channelName: '交易提醒',
      priority: NotificationLevel.LOW
    })
  }

  async sendMonthlySummary(income: number, expense: number, balance: number): Promise<void> {
    const status = balance >= 0 ? '有结余' : '超支'
    await this.sendNotification({
      title: '月度财务摘要',
      body: `收入 ${income.toFixed(2)} | 支出 ${expense.toFixed(2)} | ${status} ${Math.abs(balance).toFixed(2)}`,
      channelId: 'monthly_report',
      channelName: '月度报告',
      priority: NotificationLevel.DEFAULT
    })
  }

  private async sendNotification(options: NotificationOptions): Promise<void> {
    try {
      const request: notificationManager.NotificationRequest = {
        id: NotificationService.nextId++,
        content: {
          notificationContentType: notificationManager.ContentType.NOTIFICATION_CONTENT_BASIC_TEXT,
          normal: {
            title: options.title,
            text: options.body
          }
        }
      }
      await notificationManager.publish(request)
      hilog.info(0x0000, 'FinTrack', 'Notification sent: %{public}s', options.title)
    } catch (err) {
      hilog.error(0x0000, 'FinTrack', 'Failed to send notification')
    }
  }

  async clearAll(): Promise<void> {
    try {
      await notificationManager.cancelAll()
      this.sentBudgetAlerts.clear()
    } catch (err) {
      hilog.error(0x0000, 'FinTrack', 'Failed to clear notifications')
    }
  }

  resetMonthlyAlerts(): void {
    this.sentBudgetAlerts.clear()
  }
}

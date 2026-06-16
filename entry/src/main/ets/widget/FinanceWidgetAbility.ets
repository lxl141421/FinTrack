import { FormExtensionAbility, formBindingData } from '@kit.FormKit'
import { hilog } from '@kit.PerformanceAnalysisKit'
import { Want } from '@kit.AbilityKit'

export default class FinanceWidgetAbility extends FormExtensionAbility {
  onCreate(formId: string): formBindingData.FormBindingData {
    hilog.info(0x0000, 'FinTrack', 'Widget created: %{public}s', formId)
    const data: Record<string, Object> = {
      'income': '0.00',
      'expense': '0.00',
      'balance': '0.00',
      'lastUpdate': FinanceWidgetAbility.formatTime(Date.now())
    }
    return formBindingData.createFormBindingData(data)
  }

  onAddForm(want: Want): formBindingData.FormBindingData {
    hilog.info(0x0000, 'FinTrack', 'Widget addForm')
    const data: Record<string, Object> = {
      'income': '0.00',
      'expense': '0.00',
      'balance': '0.00',
      'lastUpdate': FinanceWidgetAbility.formatTime(Date.now())
    }
    return formBindingData.createFormBindingData(data)
  }

  onFormEvent(formId: string, message: string): void {
    hilog.info(0x0000, 'FinTrack', 'Widget event: %{public}s', formId)
  }

  onDestroy(formId: string): void {
    hilog.info(0x0000, 'FinTrack', 'Widget destroyed: %{public}s', formId)
  }

  onVisibilityChange(newStatus: Record<string, number>): void {
    hilog.info(0x0000, 'FinTrack', 'Widget visibility changed')
  }

  private static formatTime(timestamp: number): string {
    const date = new Date(timestamp)
    const month = (date.getMonth() + 1).toString().padStart(2, '0')
    const day = date.getDate().toString().padStart(2, '0')
    const hour = date.getHours().toString().padStart(2, '0')
    const minute = date.getMinutes().toString().padStart(2, '0')
    return `${month}-${day} ${hour}:${minute}`
  }
}

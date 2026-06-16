
import { AbilityConstant, UIAbility, Want } from '@kit.AbilityKit'
import { hilog } from '@kit.PerformanceAnalysisKit'
import { window } from '@kit.ArkUI'
import { SensorService, GripState } from '../services/SensorService'
import { NotificationService } from '../services/NotificationService'
import { ThemeManager, ThemeMode } from '../theme/Theme'
import { StorageService } from '../services/StorageService'
import { Constants } from '../constants/Constants'

export default class EntryAbility extends UIAbility {
  private sensorService = SensorService.getInstance()
  private notificationService = NotificationService.getInstance()
  private themeManager = ThemeManager.getInstance()
  private storageService = StorageService.getInstance()

  async onCreate(want: Want, launchParam: AbilityConstant.LaunchParam): Promise<void> {
    hilog.info(0x0000, 'FinTrack', 'Ability onCreate')

    // 初始化存储服务
    await this.storageService.init(this.context)

    // 请求通知权限
    await this.notificationService.requestPermission()
  }

  onDestroy(): void {
    hilog.info(0x0000, 'FinTrack', 'Ability onDestroy')
    // 停止所有传感器
    this.sensorService.stopAll()
  }

  onWindowStageCreate(windowStage: window.WindowStage): void {
    hilog.info(0x0000, 'FinTrack', 'Ability onWindowStageCreate')
    windowStage.loadContent('pages/Index', (err) => {
      if (err.code) {
        hilog.error(0x0000, 'FinTrack', 'Failed to load content. Cause: %{public}s', JSON.stringify(err))
        return
      }
      hilog.info(0x0000, 'FinTrack', 'Succeeded in loading content.')
    })

    // 初始化传感器服务
    this.initSensors()
  }

  onWindowStageDestroy(): void {
    hilog.info(0x0000, 'FinTrack', 'Ability onWindowStageDestroy')
  }

  onForeground(): void {
    hilog.info(0x0000, 'FinTrack', 'Ability onForeground')
    // 回到前台时重新启动传感器
    this.initSensors()
  }

  onBackground(): void {
    hilog.info(0x0000, 'FinTrack', 'Ability onBackground')
    // 进入后台时停止传感器以省电
    this.sensorService.stopAll()
  }

  /**
   * 初始化传感器服务
   * 根据用户设置决定启用哪些传感器
   */
  private async initSensors(): Promise<void> {
    try {
      // 读取用户主题设置
      const themeMode = await this.storageService.getPreferenceInt(Constants.PREF_THEME, Constants.THEME_SYSTEM)

      // 环境光传感器：仅在 AUTO_SENSOR 模式下启用
      if (themeMode === ThemeMode.AUTO_SENSOR) {
        this.sensorService.onLightChange((lux: number, isDark: boolean) => {
          this.themeManager.onAmbientLightChange(lux, isDark)
        })
        this.sensorService.startLightSensor()
        hilog.info(0x0000, 'FinTrack', 'Light sensor enabled (AUTO_SENSOR mode)')
      }

      // 距离传感器：始终启用（隐私保护）
      this.sensorService.onProximityChange((blocked: boolean) => {
        this.themeManager.setPrivacyMode(blocked)
      })
      this.sensorService.startProximitySensor()

      // 握持检测：始终启用（自适应布局）
      this.sensorService.onGripChange((state: GripState) => {
        this.themeManager.setGripState(state)
      })
      this.sensorService.startGripDetection()

      hilog.info(0x0000, 'FinTrack', 'Sensor services initialized')
    } catch (err) {
      hilog.error(0x0000, 'FinTrack', 'Failed to init sensors: %{public}s', JSON.stringify(err))
    }
  }
}

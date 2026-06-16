
import { AbilityConstant, UIAbility, Want } from '@kit.AbilityKit'
import { hilog } from '@kit.PerformanceAnalysisKit'
import { window } from '@kit.ArkUI'
import { SensorService, GripState } from '../services/SensorService'
import { NotificationService } from '../services/NotificationService'
import { PerformanceMonitor } from '../utils/PerformanceMonitor'
import { ThemeManager, ThemeMode } from '../theme/Theme'
import { StorageService } from '../services/StorageService'
import { Constants } from '../constants/Constants'

export default class EntryAbility extends UIAbility {
  private sensorService = SensorService.getInstance()
  private notificationService = NotificationService.getInstance()
  private perfMonitor = PerformanceMonitor.getInstance()
  private themeManager = ThemeManager.getInstance()
  private storageService = StorageService.getInstance()

  async onCreate(want: Want, launchParam: AbilityConstant.LaunchParam): Promise<void> {
    this.perfMonitor.markPageStart('AppLaunch')
    hilog.info(0x0000, 'FinTrack', 'Ability onCreate')

    await this.storageService.init(this.context)
    await this.notificationService.requestPermission()
  }

  onDestroy(): void {
    hilog.info(0x0000, 'FinTrack', 'Ability onDestroy')
    this.sensorService.stopAll()
    this.perfMonitor.printReport()
  }

  onWindowStageCreate(windowStage: window.WindowStage): void {
    hilog.info(0x0000, 'FinTrack', 'Ability onWindowStageCreate')
    windowStage.loadContent('pages/Index', (err) => {
      if (err.code) {
        hilog.error(0x0000, 'FinTrack', 'Failed to load content')
        return
      }
      hilog.info(0x0000, 'FinTrack', 'Succeeded in loading content.')
      const launchTime = this.perfMonitor.markPageEnd('AppLaunch')
      hilog.info(0x0000, 'FinTrack', 'App launch time: %{public}dms', launchTime)
    })

    this.initSensors()
  }

  onWindowStageDestroy(): void {
    hilog.info(0x0000, 'FinTrack', 'Ability onWindowStageDestroy')
  }

  onForeground(): void {
    hilog.info(0x0000, 'FinTrack', 'Ability onForeground')
    this.initSensors()
  }

  onBackground(): void {
    hilog.info(0x0000, 'FinTrack', 'Ability onBackground')
    this.sensorService.stopAll()
  }

  private async initSensors(): Promise<void> {
    try {
      const themeMode = await this.storageService.getPreferenceInt(Constants.PREF_THEME, Constants.THEME_SYSTEM)

      if (themeMode === ThemeMode.AUTO_SENSOR) {
        this.sensorService.onLightChange((lux: number, isDark: boolean) => {
          this.themeManager.onAmbientLightChange(lux, isDark)
        })
        this.sensorService.startLightSensor()
      }

      this.sensorService.onProximityChange((blocked: boolean) => {
        this.themeManager.setPrivacyMode(blocked)
      })
      this.sensorService.startProximitySensor()

      this.sensorService.onGripChange((state: GripState) => {
        this.themeManager.setGripState(state)
      })
      this.sensorService.startGripDetection()

      hilog.info(0x0000, 'FinTrack', 'Sensor services initialized')
    } catch (err) {
      hilog.error(0x0000, 'FinTrack', 'Failed to init sensors')
    }
  }
}

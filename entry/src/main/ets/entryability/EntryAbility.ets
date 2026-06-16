import { AbilityConstant, UIAbility, Want } from '@kit.AbilityKit'
import { hilog } from '@kit.PerformanceAnalysisKit'
import { window } from '@kit.ArkUI'
import { SensorService, GripState } from '../services/SensorService'
import { NotificationService } from '../services/NotificationService'
import { PerformanceMonitor } from '../utils/PerformanceMonitor'
import { ThemeManager, ThemeMode } from '../theme/Theme'
import { StorageService } from '../services/StorageService'
import { CrashReporter } from '../services/CrashReporter'
import { Constants } from '../constants/Constants'

export default class EntryAbility extends UIAbility {
  private sensorService = SensorService.getInstance()
  private notificationService = NotificationService.getInstance()
  private perfMonitor = PerformanceMonitor.getInstance()
  private themeManager = ThemeManager.getInstance()
  private storageService = StorageService.getInstance()
  private crashReporter = CrashReporter.getInstance()

  async onCreate(want: Want, launchParam: AbilityConstant.LaunchParam): Promise<void> {
    this.perfMonitor.markPageStart('AppLaunch')
    hilog.info(0x0000, 'FinTrack', 'Ability onCreate')
  }

  onDestroy(): void {
    hilog.info(0x0000, 'FinTrack', 'Ability onDestroy')
    this.sensorService.stopAll()
    this.perfMonitor.printReport()
  }

  async onWindowStageCreate(windowStage: window.WindowStage): Promise<void> {
    hilog.info(0x0000, 'FinTrack', 'Ability onWindowStageCreate')

    // 初始化崩溃上报（最先初始化，确保能捕获后续所有异常）
    await this.crashReporter.init(this.context)
    hilog.info(0x0000, 'FinTrack', 'CrashReporter initialized')

    // 初始化存储
    await this.storageService.init(this.context)
    hilog.info(0x0000, 'FinTrack', 'StorageService initialized')

    await this.notificationService.requestPermission()

    windowStage.loadContent('pages/Index', (err) => {
      if (err.code) {
        hilog.error(0x0000, 'FinTrack', 'Failed to load content')
        this.crashReporter.report(
          new Error(`loadContent failed: ${err.code}`),
          'EntryAbility'
        )
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
      this.crashReporter.report(err as Error, 'initSensors')
    }
  }
}

import { StorageService } from '../services/StorageService'
import { AuthService } from '../services/AuthService'
import { DistributedService } from '../services/DistributedService'
import { NotificationService } from '../services/NotificationService'
import { Constants } from '../constants/Constants'
import { ThemeFont, ThemeRadius, ThemeSpacing, ThemeMode, ThemeManager } from '../theme/Theme'
import { promptAction, router } from '@kit.ArkUI'
import { hilog } from '@kit.PerformanceAnalysisKit'

@Entry
@Component
struct Settings {
  @State themeMode: number = Constants.THEME_SYSTEM
  @State biometricEnabled: boolean = false
  @State biometricAvailable: boolean = false
  @State biometricTypes: string = ''
  @State syncEnabled: boolean = false
  @State currency: string = 'CNY'
  @State privacyModeEnabled: boolean = true
  @State sensorThemeEnabled: boolean = false
  @State notificationEnabled: boolean = true
  @State largeTxnThreshold: string = '500'

  private storageService = StorageService.getInstance()
  private authService = AuthService.getInstance()
  private distributedService = DistributedService.getInstance()
  private notificationService = NotificationService.getInstance()
  private themeManager = ThemeManager.getInstance()

  aboutToAppear(): void {
    this.loadSettings()
  }

  private async loadSettings(): Promise<void> {
    this.themeMode = await this.storageService.getPreferenceInt(Constants.PREF_THEME, Constants.THEME_SYSTEM)
    this.biometricEnabled = await this.storageService.getPreferenceBool(Constants.PREF_BIOMETRIC, false)
    this.biometricAvailable = await this.authService.isBiometricAvailable()
    this.currency = await this.storageService.getPreference(Constants.PREF_CURRENCY, 'CNY')
    this.sensorThemeEnabled = this.themeMode === ThemeMode.AUTO_SENSOR

    const types = await this.authService.getAvailableAuthTypes()
    const typeNames: string[] = []
    for (let i = 0; i < types.length; i++) {
      if (types[i] === 1) typeNames.push('指纹')
      if (types[i] === 4) typeNames.push('面部')
    }
    this.biometricTypes = typeNames.length > 0 ? typeNames.join('+') : '不支持'
  }

  private async toggleBiometric(enabled: boolean): Promise<void> {
    if (enabled) {
      const result = await this.authService.authenticateHybrid('开启生物认证保护')
      if (result.success) {
        this.biometricEnabled = true
        await this.storageService.setPreferenceBool(Constants.PREF_BIOMETRIC, true)
        promptAction.showToast({ message: `生物认证已开启（${result.method}）` })
      } else {
        promptAction.showToast({ message: result.error || '认证失败' })
      }
    } else {
      this.biometricEnabled = false
      await this.storageService.setPreferenceBool(Constants.PREF_BIOMETRIC, false)
    }
  }

  private async toggleSensorTheme(enabled: boolean): Promise<void> {
    this.sensorThemeEnabled = enabled
    if (enabled) {
      this.themeMode = ThemeMode.AUTO_SENSOR
      this.themeManager.setTheme(ThemeMode.AUTO_SENSOR)
      await this.storageService.setPreferenceInt(Constants.PREF_THEME, ThemeMode.AUTO_SENSOR)
      promptAction.showToast({ message: '已启用环境光自动主题' })
    } else {
      this.themeMode = Constants.THEME_SYSTEM
      this.themeManager.setTheme(ThemeMode.SYSTEM)
      await this.storageService.setPreferenceInt(Constants.PREF_THEME, Constants.THEME_SYSTEM)
    }
  }

  private async toggleSync(enabled: boolean): Promise<void> {
    if (enabled) {
      const ctx = this.getUIContext().getHostContext()
      if (ctx !== undefined) {
        await this.distributedService.init(ctx)
      }
      this.syncEnabled = true
      promptAction.showToast({ message: '分布式同步已开启' })
    } else {
      this.syncEnabled = false
    }
  }

  private async togglePrivacyMode(enabled: boolean): Promise<void> {
    this.privacyModeEnabled = enabled
    await this.storageService.setPreferenceBool('privacy_mode', enabled)
    promptAction.showToast({ message: enabled ? '隐私保护已开启' : '隐私保护已关闭' })
  }

  private async toggleNotifications(enabled: boolean): Promise<void> {
    this.notificationEnabled = enabled
    if (enabled) {
      await this.notificationService.requestPermission()
    }
    await this.storageService.setPreferenceBool('notifications_enabled', enabled)
  }

  build() {
    Column() {
      // 主题设置
      this.buildAppearanceSection()

      // 安全设置
      this.buildSecuritySection()

      // 通知设置
      this.buildNotificationSection()

      // 同步设置
      this.buildSyncSection()

      // 智能功能
      this.buildSensorSection()

      // 关于
      this.buildAboutSection()

      Blank()

      Text('Made with ❤️ for HarmonyOS 6')
        .fontSize(ThemeFont.sm)
        .fontColor('#CCC')
        .margin({ bottom: ThemeSpacing.xxl })
    }
    .width('100%')
    .height('100%')
    .backgroundColor(this.themeManager.isDark ? '#121212' : '#F5F5F5')
  }

  @Builder
  buildAppearanceSection() {
    Column({ space: 0 }) {
      Text('外观')
        .fontSize(ThemeFont.sm)
        .fontColor('#999')
        .padding({ left: ThemeSpacing.lg, top: ThemeSpacing.lg, bottom: ThemeSpacing.sm })
      this.buildSettingRow('主题模式',
        this.themeMode === Constants.THEME_LIGHT ? '浅色' :
          this.themeMode === Constants.THEME_DARK ? '深色' :
            this.themeMode === ThemeMode.AUTO_SENSOR ? '环境光自适应' : '跟随系统',
        true)
      this.buildSwitchRow('环境光自适应', '根据周围光线自动切换深色/浅色主题',
        this.sensorThemeEnabled, true,
        (value: boolean) => { this.toggleSensorTheme(value) })
    }
    .width('100%')
    .backgroundColor(this.themeManager.isDark ? '#1E1E1E' : '#FFFFFF')
    .borderRadius(ThemeRadius.md)
    .margin({ left: ThemeSpacing.lg, right: ThemeSpacing.lg, top: ThemeSpacing.sm })
  }

  @Builder
  buildSecuritySection() {
    Column({ space: 0 }) {
      Text('安全与隐私')
        .fontSize(ThemeFont.sm)
        .fontColor('#999')
        .padding({ left: ThemeSpacing.lg, top: ThemeSpacing.lg, bottom: ThemeSpacing.sm })
      this.buildSwitchRow('生物认证', `支持${this.biometricTypes}，保护财务数据`,
        this.biometricEnabled, this.biometricAvailable,
        (value: boolean) => { this.toggleBiometric(value) })
      this.buildSwitchRow('距离隐私保护', '遮挡手机时自动隐藏金额数据',
        this.privacyModeEnabled, true,
        (value: boolean) => { this.togglePrivacyMode(value) })
      this.buildSettingRow('手势密码锁', '绘制图案保护应用', true, () => {
        router.pushUrl({ url: 'pages/GestureLock' })
      })
    }
    .width('100%')
    .backgroundColor(this.themeManager.isDark ? '#1E1E1E' : '#FFFFFF')
    .borderRadius(ThemeRadius.md)
    .margin({ left: ThemeSpacing.lg, right: ThemeSpacing.lg, top: ThemeSpacing.sm })
  }

  @Builder
  buildNotificationSection() {
    Column({ space: 0 }) {
      Text('通知提醒')
        .fontSize(ThemeFont.sm)
        .fontColor('#999')
        .padding({ left: ThemeSpacing.lg, top: ThemeSpacing.lg, bottom: ThemeSpacing.sm })
      this.buildSwitchRow('推送通知', '接收预算预警和交易提醒',
        this.notificationEnabled, true,
        (value: boolean) => { this.toggleNotifications(value) })
      this.buildSettingRow('大额交易提醒', `≥ ¥${this.largeTxnThreshold}`, true)
    }
    .width('100%')
    .backgroundColor(this.themeManager.isDark ? '#1E1E1E' : '#FFFFFF')
    .borderRadius(ThemeRadius.md)
    .margin({ left: ThemeSpacing.lg, right: ThemeSpacing.lg, top: ThemeSpacing.sm })
  }

  @Builder
  buildSyncSection() {
    Column({ space: 0 }) {
      Text('数据同步')
        .fontSize(ThemeFont.sm)
        .fontColor('#999')
        .padding({ left: ThemeSpacing.lg, top: ThemeSpacing.lg, bottom: ThemeSpacing.sm })
      this.buildSwitchRow('分布式同步', '在多台鸿蒙设备间同步数据',
        this.syncEnabled, true,
        (value: boolean) => { this.toggleSync(value) })
      this.buildSettingRow('导出数据', '导出为 CSV 文件', true)
    }
    .width('100%')
    .backgroundColor(this.themeManager.isDark ? '#1E1E1E' : '#FFFFFF')
    .borderRadius(ThemeRadius.md)
    .margin({ left: ThemeSpacing.lg, right: ThemeSpacing.lg, top: ThemeSpacing.sm })
  }

  @Builder
  buildSensorSection() {
    Column({ space: 0 }) {
      Text('智能功能')
        .fontSize(ThemeFont.sm)
        .fontColor('#999')
        .padding({ left: ThemeSpacing.lg, top: ThemeSpacing.lg, bottom: ThemeSpacing.sm })
      this.buildSettingRow('握持检测', '已启用 - 自适应单手操作布局', false)
      this.buildSettingRow('环境光传感器', this.sensorThemeEnabled ? '已启用' : '未启用', false)
      this.buildSettingRow('距离传感器', this.privacyModeEnabled ? '已启用 - 隐私保护中' : '未启用', false)
    }
    .width('100%')
    .backgroundColor(this.themeManager.isDark ? '#1E1E1E' : '#FFFFFF')
    .borderRadius(ThemeRadius.md)
    .margin({ left: ThemeSpacing.lg, right: ThemeSpacing.lg, top: ThemeSpacing.sm })
  }

  @Builder
  buildAboutSection() {
    Column({ space: 0 }) {
      Text('关于')
        .fontSize(ThemeFont.sm)
        .fontColor('#999')
        .padding({ left: ThemeSpacing.lg, top: ThemeSpacing.lg, bottom: ThemeSpacing.sm })
      this.buildSettingRow('版本', 'v2.0.0 (HarmonyOS 6)', false)
      this.buildSettingRow('API 版本', 'API 20', false)
      this.buildSettingRow('开发者', 'lxl141421', false)
      this.buildSettingRow('开源协议', 'MIT License', false)
      this.buildSettingRow('GitHub', 'github.com/lxl141421/FinTrack', true)
    }
    .width('100%')
    .backgroundColor(this.themeManager.isDark ? '#1E1E1E' : '#FFFFFF')
    .borderRadius(ThemeRadius.md)
    .margin({ left: ThemeSpacing.lg, right: ThemeSpacing.lg, top: ThemeSpacing.sm })
  }

  @Builder
  buildSettingRow(label: string, value: string, clickable: boolean, onClick: () => void = () => {}) {
    Row() {
      Text(label)
        .fontSize(ThemeFont.md)
        .fontColor(this.themeManager.isDark ? '#E0E0E0' : '#181818')
      Blank()
      Text(value)
        .fontSize(ThemeFont.sm)
        .fontColor('#999')
      if (clickable) {
        Text(' >')
          .fontSize(ThemeFont.sm)
          .fontColor('#CCC')
          .margin({ left: 4 })
      }
    }
    .width('100%')
    .height(52)
    .padding({ left: ThemeSpacing.lg, right: ThemeSpacing.lg })
    .border({ width: { bottom: 0.5 }, color: this.themeManager.isDark ? '#333' : '#F0F0F0' })
  }

  @Builder
  buildSwitchRow(label: string, desc: string, value: boolean, enabled: boolean,
    onChange: (value: boolean) => void) {
    Row() {
      Column({ space: 2 }) {
        Text(label)
          .fontSize(ThemeFont.md)
          .fontColor(this.themeManager.isDark ? '#E0E0E0' : '#181818')
        Text(desc)
          .fontSize(ThemeFont.xs)
          .fontColor('#999')
      }
      .alignItems(HorizontalAlign.Start)
      .layoutWeight(1)

      Toggle({ type: ToggleType.Switch, isOn: value })
        .enabled(enabled)
        .onChange(onChange)
    }
    .width('100%')
    .height(60)
    .padding({ left: ThemeSpacing.lg, right: ThemeSpacing.lg })
    .border({ width: { bottom: 0.5 }, color: this.themeManager.isDark ? '#333' : '#F0F0F0' })
  }
}

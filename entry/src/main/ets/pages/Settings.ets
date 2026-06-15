
import { StorageService } from '../services/StorageService'
import { AuthService } from '../services/AuthService'
import { DistributedService } from '../services/DistributedService'
import { Constants } from '../constants/Constants'
import { ThemeFont, ThemeRadius, ThemeSpacing } from '../theme/Theme'
import { promptAction } from '@kit.ArkUI'

@Entry
@Component
struct Settings {
  @State themeMode: number = Constants.THEME_SYSTEM
  @State biometricEnabled: boolean = false
  @State biometricAvailable: boolean = false
  @State syncEnabled: boolean = false
  @State currency: string = 'CNY'
  @State aboutExpanded: boolean = false

  private storageService = StorageService.getInstance()
  private authService = AuthService.getInstance()
  private distributedService = DistributedService.getInstance()

  aboutToAppear(): void {
    this.loadSettings()
  }

  private async loadSettings(): Promise<void> {
    this.themeMode = await this.storageService.getPreferenceInt(Constants.PREF_THEME, Constants.THEME_SYSTEM)
    this.biometricEnabled = await this.storageService.getPreferenceBool(Constants.PREF_BIOMETRIC, false)
    this.biometricAvailable = await this.authService.isBiometricAvailable()
    this.currency = await this.storageService.getPreference(Constants.PREF_CURRENCY, 'CNY')
  }

  private async toggleBiometric(enabled: boolean): Promise<void> {
    if (enabled) {
      const success = await this.authService.authenticate('开启生物认证保护')
      if (success) {
        this.biometricEnabled = true
        await this.storageService.setPreferenceBool(Constants.PREF_BIOMETRIC, true)
        promptAction.showToast({ message: '生物认证已开启' })
      } else {
        promptAction.showToast({ message: '认证失败' })
      }
    } else {
      this.biometricEnabled = false
      await this.storageService.setPreferenceBool(Constants.PREF_BIOMETRIC, false)
    }
  }

  private async toggleSync(enabled: boolean): Promise<void> {
    if (enabled) {
      await this.distributedService.init(this.getContext())
      this.syncEnabled = true
      promptAction.showToast({ message: '分布式同步已开启' })
    } else {
      this.syncEnabled = false
    }
  }

  private async exportData(): Promise<void> {
    promptAction.showToast({ message: '导出功能开发中...' })
  }

  build() {
    Column() {
      // 主题设置
      this.buildSection('外观', [
        this.buildSettingRow('主题模式',
          this.themeMode === Constants.THEME_LIGHT ? '浅色' :
            this.themeMode === Constants.THEME_DARK ? '深色' : '跟随系统',
          true)
      ])

      // 安全设置
      this.buildSection('安全', [
        this.buildSwitchRow('生物认证', '使用指纹/面部识别保护数据',
          this.biometricEnabled, this.biometricAvailable,
          (value: boolean) => { this.toggleBiometric(value) })
      ])

      // 同步设置
      this.buildSection('数据同步', [
        this.buildSwitchRow('分布式同步', '在多台鸿蒙设备间同步数据',
          this.syncEnabled, true,
          (value: boolean) => { this.toggleSync(value) }),
        this.buildSettingRow('导出数据', '导出为 CSV 文件', true)
      ])

      // 关于
      this.buildSection('关于', [
        this.buildSettingRow('版本', 'v1.0.0', false),
        this.buildSettingRow('开发者', 'lxl141421', false),
        this.buildSettingRow('开源协议', 'MIT License', false),
        this.buildSettingRow('GitHub', 'github.com/lxl141421/FinTrack', true)
      ])

      Blank()

      // 底部
      Text('Made with ❤️ for HarmonyOS')
        .fontSize(ThemeFont.sm)
        .fontColor('#CCC')
        .margin({ bottom: ThemeSpacing.xxl })
    }
    .width('100%')
    .height('100%')
    .backgroundColor('#F5F5F5')
  }

  @Builder
  buildSection(title: string, rows: object[]) {
    Column({ space: 0 }) {
      Text(title)
        .fontSize(ThemeFont.sm)
        .fontColor('#999')
        .padding({ left: ThemeSpacing.lg, top: ThemeSpacing.lg, bottom: ThemeSpacing.sm })

      ForEach(rows, (row: object) => {
        row as RowBuilder
      })
    }
    .width('100%')
    .backgroundColor('#FFFFFF')
    .borderRadius(ThemeRadius.md)
    .margin({ left: ThemeSpacing.lg, right: ThemeSpacing.lg, top: ThemeSpacing.sm })
  }

  @Builder
  buildSettingRow(label: string, value: string, clickable: boolean) {
    Row() {
      Text(label)
        .fontSize(ThemeFont.md)
        .fontColor('#181818')
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
    .border({ width: { bottom: 0.5 }, color: '#F0F0F0' })
  }

  @Builder
  buildSwitchRow(label: string, desc: string, value: boolean, enabled: boolean,
    onChange: (value: boolean) => void) {
    Row() {
      Column({ space: 2 }) {
        Text(label)
          .fontSize(ThemeFont.md)
          .fontColor('#181818')
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
    .border({ width: { bottom: 0.5 }, color: '#F0F0F0' })
  }
}

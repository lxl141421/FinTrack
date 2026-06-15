/**
 * 主题系统
 * 支持浅色/深色模式，统一管理色彩、字体、间距
 * 提供运行时主题切换能力
 */
import { hilog } from '@kit.PerformanceAnalysisKit'

/**
 * 主题模式枚举
 */
export enum ThemeMode {
  LIGHT = 0,
  DARK = 1,
  SYSTEM = 2
}

/**
 * 主题色彩配置
 */
export class ThemeColors {
  primary: string = '#007DFF'
  primaryDark: string = '#005BB5'
  primaryLight: string = '#E8F4FF'
  success: string = '#00B578'
  warning: string = '#FF8800'
  danger: string = '#FA2A2D'
  background: string = '#F5F5F5'
  surface: string = '#FFFFFF'
  surfaceVariant: string = '#F8F9FA'
  textPrimary: string = '#181818'
  textSecondary: string = '#666666'
  textHint: string = '#999999'
  textOnPrimary: string = '#FFFFFF'
  border: string = '#E5E5E5'
  divider: string = '#F0F0F0'
  shadow: string = '#00000010'
  income: string = '#00B578'
  expense: string = '#FA2A2D'
  overlay: string = '#00000060'
  cardBg: string = '#FFFFFF'
  inputBg: string = '#F8F9FA'
  tabBarBg: string = '#F5F5F5'
  chartColors: string[] = [
    '#007DFF', '#00B578', '#FF8800', '#FA2A2D',
    '#9B59B6', '#3498DB', '#1ABC9C', '#F7CE46',
    '#E74C3C', '#2ECC71'
  ]
}

/**
 * 主题管理器（单例）
 * 管理当前主题状态，支持运行时切换
 */
@ObservedV2
export class ThemeManager {
  private static _instance: ThemeManager | null = null

  /** 当前主题模式 */
  @Trace mode: ThemeMode = ThemeMode.LIGHT
  /** 当前是否为暗色模式 */
  @Trace isDark: boolean = false

  static getInstance(): ThemeManager {
    if (ThemeManager._instance === null) {
      ThemeManager._instance = new ThemeManager()
    }
    return ThemeManager._instance
  }

  /**
   * 设置主题模式
   */
  setTheme(mode: ThemeMode): void {
    this.mode = mode
    if (mode === ThemeMode.DARK) {
      this.isDark = true
    } else if (mode === ThemeMode.LIGHT) {
      this.isDark = false
    }
    // SYSTEM 模式在组件层通过 systemColorMode 判断
    hilog.info(0x0000, 'FinTrack', 'Theme changed to: %{public}s', ThemeMode[mode])
  }

  /**
   * 获取当前主题色彩
   */
  getColors(): ThemeColors {
    return this.isDark ? getDarkColors() : getLightColors()
  }

  /**
   * 根据主题模式选择颜色值
   */
  pickColor(lightColor: string, darkColor: string): string {
    return this.isDark ? darkColor : lightColor
  }
}

/**
 * 间距系统
 */
export class ThemeSpacing {
  static readonly xs: number = 4
  static readonly sm: number = 8
  static readonly md: number = 12
  static readonly lg: number = 16
  static readonly xl: number = 24
  static readonly xxl: number = 32
}

/**
 * 圆角系统
 */
export class ThemeRadius {
  static readonly sm: number = 6
  static readonly md: number = 12
  static readonly lg: number = 16
  static readonly xl: number = 24
  static readonly full: number = 999
}

/**
 * 字体系统
 */
export class ThemeFont {
  static readonly xs: number = 11
  static readonly sm: number = 13
  static readonly md: number = 15
  static readonly lg: number = 17
  static readonly xl: number = 20
  static readonly xxl: number = 24
  static readonly display: number = 32
  static readonly hero: number = 40

  static readonly weightRegular: number = 400
  static readonly weightMedium: number = 500
  static readonly weightBold: number = 700
}

/**
 * 动画时长
 */
export class ThemeAnimation {
  static readonly fast: number = 200
  static readonly normal: number = 350
  static readonly slow: number = 600
}

/**
 * 获取浅色主题色彩
 */
export function getLightColors(): ThemeColors {
  return new ThemeColors()
}

/**
 * 获取深色主题色彩
 */
export function getDarkColors(): ThemeColors {
  const colors = new ThemeColors()
  colors.background = '#121212'
  colors.surface = '#1E1E1E'
  colors.surfaceVariant = '#2C2C2C'
  colors.textPrimary = '#E0E0E0'
  colors.textSecondary = '#A0A0A0'
  colors.textHint = '#707070'
  colors.border = '#333333'
  colors.divider = '#2A2A2A'
  colors.shadow = '#00000030'
  colors.primaryLight = '#1A3A5C'
  colors.overlay = '#00000080'
  colors.cardBg = '#1E1E1E'
  colors.inputBg = '#2C2C2C'
  colors.tabBarBg = '#1A1A1A'
  return colors
}

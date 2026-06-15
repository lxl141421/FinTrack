
/**
 * 全局常量定义
 */
export class Constants {
  // 数据库
  static readonly DB_NAME: string = 'fintrack.db'
  static readonly DB_VERSION: number = 1
  static readonly TABLE_TRANSACTION: string = 'transactions'
  static readonly TABLE_CATEGORY: string = 'categories'
  static readonly TABLE_BUDGET: string = 'budgets'
  static readonly TABLE_ACCOUNT: string = 'accounts'

  // 分布式
  static readonly STORE_ID: string = 'fintrack_kv_store'
  static readonly BUNDLE_NAME: string = 'com.example.fintrack'

  // 偏好键
  static readonly PREF_THEME: string = 'theme_mode'
  static readonly PREF_BIOMETRIC: string = 'biometric_enabled'
  static readonly PREF_CURRENCY: string = 'currency_format'
  static readonly PREF_FIRST_LAUNCH: string = 'first_launch'

  // 主题
  static readonly THEME_LIGHT: number = 0
  static readonly THEME_DARK: number = 1
  static readonly THEME_SYSTEM: number = 2

  // 交易类型
  static readonly TYPE_INCOME: number = 0
  static readonly TYPE_EXPENSE: number = 1
  static readonly TYPE_TRANSFER: number = 2

  // 图表
  static readonly CHART_PADDING: number = 16
  static readonly CHART_ANIMATION_DURATION: number = 800
  static readonly KLINE_CANDLE_MIN_WIDTH: number = 8
  static readonly KLINE_CANDLE_MAX_WIDTH: number = 24

  // 动画
  static readonly ANIM_DURATION_FAST: number = 200
  static readonly ANIM_DURATION_NORMAL: number = 350
  static readonly ANIM_DURATION_SLOW: number = 600

  // 预算
  static readonly BUDGET_WARN_THRESHOLD: number = 0.8  // 80% 预警
  static readonly BUDGET_DANGER_THRESHOLD: number = 1.0 // 100% 超支

  // 默认分类
  static readonly DEFAULT_CATEGORIES: string[] = [
    '餐饮', '交通', '购物', '娱乐', '住房', '医疗',
    '教育', '通讯', '工资', '投资', '红包', '其他'
  ]
}

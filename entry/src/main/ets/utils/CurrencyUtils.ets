
/**
 * 货币格式化工具类
 */
export class CurrencyUtils {
  /** 币种符号映射 */
  private static readonly SYMBOLS: Record<string, string> = {
    'CNY': '¥',
    'USD': '$',
    'EUR': '€',
    'GBP': '£',
    'JPY': '¥'
  }

  /** 币种小数位数 */
  private static readonly DECIMALS: Record<string, number> = {
    'CNY': 2,
    'USD': 2,
    'EUR': 2,
    'GBP': 2,
    'JPY': 0
  }

  /**
   * 格式化金额显示
   * @param amount 金额
   * @param currency 币种代码
   * @param showSign 是否显示正负号
   */
  static format(amount: number, currency: string = 'CNY', showSign: boolean = false): string {
    const symbol = CurrencyUtils.SYMBOLS[currency] ?? '¥'
    const decimals = CurrencyUtils.DECIMALS[currency] ?? 2
    const formatted = CurrencyUtils.addThousandsSeparator(
      Math.abs(amount).toFixed(decimals)
    )
    const sign = showSign ? (amount >= 0 ? '+' : '-') : ''
    return `${sign}${symbol}${formatted}`
  }

  /**
   * 格式化为简短形式（如 1.2万、3.5亿）
   */
  static formatShort(amount: number, currency: string = 'CNY'): string {
    const symbol = CurrencyUtils.SYMBOLS[currency] ?? '¥'
    const abs = Math.abs(amount)

    if (abs >= 100000000) {
      return `${symbol}${(abs / 100000000).toFixed(1)}亿`
    }
    if (abs >= 10000) {
      return `${symbol}${(abs / 10000).toFixed(1)}万`
    }
    return CurrencyUtils.format(amount, currency)
  }

  /**
   * 添加千分位分隔符
   */
  private static addThousandsSeparator(numStr: string): string {
    const parts = numStr.split('.')
    const intPart = parts[0]
    const decPart = parts.length > 1 ? '.' + parts[1] : ''

    let result = ''
    let count = 0
    for (let i = intPart.length - 1; i >= 0; i--) {
      if (count > 0 && count % 3 === 0) {
        result = ',' + result
      }
      result = intPart[i] + result
      count++
    }
    return result + decPart
  }

  /**
   * 解析金额字符串为数字
   */
  static parse(text: string): number {
    const cleaned = text.replace(/[^\d.-]/g, '')
    const value = Number(cleaned)
    return isNaN(value) ? 0 : value
  }

  /**
   * 获取币种符号
   */
  static getSymbol(currency: string): string {
    return CurrencyUtils.SYMBOLS[currency] ?? '¥'
  }
}

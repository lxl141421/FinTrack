import { describe, it, expect } from '@ohos/hypium'
import { DateUtils } from '../../main/ets/utils/DateUtils'
import { CurrencyUtils } from '../../main/ets/utils/CurrencyUtils'

export default function UtilsTest() {
  describe('DateUtilsTest', () => {
    it('format_默认格式_返回YYYY-MM-DD', 0, () => {
      // 2026-01-15 10:30:00
      const ts = new Date(2026, 0, 15, 10, 30, 0).getTime()
      const result = DateUtils.format(ts)
      expect(result).assertEqual('2026-01-15')
    })

    it('format_自定义格式_正确替换', 0, () => {
      const ts = new Date(2026, 5, 15, 14, 30, 45).getTime()
      const result = DateUtils.format(ts, 'YYYY/MM/DD HH:mm')
      expect(result).assertEqual('2026/06/15 14:30')
    })

    it('getCurrentMonth_返回当前月份格式', 0, () => {
      const result = DateUtils.getCurrentMonth()
      expect(result).assertContain('-')
      expect(result.length).assertEqual(7) // "2026-06"
    })

    it('getRecentMonths_返回指定数量', 0, () => {
      const months = DateUtils.getRecentMonths(3)
      expect(months.length).assertEqual(3)
      expect(months[0]).assertEqual(DateUtils.getCurrentMonth())
    })

    it('getDaysInMonth_二月_返回28或29', 0, () => {
      const days = DateUtils.getDaysInMonth(2026, 2)
      expect(days >= 28).assertTrue()
      expect(days <= 29).assertTrue()
    })

    it('getDaysInMonth_一月_返回31', 0, () => {
      const days = DateUtils.getDaysInMonth(2026, 1)
      expect(days).assertEqual(31)
    })

    it('getWeekdayName_周一_返回周一', 0, () => {
      // 2026-06-15 is a Monday
      const ts = new Date(2026, 5, 15).getTime()
      const result = DateUtils.getWeekdayName(ts)
      expect(result).assertEqual('周一')
    })

    it('getRelativeTime_今天_返回时间', 0, () => {
      const now = Date.now()
      const result = DateUtils.getRelativeTime(now)
      // Should return HH:mm format
      expect(result).assertContain(':')
    })
  })

  describe('CurrencyUtilsTest', () => {
    it('format_默认人民币_正确格式', 0, () => {
      const result = CurrencyUtils.format(1234.56)
      expect(result).assertContain('¥')
      expect(result).assertContain('1,234.56')
    })

    it('format_负数_正确格式', 0, () => {
      const result = CurrencyUtils.format(-500)
      expect(result).assertContain('¥')
      expect(result).assertContain('500.00')
    })

    it('format_显示正号', 0, () => {
      const result = CurrencyUtils.format(100, 'CNY', true)
      expect(result).assertContain('+')
    })

    it('format_显示负号', 0, () => {
      const result = CurrencyUtils.format(-100, 'CNY', true)
      expect(result).assertContain('-')
    })

    it('formatShort_万元_正确格式', 0, () => {
      const result = CurrencyUtils.formatShort(15000)
      expect(result).assertContain('万')
    })

    it('formatShort_亿元_正确格式', 0, () => {
      const result = CurrencyUtils.formatShort(150000000)
      expect(result).assertContain('亿')
    })

    it('formatShort_小数字_不缩写', 0, () => {
      const result = CurrencyUtils.formatShort(999)
      expect(result).assertContain('¥')
      expect(result).assertContain('999.00')
    })

    it('getSymbol_人民币_返回¥', 0, () => {
      expect(CurrencyUtils.getSymbol('CNY')).assertEqual('¥')
    })

    it('getSymbol_美元_返回$', 0, () => {
      expect(CurrencyUtils.getSymbol('USD')).assertEqual('$')
    })

    it('getSymbol_未知币种_返回¥', 0, () => {
      expect(CurrencyUtils.getSymbol('XYZ')).assertEqual('¥')
    })

    it('parse_正常数字_返回数值', 0, () => {
      expect(CurrencyUtils.parse('1234.56')).assertEqual(1234.56)
    })

    it('parse_带符号_返回数值', 0, () => {
      expect(CurrencyUtils.parse('¥1,234.56')).assertEqual(1234.56)
    })

    it('parse_非法字符串_返回0', 0, () => {
      expect(CurrencyUtils.parse('abc')).assertEqual(0)
    })
  })
}

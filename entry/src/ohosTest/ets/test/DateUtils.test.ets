
import { describe, it, expect } from '@ohos/hypium'
import { DateUtils } from '../../../../main/ets/utils/DateUtils'

export default function DateUtilsTest() {
  describe('DateUtilsTest', () => {
    it('should_return_month_start', 0, () => {
      const start = DateUtils.getMonthStart()
      const date = new Date(start)
      expect(date.getDate()).assertEqual(1)
      expect(date.getHours()).assertEqual(0)
      expect(date.getMinutes()).assertEqual(0)
    })

    it('should_return_month_end', 0, () => {
      const end = DateUtils.getMonthEnd()
      const date = new Date(end)
      // Should be last day of month at 23:59:59
      expect(date.getHours()).assertEqual(23)
      expect(date.getMinutes()).assertEqual(59)
    })

    it('should_format_timestamp', 0, () => {
      // 2026-06-15 10:30:00
      const ts = new Date(2026, 5, 15, 10, 30, 0).getTime()
      const formatted = DateUtils.format(ts, 'YYYY-MM-DD')
      expect(formatted).assertEqual('2026-06-15')
    })

    it('should_get_current_month_string', 0, () => {
      const month = DateUtils.getCurrentMonth()
      expect(month.length).assertEqual(7) // YYYY-MM
      expect(month.charAt(4)).assertEqual('-')
    })

    it('should_detect_current_month', 0, () => {
      const now = Date.now()
      expect(DateUtils.isCurrentMonth(now)).assertTrue()
    })

    it('should_detect_old_date_not_current_month', 0, () => {
      const old = new Date(2020, 0, 1).getTime()
      expect(DateUtils.isCurrentMonth(old)).assertFalse()
    })

    it('should_get_days_in_month', 0, () => {
      expect(DateUtils.getDaysInMonth(2026, 1)).assertEqual(31)
      expect(DateUtils.getDaysInMonth(2026, 2)).assertEqual(28)
      expect(DateUtils.getDaysInMonth(2024, 2)).assertEqual(29) // leap year
      expect(DateUtils.getDaysInMonth(2026, 6)).assertEqual(30)
    })

    it('should_get_weekday_name', 0, () => {
      // 2026-06-15 is Monday
      const ts = new Date(2026, 5, 15).getTime()
      const name = DateUtils.getWeekdayName(ts)
      expect(name).assertEqual('周一')
    })

    it('should_get_relative_time_just_now', 0, () => {
      const now = Date.now()
      const result = DateUtils.getRelativeTime(now)
      expect(result).assertContain('刚刚')
    })

    it('should_get_recent_months', 0, () => {
      const months = DateUtils.getRecentMonths(3)
      expect(months.length).assertEqual(3)
      // Each should be YYYY-MM format
      for (let i = 0; i < months.length; i++) {
        expect(months[i].length).assertEqual(7)
      }
    })
  })
}


import { describe, it, expect } from '@ohos/hypium'
import { Budget } from '../../../../main/ets/models/Budget'

export default function BudgetServiceTest() {
  describe('BudgetServiceTest', () => {
    it('should_create_budget', 0, () => {
      const budget = Budget.create('cat_food', '餐饮', 2000, '2026-06')

      expect(budget.id.startsWith('budget_')).assertTrue()
      expect(budget.category).assertEqual('cat_food')
      expect(budget.categoryName).assertEqual('餐饮')
      expect(budget.limitAmount).assertEqual(2000)
      expect(budget.month).assertEqual('2026-06')
    })

    it('should_calculate_remaining', 0, () => {
      const budget = Budget.create('', '总预算', 5000, '2026-06')
      budget.spentAmount = 3000

      expect(budget.getRemaining()).assertEqual(2000)
    })

    it('should_detect_exceeded_budget', 0, () => {
      const budget = Budget.create('', '总预算', 5000, '2026-06')
      budget.spentAmount = 6000

      expect(budget.isExceeded()).assertTrue()
      expect(budget.getUsagePercent()).assertEqual(1.2)
    })

    it('should_detect_warning_level', 0, () => {
      const budget = Budget.create('', '总预算', 5000, '2026-06')
      budget.spentAmount = 4200  // 84%

      expect(budget.isWarning()).assertTrue()
      expect(budget.isExceeded()).assertFalse()
    })

    it('should_handle_zero_limit', 0, () => {
      const budget = Budget.create('', '总预算', 0, '2026-06')
      budget.spentAmount = 100

      expect(budget.getUsagePercent()).assertEqual(0)
      expect(budget.isExceeded()).assertTrue()
    })

    it('should_serialize_and_deserialize', 0, () => {
      const budget = Budget.create('cat_food', '餐饮', 2000, '2026-06')
      budget.spentAmount = 1500

      const json = budget.toJson()
      const restored = Budget.fromJson(json)

      expect(restored.id).assertEqual(budget.id)
      expect(restored.limitAmount).assertEqual(2000)
      expect(restored.spentAmount).assertEqual(1500)
      expect(restored.month).assertEqual('2026-06')
    })

    it('should_generate_unique_ids', 0, () => {
      const b1 = Budget.create('cat1', '分类1', 100, '2026-06')
      const b2 = Budget.create('cat2', '分类2', 200, '2026-06')
      expect(b1.id).assertNotEqual(b2.id)
      expect(b1.id.startsWith('budget_')).assertTrue()
    })

    it('should_handle_exact_limit_usage', 0, () => {
      const budget = Budget.create('', '总预算', 5000, '2026-06')
      budget.spentAmount = 5000

      expect(budget.getRemaining()).assertEqual(0)
      expect(budget.isExceeded()).assertFalse()
      expect(budget.getUsagePercent()).assertEqual(1.0)
    })

    it('should_not_warn_below_threshold', 0, () => {
      const budget = Budget.create('', '总预算', 5000, '2026-06')
      budget.spentAmount = 3000  // 60%

      expect(budget.isWarning()).assertFalse()
      expect(budget.isExceeded()).assertFalse()
    })

    it('should_handle_empty_json', 0, () => {
      const budget = Budget.fromJson('{}')
      expect(budget.id).assertEqual('')
      expect(budget.limitAmount).assertEqual(0)
      expect(budget.spentAmount).assertEqual(0)
    })

    it('should_calculate_usage_percent_correctly', 0, () => {
      const budget = Budget.create('', '总预算', 1000, '2026-06')
      budget.spentAmount = 750

      expect(budget.getUsagePercent()).assertEqual(0.75)
    })
  })
}

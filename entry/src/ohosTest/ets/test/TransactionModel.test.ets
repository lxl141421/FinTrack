
import { describe, it, expect } from '@ohos/hypium'
import { Transaction } from '../../../../main/ets/models/Transaction'
import { Constants } from '../../../../main/ets/constants/Constants'

export default function TransactionModelTest() {
  describe('TransactionModelTest', () => {
    it('should_create_transaction_with_factory_method', 0, () => {
      const txn = Transaction.create(
        Constants.TYPE_EXPENSE,
        100.50,
        'cat_food',
        '餐饮',
        '午餐',
        Date.now()
      )

      expect(txn.id.startsWith('txn_')).assertTrue()
      expect(txn.type).assertEqual(Constants.TYPE_EXPENSE)
      expect(txn.amount).assertEqual(100.50)
      expect(txn.category).assertEqual('cat_food')
      expect(txn.categoryName).assertEqual('餐饮')
      expect(txn.note).assertEqual('午餐')
    })

    it('should_serialize_and_deserialize_json', 0, () => {
      const txn = Transaction.create(
        Constants.TYPE_INCOME,
        5000,
        'cat_salary',
        '工资',
        '6月工资'
      )

      const json = txn.toJson()
      const restored = Transaction.fromJson(json)

      expect(restored.id).assertEqual(txn.id)
      expect(restored.type).assertEqual(txn.type)
      expect(restored.amount).assertEqual(txn.amount)
      expect(restored.category).assertEqual(txn.category)
      expect(restored.categoryName).assertEqual(txn.categoryName)
      expect(restored.note).assertEqual(txn.note)
    })

    it('should_identify_income_correctly', 0, () => {
      const income = Transaction.create(Constants.TYPE_INCOME, 100, '', '')
      const expense = Transaction.create(Constants.TYPE_EXPENSE, 100, '', '')

      expect(income.isIncome()).assertTrue()
      expect(income.isExpense()).assertFalse()
      expect(expense.isIncome()).assertFalse()
      expect(expense.isExpense()).assertTrue()
    })

    it('should_return_correct_signed_amount', 0, () => {
      const income = Transaction.create(Constants.TYPE_INCOME, 500, '', '')
      const expense = Transaction.create(Constants.TYPE_EXPENSE, 300, '', '')

      expect(income.getSignedAmount()).assertEqual(500)
      expect(expense.getSignedAmount()).assertEqual(-300)
    })

    it('should_generate_unique_ids', 0, () => {
      const id1 = Transaction.generateId()
      const id2 = Transaction.generateId()

      expect(id1).assertNotEqual(id2)
      expect(id1.startsWith('txn_')).assertTrue()
    })

    it('should_handle_empty_json_gracefully', 0, () => {
      const txn = Transaction.fromJson('{}')

      expect(txn.id).assertEqual('')
      expect(txn.type).assertEqual(0)
      expect(txn.amount).assertEqual(0)
    })
  })
}

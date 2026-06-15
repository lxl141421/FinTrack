import { describe, it, expect } from '@ohos/hypium'
import { Validator, ValidationResult } from '../../main/ets/utils/Validator'
import { Constants } from '../../main/ets/constants/Constants'

export default function ValidatorTest() {
  describe('ValidatorTest', () => {
    // ==================== 金额验证 ====================

    it('validateAmount_正常金额_通过', 0, () => {
      const result = Validator.validateAmount('100')
      expect(result.valid).assertTrue()
      expect(result.errorMessage).assertEqual('')
    })

    it('validateAmount_小数金额_通过', 0, () => {
      const result = Validator.validateAmount('99.99')
      expect(result.valid).assertTrue()
    })

    it('validateAmount_空字符串_失败', 0, () => {
      const result = Validator.validateAmount('')
      expect(result.valid).assertFalse()
      expect(result.errorMessage).assertEqual('请输入金额')
    })

    it('validateAmount_零_失败', 0, () => {
      const result = Validator.validateAmount('0')
      expect(result.valid).assertFalse()
      expect(result.errorMessage).assertEqual('金额必须大于零')
    })

    it('validateAmount_负数_失败', 0, () => {
      const result = Validator.validateAmount('-10')
      expect(result.valid).assertFalse()
    })

    it('validateAmount_超出最大值_失败', 0, () => {
      const result = Validator.validateAmount('999999999.99')
      expect(result.valid).assertFalse()
    })

    it('validateAmount_三位小数_失败', 0, () => {
      const result = Validator.validateAmount('10.123')
      expect(result.valid).assertFalse()
      expect(result.errorMessage).assertContain('2 位小数')
    })

    it('validateAmount_非数字_失败', 0, () => {
      const result = Validator.validateAmount('abc')
      expect(result.valid).assertFalse()
    })

    it('validateAmount_带空格_正常处理', 0, () => {
      const result = Validator.validateAmount(' 100 ')
      expect(result.valid).assertTrue()
    })

    // ==================== 分类验证 ====================

    it('validateCategory_正常分类_通过', 0, () => {
      const result = Validator.validateCategory('food', '餐饮')
      expect(result.valid).assertTrue()
    })

    it('validateCategory_空ID_失败', 0, () => {
      const result = Validator.validateCategory('', '餐饮')
      expect(result.valid).assertFalse()
      expect(result.errorMessage).assertEqual('请选择分类')
    })

    it('validateCategory_空名称_失败', 0, () => {
      const result = Validator.validateCategory('food', '')
      expect(result.valid).assertFalse()
      expect(result.errorMessage).assertEqual('分类名称不能为空')
    })

    it('validateCategory_名称过长_失败', 0, () => {
      const longName = 'A'.repeat(51)
      const result = Validator.validateCategory('food', longName)
      expect(result.valid).assertFalse()
      expect(result.errorMessage).assertContain('50')
    })

    // ==================== 日期范围验证 ====================

    it('validateDateRange_正常范围_通过', 0, () => {
      const start = Date.now() - 86400000
      const end = Date.now()
      const result = Validator.validateDateRange(start, end)
      expect(result.valid).assertTrue()
    })

    it('validateDateRange_开始晚于结束_失败', 0, () => {
      const start = Date.now()
      const end = Date.now() - 86400000
      const result = Validator.validateDateRange(start, end)
      expect(result.valid).assertFalse()
      expect(result.errorMessage).assertContain('不能晚于')
    })

    it('validateDateRange_零值_失败', 0, () => {
      const result = Validator.validateDateRange(0, Date.now())
      expect(result.valid).assertFalse()
    })

    // ==================== 备注验证 ====================

    it('validateAndSanitizeNote_正常备注_通过', 0, () => {
      const result = Validator.validateAndSanitizeNote('午餐费用')
      expect(result.valid).assertTrue()
    })

    it('validateAndSanitizeNote_超长备注_失败', 0, () => {
      const longNote = 'A'.repeat(501)
      const result = Validator.validateAndSanitizeNote(longNote)
      expect(result.valid).assertFalse()
    })

    it('validateAndSanitizeNote_null_通过', 0, () => {
      const result = Validator.validateAndSanitizeNote(null as unknown as string)
      expect(result.valid).assertTrue()
    })

    // ==================== 输入清理 ====================

    it('sanitizeInput_正常文本_不变', 0, () => {
      const result = Validator.sanitizeInput('午餐 25元')
      expect(result).assertEqual('午餐 25元')
    })

    it('sanitizeInput_SQL注入_清理', 0, () => {
      const result = Validator.sanitizeInput("'; DROP TABLE users; --")
      expect(result).assertNotContain('DROP')
      expect(result).assertNotContain('--')
      expect(result).assertNotContain(';')
    })

    it('sanitizeInput_XSS_清理', 0, () => {
      const result = Validator.sanitizeInput('<script>alert(1)</script>')
      expect(result).assertNotContain('<')
      expect(result).assertNotContain('>')
    })

    // ==================== 交易类型验证 ====================

    it('validateTransactionType_收入类型_通过', 0, () => {
      const result = Validator.validateTransactionType(Constants.TYPE_INCOME)
      expect(result.valid).assertTrue()
    })

    it('validateTransactionType_支出类型_通过', 0, () => {
      const result = Validator.validateTransactionType(Constants.TYPE_EXPENSE)
      expect(result.valid).assertTrue()
    })

    it('validateTransactionType_无效类型_失败', 0, () => {
      const result = Validator.validateTransactionType(99)
      expect(result.valid).assertFalse()
    })

    // ==================== 预算金额验证 ====================

    it('validateBudgetAmount_正常金额_通过', 0, () => {
      const result = Validator.validateBudgetAmount('1000')
      expect(result.valid).assertTrue()
    })

    it('validateBudgetAmount_小于1元_失败', 0, () => {
      const result = Validator.validateBudgetAmount('0.5')
      expect(result.valid).assertFalse()
      expect(result.errorMessage).assertContain('至少为 1 元')
    })
  })
}

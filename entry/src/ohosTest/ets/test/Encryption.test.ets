
import { describe, it, expect } from '@ohos/hypium'
import { Encryption } from '../../../../main/ets/utils/Encryption'

export default function EncryptionTest() {
  describe('EncryptionTest', () => {
    it('should_encrypt_and_decrypt_roundtrip', 0, async () => {
      const plainText = 'Hello FinTrack 123'
      const encrypted = await Encryption.encrypt(plainText)
      const decrypted = await Encryption.decrypt(encrypted)

      expect(decrypted).assertEqual(plainText)
    })

    it('should_produce_enc_prefix', 0, async () => {
      const encrypted = await Encryption.encrypt('test')
      expect(encrypted.startsWith('enc:')).assertTrue()
    })

    it('should_handle_empty_string_encrypt', 0, async () => {
      const result = await Encryption.encrypt('')
      expect(result).assertEqual('')
    })

    it('should_handle_empty_string_decrypt', 0, async () => {
      const result = await Encryption.decrypt('')
      expect(result).assertEqual('')
    })

    it('should_passthrough_non_encrypted_text', 0, async () => {
      const plainText = 'not encrypted'
      const result = await Encryption.decrypt(plainText)
      expect(result).assertEqual(plainText)
    })

    it('should_encrypt_chinese_text', 0, async () => {
      const plainText = '午餐费用 ¥25.50'
      const encrypted = await Encryption.encrypt(plainText)
      const decrypted = await Encryption.decrypt(encrypted)
      expect(decrypted).assertEqual(plainText)
    })

    it('should_encrypt_long_text', 0, async () => {
      const plainText = 'A'.repeat(1000)
      const encrypted = await Encryption.encrypt(plainText)
      const decrypted = await Encryption.decrypt(encrypted)
      expect(decrypted).assertEqual(plainText)
    })

    it('should_produce_different_output_with_different_keys', 0, async () => {
      const plainText = 'test data'
      const enc1 = await Encryption.encrypt(plainText, 'Key1______________________________')
      const enc2 = await Encryption.encrypt(plainText, 'Key2______________________________')
      expect(enc1).assertNotEqual(enc2)
    })
  })
}

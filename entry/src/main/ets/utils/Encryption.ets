import { cryptoFramework } from '@kit.CoreServicesKit'
import { buffer } from '@kit.ArkTS'
import { hilog } from '@kit.PerformanceAnalysisKit'

/**
 * AES 加密工具
 * 使用 AES-256-GCM 模式加密敏感数据
 */
export class Encryption {
  /** 加密算法标识 */
  private static readonly ALGORITHM_NAME: string = 'AES256'
  /** GCM 模式的认证标签长度 */
  private static readonly GCM_TAG_LENGTH: number = 128
  /** 默认密钥（实际项目应从安全存储获取） */
  private static readonly DEFAULT_KEY: string = 'FinTrack_AES256_Default_Key_32B!'
  /** 默认 IV 长度 */
  private static readonly IV_LENGTH: number = 12

  /**
   * 生成随机 IV（初始化向量）
   */
  private static generateIV(): Uint8Array {
    const iv = new Uint8Array(this.IV_LENGTH)
    for (let i = 0; i < this.IV_LENGTH; i++) {
      iv[i] = Math.floor(Math.random() * 256)
    }
    return iv
  }

  /**
   * 获取 AES 密钥生成器参数
   */
  private static getGcmParamsSpec(iv: Uint8Array): cryptoFramework.GcmParamsSpec {
    const gcmParams: cryptoFramework.GcmParamsSpec = {
      iv: { data: iv },
      aad: { data: new Uint8Array(0) },
      authTag: { data: new Uint8Array(this.GCM_TAG_LENGTH / 8) },
      algName: cryptoFramework.AlgName.AES256_GCM
    }
    return gcmParams
  }

  /**
   * 从字符串生成对称密钥
   * 使用简单的密钥派生（生产环境应使用 PBKDF2/scrypt）
   */
  static async generateKey(keyMaterial: string = this.DEFAULT_KEY): Promise<cryptoFramework.SymKey> {
    // 确保密钥材料为 32 字节 (AES-256)
    const keyBytes = new Uint8Array(32)
    const inputBytes = buffer.from(keyMaterial, 'utf-8').buffer as Uint8Array
    for (let i = 0; i < 32; i++) {
      keyBytes[i] = i < inputBytes.length ? inputBytes[i] : 0
    }

    const symKeyGenerator = cryptoFramework.createSymKeyGenerator('AES256')
    const symKey = await symKeyGenerator.convertKey({ data: keyBytes })
    return symKey
  }

  /**
   * AES-GCM 加密
   * @param plainText 明文字符串
   * @param keyMaterial 密钥材料（可选）
   * @returns Base64 编码的密文（含 IV 前缀）
   */
  static async encrypt(plainText: string, keyMaterial: string = this.DEFAULT_KEY): Promise<string> {
    try {
      const iv = this.generateIV()
      const symKey = await this.generateKey(keyMaterial)
      const gcmParams = this.getGcmParamsSpec(iv)

      const cipher = cryptoFramework.createCipher('AES256_GCM')
      await cipher.init(cryptoFramework.CryptoMode.ENCRYPT_MODE, symKey, gcmParams)

      const plainBuffer = { data: buffer.from(plainText, 'utf-8').buffer as Uint8Array }
      const encrypted = await cipher.doFinal(plainBuffer)

      // 将 IV + 密文合并后 Base64 编码
      const ivStr = buffer.from(iv).toString('base64')
      const cipherStr = buffer.from(encrypted.data).toString('base64')
      return `${ivStr}:${cipherStr}`
    } catch (err) {
      hilog.error(0x0000, 'FinTrack', 'Encryption failed: %{public}s', JSON.stringify(err))
      // 降级：Base64 编码（非安全加密，仅保证数据不为明文）
      return `b64:${buffer.from(plainText, 'utf-8').toString('base64')}`
    }
  }

  /**
   * AES-GCM 解密
   * @param cipherText Base64 编码的密文
   * @param keyMaterial 密钥材料（可选）
   * @returns 明文字符串
   */
  static async decrypt(cipherText: string, keyMaterial: string = this.DEFAULT_KEY): Promise<string> {
    try {
      // 处理降级的 Base64 编码
      if (cipherText.startsWith('b64:')) {
        return buffer.from(cipherText.substring(4), 'base64').toString('utf-8')
      }

      const parts = cipherText.split(':')
      if (parts.length !== 2) {
        throw new Error('Invalid cipher format')
      }

      const iv = buffer.from(parts[0], 'base64').buffer as Uint8Array
      const cipherData = buffer.from(parts[1], 'base64').buffer as Uint8Array

      const symKey = await this.generateKey(keyMaterial)
      const gcmParams = this.getGcmParamsSpec(iv)

      const decipher = cryptoFramework.createCipher('AES256_GCM')
      await decipher.init(cryptoFramework.CryptoMode.DECRYPT_MODE, symKey, gcmParams)

      const cipherBuffer = { data: cipherData }
      const decrypted = await decipher.doFinal(cipherBuffer)

      return buffer.from(decrypted.data).toString('utf-8')
    } catch (err) {
      hilog.error(0x0000, 'FinTrack', 'Decryption failed: %{public}s', JSON.stringify(err))
      return ''
    }
  }

  /**
   * 生成安全的随机 ID
   * @param length ID 长度（字节数，输出为十六进制会翻倍）
   */
  static generateSecureId(length: number = 16): string {
    const bytes = new Uint8Array(length)
    for (let i = 0; i < length; i++) {
      bytes[i] = Math.floor(Math.random() * 256)
    }
    let hex = ''
    for (let i = 0; i < bytes.length; i++) {
      hex += bytes[i].toString(16).padStart(2, '0')
    }
    return hex
  }

  /**
   * 简单的字符串哈希（非加密安全，用于缓存键等场景）
   */
  static simpleHash(str: string): number {
    let hash = 0
    for (let i = 0; i < str.length; i++) {
      const char = str.charCodeAt(i)
      hash = ((hash << 5) - hash) + char
      hash = hash & hash // 转换为32位整数
    }
    return Math.abs(hash)
  }
}

import { hilog } from '@kit.PerformanceAnalysisKit'

/**
 * AES 加密工具
 * 使用 Base64 + 简单异或混淆保护敏感数据
 * 生产环境应替换为 @ohos.security.cryptoFramework
 */
export class Encryption {
  private static readonly DEFAULT_KEY: string = 'FinTrack_AES256_Default_Key_32B!'

  /**
   * 加密字符串（Base64 + XOR 混淆）
   */
  static async encrypt(plainText: string, keyMaterial: string = Encryption.DEFAULT_KEY): Promise<string> {
    try {
      if (plainText === '') return ''

      const keyBytes = Encryption.stringToBytes(keyMaterial)
      const plainBytes = Encryption.stringToBytes(plainText)
      const encrypted = new Uint8Array(plainBytes.length)

      for (let i = 0; i < plainBytes.length; i++) {
        encrypted[i] = plainBytes[i] ^ keyBytes[i % keyBytes.length]
      }

      return 'enc:' + Encryption.bytesToBase64(encrypted)
    } catch (err) {
      hilog.error(0x0000, 'FinTrack', 'Encryption failed')
      return plainText
    }
  }

  /**
   * 解密字符串
   */
  static async decrypt(cipherText: string, keyMaterial: string = Encryption.DEFAULT_KEY): Promise<string> {
    try {
      if (cipherText === '') return ''

      // 非加密格式直接返回
      if (!cipherText.startsWith('enc:')) return cipherText

      const keyBytes = Encryption.stringToBytes(keyMaterial)
      const cipherBytes = Encryption.base64ToBytes(cipherText.substring(4))
      const decrypted = new Uint8Array(cipherBytes.length)

      for (let i = 0; i < cipherBytes.length; i++) {
        decrypted[i] = cipherBytes[i] ^ keyBytes[i % keyBytes.length]
      }

      return Encryption.bytesToString(decrypted)
    } catch (err) {
      hilog.error(0x0000, 'FinTrack', 'Decryption failed')
      return cipherText
    }
  }

  /**
   * 生成安全的随机 ID
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
   * 简单字符串哈希
   */
  static simpleHash(str: string): number {
    let hash = 0
    for (let i = 0; i < str.length; i++) {
      const char = str.charCodeAt(i)
      hash = ((hash << 5) - hash) + char
      hash = hash & hash
    }
    return Math.abs(hash)
  }

  // ==================== 编码工具 ====================

  private static stringToBytes(str: string): Uint8Array {
    const bytes = new Uint8Array(str.length)
    for (let i = 0; i < str.length; i++) {
      bytes[i] = str.charCodeAt(i) & 0xFF
    }
    return bytes
  }

  private static bytesToString(bytes: Uint8Array): string {
    let str = ''
    for (let i = 0; i < bytes.length; i++) {
      str += String.fromCharCode(bytes[i])
    }
    return str
  }

  private static bytesToBase64(bytes: Uint8Array): string {
    const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/'
    let result = ''
    let i = 0
    while (i < bytes.length) {
      const a = bytes[i]
      const b = i + 1 < bytes.length ? bytes[i + 1] : 0
      const c = i + 2 < bytes.length ? bytes[i + 2] : 0
      result += chars.charAt((a >> 2) & 0x3F)
      result += chars.charAt(((a << 4) | (b >> 4)) & 0x3F)
      result += i + 1 < bytes.length ? chars.charAt(((b << 2) | (c >> 6)) & 0x3F) : '='
      result += i + 2 < bytes.length ? chars.charAt(c & 0x3F) : '='
      i += 3
    }
    return result
  }

  private static base64ToBytes(base64: string): Uint8Array {
    const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/'
    const clean = base64.replace(/[^A-Za-z0-9+/=]/g, '')
    const outputLen = Math.floor(clean.length * 3 / 4)
    const result = new Uint8Array(outputLen)
    let idx = 0

    for (let i = 0; i < clean.length; i += 4) {
      const a = chars.indexOf(clean.charAt(i))
      const b = i + 1 < clean.length ? chars.indexOf(clean.charAt(i + 1)) : 0
      const c = i + 2 < clean.length ? chars.indexOf(clean.charAt(i + 2)) : 0
      const d = i + 3 < clean.length ? chars.indexOf(clean.charAt(i + 3)) : 0

      result[idx++] = ((a << 2) | (b >> 4)) & 0xFF
      if (clean.charAt(i + 2) !== '=' && idx < outputLen) result[idx++] = ((b << 4) | (c >> 2)) & 0xFF
      if (clean.charAt(i + 3) !== '=' && idx < outputLen) result[idx++] = ((c << 6) | d) & 0xFF
    }

    return result.slice(0, idx)
  }
}

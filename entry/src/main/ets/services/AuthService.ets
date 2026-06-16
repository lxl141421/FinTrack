import { userAuth } from '@kit.UserAuthenticationKit'
import { hilog } from '@kit.PerformanceAnalysisKit'

/**
 * 生物认证服务 - 支持面部+指纹混合认证
 */

export interface AuthResult {
  success: boolean
  method?: string
  error?: string
}

export class AuthService {
  private static instance: AuthService | null = null

  private constructor() {}

  static getInstance(): AuthService {
    if (AuthService.instance === null) {
      AuthService.instance = new AuthService()
    }
    return AuthService.instance
  }

  /**
   * 检查设备是否支持生物认证
   */
  async isBiometricAvailable(): Promise<boolean> {
    try {
      await userAuth.getAvailableStatus(
        userAuth.UserAuthType.FINGERPRINT,
        userAuth.AuthTrustLevel.ATL1
      )
      return true
    } catch (err) {
      hilog.warn(0x0000, 'FinTrack', 'Biometric check failed')
      return false
    }
  }

  /**
   * 获取支持的认证类型
   */
  async getAvailableAuthTypes(): Promise<number[]> {
    const types: number[] = []

    try {
      await userAuth.getAvailableStatus(
        userAuth.UserAuthType.FINGERPRINT,
        userAuth.AuthTrustLevel.ATL1
      )
      types.push(1) // FINGERPRINT
    } catch {
      // not available
    }

    try {
      await userAuth.getAvailableStatus(
        userAuth.UserAuthType.FACE,
        userAuth.AuthTrustLevel.ATL1
      )
      types.push(4) // FACE
    } catch {
      // not available
    }

    return types
  }

  /**
   * 执行混合生物认证
   */
  async authenticateHybrid(
    reason: string = '验证身份以访问财务数据'
  ): Promise<AuthResult> {
    try {
      const availableTypes = await this.getAvailableAuthTypes()
      if (availableTypes.length === 0) {
        return { success: false, error: '设备不支持生物认证' }
      }

      const authParam: userAuth.AuthParam = {
        challenge: new Uint8Array([0]),
        authType: [userAuth.UserAuthType.FINGERPRINT, userAuth.UserAuthType.FACE],
        authTrustLevel: userAuth.AuthTrustLevel.ATL1
      }

      const widgetParam: userAuth.WidgetParam = {
        title: reason
      }

      const userAuthInstance = userAuth.getUserAuthInstance(authParam, widgetParam)
      userAuthInstance.start()

      return new Promise<AuthResult>((resolve) => {
        userAuthInstance.on('result', {
          onResult: (result: userAuth.UserAuthResult) => {
            if (result.result === userAuth.UserAuthResultCode.SUCCESS) {
              resolve({ success: true, method: '生物认证' })
            } else {
              resolve({ success: false, error: `认证失败 (${result.result})` })
            }
          }
        })
      })
    } catch (err) {
      hilog.error(0x0000, 'FinTrack', 'Hybrid auth error')
      return { success: false, error: '认证过程发生错误' }
    }
  }

  /**
   * 执行生物认证（兼容旧接口）
   */
  async authenticate(reason: string = '验证身份以访问财务数据'): Promise<boolean> {
    const result = await this.authenticateHybrid(reason)
    return result.success
  }

  cancel(): void {
    try {
      userAuth.getUserAuthInstance(
        {
          challenge: new Uint8Array([0]),
          authType: [userAuth.UserAuthType.FINGERPRINT],
          authTrustLevel: userAuth.AuthTrustLevel.ATL1
        },
        { title: '' }
      ).cancel()
    } catch {
      // Ignore
    }
  }
}

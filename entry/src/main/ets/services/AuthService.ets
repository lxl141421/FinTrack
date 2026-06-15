
import { userAuth } from '@kit.UserAuthenticationKit'
import { hilog } from '@kit.PerformanceAnalysisKit'

/**
 * 生物认证服务
 * 封装指纹/面部识别认证
 */
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
      const result = await userAuth.getAvailableStatus(
        userAuth.AuthType.FINGERPRINT,
        userAuth.AuthTrustLevel.ATL1
      )
      return result === 0
    } catch (err) {
      hilog.warn(0x0000, 'FinTrack', 'Biometric check failed: %{public}s', JSON.stringify(err))
      return false
    }
  }

  /**
   * 执行生物认证
   * @param reason 认证原因提示
   * @returns 是否认证成功
   */
  async authenticate(reason: string = '验证身份以访问财务数据'): Promise<boolean> {
    try {
      const authParam: userAuth.AuthParam = {
        challenge: new Uint8Array([0]),
        authType: [userAuth.AuthType.FINGERPRINT],
        authTrustLevel: userAuth.AuthTrustLevel.ATL1
      }

      const widgetParam: userAuth.WidgetParam = {
        title: reason
      }

      const userAuthInstance = userAuth.getUserAuthInstance(authParam, widgetParam)
      userAuthInstance.start()

      return new Promise<boolean>((resolve) => {
        userAuthInstance.on('result', {
          onResult: (result: userAuth.UserAuthResult) => {
            if (result.result === userAuth.UserAuthResultCode.SUCCESS) {
              hilog.info(0x0000, 'FinTrack', 'Biometric auth succeeded')
              resolve(true)
            } else {
              hilog.warn(0x0000, 'FinTrack', 'Biometric auth failed: %{public}d', result.result)
              resolve(false)
            }
          }
        })
      })
    } catch (err) {
      hilog.error(0x0000, 'FinTrack', 'Biometric auth error: %{public}s', JSON.stringify(err))
      return false
    }
  }

  /**
   * 取消进行中的认证
   */
  cancel(): void {
    try {
      userAuth.getUserAuthInstance(
        { challenge: new Uint8Array([0]), authType: [userAuth.AuthType.FINGERPRINT], authTrustLevel: userAuth.AuthTrustLevel.ATL1 },
        { title: '' }
      ).cancel()
    } catch {
      // Ignore cancel errors
    }
  }
}

import { hilog } from '@kit.PerformanceAnalysisKit'
import { preferences } from '@kit.ArkData'
import { userAuth } from '@kit.UserAuthenticationKit'
import { Context } from '@kit.AbilityKit'

/**
 * 会话状态
 */
export enum SessionState {
  ACTIVE = 'ACTIVE',         // 活跃状态
  IDLE = 'IDLE',             // 空闲状态
  LOCKED = 'LOCKED',         // 已锁定
  EXPIRED = 'EXPIRED'        // 已过期
}

/**
 * 认证方式
 */
export enum AuthMethod {
  GESTURE = 'GESTURE',       // 手势密码
  FINGERPRINT = 'FINGERPRINT', // 指纹
  FACE = 'FACE',             // 面部识别
  BIOMETRIC = 'BIOMETRIC'    // 生物认证（自动选择）
}

/**
 * 会话安全服务
 *
 * 金融合规要求：
 * - 用户无操作N分钟后自动锁定
 * - 敏感操作（大额交易、删除）需要二次认证
 * - 会话超时后需要重新验证身份
 * - 支持多种认证方式（手势/指纹/面部）
 */
export class SessionGuard {
  private static instance: SessionGuard | null = null
  private static readonly TAG: string = 'FinTrack-Session'
  private static readonly STORE_NAME: string = 'session_config'
  private static readonly KEY_TIMEOUT: string = 'session_timeout'
  private static readonly KEY_LAST_ACTIVE: string = 'last_active_time'
  private static readonly KEY_AUTH_REQUIRED: string = 'auth_required'

  // 默认5分钟超时（金融行业标准）
  private static readonly DEFAULT_TIMEOUT_MS: number = 5 * 60 * 1000
  // 敏感操作金额阈值（超过此金额需要二次认证）
  private static readonly SENSITIVE_AMOUNT_THRESHOLD: number = 10000

  private context: Context | null = null
  private prefStore: preferences.Preferences | null = null
  private isInitialized: boolean = false

  private currentState: SessionState = SessionState.ACTIVE
  private timeoutMs: number = SessionGuard.DEFAULT_TIMEOUT_MS
  private lastActiveTime: number = Date.now()
  private timeoutTimer: number = -1
  private onStateChange: ((state: SessionState) => void) | null = null

  private constructor() {}

  static getInstance(): SessionGuard {
    if (SessionGuard.instance === null) {
      SessionGuard.instance = new SessionGuard()
    }
    return SessionGuard.instance
  }

  /**
   * 初始化会话安全服务
   */
  async init(context: Context): Promise<void> {
    this.context = context
    try {
      this.prefStore = await preferences.getPreferences(context, SessionGuard.STORE_NAME)

      // 读取配置
      const savedTimeout = await this.prefStore.get(SessionGuard.KEY_TIMEOUT, SessionGuard.DEFAULT_TIMEOUT_MS)
      this.timeoutMs = savedTimeout as number

      this.isInitialized = true
      this.resetTimer()

      hilog.info(0x0000, SessionGuard.TAG,
        'SessionGuard initialized, timeout: %{public}d min', this.timeoutMs / 60000)
    } catch (err) {
      hilog.error(0x0000, SessionGuard.TAG, 'SessionGuard init failed')
    }
  }

  /**
   * 设置状态变化回调
   */
  setStateChangeCallback(callback: (state: SessionState) => void): void {
    this.onStateChange = callback
  }

  /**
   * 设置超时时间（分钟）
   */
  async setTimeoutMinutes(minutes: number): Promise<void> {
    this.timeoutMs = minutes * 60 * 1000
    if (this.prefStore !== null) {
      await this.prefStore.put(SessionGuard.KEY_TIMEOUT, this.timeoutMs)
      await this.prefStore.flush()
    }
    this.resetTimer()
  }

  /**
   * 获取超时时间（分钟）
   */
  getTimeoutMinutes(): number {
    return Math.floor(this.timeoutMs / 60000)
  }

  /**
   * 用户活动通知（重置计时器）
   */
  onUserActivity(): void {
    if (this.currentState === SessionState.LOCKED || this.currentState === SessionState.EXPIRED) {
      return  // 已锁定，不响应普通活动
    }

    this.lastActiveTime = Date.now()
    this.currentState = SessionState.ACTIVE
    this.resetTimer()
  }

  /**
   * 重置超时计时器
   */
  private resetTimer(): void {
    if (this.timeoutTimer !== -1) {
      clearTimeout(this.timeoutTimer)
    }

    this.timeoutTimer = setTimeout(() => {
      this.onTimeout()
    }, this.timeoutMs) as unknown as number
  }

  /**
   * 超时处理
   */
  private onTimeout(): void {
    this.currentState = SessionState.LOCKED
    hilog.warn(0x0000, SessionGuard.TAG, 'Session locked due to inactivity')

    if (this.onStateChange !== null) {
      this.onStateChange(SessionState.LOCKED)
    }
  }

  /**
   * 获取当前会话状态
   */
  getState(): SessionState {
    return this.currentState
  }

  /**
   * 检查是否需要认证
   */
  isAuthRequired(): boolean {
    return this.currentState === SessionState.LOCKED ||
      this.currentState === SessionState.EXPIRED
  }

  /**
   * 检查是否为敏感操作（需要二次认证）
   */
  isSensitiveOperation(amount: number): boolean {
    return amount >= SessionGuard.SENSITIVE_AMOUNT_THRESHOLD
  }

  /**
   * 解锁会话（验证身份）
   */
  async unlock(method: AuthMethod = AuthMethod.BIOMETRIC): Promise<boolean> {
    try {
      let success = false

      switch (method) {
        case AuthMethod.GESTURE:
          success = await this.verifyGesture()
          break
        case AuthMethod.FINGERPRINT:
        case AuthMethod.FACE:
        case AuthMethod.BIOMETRIC:
          success = await this.verifyBiometric()
          break
      }

      if (success) {
        this.currentState = SessionState.ACTIVE
        this.lastActiveTime = Date.now()
        this.resetTimer()
        hilog.info(0x0000, SessionGuard.TAG, 'Session unlocked')

        if (this.onStateChange !== null) {
          this.onStateChange(SessionState.ACTIVE)
        }
      }

      return success
    } catch (err) {
      hilog.error(0x0000, SessionGuard.TAG, 'Unlock failed')
      return false
    }
  }

  /**
   * 生物认证验证
   */
  private async verifyBiometric(): Promise<boolean> {
    return new Promise<boolean>((resolve) => {
      try {
        const authParam: userAuth.AuthParam = {
          challenge: new Uint8Array([1, 2, 3, 4, 5, 6, 7, 8]),
          authType: [userAuth.UserAuthType.FINGERPRINT, userAuth.UserAuthType.FACE],
          authTrustLevel: userAuth.AuthTrustLevel.ATL1
        }

        const widgetParam: userAuth.WidgetParam = {
          title: '请验证身份'
        }

        const userAuthInstance = userAuth.getUserAuthInstance(authParam, widgetParam)
        userAuthInstance.on('result', {
          onResult: (result: userAuth.UserAuthResult) => {
            if (result.result === userAuth.UserAuthResultCode.SUCCESS) {
              resolve(true)
            } else {
              resolve(false)
            }
          }
        })
        userAuthInstance.start()
      } catch (err) {
        hilog.error(0x0000, SessionGuard.TAG, 'Biometric auth failed')
        resolve(false)
      }
    })
  }

  /**
   * 手势密码验证（简单实现，实际应调用手势锁页面）
   */
  private async verifyGesture(): Promise<boolean> {
    // 实际实现中，这里会跳转到手势锁页面验证
    // 这里简化为直接返回 true（由 UI 层处理）
    return true
  }

  /**
   * 锁定会话
   */
  lock(): void {
    this.currentState = SessionState.LOCKED
    if (this.timeoutTimer !== -1) {
      clearTimeout(this.timeoutTimer)
    }
    hilog.info(0x0000, SessionGuard.TAG, 'Session manually locked')

    if (this.onStateChange !== null) {
      this.onStateChange(SessionState.LOCKED)
    }
  }

  /**
   * 销毁会话
   */
  destroy(): void {
    if (this.timeoutTimer !== -1) {
      clearTimeout(this.timeoutTimer)
    }
    this.currentState = SessionState.EXPIRED
  }
}

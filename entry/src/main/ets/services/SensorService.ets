import { sensor } from '@kit.SensorServiceKit'
import { hilog } from '@kit.PerformanceAnalysisKit'

/**
 * 传感器服务
 * 封装环境光、距离、握持检测等传感器
 */

/** 握持状态枚举 */
export enum GripState {
  UNKNOWN = 0,
  LEFT_HAND = 1,
  RIGHT_HAND = 2,
  BOTH_HANDS = 3
}

export class SensorService {
  private static instance: SensorService | null = null

  private ambientLux: number = 0
  private isProximityBlocked: boolean = false
  private gripState: GripState = GripState.UNKNOWN
  private lastLightState: boolean = false

  private lightCallbacks: Array<(lux: number, isDark: boolean) => void> = []
  private proximityCallbacks: Array<(blocked: boolean) => void> = []
  private gripCallbacks: Array<(state: GripState) => void> = []

  private lightRunning: boolean = false
  private proximityRunning: boolean = false
  private gripRunning: boolean = false

  private static readonly DARK_THRESHOLD: number = 30
  private static readonly LIGHT_THRESHOLD: number = 80

  private constructor() {}

  static getInstance(): SensorService {
    if (SensorService.instance === null) {
      SensorService.instance = new SensorService()
    }
    return SensorService.instance
  }

  startLightSensor(): void {
    if (this.lightRunning) return
    try {
      // HarmonyOS sensorId: LIGHT = 5
      sensor.on(5, (data: sensor.LightResponse) => {
        this.ambientLux = data.intensity
        const isDark = this.ambientLux < SensorService.DARK_THRESHOLD
        const isLight = this.ambientLux > SensorService.LIGHT_THRESHOLD

        if (!isDark && !isLight) return

        if (isDark && !this.lastLightState) {
          this.lastLightState = true
          for (const cb of this.lightCallbacks) {
            cb(this.ambientLux, true)
          }
        } else if (isLight && this.lastLightState) {
          this.lastLightState = false
          for (const cb of this.lightCallbacks) {
            cb(this.ambientLux, false)
          }
        }
      }, { interval: 1000000000 })
      this.lightRunning = true
      hilog.info(0x0000, 'FinTrack', 'Light sensor started')
    } catch (err) {
      hilog.error(0x0000, 'FinTrack', 'Failed to start light sensor')
    }
  }

  onLightChange(callback: (lux: number, isDark: boolean) => void): void {
    this.lightCallbacks.push(callback)
  }

  offLightChange(callback: (lux: number, isDark: boolean) => void): void {
    const idx = this.lightCallbacks.indexOf(callback)
    if (idx >= 0) this.lightCallbacks.splice(idx, 1)
  }

  startProximitySensor(): void {
    if (this.proximityRunning) return
    try {
      // HarmonyOS sensorId: PROXIMITY = 8
      sensor.on(8, (data: sensor.ProximityResponse) => {
        const blocked = data.distance === 0 || data.distance < 5
        if (blocked !== this.isProximityBlocked) {
          this.isProximityBlocked = blocked
          for (const cb of this.proximityCallbacks) {
            cb(blocked)
          }
        }
      }, { interval: 500000000 })
      this.proximityRunning = true
      hilog.info(0x0000, 'FinTrack', 'Proximity sensor started')
    } catch (err) {
      hilog.error(0x0000, 'FinTrack', 'Failed to start proximity sensor')
    }
  }

  onProximityChange(callback: (blocked: boolean) => void): void {
    this.proximityCallbacks.push(callback)
  }

  offProximityChange(callback: (blocked: boolean) => void): void {
    const idx = this.proximityCallbacks.indexOf(callback)
    if (idx >= 0) this.proximityCallbacks.splice(idx, 1)
  }

  startGripDetection(): void {
    if (this.gripRunning) return
    try {
      // HarmonyOS sensorId: ACCELEROMETER = 1
      sensor.on(1, (data: sensor.AccelerometerResponse) => {
        const x = data.x
        let newState = GripState.UNKNOWN
        if (Math.abs(x) > 3) {
          newState = x > 0 ? GripState.RIGHT_HAND : GripState.LEFT_HAND
        } else if (Math.abs(x) < 1.5) {
          newState = GripState.BOTH_HANDS
        }
        if (newState !== this.gripState && newState !== GripState.UNKNOWN) {
          this.gripState = newState
          for (const cb of this.gripCallbacks) {
            cb(newState)
          }
        }
      }, { interval: 500000000 })
      this.gripRunning = true
      hilog.info(0x0000, 'FinTrack', 'Grip detection started')
    } catch (err) {
      hilog.error(0x0000, 'FinTrack', 'Failed to start grip detection')
    }
  }

  onGripChange(callback: (state: GripState) => void): void {
    this.gripCallbacks.push(callback)
  }

  offGripChange(callback: (state: GripState) => void): void {
    const idx = this.gripCallbacks.indexOf(callback)
    if (idx >= 0) this.gripCallbacks.splice(idx, 1)
  }

  startAll(): void {
    this.startLightSensor()
    this.startProximitySensor()
    this.startGripDetection()
  }

  stopAll(): void {
    try {
      if (this.lightRunning) {
        sensor.off(5)
        this.lightRunning = false
      }
      if (this.proximityRunning) {
        sensor.off(8)
        this.proximityRunning = false
      }
      if (this.gripRunning) {
        sensor.off(1)
        this.gripRunning = false
      }
      this.lightCallbacks = []
      this.proximityCallbacks = []
      this.gripCallbacks = []
    } catch (err) {
      hilog.error(0x0000, 'FinTrack', 'Failed to stop sensors')
    }
  }

  getCurrentLux(): number { return this.ambientLux }
  isProximityBlockedState(): boolean { return this.isProximityBlocked }
  getCurrentGrip(): GripState { return this.gripState }
}

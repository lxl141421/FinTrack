
/**
 * 图表数据处理工具类
 */
export class ChartDataPoint {
  x: number = 0
  y: number = 0
  label: string = ''
  value: number = 0
  color: string = '#007DFF'

  constructor(x: number, y: number, label: string = '', value: number = 0, color: string = '#007DFF') {
    this.x = x
    this.y = y
    this.label = label
    this.value = value
    this.color = color
  }
}

export class KLineData {
  timestamp: number = 0
  open: number = 0
  high: number = 0
  low: number = 0
  close: number = 0
  volume: number = 0

  constructor(timestamp: number, open: number, high: number, low: number, close: number, volume: number = 0) {
    this.timestamp = timestamp
    this.open = open
    this.high = high
    this.low = low
    this.close = close
    this.volume = volume
  }

  /** 是否为阳线（收盘 > 开盘） */
  isPositive(): boolean {
    return this.close >= this.open
  }

  /** 实体高度 */
  bodyHeight(): number {
    return Math.abs(this.close - this.open)
  }

  /** 上影线长度 */
  upperShadow(): number {
    return this.high - Math.max(this.open, this.close)
  }

  /** 下影线长度 */
  lowerShadow(): number {
    return Math.min(this.open, this.close) - this.low
  }
}

export class PieSlice {
  label: string = ''
  value: number = 0
  color: string = '#007DFF'
  percent: number = 0

  constructor(label: string, value: number, color: string) {
    this.label = label
    this.value = value
    this.color = color
  }
}

export class ChartUtils {
  /**
   * 计算折线图的点坐标
   * @param data 数据数组
   * @param width 画布宽度
   * @param height 画布高度
   * @param padding 内边距
   */
  static calculateLinePoints(
    data: number[],
    width: number,
    height: number,
    padding: number = 16
  ): ChartDataPoint[] {
    if (data.length === 0) return []

    const points: ChartDataPoint[] = []
    const chartWidth = width - padding * 2
    const chartHeight = height - padding * 2

    const min = Math.min(...data)
    const max = Math.max(...data)
    const range = max - min || 1

    for (let i = 0; i < data.length; i++) {
      const x = padding + (i / Math.max(data.length - 1, 1)) * chartWidth
      const y = padding + chartHeight - ((data[i] - min) / range) * chartHeight
      points.push(new ChartDataPoint(x, y, '', data[i]))
    }

    return points
  }

  /**
   * 计算饼图的数据切片
   * @param data 标签和数值的映射
   * @param colors 颜色数组
   */
  static calculatePieSlices(
    data: Record<string, number>,
    colors: string[]
  ): PieSlice[] {
    const slices: PieSlice[] = []
    let total = 0

    for (const key in data) {
      total += data[key]
    }
    if (total <= 0) return slices

    let idx = 0
    for (const key in data) {
      const slice = new PieSlice(key, data[key], colors[idx % colors.length])
      slice.percent = data[key] / total
      slices.push(slice)
      idx++
    }

    // 按百分比降序排列
    slices.sort((a, b) => b.percent - a.percent)
    return slices
  }

  /**
   * 从每日交易数据生成 K 线数据
   * @param dailyAmounts 每日金额数组 {date, amount}
   */
  static generateKLineFromDaily(
    dailyAmounts: { timestamp: number; amount: number }[]
  ): KLineData[] {
    if (dailyAmounts.length === 0) return []

    const result: KLineData[] = []
    for (let i = 0; i < dailyAmounts.length; i++) {
      const item = dailyAmounts[i]
      const prevClose = i > 0 ? dailyAmounts[i - 1].amount : item.amount
      const open = prevClose
      const close = item.amount
      const high = Math.max(open, close) * (1 + Math.random() * 0.02)
      const low = Math.min(open, close) * (1 - Math.random() * 0.02)
      const volume = Math.abs(close - open) * 100

      result.push(new KLineData(
        item.timestamp,
        Number(open.toFixed(2)),
        Number(high.toFixed(2)),
        Number(low.toFixed(2)),
        Number(close.toFixed(2)),
        Math.floor(volume)
      ))
    }
    return result
  }

  /**
   * 计算移动平均线
   * @param data 数据
   * @param period 周期
   */
  static calculateMA(data: number[], period: number): number[] {
    const result: number[] = []
    for (let i = 0; i < data.length; i++) {
      if (i < period - 1) {
        result.push(NaN)
      } else {
        let sum = 0
        for (let j = i - period + 1; j <= i; j++) {
          sum += data[j]
        }
        result.push(Number((sum / period).toFixed(2)))
      }
    }
    return result
  }

  /**
   * 聚合数据（按分组键）
   */
  static aggregateByCategory(
    items: { category: string; categoryName: string; amount: number; color: string }[]
  ): Record<string, number> {
    const result: Record<string, number> = {}
    for (const item of items) {
      const key = item.categoryName
      if (result[key] === undefined) {
        result[key] = 0
      }
      result[key] += item.amount
    }
    return result
  }
}

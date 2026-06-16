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

  isPositive(): boolean {
    return this.close >= this.open
  }

  bodyHeight(): number {
    return Math.abs(this.close - this.open)
  }

  upperShadow(): number {
    return this.high - Math.max(this.open, this.close)
  }

  lowerShadow(): number {
    return Math.min(this.open, this.close) - this.low
  }
}

export class PieSlice {
  label: string = ''
  value: number = 0
  color: string = '#007DFF'
  percent: number = 0

  constructor(label: string, value: number, color: string, total: number = 0) {
    this.label = label
    this.value = value
    this.color = color
    this.percent = total > 0 ? value / total : 0
  }
}

/** 每日金额数据点 */
export class DailyAmount {
  timestamp: number = 0
  amount: number = 0

  constructor(timestamp: number, amount: number) {
    this.timestamp = timestamp
    this.amount = amount
  }
}

/** 分类聚合数据项 */
export class CategoryItem {
  category: string = ''
  categoryName: string = ''
  amount: number = 0
  color: string = '#007DFF'

  constructor(category: string, categoryName: string, amount: number, color: string) {
    this.category = category
    this.categoryName = categoryName
    this.amount = amount
    this.color = color
  }
}

export class ChartUtils {
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

  static calculatePieSlices(
    data: Record<string, number>,
    colors: string[]
  ): PieSlice[] {
    const slices: PieSlice[] = []
    let total = 0

    const keys = Object.keys(data)
    for (let i = 0; i < keys.length; i++) {
      total += data[keys[i]]
    }
    if (total <= 0) return slices

    for (let i = 0; i < keys.length; i++) {
      const key = keys[i]
      const slice = new PieSlice(key, data[key], colors[i % colors.length])
      slice.percent = data[key] / total
      slices.push(slice)
    }

    slices.sort((a: PieSlice, b: PieSlice) => b.percent - a.percent)
    return slices
  }

  static generateKLineFromDaily(dailyAmounts: DailyAmount[]): KLineData[] {
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

  static aggregateByCategory(items: CategoryItem[]): Record<string, number> {
    const result: Record<string, number> = {}
    for (let i = 0; i < items.length; i++) {
      const key = items[i].categoryName
      if (result[key] === undefined) {
        result[key] = 0
      }
      result[key] += items[i].amount
    }
    return result
  }
}

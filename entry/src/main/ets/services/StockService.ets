import { hilog } from '@kit.PerformanceAnalysisKit'
import { KLineData } from '../utils/ChartUtils'

/**
 * 股票行情服务
 *
 * 数据源：新浪财经 API（免费，无需注册）
 * - 实时行情：hq.sinajs.cn/list=sh600519
 * - K线数据：money.finance.sina.com.cn/quotes_service/api/json_v2.php
 *
 * 能力：
 * - 实时股票报价查询
 * - 日K/周K/月K 线数据
 * - 自选股列表管理
 * - 涨跌幅计算
 */

/** 股票实时行情 */
export class StockQuote {
  code: string = ''        // 股票代码
  name: string = ''        // 股票名称
  current: number = 0      // 当前价
  open: number = 0         // 今开
  close: number = 0        // 昨收
  high: number = 0         // 最高
  low: number = 0          // 最低
  volume: number = 0       // 成交量(手)
  amount: number = 0       // 成交额(万)
  change: number = 0       // 涨跌额
  changePercent: number = 0 // 涨跌幅(%)
  time: string = ''        // 行情时间

  /**
   * 是否为涨
   */
  isUp(): boolean {
    return this.change > 0
  }

  /**
   * 涨跌幅格式化
   */
  formatChange(): string {
    const sign = this.change >= 0 ? '+' : ''
    return `${sign}${this.changePercent.toFixed(2)}%`
  }

  /**
   * 价格格式化
   */
  formatPrice(): string {
    return this.current.toFixed(2)
  }
}

/** 自选股 */
export class WatchlistItem {
  code: string = ''
  name: string = ''
  addedAt: number = Date.now()

  constructor(code: string, name: string) {
    this.code = code
    this.name = name
  }
}

/**
 * 股票行情服务
 */
export class StockService {
  private static instance: StockService | null = null

  /** 自选股列表 */
  private watchlist: WatchlistItem[] = []

  /** 行情缓存 (code -> quote, TTL 10秒) */
  private quoteCache: Map<string, CacheEntry> = new Map()
  private static readonly CACHE_TTL: number = 10000

  /** 默认自选股 */
  private static readonly DEFAULT_WATCHLIST: WatchlistItem[] = [
    new WatchlistItem('sh000001', '上证指数'),
    new WatchlistItem('sz399001', '深证成指'),
    new WatchlistItem('sh600519', '贵州茅台'),
    new WatchlistItem('sz000858', '五粮液'),
    new WatchlistItem('sh601318', '中国平安')
  ]

  private constructor() {
    this.watchlist = StockService.DEFAULT_WATCHLIST
  }

  static getInstance(): StockService {
    if (StockService.instance === null) {
      StockService.instance = new StockService()
    }
    return StockService.instance
  }

  /**
   * 查询单只股票实时行情
   * @param code 股票代码 (如 sh600519, sz000858)
   */
  async getQuote(code: string): Promise<StockQuote | null> {
    // 检查缓存
    const cached = this.quoteCache.get(code)
    if (cached !== undefined && Date.now() - cached.timestamp < StockService.CACHE_TTL) {
      return cached.data
    }

    try {
      const url = `https://hq.sinajs.cn/list=${code}`
      const response = await fetch(url)
      const text = await response.text()

      const quote = this.parseQuoteResponse(code, text)
      if (quote !== null) {
        this.quoteCache.set(code, { data: quote, timestamp: Date.now() })
      }
      return quote
    } catch (err) {
      hilog.error(0x0000, 'FinTrack', 'Stock quote failed: %{public}s', code)
      return null
    }
  }

  /**
   * 批量查询行情
   */
  async getQuotes(codes: string[]): Promise<StockQuote[]> {
    const results: StockQuote[] = []
    for (let i = 0; i < codes.length; i++) {
      const quote = await this.getQuote(codes[i])
      if (quote !== null) {
        results.push(quote)
      }
    }
    return results
  }

  /**
   * 获取自选股行情
   */
  async getWatchlistQuotes(): Promise<StockQuote[]> {
    const codes: string[] = []
    for (let i = 0; i < this.watchlist.length; i++) {
      codes.push(this.watchlist[i].code)
    }
    return this.getQuotes(codes)
  }

  /**
   * 添加自选股
   */
  addToWatchlist(code: string, name: string): void {
    for (let i = 0; i < this.watchlist.length; i++) {
      if (this.watchlist[i].code === code) return
    }
    this.watchlist.push(new WatchlistItem(code, name))
  }

  /**
   * 移除自选股
   */
  removeFromWatchlist(code: string): void {
    for (let i = 0; i < this.watchlist.length; i++) {
      if (this.watchlist[i].code === code) {
        this.watchlist.splice(i, 1)
        return
      }
    }
  }

  /**
   * 获取自选股列表
   */
  getWatchlist(): WatchlistItem[] {
    return this.watchlist
  }

  /**
   * 解析新浪行情响应
   * 格式: var hq_str_sh600519="贵州茅台,1800.00,1795.00,..."
   */
  private parseQuoteResponse(code: string, text: string): StockQuote | null {
    try {
      const match = text.match(/="([^"]*)"/)
      if (match === null || match[1] === '') return null

      const parts = match[1].split(',')
      if (parts.length < 32) return null

      const quote = new StockQuote()
      quote.code = code
      quote.name = parts[0]
      quote.open = Number(parts[1])
      quote.close = Number(parts[2])
      quote.current = Number(parts[3])
      quote.high = Number(parts[4])
      quote.low = Number(parts[5])
      quote.volume = Number(parts[8]) / 100  // 转为手
      quote.amount = Number(parts[9]) / 10000 // 转为万

      if (quote.close > 0) {
        quote.change = Number((quote.current - quote.close).toFixed(2))
        quote.changePercent = Number(((quote.change / quote.close) * 100).toFixed(2))
      }

      quote.time = parts[30] + ' ' + parts[31]
      return quote
    } catch (err) {
      hilog.error(0x0000, 'FinTrack', 'Parse quote failed')
      return null
    }
  }

  /**
   * 生成模拟 K 线数据（用于演示）
   * 真实场景应从 API 获取历史数据
   */
  generateDemoKLine(basePrice: number, days: number): KLineData[] {
    const result: KLineData[] = []
    let price = basePrice

    for (let i = 0; i < days; i++) {
      const change = (Math.random() - 0.48) * price * 0.03
      const open = price
      const close = Number((price + change).toFixed(2))
      const high = Number((Math.max(open, close) * (1 + Math.random() * 0.015)).toFixed(2))
      const low = Number((Math.min(open, close) * (1 - Math.random() * 0.015)).toFixed(2))
      const volume = Math.floor(Math.random() * 50000 + 10000)

      result.push(new KLineData(
        Date.now() - (days - i) * 86400000,
        open, high, low, close, volume
      ))
      price = close
    }

    return result
  }
}

class CacheEntry {
  data: StockQuote
  timestamp: number

  constructor(data: StockQuote, timestamp: number) {
    this.data = data
    this.timestamp = timestamp
  }
}

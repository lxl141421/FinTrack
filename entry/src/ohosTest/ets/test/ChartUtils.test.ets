
import { describe, it, expect } from '@ohos/hypium'
import { ChartUtils, KLineData, PieSlice } from '../../../../main/ets/utils/ChartUtils'

export default function ChartUtilsTest() {
  describe('ChartUtilsTest', () => {
    it('should_calculate_line_points', 0, () => {
      const data = [10, 20, 15, 30, 25]
      const points = ChartUtils.calculateLinePoints(data, 350, 200, 16)

      expect(points.length).assertEqual(5)
      expect(points[0].x).assertEqual(16) // First point at padding
      expect(points[4].x).assertEqual(334) // Last point at width - padding
    })

    it('should_handle_empty_data', 0, () => {
      const points = ChartUtils.calculateLinePoints([], 350, 200, 16)
      expect(points.length).assertEqual(0)
    })

    it('should_handle_single_data_point', 0, () => {
      const points = ChartUtils.calculateLinePoints([42], 350, 200, 16)
      expect(points.length).assertEqual(1)
    })

    it('should_calculate_pie_slices', 0, () => {
      const data: Record<string, number> = {
        '餐饮': 500,
        '交通': 300,
        '购物': 200
      }
      const colors = ['#007DFF', '#00B578', '#FF8800']
      const slices = ChartUtils.calculatePieSlices(data, colors)

      expect(slices.length).assertEqual(3)
      // Should be sorted by percent descending
      expect(slices[0].label).assertEqual('餐饮')
      expect(slices[0].percent).assertEqual(0.5)
    })

    it('should_calculate_moving_average', 0, () => {
      const data = [10, 20, 30, 40, 50]
      const ma3 = ChartUtils.calculateMA(data, 3)

      expect(ma3.length).assertEqual(5)
      // First 2 should be NaN
      expect(isNaN(ma3[0])).assertTrue()
      expect(isNaN(ma3[1])).assertTrue()
      // MA3 of [10,20,30] = 20
      expect(ma3[2]).assertEqual(20)
      // MA3 of [20,30,40] = 30
      expect(ma3[3]).assertEqual(30)
      // MA3 of [30,40,50] = 40
      expect(ma3[4]).assertEqual(40)
    })

    it('should_create_kline_data', 0, () => {
      const kline = new KLineData(1000, 100, 110, 95, 105, 1000)

      expect(kline.isPositive()).assertTrue() // close > open
      expect(kline.bodyHeight()).assertEqual(5) // |105 - 100|
      expect(kline.upperShadow()).assertEqual(5) // 110 - 105
      expect(kline.lowerShadow()).assertEqual(5) // 100 - 95
    })

    it('should_identify_negative_kline', 0, () => {
      const kline = new KLineData(1000, 105, 110, 95, 100, 1000)

      expect(kline.isPositive()).assertFalse() // close < open
      expect(kline.bodyHeight()).assertEqual(5) // |100 - 105|
    })

    it('should_aggregate_by_category', 0, () => {
      const items = [
        { category: 'food', categoryName: '餐饮', amount: 100, color: '#000' },
        { category: 'food', categoryName: '餐饮', amount: 200, color: '#000' },
        { category: 'transport', categoryName: '交通', amount: 50, color: '#000' }
      ]
      const result = ChartUtils.aggregateByCategory(items)

      expect(result['餐饮']).assertEqual(300)
      expect(result['交通']).assertEqual(50)
    })

    it('should_calculate_pie_percent_correctly', 0, () => {
      const slice1 = new PieSlice('餐饮', 600, '#007DFF', 1000)
      const slice2 = new PieSlice('交通', 400, '#00B578', 1000)

      expect(slice1.percent).assertEqual(0.6)
      expect(slice2.percent).assertEqual(0.4)
    })

    it('should_handle_pie_percent_zero_total', 0, () => {
      const slice = new PieSlice('空', 0, '#007DFF', 0)
      expect(slice.percent).assertEqual(0)
    })

    it('should_sort_pie_slices_by_percent', 0, () => {
      const data: Record<string, number> = { 'A': 100, 'B': 300, 'C': 200 }
      const colors = ['#007DFF', '#00B578', '#FF8800']
      const slices = ChartUtils.calculatePieSlices(data, colors)

      expect(slices[0].label).assertEqual('B')
      expect(slices[0].percent).assertEqual(0.5)
      expect(slices[1].label).assertEqual('C')
      expect(slices[2].label).assertEqual('A')
    })

    it('should_calculate_moving_average_window_5', 0, () => {
      const data = [10, 20, 30, 40, 50, 60]
      const ma5 = ChartUtils.calculateMA(data, 5)

      expect(isNaN(ma5[0])).assertTrue()
      expect(isNaN(ma5[3])).assertTrue()
      // MA5 of [10,20,30,40,50] = 30
      expect(ma5[4]).assertEqual(30)
      // MA5 of [20,30,40,50,60] = 40
      expect(ma5[5]).assertEqual(40)
    })
  })
}

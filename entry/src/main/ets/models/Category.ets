import { Constants } from '../constants/Constants'

/**
 * 交易分类数据模型
 */
export class Category {
  id: string = ''
  name: string = ''
  icon: string = ''
  color: string = '#007DFF'
  type: number = Constants.TYPE_EXPENSE
  sortOrder: number = 0
  isDefault: boolean = false

  static create(name: string, icon: string, color: string, type: number): Category {
    const cat = new Category()
    cat.id = `cat_${Date.now()}_${Math.random().toString(36).substr(2, 6)}`
    cat.name = name
    cat.icon = icon
    cat.color = color
    cat.type = type
    return cat
  }

  toJson(): string {
    return JSON.stringify({
      id: this.id,
      name: this.name,
      icon: this.icon,
      color: this.color,
      type: this.type,
      sortOrder: this.sortOrder,
      isDefault: this.isDefault
    })
  }

  static fromJson(json: string): Category {
    const obj = JSON.parse(json) as Record<string, Object>
    const cat = new Category()
    cat.id = obj['id'] as string ?? ''
    cat.name = obj['name'] as string ?? ''
    cat.icon = obj['icon'] as string ?? ''
    cat.color = obj['color'] as string ?? '#007DFF'
    cat.type = obj['type'] as number ?? 0
    cat.sortOrder = obj['sortOrder'] as number ?? 0
    cat.isDefault = obj['isDefault'] as boolean ?? false
    return cat
  }

  /**
   * 获取默认分类列表
   */
  static getDefaults(): Category[] {
    const defaults: Category[] = []
    const expenseData: string[][] = [
      ['餐饮', '🍜', '#FA2A2D'],
      ['交通', '🚌', '#FF8800'],
      ['购物', '🛍️', '#F7CE46'],
      ['娱乐', '🎮', '#9B59B6'],
      ['住房', '🏠', '#007DFF'],
      ['医疗', '💊', '#00B578'],
      ['教育', '📚', '#3498DB'],
      ['通讯', '📱', '#1ABC9C'],
    ]
    const incomeData: string[][] = [
      ['工资', '💰', '#00B578'],
      ['投资', '📈', '#007DFF'],
      ['红包', '🧧', '#FA2A2D'],
      ['其他', '📌', '#666666'],
    ]

    let sortIdx = 0
    for (let _idx1 = 0; _idx1 < expenseData.length; _idx1++) {
      const d = expenseData[_idx1]
      const cat = Category.create(d[0], d[1], d[2], Constants.TYPE_EXPENSE)
      cat.sortOrder = sortIdx++
      cat.isDefault = true
      defaults.push(cat)
    }
    for (let _idx2 = 0; _idx2 < incomeData.length; _idx2++) {
      const d = incomeData[_idx2]
      const cat = Category.create(d[0], d[1], d[2], Constants.TYPE_INCOME)
      cat.sortOrder = sortIdx++
      cat.isDefault = true
      defaults.push(cat)
    }
    return defaults
  }
}
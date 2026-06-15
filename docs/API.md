# FinTrack API 文档

## Models

### Transaction
| 属性 | 类型 | 说明 |
|------|------|------|
| id | string | 唯一标识 |
| type | number | 0: 收入, 1: 支出, 2: 转账 |
| amount | number | 金额（绝对值） |
| category | string | 分类 ID |
| categoryName | string | 分类名称 |
| note | string | 备注 |
| date | number | 时间戳 |
| tags | string[] | 标签 |

### Budget
| 属性 | 类型 | 说明 |
|------|------|------|
| id | string | 唯一标识 |
| category | string | 分类（空=总预算） |
| limitAmount | number | 预算限额 |
| spentAmount | number | 已用金额 |
| month | string | 月份（YYYY-MM） |

## Services

### StorageService
```typescript
// 初始化
await StorageService.getInstance().init(context)

// 偏好存储
await storage.setPreference('key', 'value')
const value = await storage.getPreference('key', 'default')

// 交易 CRUD
await storage.insertTransaction(txn)
const txns = await storage.queryTransactions(type, startDate, endDate, category, keyword, limit)
await storage.updateTransaction(txn)
await storage.deleteTransaction(id)

// 预算 CRUD
await storage.insertBudget(budget)
const budgets = await storage.queryBudgets(month)
```

### DistributedService
```typescript
// 初始化
await DistributedService.getInstance().init(context)

// 同步
await distributed.putTransaction(txn)
await distributed.deleteTransaction(id)
const txns = await distributed.syncTransactions()

// 监听
distributed.setDataChangedCallback((txns) => { ... })
```

### AuthService
```typescript
const available = await AuthService.getInstance().isBiometricAvailable()
const success = await AuthService.getInstance().authenticate('验证身份')
```

## Utils

### CurrencyUtils
```typescript
CurrencyUtils.format(12345.67)         // "¥12,345.67"
CurrencyUtils.formatShort(12345678)    // "¥1,234.6万"
CurrencyUtils.parse("¥12,345.67")     // 12345.67
```

### DateUtils
```typescript
DateUtils.format(timestamp, 'YYYY-MM-DD')
DateUtils.getRelativeTime(timestamp)   // "昨天", "3天前", "06-15"
DateUtils.getCurrentMonth()            // "2026-06"
DateUtils.isCurrentMonth(timestamp)
```

### ChartUtils
```typescript
ChartUtils.calculateLinePoints(data, width, height, padding)
ChartUtils.calculatePieSlices(dataMap, colors)
ChartUtils.calculateMA(data, period)
ChartUtils.generateKLineFromDaily(dailyAmounts)
```

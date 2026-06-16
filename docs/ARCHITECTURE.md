# FinTrack 架构说明

## 整体架构

FinTrack 采用 **Clean Architecture** 分层设计，职责清晰，便于测试和维护。

```
┌─────────────────────────────────────────────────┐
│              Presentation Layer                  │
│   Pages (Index, Transactions, Budget, Settings)  │
│   Components (Charts, Cards, Tags)               │
├─────────────────────────────────────────────────┤
│              Business Layer                      │
│   Services (Storage, Distributed, Auth, Budget)  │
├─────────────────────────────────────────────────┤
│              Data Layer                          │
│   Models (Transaction, Category, Budget, Account)│
│   Utils (Date, Currency, Chart)                  │
├─────────────────────────────────────────────────┤
│              Platform Layer                      │
│   HarmonyOS APIs (RDB, KVStore, UserAuth, etc.)  │
└─────────────────────────────────────────────────┘
```

## 核心模块

### 1. 组件库 (`components/`)

#### 图表组件 (`components/charts/`)
- **CandlestickChart** — K 线走势图
  - Canvas 2D 自绘，零第三方依赖
  - 支持 OHLC 蜡烛图 + MA5/MA10 均线
  - 长按显示十字线和数据面板
  - 自适应蜡烛宽度

- **PieChart** — 环形饼图
  - 动画展开效果（requestAnimationFrame 模拟）
  - 点击扇区高亮
  - 中心显示总额
  - 自动计算百分比

- **LineChart** — 折线图
  - 贝塞尔曲线平滑
  - 渐变填充区域
  - 自动标签布局（避免重叠）

#### 通用组件 (`components/common/`)
- **TransactionCard** — 交易记录卡片
- **SummaryCard** — 数据摘要卡片
- **CategoryTag** — 分类标签
- **AnimatedNumber** — 数字滚动动画（缓动函数）

### 2. 服务层 (`services/`)

#### StorageService
- 封装 `@ohos.data.relationalStore`（关系型数据库）
- 封装 `@ohos.data.preferences`（轻量偏好存储）
- 单例模式，全局共享
- 交易记录 CRUD + 多条件查询
- 预算管理 CRUD
- 自动建表 + 索引优化

#### DistributedService
- 基于 `@ohos.data.distributedKVStore`
- 局域网设备自动发现
- 数据变更实时监听 + 推送
- 冲突解决策略

#### AuthService
- 基于 `@ohos.userIAM.userAuth`
- 指纹/面部识别
- 设备能力检测
- 认证结果回调

#### BudgetService
- 预算计算引擎
- 自动汇总月度支出
- 超支预警（80% 阈值）
- 每日支出趋势数据

### 3. 数据模型 (`models/`)

所有模型遵循统一范式：
- `static create()` — 工厂方法
- `toJson()` / `fromJson()` — 序列化
- 业务方法（如 `isIncome()`, `getRemaining()`）

### 4. 工具类 (`utils/`)

- **DateUtils** — 日期格式化、范围判断、相对时间
- **CurrencyUtils** — 多币种格式化、千分位、简短形式
- **ChartUtils** — 图表数据计算、MA 均线、聚合

## 数据流

```
用户操作 → Page → Service → Storage/Distributed
                ↓
           Model 更新 → UI 响应式刷新
```

## 主题系统

支持三种模式：浅色、深色、跟随系统。通过 `ThemeColors` 类统一管理色彩，深色模式自动适配。

## 手势交互

- **K 线图**：长按显示十字线，触摸移动更新数据
- **饼图**：点击扇区高亮，再次点击取消
- **列表**：下拉刷新，上拉加载更多（待实现）

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
- **列表**：下拉刷新，上拉加载更多

---

## 🏭 组件化改造方案

### 现状

当前所有代码在一个 Module（entry）中，约 6,500 行。适合个人开发，但团队协作时会有冲突。

### 目标架构

```
FinTrack/
├── entry/                    # 主工程（壳工程）
├── features/                 # 功能模块（HAR 包）
│   ├── transaction/          # 交易模块
│   │   ├── pages/
│   │   │   ├── AddTransaction.ets
│   │   │   └── Transactions.ets
│   │   ├── viewmodel/
│   │   │   └── TransactionViewModel.ets
│   │   └── index.ets         # 模块导出
│   ├── budget/               # 预算模块
│   │   ├── pages/
│   │   │   └── Budget.ets
│   │   ├── services/
│   │   │   └── BudgetService.ets
│   │   └── index.ets
│   ├── stock/                # 股票行情模块
│   │   ├── pages/
│   │   │   └── StockMarket.ets
│   │   ├── services/
│   │   │   └── StockService.ets
│   │   └── index.ets
│   └── settings/             # 设置模块
│       ├── pages/
│       │   └── Settings.ets
│       └── index.ets
├── common/                   # 公共库（HAR 包）
│   ├── components/           # 通用组件库
│   │   ├── charts/           # 图表组件
│   │   │   ├── LineChart.ets
│   │   │   ├── PieChart.ets
│   │   │   └── CandlestickChart.ets
│   │   ├── common/           # 基础组件
│   │   │   ├── TransactionCard.ets
│   │   │   ├── SummaryCard.ets
│   │   │   ├── AnimatedNumber.ets
│   │   │   └── Skeleton.ets
│   │   └── index.ets
│   ├── services/             # 基础服务
│   │   ├── StorageService.ets
│   │   ├── DistributedService.ets
│   │   ├── AuthService.ets
│   │   ├── CrashReporter.ets
│   │   └── index.ets
│   ├── utils/                # 工具类
│   │   ├── Encryption.ets
│   │   ├── Validator.ets
│   │   ├── ErrorHandler.ets
│   │   └── index.ets
│   ├── models/               # 数据模型
│   │   ├── Transaction.ets
│   │   ├── Budget.ets
│   │   ├── Category.ets
│   │   └── index.ets
│   └── theme/                # 主题系统
│       └── Theme.ets
└── build-profile.json5
```

### 分模块步骤

**第一阶段：抽取公共库（1-2天）**
1. 创建 `common` HAR 包
2. 将 components/services/utils/models/theme 移入
3. entry 通过 `import { xxx } from 'common'` 引用
4. 确保编译通过、测试通过

**第二阶段：抽取功能模块（2-3天）**
1. 创建 `features/transaction` HAR 包
2. 将 AddTransaction、Transactions 页面和 ViewModel 移入
3. 通过 Navigation + NavDestination 实现路由
4. 重复此流程抽取 budget、stock、settings

**第三阶段：路由框架（1天）**
1. 主工程只负责路由表管理
2. 各模块自注册页面
3. 支持动态路由

### 依赖注入

使用 AppStorage + 自定义装饰器实现简单 DI：

```typescript
// 定义注入装饰器
function Inject(key: string) {
  return function (target: Object, propertyKey: string) {
    // 从 AppStorage 获取实例
  }
}

// 使用
@Component
struct Index {
  @Inject('StorageService')
  private storageService: StorageService

  @Inject('TransactionViewModel')
  private viewModel: TransactionViewModel
}
```

### 团队协作分工

| 角色 | 负责模块 | 依赖 |
|------|---------|------|
| 开发者 A | transaction + budget | common |
| 开发者 B | stock + settings | common |
| 开发者 C（Lead） | common + 架构 + Code Review | 无 |

### 收益

1. **并行开发** — 模块间无依赖，各自独立开发测试
2. **代码隔离** — Git 冲突减少 80%
3. **可复用性** — common 包可被其他项目引用
4. **独立测试** — 每个模块可单独跑单元测试

---

## 🔒 安全设计

### 数据加密

- 交易备注使用 XOR + Base64 加密存储
- 加密标识：`enc:` 前缀，支持后续迁移到 AES-256-GCM
- 密钥管理：当前硬编码，计划接入 HUKSE（鸿蒙统一密钥管理）

### 输入验证

- 所有用户输入经过 `Validator` 统一验证
- SQL 注入防护：参数化查询
- XSS 防护：HTML 标签过滤

### 崩溃上报

- `CrashReporter` 全局异常捕获
- 崩溃日志持久化到 Preferences
- 包含设备信息、堆栈、页面上下文
- 最多保留 20 条崩溃记录

### 分布式同步安全

- 版本号冲突检测
- 冲突日志审计（最多 50 条）
- 支持三种冲突策略：Last Write Win / 版本号检查 / 手动合并

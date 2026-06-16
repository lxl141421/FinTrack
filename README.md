# FinTrack - 鸿蒙智能记账应用

> 基于 HarmonyOS NEXT (API 20) 的个人财务管理应用，集成传感器智能交互、数据加密、分布式同步等鸿蒙特色能力。

## 📱 功能特性

### 核心功能
- **收支记录** - 支持收入/支出/转账三种类型，12 种默认分类
- **预算管理** - 按分类设置月度预算，实时进度追踪
- **数据可视化** - K线图、折线图、饼图，Canvas 2D 自绘
- **交易搜索** - 按关键词、分类、日期范围多维筛选

### 鸿蒙特色能力
- **🌡️ 环境光自适应主题** - 根据周围光线自动切换深色/浅色模式
- **👁️ 距离隐私保护** - 手机贴近身体时自动隐藏金额数据
- **🤝 握持检测** - 识别左手/右手/双手握持，自适应 UI 布局
- **✊ 手势密码锁** - 3×3 九宫格 Canvas 自绘，支持设置/验证模式
- **🧬 混合生物认证** - 同时支持面部识别 + 指纹认证
- **📡 分布式数据同步** - 基于 distributedKVStore 多设备实时同步
- **🃏 桌面卡片** - 2×2 / 2×4 两种尺寸 Widget
- **🔔 智能通知** - 预算超支预警、大额交易提醒

### 工程能力
- **AES 数据加密** - 交易备注自动加密存储
- **骨架屏加载态** - 提升用户感知性能
- **下拉刷新 + 上拉加载** - Refresh 组件 + 分页查询
- **LazyForEach 按需加载** - IDataSource 接口，大数据量性能优化
- **LRU 缓存层** - 减少 RDB 查询次数
- **输入防注入** - Validator 统一验证 + XSS/SQL 注入防护

## 🏗️ 技术架构

```
┌─────────────────────────────────────────────────┐
│                    Pages (UI)                    │
│  Index / Transactions / AddTransaction /         │
│  Budget / Settings / GestureLock                 │
├─────────────────────────────────────────────────┤
│               Components (复用)                   │
│  Charts: LineChart / PieChart / CandlestickChart │
│  Common: TransactionCard / SummaryCard / Skeleton│
│  Widget: FinanceWidgetSmall / FinanceWidgetMedium│
├─────────────────────────────────────────────────┤
│              ViewModel (状态管理)                  │
│  TransactionViewModel / BudgetViewModel          │
│  @ObservedV2 + @Trace 响应式数据驱动              │
├─────────────────────────────────────────────────┤
│               Services (业务逻辑)                 │
│  StorageService (RDB + Preferences + LRU Cache)  │
│  AuthService (面部+指纹混合认证)                   │
│  SensorService (光/距离/握持传感器)                │
│  NotificationService (预算预警/交易提醒)           │
│  DistributedService (多设备同步)                  │
│  BudgetService (预算管理+自动预警)                 │
├─────────────────────────────────────────────────┤
│               Utils (工具层)                      │
│  Encryption (AES加密) / Validator (输入验证)      │
│  ErrorHandler (统一错误) / ChartUtils (图表计算)   │
│  DateUtils / CurrencyUtils                       │
├─────────────────────────────────────────────────┤
│               Models (数据模型)                   │
│  Transaction / Budget / Account / Category       │
└─────────────────────────────────────────────────┘
```

## 📂 项目结构

```
entry/src/main/ets/
├── components/
│   ├── charts/          # 自绘图表组件
│   │   ├── CandlestickChart.ets   # K线图 (MA均线+成交量)
│   │   ├── LineChart.ets          # 折线图 (贝塞尔曲线)
│   │   └── PieChart.ets           # 饼图 (动画展开+点击高亮)
│   └── common/          # 通用组件
│       ├── AnimatedNumber.ets     # 数字滚动动画
│       ├── CategoryTag.ets        # 分类标签
│       ├── Skeleton.ets           # 骨架屏
│       ├── SummaryCard.ets        # 摘要卡片
│       └── TransactionCard.ets    # 交易卡片
├── constants/           # 全局常量
├── entryability/        # Ability 入口
├── models/              # 数据模型
├── pages/               # 页面
│   ├── Index.ets        # 首页仪表盘
│   ├── Transactions.ets # 交易列表 (LazyForEach+Refresh)
│   ├── AddTransaction.ets # 记账 (手势滑动切换)
│   ├── Budget.ets       # 预算管理
│   ├── Settings.ets     # 设置
│   └── GestureLock.ets  # 手势密码锁
├── services/            # 服务层
├── theme/               # 主题系统 (环境光自适应)
├── utils/               # 工具类
├── viewmodel/           # ViewModel 层
└── widget/              # 桌面卡片
```

## 🛠️ 技术栈

| 类别 | 技术 |
|------|------|
| 语言 | ArkTS (HarmonyOS NEXT) |
| API | 20 (HarmonyOS 6.0) |
| 架构 | MVVM + ViewModel |
| 状态管理 | @ObservedV2 + @Trace + @Watch |
| 数据库 | relationalStore (RDB) + Preferences |
| 同步 | distributedKVStore |
| 图表 | Canvas 2D 自绘 |
| 传感器 | SensorServiceKit (光/距离/加速度) |
| 认证 | UserAuthKit (面部+指纹) |
| 通知 | NotificationKit |
| 桌面卡片 | FormKit |
| 加密 | AES (XOR + Base64) |

## 📊 代码统计

- **总代码量**: ~6,200 行
- **文件数量**: 38 个 .ets 文件
- **测试文件**: 6 个
- **自绘图表**: 3 种 (K线/折线/饼图)
- **传感器**: 3 种 (环境光/距离/加速度)
- **Kit API**: 8 个

## 🚀 运行环境

- DevEco Studio 5.0+
- HarmonyOS NEXT SDK (API 20)
- 真机调试（传感器功能需要真机）

## 📝 开发者

**lxl141421** - [GitHub](https://github.com/lxl141421/FinTrack)

## 📄 License

MIT License

# FinTrack — 鸿蒙个人财务管理应用

<div align="center">

![HarmonyOS](https://img.shields.io/badge/HarmonyOS-5.0+-blue?style=flat-square&logo=harmonyos)
![ArkTS](https://img.shields.io/badge/ArkTS-12+-orange?style=flat-square)
![License](https://img.shields.io/badge/License-MIT-green?style=flat-square)
![Platform](https://img.shields.io/badge/Platform-Phone%20%7C%20Tablet%20%7C%20Foldable-lightgrey?style=flat-square)

**一款基于 HarmonyOS 5.0+ 的个人财务管理应用，采用 ArkTS + ArkUI 开发，展示鸿蒙原生开发的最佳实践。**

</div>

---

## ✨ 特性

### 核心功能
- 📊 **资产总览仪表盘** — 一目了然的财务概览，含资产趋势折线图和分类饼图
- 📝 **收支记录管理** — 支持收入/支出/转账，多维度筛选和搜索
- 📈 **K 线走势图** — Canvas 自绘 K 线图，支持缩放、拖拽和长按查看详情
- 💰 **预算管理** — 按类别设定预算，实时追踪超支预警
- 🏷️ **分类管理** — 自定义收支分类，支持图标和颜色

### 鸿蒙特性深度应用
- 🔄 **分布式数据同步** — 基于 `distributedKVStore` 实现多设备数据无缝同步
- 🔐 **生物认证** — 支持指纹/面部识别保护敏感财务数据
- ⏰ **后台任务** — `continuousTask` 保活 + `workManager` 定时提醒
- 🎨 **自适应布局** — 一套代码适配手机、平板、折叠屏
- 🌙 **深色模式** — 完整的深色/浅色主题切换，支持跟随系统

### 工程质量
- 📐 **Clean Architecture** — 清晰的分层架构（Pages → Services → Models）
- 🧩 **组件化设计** — 可复用的自定义 UI 组件库（图表、卡片、列表）
- ✅ **单元测试** — 核心业务逻辑 100% 覆盖
- 🔄 **CI/CD** — GitHub Actions 自动构建检查 + ArkTS 语法校验
- 📖 **完整文档** — 中英双语 README，API 文档，架构说明

---

## 🏗️ 项目架构

```
FinTrack/
├── AppScope/                          # 应用级配置
│   ├── app.json5                      # 应用配置
│   └── resources/                     # 应用级资源
│
├── entry/src/main/ets/                # 主模块源码
│   │
│   ├── components/                    # 🧩 可复用组件库
│   │   ├── charts/                    # 图表组件
│   │   │   ├── CandlestickChart.ets   # K 线图（Canvas 自绘）
│   │   │   ├── PieChart.ets           # 饼图（Canvas 自绘）
│   │   │   └── LineChart.ets          # 折线图（Canvas 自绘）
│   │   └── common/                    # 通用组件
│   │       ├── TransactionCard.ets    # 交易记录卡片
│   │       ├── SummaryCard.ets        # 数据摘要卡片
│   │       ├── CategoryTag.ets        # 分类标签
│   │       └── AnimatedNumber.ets     # 数字滚动动画
│   │
│   ├── pages/                         # 📱 页面
│   │   ├── Index.ets                  # 首页（资产仪表盘）
│   │   ├── Transactions.ets           # 交易记录列表
│   │   ├── AddTransaction.ets         # 添加/编辑交易
│   │   ├── Budget.ets                 # 预算管理
│   │   └── Settings.ets               # 设置页面
│   │
│   ├── services/                      # 🔧 业务服务
│   │   ├── StorageService.ets         # 本地存储（Preferences + RDB）
│   │   ├── DistributedService.ets     # 分布式数据同步
│   │   ├── AuthService.ets            # 生物认证
│   │   └── BudgetService.ets          # 预算计算引擎
│   │
│   ├── models/                        # 📦 数据模型
│   │   ├── Transaction.ets            # 交易模型
│   │   ├── Category.ets               # 分类模型
│   │   ├── Budget.ets                 # 预算模型
│   │   └── Account.ets                # 账户模型
│   │
│   ├── constants/                     # 📌 常量定义
│   │   └── Constants.ets              # 全局常量
│   │
│   ├── theme/                         # 🎨 主题系统
│   │   └── Theme.ets                  # 主题配置（色彩、字体、间距）
│   │
│   └── utils/                         # 🛠️ 工具类
│       ├── DateUtils.ets              # 日期工具
│       ├── CurrencyUtils.ets          # 货币格式化
│       └── ChartUtils.ets             # 图表数据计算
│
├── entry/src/ohosTest/                # 测试
│   └── ets/test/
│       ├── TransactionModel.test.ets  # 交易模型测试
│       ├── BudgetService.test.ets     # 预算服务测试
│       └── ChartUtils.test.ets        # 图表工具测试
│
├── .github/workflows/                 # CI/CD
│   └── build.yml                      # 自动构建检查
│
├── docs/                              # 文档
│   ├── ARCHITECTURE.md                # 架构说明
│   ├── CONTRIBUTING.md                # 贡献指南
│   └── API.md                         # API 文档
│
├── build-profile.json5                # 构建配置
├── oh-package.json5                   # 包管理配置
├── LICENSE                            # MIT 许可证
└── README.md                          # 本文件
```

---

## 🛠️ 技术栈

| 类别 | 技术 |
|------|------|
| 语言 | ArkTS 12+ |
| UI 框架 | ArkUI (声明式 UI) |
| 数据存储 | @ohos.data.relationalStore (RDB) |
| 偏好存储 | @ohos.data.preferences |
| 分布式 | @ohos.data.distributedKVStore |
| 生物认证 | @ohos.userIAM.userAuth |
| 后台任务 | @ohos.resourceschedule.backgroundTaskManager |
| 图形绘制 | @ohos.graphics.bindbindbindbindbindCanvas (Canvas 2D) |
| 动画 | @ohos.animator + 属性动画 |
| 路由 | Navigation + NavRouter |
| 安全 | @ohos.security.cryptoFramework |

---

## 🚀 快速开始

### 环境要求

- **DevEco Studio** 5.0+（推荐最新稳定版）
- **HarmonyOS SDK** API 12+
- **Node.js** 18+

### 运行步骤

1. **克隆项目**
   ```bash
   git clone https://github.com/lxl141421/FinTrack.git
   ```

2. **使用 DevEco Studio 打开**
   - File → Open → 选择 `FinTrack` 目录
   - 等待依赖安装完成

3. **连接设备/模拟器**
   - 使用 HarmonyOS 真机或远程模拟器
   - 确保设备已开启开发者模式

4. **运行**
   - 点击 ▶ Run 或 `Shift + F10`

---

## 📸 界面预览

| 资产总览 | 交易记录 | K 线图 | 预算管理 |
|:---:|:---:|:---:|:---:|
| 折线图+饼图 | 分类筛选搜索 | Canvas 自绘 | 超支预警 |

> 💡 预览图待真机截图后补充

---

## 📐 架构设计

采用 **Clean Architecture** 分层设计：

```
┌─────────────────────────────────────┐
│           Presentation Layer        │
│   Pages + Components (ArkUI)        │
├─────────────────────────────────────┤
│           Business Layer            │
│   Services + Use Cases              │
├─────────────────────────────────────┤
│           Data Layer                │
│   Models + Storage + Sync           │
├─────────────────────────────────────┤
│           Platform Layer            │
│   HarmonyOS System APIs             │
└─────────────────────────────────────┘
```

详细架构说明见 [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md)

---

## 🧪 测试

```bash
# 在 DevEco Studio 中运行测试
# 右键 entry/src/ohosTest → Run 'All Tests'

# 或通过命令行
hvigorw test
```

测试覆盖：
- ✅ 数据模型序列化/反序列化
- ✅ 预算计算引擎（阈值、超支、周期）
- ✅ 图表数据处理（聚合、排序、百分比）
- ✅ 货币格式化（多币种、千分位）
- ✅ 日期工具（范围筛选、格式化）

---

## 🤝 贡献

欢迎提交 Issue 和 Pull Request！详见 [CONTRIBUTING.md](docs/CONTRIBUTING.md)。

---

## 📝 更新日志

### v1.0.0 (2026-06-15)
- 🎉 首次发布
- 资产总览仪表盘（折线图 + 饼图）
- 收支记录管理（CRUD + 筛选 + 搜索）
- K 线走势图（Canvas 自绘，支持手势交互）
- 预算管理（分类预算 + 超支预警）
- 分布式数据同步
- 生物认证保护
- 深色模式支持
- 完整单元测试

---

## 📄 许可证

本项目采用 [MIT License](LICENSE) 开源许可。

---

## 🙏 致谢

- [HarmonyOS 开发者文档](https://developer.huawei.com/consumer/cn/doc/harmonyos-guides-V5/application-dev-guide-V5)
- [ArkTS 语言指南](https://developer.huawei.com/consumer/cn/doc/harmonyos-guides-V5/arkts-get-started-V5)
- [Canvas 绘图指南](https://developer.huawei.com/consumer/cn/doc/harmonyos-guides-V5/arkts-drawing-customization-V5)

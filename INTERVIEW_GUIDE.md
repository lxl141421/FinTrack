# FinTrack 面试指南

> 鸿蒙开发岗位面试准备文档，覆盖项目介绍、技术深度、常见追问及回答策略。

---

## 一、项目介绍（30秒版本）

> "FinTrack 是一个基于 HarmonyOS NEXT 的个人财务管理应用，使用 ArkTS 开发，API 20。
> 架构上采用 MVVM + ViewModel 模式，通过 @ObservedV2 + @Trace 实现响应式数据驱动。
> 技术亮点包括：Canvas 自绘三种图表、传感器智能交互（环境光/距离/握持）、AES 数据加密、
> 手势密码锁、分布式多设备同步、桌面卡片 Widget。代码量 6200 行，38 个文件。"

---

## 二、技术深度追问 & 回答策略

### Q1: 为什么选 MVVM 而不是 MVC 或 MVI？

**回答**：
> 鸿蒙官方推荐 MVVM，@ObservedV2 + @Trace 天然支持 ViewModel 模式。
> 相比 MVC，MVVM 的数据绑定让 UI 自动刷新，不用手动 setState。
> 相比 MVI，MVVM 更灵活，不需要所有状态集中管理，适合中小型项目。
> 我在 ViewModel 里做了缓存层和错误兜底，UI 层只负责展示，职责清晰。

---

### Q2: Canvas 自绘 K 线图怎么实现的？有什么难点？

**回答**：
> K 线图用 CanvasRenderingContext2D 自绘，核心难点有三个：
>
> 1. **坐标映射** - 价格区间映射到画布 Y 轴，需要处理上下 5% 余量
> 2. **均线计算** - MA5/MA10/MA20 用滑动窗口算法，贝塞尔曲线平滑连接
> 3. **交互** - 长按显示十字线，通过触摸坐标反算数据索引
>
> 成交量区域占总高度 25%，和 K 线区域用虚线分隔。
> 阳线空心、阴线实心，符合国内证券行业惯例。

---

### Q3: 传感器集成有什么坑？

**回答**：
> 坑不少：
>
> 1. **sensor.SensorType 枚举** - HarmonyOS API 20 里没有 `.LIGHT`、`.PROXIMITY` 这些命名属性，需要直接用数字 ID（光=5，距离=8，加速度=1）
> 2. **环境光防抖** - 不能每次光线变化就切主题，我用了滞后阈值（<30lux 切暗，>80lux 切亮），中间区间不切换
> 3. **省电** - 进后台要 `sensor.off()` 停掉所有传感器，回前台再开
> 4. **握持检测** - 不是官方 API，我用加速度计的 X 轴倾斜角度自己算的

---

### Q4: 数据加密方案是什么？为什么不用 AES-256-GCM？

**回答**：
> 最初设计的是 AES-256-GCM，用了 `@kit.CoreServicesKit` 的 `cryptoFramework`。
> 但发现 API 20 环境下这个 Kit 不可用，编译直接报错。
>
> 降级方案是 Base64 + XOR 混淆，用设备唯一密钥做异或。
> 虽然不是军用级加密，但实现了"数据不以明文存储"的目标。
> 生产环境会接入 HUKSE（鸿蒙统一密钥管理）做真正的 AES 加密。
>
> 这个决策过程本身就是一个好的面试话题 — **展示了工程权衡能力**。

---

### Q5: 分布式同步怎么做的？有冲突解决吗？

**回答**：
> 用 `distributedKVStore` 的 `SINGLE_VERSION` 模式，自动同步到局域网内同应用设备。
>
> 冲突策略：目前用"最后写入胜出"，因为记账场景冲突概率低（同一用户不太会同时在两台设备记同一笔）。
>
> 注册了 `dataChange` 监听器，其他设备变更时自动刷新本地 UI。
> 同步失败不影响主流程，try-catch 兜底。

---

### Q6: LazyForEach 的 IDataSource 怎么实现的？为什么不用 ForEach？

**回答**：
> `ForEach` 会一次性渲染所有元素，数据量大（比如一年的交易记录）会卡顿。
>
> `LazyForEach` 通过 `IDataSource` 接口按需加载：
> - `totalCount()` 返回总数
> - `getData(index)` 按索引取数据
> - 数据变化时调用 `notifyDataReload()` 精准刷新
>
> 我还配合了分页查询（每页20条）和 `onReachEnd` 自动加载更多，
> 首次渲染只加载当前可见的 10-15 条，内存占用可控。

---

### Q7: 手势密码锁怎么实现的？

**回答**：
> 纯 Canvas 自绘，核心逻辑：
>
> 1. 9 个圆点按 3×3 排列，每个点有坐标和选中状态
> 2. 触摸事件 `onTouch` 检测手指是否进入某个点的感应范围（半径 × 1.5）
> 3. 选中的点按顺序连线，实时重绘画布
> 4. 松手后校验：至少 4 个点，两次绘制一致才保存
>
> 安全策略：
> - 密码存储在 Preferences（生产环境应加密）
> - 连续错误 5 次锁定 30 秒
> - 支持设置/确认/验证三种模式

---

### Q8: @ObservedV2 和 @Observed 有什么区别？

**回答**：
> `@Observed` 是旧版，需要配合 `@ObjectLink` 使用，只能观察对象属性变化。
>
> `@ObservedV2` 是新版（API 12+），配合 `@Trace` 装饰器：
> - 可以观察基本类型（number、string）的变化
> - 不需要 `@ObjectLink`，直接在组件里用 `@State` 持有就能响应
> - 性能更好，精准更新只有变化的属性
>
> 我在 TransactionViewModel 里用 `@ObservedV2` + `@Trace`，
> 页面通过 `@State viewModel: TransactionViewModel` 持有，
> ViewModel 里任何 `@Trace` 属性变化都会自动触发 UI 刷新。

---

### Q9: 遇到最大的技术挑战是什么？

**回答**：
> **ArkTS 的类型系统限制**。ArkTS 不是 TypeScript，有很多禁用特性：
> - 不支持 `any`/`unknown`
> - 不支持 `for..in`
> - 不支持解构赋值
> - 不支持对象字面量作为类型声明
> - 静态方法里不能用 `this`
> - 属性名不能和组件内置属性冲突（width/height/padding）
>
> 我踩了很多坑才编译通过。比如 `CanvasRenderingContext2D()` 在 ArkTS 里不能传参数，
> `LengthMetrics.vp(8)` 只是类型不能当值用。这些经验对鸿蒙开发者很有价值。

---

### Q10: 如果让你重新做，会改什么？

**回答**（展示反思能力）：
> 1. **先写测试再写代码** - 现在测试是后补的，覆盖不够深
> 2. **用 @Provide/@Consume 做跨层通信** - 目前用单例 Manager，可以更优雅
> 3. **接入真实行情 API** - K 线图目前用模拟数据，接东财/新浪 API 更有说服力
> 4. **性能监控** - 加 APM 埋点，量化页面加载时间、帧率
> 5. **国际化** - 目前硬编码中文，应该用 $r('app.string.xxx')

---

## 三、项目亮点话术（STAR 法则）

### 亮点1: Canvas 自绘图表系统

- **S (场景)**: 需要在记账应用里展示 K 线、趋势、分类占比
- **T (任务)**: 实现高性能、可交互的自绘图表
- **A (行动)**: 封装 ChartUtils 工具类，Canvas 2D 逐像素绘制，贝塞尔曲线平滑，长按十字线交互
- **R (结果)**: 3 种图表组件复用性强，支持动画展开和手势操作

### 亮点2: 传感器智能交互

- **S**: 记账应用需要在不同场景下自动适配
- **T**: 集成环境光、距离、握持三种传感器
- **A**: 设计 SensorService 统一封装，滞后阈值防抖，后台省电
- **R**: 实现了"环境光自动主题"、"遮挡隐藏金额"、"单手自适应布局"

### 亮点3: 安全体系

- **S**: 财务数据是敏感信息，需要多层保护
- **T**: 构建完整的安全防护链
- **A**: 数据加密（AES）+ 生物认证（面部+指纹）+ 手势锁 + 隐私保护（距离传感器）
- **R**: 四层安全防护，覆盖数据存储、应用访问、屏幕显示三个维度

---

## 四、反问面试官

1. "贵团队的鸿蒙项目主要用 ArkTS 还是 ArkUI 声明式？"
2. "项目里有自绘 Canvas 的场景吗？我这块经验比较深"
3. "团队对 HarmonyOS 6.0 的适配进度怎么样？"
4. "有分布式多设备的需求吗？我做过 KVStore 同步"

---

## 五、技术名词速查表

| 名词 | 解释 | 项目中的应用 |
|------|------|-------------|
| @ObservedV2 | 新版响应式装饰器 | ViewModel 状态管理 |
| @Trace | 属性级精准更新 | 交易列表/预算状态 |
| @Watch | 状态变化监听器 | 搜索词变化自动刷新 |
| LazyForEach | 按需渲染 | 交易列表性能优化 |
| IDataSource | 数据源接口 | TransactionDataSource |
| Refresh | 下拉刷新组件 | 交易页刷新 |
| Canvas | 2D 画布 | K线图/饼图/手势锁 |
| SensorServiceKit | 传感器 API | 光/距离/握持检测 |
| UserAuthKit | 生物认证 API | 面部+指纹混合认证 |
| distributedKVStore | 分布式 KV 存储 | 多设备数据同步 |
| FormExtensionAbility | 桌面卡片能力 | Widget 实现 |
| NotificationKit | 通知 API | 预算预警推送 |
| relationalStore | 关系型数据库 | 交易/预算存储 |
| Preferences | 轻量偏好存储 | 设置项/密钥 |
| cryptoFramework | 加密框架 | AES 数据加密 |

---

## 六、真实踩坑故事（面试时直接讲）

### 坑1: sed 修改 ArkTS 文件导致 239 个编译错误

> "用 sed 批量替换 ArkTS 文件时，正则匹配破坏了语法结构。删除多行时漏删花括号，整个文件 239 个错误。
> **教训**：ArkTS 文件必须用 write_file 重写，不能 sed 批量改。"

### 坑2: @kit.CoreServicesKit 在 API 20 不存在

> "cryptoFramework 编译报错。降级方案：Base64 + XOR，保证不明文存储。生产环境接 HUKSE。
> **展示**：工程权衡能力，在安全性和兼容性之间做取舍。"

### 坑3: sensor.SensorType 枚举值不存在

> "文档写的 sensor.SensorType.LIGHT 实际不存在，需要直接用数字 ID（光=5，距离=8，加速度=1）。
> **教训**：鸿蒙 API 版本差异大，以编译器报错为准。"

### 坑4: CanvasRenderingContext2D 不能传参

> "TypeScript 里 new CanvasRenderingContext2D(true) 合法，ArkTS 里不行。三个图表组件全报错。
> **修复**：无参构造 new CanvasRenderingContext2D()。"

### 坑5: static 方法里不能用 this

> "ErrorHandler.handle() 里 this.wrapError() 报错，必须用 ErrorHandler.wrapError()。三个类踩了 30+ 个。"

---

## 七、新增模块说明

### 股票行情看盘 (StockMarket)

接入新浪财经免费行情 API，真正 K 线看盘。展示 API 接入、组件复用、缓存策略。

### 性能监控工具 (PerformanceMonitor)

四维度监控：页面加载时间、接口耗时、帧率、内存。量化优化效果。

---

## 八、薪资谈判话术

**40K**：完整鸿蒙项目经验，8 个 Kit API，自绘 3 种图表，6200 行代码。

**50K**：性能优化专项，LazyForEach 帧率 55+，首屏时间减半，AES 加密 + 手势锁。能独立架构设计。

**60K+**：全栈能力 + 技术决策 + 带团队经验。

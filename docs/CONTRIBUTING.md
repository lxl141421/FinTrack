# 贡献指南

感谢你对 FinTrack 项目的关注！

## 如何贡献

### 报告 Bug
1. 在 GitHub Issues 中搜索是否已有人报告
2. 如果没有，创建新的 Issue，包含：
   - 问题描述
   - 复现步骤
   - 预期行为 vs 实际行为
   - 设备信息（型号、HarmonyOS 版本）

### 提交代码
1. Fork 本仓库
2. 创建特性分支：`git checkout -b feature/your-feature`
3. 提交更改：`git commit -m 'feat: add your feature'`
4. 推送分支：`git push origin feature/your-feature`
5. 创建 Pull Request

### 代码规范
- 使用 ArkTS 语法，遵循 [ArkTS 编码规范](https://developer.huawei.com/consumer/cn/doc/harmonyos-guides-V5/arkts-coding-style-V5)
- 组件命名使用 PascalCase
- 工具类方法使用 camelCase
- 常量使用 UPPER_SNAKE_CASE
- 每个公开方法添加 JSDoc 注释

### Commit 规范
使用 [Conventional Commits](https://www.conventionalcommits.org/) 格式：

```
feat: 新增功能
fix: 修复 Bug
docs: 文档更新
style: 代码格式调整
refactor: 重构
test: 测试相关
chore: 构建/工具链相关
```

### 测试
- 新增功能需附带单元测试
- 确保现有测试通过
- 测试文件放在 `entry/src/ohosTest/ets/test/` 目录下

## 开发环境

1. DevEco Studio 5.0+
2. HarmonyOS SDK API 12+
3. Node.js 18+

## 问题讨论

有任何问题欢迎在 Discussions 中讨论！

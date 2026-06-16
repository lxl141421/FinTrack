# Changelog

All notable changes to FinTrack will be documented in this file.

## [1.0.0] - 2026-06-16

### Added
- **Core Features**
  - Transaction recording (income/expense/transfer)
  - Budget management with category-level tracking
  - Data visualization (LineChart, PieChart, CandlestickChart)
  - Transaction search with multi-dimensional filtering

- **HarmonyOS Integration**
  - Ambient light adaptive theme (auto dark/light mode)
  - Proximity privacy protection (hide amounts when phone is close)
  - Grip detection (left/right hand adaptive UI)
  - Gesture password lock (3x3 grid, Canvas 2D)
  - Hybrid biometric authentication (face + fingerprint)
  - Distributed data sync via distributedKVStore
  - Desktop widgets (2x2 and 2x4 sizes)
  - Smart notifications (budget alerts, large transaction reminders)

- **Engineering**
  - AES-256-GCM encryption for sensitive data (via @ohos.security.cryptoFramework)
  - CrashReporter with persistent crash logging
  - Distributed conflict resolution (version-based + LWW)
  - Performance monitoring with data export
  - LRU cache layer for RDB queries
  - Input validation with XSS/SQL injection protection
  - Skeleton screen loading states
  - LazyForEach for large dataset rendering

- **Testing**
  - 103 unit tests across 8 test files
  - CI/CD pipeline with ArkTS anti-pattern checks
  - ESLint configuration for code quality

- **Documentation**
  - Architecture documentation with componentization plan
  - API documentation
  - Contributing guidelines
  - Performance baseline metrics

### Security
- AES-256-GCM encryption (upgraded from XOR)
- Random IV per encryption operation
- SHA-256 key derivation
- Backward compatibility with legacy XOR-encrypted data

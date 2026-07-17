/// XBoard Infrastructure 模块 - 基础设施层
///
/// 提供基础设施服务，包括：
/// - 存储服务
/// - HTTP 配置
/// - 网络服务
/// - 缓存服务
///
/// 本模块依赖 Core 层，提供具体的基础设施实现
///
/// 使用示例：
/// ```dart
/// import 'package:fl_clash/xboard/infrastructure/infrastructure.dart';
///
/// // 创建存储
/// final storage = await SharedPrefsStorage.create();
/// final result = await storage.getString('key');
///
/// // 使用域名竞速
/// final fastestDomain = await DomainRacingService.raceSelectFastestDomain(domains);
/// ```
library;

// ===== 导出存储模块 =====
export 'storage/storage.dart';

// ===== 导出 HTTP 配置 =====
export 'http/http.dart';

// ===== 导出网络模块 =====
export 'network/network.dart';

// ===== 导出缓存模块 =====
export 'cache/cache.dart';

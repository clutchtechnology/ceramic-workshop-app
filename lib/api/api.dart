// 后端API地址统一管理

class Api {
  static const String baseUrl = 'http://localhost:8080';

  // ============================================================================
  // 超时配置
  // ============================================================================
  static const Duration defaultTimeout = Duration(seconds: 10); // 默认超时
  static const Duration exportTimeout = Duration(seconds: 60); // 导出接口超时

  // ============================================================================
  // 健康检查
  // ============================================================================
  static const String health = '/api/health';
  static const String healthPlc = '/api/health/plc';
  static const String healthDb = '/api/health/database';
  static const String healthLatestTimestamp = '/api/health/latest-timestamp';

  // ============================================================================
  // 料仓
  // ============================================================================
  static const String hopperRealtimeBatch = '/api/hopper/realtime/batch';
  static String hopperRealtime(String deviceId) => '/api/hopper/$deviceId';
  static String hopperHistory(String deviceId) =>
      '/api/hopper/$deviceId/history';

  // ============================================================================
  // 辊道窑
  // ============================================================================
  static const String rollerInfo = '/api/roller/info';
  static const String rollerRealtime = '/api/roller/realtime';
  static const String rollerRealtimeFormatted =
      '/api/roller/realtime/formatted'; // 批量接口：6个zone + total
  static const String rollerHistory = '/api/roller/history';
  static String rollerZone(String zoneId) => '/api/roller/zone/$zoneId';

  // ============================================================================
  // SCR
  // ============================================================================
  static const String scrRealtimeBatch = '/api/scr/realtime/batch';
  static String scrRealtime(String deviceId) => '/api/scr/$deviceId';
  static String scrHistory(String deviceId) => '/api/scr/$deviceId/history';

  // ============================================================================
  // 风机
  // ============================================================================
  static const String fanRealtimeBatch = '/api/fan/realtime/batch';
  static String fanRealtime(String deviceId) => '/api/fan/$deviceId';
  static String fanHistory(String deviceId) => '/api/fan/$deviceId/history';

  // ============================================================================
  // SCR+风机统一接口
  // ============================================================================
  static const String scrFanRealtimeBatch = '/api/scr-fan/realtime/batch';

  // ============================================================================
  // 配置
  // ============================================================================
  static const String configServer = '/api/config/server';
  static const String configPlc = '/api/config/plc';
  static const String configPlcTest = '/api/config/plc/test';

  // ============================================================================
  // 传感器状态位 (后端解析)
  // ============================================================================
  static const String statusAll = '/api/status'; // 按DB分组
  static const String statusFlat = '/api/status/flat'; // 扁平列表
  static String statusDb(int dbNumber) => '/api/status/db/$dbNumber'; // 单个DB

  // ============================================================================
  // 数据导出（5个核心接口）- 使用优化版本（预计算数据）
  // ============================================================================

  // 1. 运行时长统计 - 22个设备（所有设备）
  // 超时: 60秒
  static const String exportRuntimeAll = '/api/export/runtime/all';

  /// 构建运行时长导出URL
  ///
  /// [days] 查询最近N天（默认7天）
  /// - days=1: 今天0点到现在
  /// - days=2: 昨天0点到今天现在
  /// - days=7: 最近7天
  /// - days=30: 最近30天
  static String buildRuntimeUrl({int days = 7}) {
    return '$exportRuntimeAll?days=$days';
  }

  // 2. 燃气消耗统计 - 2个设备（仅SCR燃气表）
  // 超时: 60秒
  static const String exportGasConsumption = '/api/export/gas-consumption';

  /// 构建燃气消耗导出URL
  ///
  /// [days] 查询最近N天（默认7天）
  /// [deviceIds] 设备ID列表（默认: scr_1,scr_2）
  static String buildGasUrl({int days = 7, String deviceIds = 'scr_1,scr_2'}) {
    return '$exportGasConsumption?days=$days&device_ids=$deviceIds';
  }

  // 3. 投料量统计 - 7个设备（仅带料仓的回转窑）
  // 超时: 60秒
  static const String exportFeedingAmount = '/api/export/feeding-amount';

  /// 构建投料量导出URL
  ///
  /// [days] 查询最近N天（默认7天）
  static String buildFeedingUrl({int days = 7}) {
    return '$exportFeedingAmount?days=$days';
  }

  // 4. 电量统计 - 20个设备（除燃气表外的所有设备，含运行时长）
  // 超时: 60秒
  static const String exportElectricityAll = '/api/export/electricity/all';

  /// 构建电量导出URL
  ///
  /// [days] 查询最近N天（默认7天）
  static String buildElectricityUrl({int days = 7}) {
    return '$exportElectricityAll?days=$days';
  }

  // 5. 综合数据统计 - 22个设备（所有数据整合）
  // 超时: 60秒
  // 性能: 使用优化版本（预计算数据），30天查询约8秒
  static const String exportComprehensive = '/api/export/comprehensive';

  /// 构建综合导出URL（推荐使用）
  ///
  /// [days] 查询最近N天（默认7天）
  /// [useOptimized] 是否使用优化版本（默认true，推荐）
  ///
  /// 性能对比（30天查询）:
  /// - useOptimized=true: ~8秒（推荐）
  /// - useOptimized=false: ~24秒（仅用于调试）
  ///
  /// 示例:
  /// ```dart
  /// // 查询最近7天（推荐）
  /// final url = Api.buildComprehensiveUrl(days: 7);
  ///
  /// // 查询最近30天
  /// final url = Api.buildComprehensiveUrl(days: 30);
  ///
  /// // 使用旧逻辑（调试）
  /// final url = Api.buildComprehensiveUrl(days: 7, useOptimized: false);
  /// ```
  static String buildComprehensiveUrl({
    int days = 7,
    bool useOptimized = true,
  }) {
    return '$exportComprehensive?days=$days&use_optimized=$useOptimized';
  }

  // ============================================================================
  // 单个设备电量统计（备用接口，前端暂未使用）
  // ============================================================================
  static const String exportElectricity = '/api/export/electricity';
}

// 后端 API 地址与路由常量

class Api {
  static const String baseUrl = 'http://localhost:8080';
  static String get wsBaseUrl => baseUrl.replaceFirst('http://', 'ws://');
  static const String wsRealtimePath = '/ws/realtime';
  static String get wsRealtimeUrl => '$wsBaseUrl$wsRealtimePath';

  static const Duration defaultTimeout = Duration(seconds: 10);
  static const Duration exportTimeout = Duration(seconds: 60);

  // 健康检查
  static const String health = '/api/health';
  static const String healthPlc = '/api/health/plc';
  static const String healthDb = '/api/health/database';
  // 料仓
  static const String hopperRealtimeBatch = '/api/hopper/realtime/batch';
  static String hopperRealtime(String deviceId) => '/api/hopper/$deviceId';
  static String hopperHistory(String deviceId) =>
      '/api/hopper/$deviceId/history';

  /// 料仓下料速度和投料总量历史 (feeding_cumulative)
  static String hopperFeedingCumulative(String deviceId) =>
      '/api/hopper/$deviceId/feeding-cumulative';

  // 辊道窑
  static const String rollerInfo = '/api/roller/info';
  static const String rollerRealtime = '/api/roller/realtime';
  static const String rollerRealtimeFormatted =
      '/api/roller/realtime/formatted';
  static const String rollerHistory = '/api/roller/history';
  static String rollerZone(String zoneId) => '/api/roller/zone/$zoneId';

  // SCR
  static const String scrRealtimeBatch = '/api/scr/realtime/batch';
  static String scrRealtime(String deviceId) => '/api/scr/$deviceId';
  static String scrHistory(String deviceId) => '/api/scr/$deviceId/history';

  // 风机
  static const String fanRealtimeBatch = '/api/fan/realtime/batch';
  static String fanRealtime(String deviceId) => '/api/fan/$deviceId';
  static String fanHistory(String deviceId) => '/api/fan/$deviceId/history';

  // SCR + 风机
  static const String scrFanRealtimeBatch = '/api/scr-fan/realtime/batch';

  // 配置
  static const String configServer = '/api/config/server';
  static const String configPlc = '/api/config/plc';
  static const String configPlcTest = '/api/config/plc/test';

  // 状态位
  static const String statusAll = '/api/status';
  static const String statusFlat = '/api/status/flat';
  static String statusDb(int dbNumber) => '/api/status/db/$dbNumber';

  // 数据导出
  static const String exportRuntimeAll = '/api/export/runtime/all';

  /// 构建运行时长导出 URL
  static String buildRuntimeUrl({int days = 7}) {
    return '$exportRuntimeAll?days=$days';
  }

  static const String exportGasConsumption = '/api/export/gas-consumption';

  /// 构建燃气消耗导出 URL
  static String buildGasUrl({int days = 7, String deviceIds = 'scr_1,scr_2'}) {
    return '$exportGasConsumption?days=$days&device_ids=$deviceIds';
  }

  static const String exportFeedingAmount = '/api/export/feeding-amount';

  /// 构建投料量导出 URL
  static String buildFeedingUrl({int days = 7}) {
    return '$exportFeedingAmount?days=$days';
  }

  static const String exportElectricityAll = '/api/export/electricity/all';

  /// 构建电量导出 URL
  static String buildElectricityUrl({int days = 7}) {
    return '$exportElectricityAll?days=$days';
  }

  static const String exportComprehensive = '/api/export/comprehensive';

  /// 构建综合导出 URL
  static String buildComprehensiveUrl({
    int days = 7,
    bool useOptimized = true,
  }) {
    return '$exportComprehensive?days=$days&use_optimized=$useOptimized';
  }

  // 备用
  static const String exportElectricity = '/api/export/electricity';

  // 报警管理
  static const String alarmThresholds = '/api/alarm/thresholds';
  static const String alarmRecords = '/api/alarm/records';
  static const String alarmCount = '/api/alarm/count';
}

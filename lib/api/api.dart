// 后端API地址统一管理

class Api {
  static const String baseUrl = 'http://localhost:8080';

  // 健康检查
  static const String health = '/api/health';
  static const String healthPlc = '/api/health/plc';
  static const String healthDb = '/api/health/database';
  static const String healthLatestTimestamp = '/api/health/latest-timestamp';

  // 料仓
  static const String hopperRealtimeBatch = '/api/hopper/realtime/batch';
  static String hopperRealtime(String deviceId) => '/api/hopper/$deviceId';
  static String hopperHistory(String deviceId) =>
      '/api/hopper/$deviceId/history';

  // 辊道窑
  static const String rollerInfo = '/api/roller/info';
  static const String rollerRealtime = '/api/roller/realtime';
  static const String rollerRealtimeFormatted =
      '/api/roller/realtime/formatted'; // 批量接口：6个zone + total
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

  // SCR+风机统一接口
  static const String scrFanRealtimeBatch = '/api/scr-fan/realtime/batch';

  // 配置
  static const String configServer = '/api/config/server';
  static const String configPlc = '/api/config/plc';
  static const String configPlcTest = '/api/config/plc/test';

  // 传感器状态位 (后端解析)
  static const String statusAll = '/api/status'; // 按DB分组
  static const String statusFlat = '/api/status/flat'; // 扁平列表
  static String statusDb(int dbNumber) => '/api/status/db/$dbNumber'; // 单个DB

  // 数据导出（5个核心接口）
  // ============================================================================
  // 1. 运行时长统计 - 20个设备（除燃气表外的所有设备）
  // ============================================================================
  static const String exportRuntimeAll = '/api/export/runtime/all';

  // ============================================================================
  // 2. 燃气消耗统计 - 2个设备（仅SCR燃气表）
  // ============================================================================
  static const String exportGasConsumption = '/api/export/gas-consumption';

  // ============================================================================
  // 3. 投料量统计 - 7个设备（仅带料仓的回转窑）
  // ============================================================================
  static const String exportFeedingAmount = '/api/export/feeding-amount';

  // ============================================================================
  // 4. 电量统计 - 20个设备（除燃气表外的所有设备，含运行时长）
  // ============================================================================
  static const String exportElectricityAll = '/api/export/electricity/all';

  // ============================================================================
  // 5. 综合数据统计 - 20个设备（所有数据整合）
  // ============================================================================
  static const String exportComprehensive = '/api/export/comprehensive';

  // ============================================================================
  // 单个设备电量统计（备用接口，前端暂未使用）
  // ============================================================================
  static const String exportElectricity = '/api/export/electricity';
}

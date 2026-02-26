// 报警服务 - 阈值同步与记录查询

import '../api/api.dart';
import '../api/index.dart';
import '../models/alarm_model.dart';
import '../providers/realtime_config_provider.dart';
import '../utils/app_logger.dart';

class AlarmService {
  static final AlarmService _instance = AlarmService._internal();
  factory AlarmService() => _instance;
  AlarmService._internal();

  final ApiClient _httpClient = ApiClient();

  // ============================================================
  // 1. syncThresholds() - 将前端阈值配置同步到后端
  // ============================================================
  /// 将 RealtimeConfigProvider 中的阈值转换为后端 param_name 格式，然后 PUT。
  ///
  /// 映射规则:
  ///   frontend key              backend param_name
  ///   short_hopper_1_temp   ->  rotary_temp_short_hopper_1
  ///   short_hopper_1_power  ->  rotary_power_short_hopper_1
  ///   zone1_temp            ->  roller_temp_zone1
  ///   fan_1_power           ->  fan_power_1
  ///   scr_1_meter           ->  scr_power_1
  ///   scr_1_gas_meter       ->  scr_gas_1
  ///
  /// subtractTemp100 处理:
  ///   no_hopper 设备温度显示时减去 100，后端比较的是 PLC 原始值，
  ///   所以同步时阈值 +100。
  ///
  /// 功率运行阈值处理:
  ///   normalMax < 5.0 时认为是"是否运行"阈值而非警告阈值，
  ///   此时 warning_max = warningMax * 0.85，alarm_max = warningMax。
  Future<bool> syncThresholds(RealtimeConfigProvider config) async {
    try {
      final body = _buildSyncMap(config);
      await _httpClient.put(Api.alarmThresholds, body: body);
      logger.info('[AlarmService] 阈值同步成功，共 ${body.length} 个参数');
      return true;
    } catch (e) {
      logger.warning('[AlarmService] 阈值同步失败: $e');
      return false;
    }
  }

  // 1.1 构建 backend param_name -> {warning_max, alarm_max, enabled} 映射表
  Map<String, dynamic> _buildSyncMap(RealtimeConfigProvider config) {
    final map = <String, dynamic>{};

    // --- 回转窑温度 x9 ---
    for (final cfg in config.rotaryKilnConfigs) {
      // key = "{device_id}_temp"
      final deviceId = cfg.key.replaceAll('_temp', '');
      final offset = cfg.subtractTemp100 ? 100.0 : 0.0;
      map['rotary_temp_$deviceId'] = {
        'warning_max': cfg.normalMax + offset,
        'alarm_max': cfg.warningMax + offset,
        'enabled': true,
      };
    }

    // --- 回转窑功率 x9 ---
    for (final cfg in config.rotaryKilnPowerConfigs) {
      // key = "{device_id}_power"
      final deviceId = cfg.key.replaceAll('_power', '');
      map['rotary_power_$deviceId'] = _makePowerEntry(cfg);
    }

    // --- 辊道窑温度 x6 ---
    for (final cfg in config.rollerKilnConfigs) {
      // key = "zone{n}_temp"
      final zoneTag = cfg.key.replaceAll('_temp', ''); // e.g. "zone1"
      map['roller_temp_$zoneTag'] = {
        'warning_max': cfg.normalMax,
        'alarm_max': cfg.warningMax,
        'enabled': true,
      };
    }

    // --- 风机功率 x2 ---
    for (final cfg in config.fanConfigs) {
      // key = "fan_{n}_power"
      final num = cfg.key.split('_')[1]; // "1" or "2"
      map['fan_power_$num'] = _makePowerEntry(cfg);
    }

    // --- SCR 氨水泵功率 x2 ---
    for (final cfg in config.scrPumpConfigs) {
      // key = "scr_{n}_meter"
      final num = cfg.key.split('_')[1]; // "1" or "2"
      map['scr_power_$num'] = _makePowerEntry(cfg);
    }

    // --- SCR 燃气表流量 x2 ---
    for (final cfg in config.scrGasConfigs) {
      // key = "scr_{n}_gas_meter"
      final num = cfg.key.split('_')[1]; // "1" or "2"
      map['scr_gas_$num'] = {
        'warning_max': cfg.normalMax,
        'alarm_max': cfg.warningMax,
        'enabled': true,
      };
    }

    return map;
  }

  // 1.2 功率阈值处理：normalMax < 5.0 视为运行标志，非警告阈值
  Map<String, dynamic> _makePowerEntry(ThresholdConfig cfg) {
    final double warningMax;
    final double alarmMax = cfg.warningMax;
    if (cfg.normalMax < 5.0) {
      // 运行阈值 -> 取报警阈值的 85% 作为警告阈值
      warningMax = cfg.warningMax * 0.85;
    } else {
      warningMax = cfg.normalMax;
    }
    return {
      'warning_max': warningMax,
      'alarm_max': alarmMax,
      'enabled': true,
    };
  }

  // ============================================================
  // 2. queryAlarms() - 查询历史报警记录
  // ============================================================
  Future<List<AlarmRecord>> queryAlarms({
    DateTime? start,
    DateTime? end,
    String? level,
    String? paramPrefix,
    int limit = 200,
  }) async {
    final params = <String, String>{
      'limit': limit.toString(),
    };
    if (start != null) params['start'] = start.toUtc().toIso8601String();
    if (end != null) params['end'] = end.toUtc().toIso8601String();
    if (level != null && level.isNotEmpty) params['level'] = level;
    if (paramPrefix != null && paramPrefix.isNotEmpty) {
      params['param_prefix'] = paramPrefix;
    }

    try {
      final data = await _httpClient.get(Api.alarmRecords, params: params);
      if (data == null || data['success'] != true) return [];
      final list = (data['data']?['records'] as List?) ?? [];
      return list
          .whereType<Map<String, dynamic>>()
          .map(AlarmRecord.fromJson)
          .toList();
    } catch (e) {
      logger.warning('[AlarmService] 查询报警记录失败: $e');
      return [];
    }
  }

  // ============================================================
  // 3. getAlarmCount() - 统计报警数量
  // ============================================================
  Future<AlarmCount> getAlarmCount({int hours = 24}) async {
    try {
      final data = await _httpClient.get(
        Api.alarmCount,
        params: {'hours': hours.toString()},
      );
      if (data == null || data['success'] != true) return AlarmCount.zero;
      return AlarmCount.fromJson(data['data'] as Map<String, dynamic>);
    } catch (e) {
      logger.warning('[AlarmService] 统计报警数量失败: $e');
      return AlarmCount.zero;
    }
  }
}

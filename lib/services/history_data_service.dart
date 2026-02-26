import 'dart:async';
import 'package:flutter/material.dart';
import '../api/api.dart';
import '../api/index.dart';

/// 历史数据服务
/// 用于查询后端历史数据API，支持动态聚合间隔
class HistoryDataService {
  static final HistoryDataService _instance = HistoryDataService._internal();
  factory HistoryDataService() => _instance;
  HistoryDataService._internal();

  // ============================================================
  // 时间格式化辅助方法
  // ============================================================

  /// 将DateTime转换为本地时间字符串（不转UTC，因为后端存储的是北京时间）
  /// 例如: "2025-12-20T10:30:00" (用户选择的北京时间)
  ///
  /// 注意：后端 polling_service.py 使用 now_beijing() 存储时间戳，
  /// 因此查询时应发送本地时间（北京时间），而不是 UTC 时间
  static String _formatLocalTime(DateTime dateTime) {
    return '${dateTime.year.toString().padLeft(4, '0')}-'
        '${dateTime.month.toString().padLeft(2, '0')}-'
        '${dateTime.day.toString().padLeft(2, '0')}T'
        '${dateTime.hour.toString().padLeft(2, '0')}:'
        '${dateTime.minute.toString().padLeft(2, '0')}:'
        '${dateTime.second.toString().padLeft(2, '0')}';
  }

  // ============================================================
  // 设备ID映射常量
  // ============================================================

  /// 回转窑设备ID映射（1-9号窑对应device_id）
  static const Map<int, String> hopperDeviceIds = {
    1: 'short_hopper_1',
    2: 'short_hopper_2',
    3: 'short_hopper_3',
    4: 'short_hopper_4',
    5: 'no_hopper_1',
    6: 'no_hopper_2',
    7: 'long_hopper_1',
    8: 'long_hopper_2',
    9: 'long_hopper_3',
  };

  /// 辊道窑温区ID映射（1-6号温区）
  static const Map<int, String> rollerZoneIds = {
    1: 'zone1',
    2: 'zone2',
    3: 'zone3',
    4: 'zone4',
    5: 'zone5',
    6: 'zone6',
  };

  /// SCR设备ID映射
  static const Map<int, String> scrDeviceIds = {
    1: 'scr_1',
    2: 'scr_2',
  };

  /// 风机设备ID映射
  static const Map<int, String> fanDeviceIds = {
    1: 'fan_1',
    2: 'fan_2',
  };

  // ============================================================
  // 动态聚合间隔计算
  // ============================================================

  /// 目标数据点数（保持图表显示效果一致）
  static const int _targetPoints = 80;

  /// 可接受的数据点范围
  static const int _minPoints = 40;
  static const int _maxPoints = 150;

  /// 有效的聚合间隔选项（秒）
  /// InfluxDB 支持的常用间隔值
  static const List<int> _validIntervals = [
    5, // 5s - 原始精度
    10, // 10s
    15, // 15s
    30, // 30s
    60, // 1m
    120, // 2m
    180, // 3m
    300, // 5m
    600, // 10m
    900, // 15m
    1800, // 30m
    3600, // 1h
    7200, // 2h
    14400, // 4h
    21600, // 6h
    43200, // 12h
    86400, // 1d
    172800, // 2d
    259200, // 3d
    604800, // 7d (1周)
    1209600, // 14d (2周)
    2592000, // 30d (1月)
  ];

  /// 根据时间范围计算最佳聚合间隔
  ///
  /// 核心逻辑：选择能让数据点数最接近目标值(120)的聚合间隔
  /// 这样无论时间范围多大，返回的数据点数都相对一致
  ///
  /// 示例：
  /// - 2分钟 → 5s → ~24点 (短时间保持原始精度)
  /// - 10分钟 → 5s → 120点
  /// - 1小时 → 30s → 120点
  /// - 6小时 → 3m → 120点
  /// - 24小时 → 12m (720s) → ~120点 → 取10m → 144点
  /// - 7天 → 1h → 168点
  static String calculateAggregateInterval(DateTime start, DateTime end) {
    final duration = end.difference(start);
    final totalSeconds = duration.inSeconds;

    // 特殊情况：时间范围太短，直接返回原始精度
    if (totalSeconds <= 0) {
      return '5s';
    }

    // 计算理想的聚合间隔（秒）
    final idealIntervalSeconds = totalSeconds / _targetPoints;

    // 找到最佳的有效间隔
    int bestInterval = _validIntervals[0];
    double minDiff = double.infinity;

    for (final interval in _validIntervals) {
      final estimatedPoints = totalSeconds / interval;

      // 优先选择在合理范围内且最接近目标的间隔
      if (estimatedPoints >= _minPoints && estimatedPoints <= _maxPoints) {
        final diff = (estimatedPoints - _targetPoints).abs();
        if (diff < minDiff) {
          minDiff = diff;
          bestInterval = interval;
        }
      }
    }

    // 如果没有找到合理范围内的，选择最接近理想值的间隔
    if (minDiff == double.infinity) {
      minDiff = double.infinity;
      for (final interval in _validIntervals) {
        final diff = (interval - idealIntervalSeconds).abs();
        if (diff < minDiff) {
          minDiff = diff;
          bestInterval = interval;
        }
      }
    }

    return _formatInterval(bestInterval);
  }

  /// 将秒数格式化为 InfluxDB 支持的间隔字符串
  static String _formatInterval(int seconds) {
    if (seconds < 60) {
      return '${seconds}s';
    } else if (seconds < 3600) {
      return '${seconds ~/ 60}m';
    } else if (seconds < 86400) {
      return '${seconds ~/ 3600}h';
    } else {
      return '${seconds ~/ 86400}d';
    }
  }

  // ============================================================
  // 料仓历史数据查询
  // ============================================================

  /// 查询料仓历史数据（支持动态聚合间隔）
  ///
  /// [deviceId] 设备ID（如 short_hopper_1）
  /// [start] 开始时间
  /// [end] 结束时间
  /// [moduleType] 模块类型（WeighSensor, TemperatureSensor, ElectricityMeter）
  /// [fields] 查询字段列表
  /// [autoInterval] 是否自动计算最佳聚合间隔（默认 true）
  /// [interval] 手动指定聚合间隔（如果 autoInterval=false）
  Future<HistoryDataResult> queryHopperHistory({
    required String deviceId,
    required DateTime start,
    required DateTime end,
    String? moduleType,
    List<String>? fields,
    bool autoInterval = true,
    String? interval,
  }) async {
    // 发送本地时间（后端使用北京时间存储）
    final queryParams = <String, String>{
      'start': _formatLocalTime(start),
      'end': _formatLocalTime(end),
      'auto_interval': autoInterval.toString(),
    };

    // 不自动计算时，发送手动指定的 interval，否则后端自己计算
    if (!autoInterval) {
      final String computedInterval =
          interval ?? calculateAggregateInterval(start, end);
      queryParams['interval'] = computedInterval;
    }

    if (moduleType != null) {
      queryParams['module_type'] = moduleType;
    }
    if (fields != null && fields.isNotEmpty) {
      queryParams['fields'] = fields.join(',');
    }

    final uri = Uri.parse('${Api.baseUrl}${Api.hopperHistory(deviceId)}')
        .replace(queryParameters: queryParams);

    return _fetchHistoryData(uri, deviceId);
  }

  /// 查询料仓温度历史
  Future<HistoryDataResult> queryHopperTemperatureHistory({
    required String deviceId,
    required DateTime start,
    required DateTime end,
  }) {
    return queryHopperHistory(
      deviceId: deviceId,
      start: start,
      end: end,
      moduleType: 'TemperatureSensor',
      fields: ['temperature'],
    );
  }

  /// 查询料仓称重历史（仅重量）
  /// 注意: feed_rate 不在 sensor_data 中, 需要用 queryHopperFeedRateHistory 查 feeding_cumulative
  Future<HistoryDataResult> queryHopperWeightHistory({
    required String deviceId,
    required DateTime start,
    required DateTime end,
  }) {
    return queryHopperHistory(
      deviceId: deviceId,
      start: start,
      end: end,
      moduleType: 'WeighSensor',
      fields: ['weight'],
    );
  }

  /// 查询料仓下料速度历史 (从 feeding_cumulative measurement)
  /// 返回 display_feed_rate 数据点
  Future<HistoryDataResult> queryHopperFeedRateHistory({
    required String deviceId,
    required DateTime start,
    required DateTime end,
  }) async {
    final queryParams = <String, String>{
      'start': _formatLocalTime(start),
      'end': _formatLocalTime(end),
      'fields': 'display_feed_rate',
      'auto_interval': 'true',
    };

    final uri =
        Uri.parse('${Api.baseUrl}${Api.hopperFeedingCumulative(deviceId)}')
            .replace(queryParameters: queryParams);

    return _fetchHistoryData(uri, deviceId);
  }

  /// 查询料仓投料总量历史 (从 feeding_cumulative measurement)
  /// 返回 feeding_total 数据点
  Future<HistoryDataResult> queryHopperFeedingTotalHistory({
    required String deviceId,
    required DateTime start,
    required DateTime end,
  }) async {
    final queryParams = <String, String>{
      'start': _formatLocalTime(start),
      'end': _formatLocalTime(end),
      'fields': 'feeding_total',
      'auto_interval': 'true',
    };

    final uri =
        Uri.parse('${Api.baseUrl}${Api.hopperFeedingCumulative(deviceId)}')
            .replace(queryParameters: queryParams);

    return _fetchHistoryData(uri, deviceId);
  }

  /// 查询料仓功率历史
  Future<HistoryDataResult> queryHopperPowerHistory({
    required String deviceId,
    required DateTime start,
    required DateTime end,
  }) {
    return queryHopperHistory(
      deviceId: deviceId,
      start: start,
      end: end,
      moduleType: 'ElectricityMeter',
      fields: ['Pt'],
    );
  }

  ///  查询料仓能耗历史 (ImpEp - 累积电能)
  Future<HistoryDataResult> queryHopperEnergyHistory({
    required String deviceId,
    required DateTime start,
    required DateTime end,
  }) {
    return queryHopperHistory(
      deviceId: deviceId,
      start: start,
      end: end,
      moduleType: 'ElectricityMeter',
      fields: ['ImpEp'],
    );
  }

  /// 查询回转窑投料记录 (Feeding History)
  /// 返回原始投料事件列表
  Future<List<FeedingRecord>> queryHopperFeedingHistory({
    required String deviceId,
    required DateTime start,
    required DateTime end,
  }) async {
    try {
      debugPrint(
          '🔍 查询投料历史: $deviceId, Start: ${start.toString()}, End: ${end.toString()}');
      final jsonResponse = await ApiClient().get(
        '/api/hopper/$deviceId/feeding-history',
        params: {
          'start': _formatLocalTime(start),
          'end': _formatLocalTime(end),
          'limit': '5000', // 增加Limit以支持高频数据
        },
      );

      if (jsonResponse['success'] == true || jsonResponse['code'] == 200) {
        final List<dynamic> list = jsonResponse['data'];
        debugPrint(' 投料历史返回: ${list.length} 条记录');
        return list.map((json) => FeedingRecord.fromJson(json)).toList();
      } else {
        debugPrint(
            ' 后端返回错误: ${jsonResponse['error'] ?? jsonResponse['message']}');
      }
      return [];
    } catch (e) {
      debugPrint(' 查询投料记录异常: $e');
      return [];
    }
  }

  /// 回填（校正）投料记录
  Future<bool> backfillFeedingRecord(
      String deviceId, Map<String, dynamic> record) async {
    try {
      final jsonResponse = await ApiClient().post(
        '/api/hopper/$deviceId/feeding-history/backfill',
        body: record,
      );

      return jsonResponse['success'] == true || jsonResponse['code'] == 200;
    } catch (e) {
      debugPrint(' 回填投料记录失败: $e');
      return false;
    }
  }

  ///  [New] 删除错误的投料记录
  Future<bool> deleteFeedingRecord(String deviceId, DateTime time) async {
    try {
      final jsonResponse = await ApiClient().delete(
        '/api/hopper/$deviceId/feeding-history',
        params: {'time': time.toIso8601String()},
      );

      return jsonResponse['success'] == true || jsonResponse['code'] == 200;
    } catch (e) {
      debugPrint(' 删除投料记录失败: $e');
      return false;
    }
  }

  // ============================================================
  // 辊道窑历史数据查询
  // ============================================================

  /// 查询辊道窑历史数据
  Future<HistoryDataResult> queryRollerHistory({
    required DateTime start,
    required DateTime end,
    String? zone,
    String? moduleType,
    List<String>? fields,
  }) async {
    final interval = calculateAggregateInterval(start, end);

    // 发送本地时间（后端使用北京时间存储）
    final queryParams = <String, String>{
      'start': _formatLocalTime(start),
      'end': _formatLocalTime(end),
      'interval': interval,
    };

    if (zone != null) {
      queryParams['zone'] = zone;
    }
    if (moduleType != null) {
      queryParams['module_type'] = moduleType;
    }
    if (fields != null && fields.isNotEmpty) {
      queryParams['fields'] = fields.join(',');
    }

    final uri = Uri.parse('${Api.baseUrl}${Api.rollerHistory}')
        .replace(queryParameters: queryParams);

    return _fetchHistoryData(uri, 'roller_kiln');
  }

  /// 查询辊道窑温度历史（所有温区或指定温区）
  Future<HistoryDataResult> queryRollerTemperatureHistory({
    required DateTime start,
    required DateTime end,
    String? zone,
  }) {
    return queryRollerHistory(
      start: start,
      end: end,
      zone: zone,
      moduleType: 'TemperatureSensor',
      fields: ['temperature'],
    );
  }

  /// 查询辊道窑功率历史
  Future<HistoryDataResult> queryRollerPowerHistory({
    required DateTime start,
    required DateTime end,
    String? zone,
  }) {
    return queryRollerHistory(
      start: start,
      end: end,
      zone: zone,
      moduleType: 'ElectricityMeter',
      fields: ['Pt', 'ImpEp'],
    );
  }

  // ============================================================
  // SCR历史数据查询
  // ============================================================

  /// 查询SCR历史数据
  Future<HistoryDataResult> queryScrHistory({
    required String deviceId,
    required DateTime start,
    required DateTime end,
    String? moduleType,
    List<String>? fields,
  }) async {
    final interval = calculateAggregateInterval(start, end);

    // 发送本地时间（后端使用北京时间存储）
    final queryParams = <String, String>{
      'start': _formatLocalTime(start),
      'end': _formatLocalTime(end),
      'interval': interval,
    };

    if (moduleType != null) {
      queryParams['module_type'] = moduleType;
    }
    if (fields != null && fields.isNotEmpty) {
      queryParams['fields'] = fields.join(',');
    }

    final uri = Uri.parse('${Api.baseUrl}${Api.scrHistory(deviceId)}')
        .replace(queryParameters: queryParams);

    return _fetchHistoryData(uri, deviceId);
  }

  /// 查询SCR功率历史
  Future<HistoryDataResult> queryScrPowerHistory({
    required String deviceId,
    required DateTime start,
    required DateTime end,
  }) {
    return queryScrHistory(
      deviceId: deviceId,
      start: start,
      end: end,
      moduleType: 'ElectricityMeter',
      fields: ['Pt', 'ImpEp'],
    );
  }

  /// 查询SCR燃气流量历史
  Future<HistoryDataResult> queryScrGasHistory({
    required String deviceId,
    required DateTime start,
    required DateTime end,
  }) {
    return queryScrHistory(
      deviceId: deviceId,
      start: start,
      end: end,
      moduleType: 'FlowMeter',
      fields: ['flow_rate', 'total_flow'],
    );
  }

  // ============================================================
  // 风机历史数据查询
  // ============================================================

  /// 查询风机历史数据
  Future<HistoryDataResult> queryFanHistory({
    required String deviceId,
    required DateTime start,
    required DateTime end,
    String? moduleType,
    List<String>? fields,
  }) async {
    final interval = calculateAggregateInterval(start, end);

    // 发送本地时间（后端使用北京时间存储）
    final queryParams = <String, String>{
      'start': _formatLocalTime(start),
      'end': _formatLocalTime(end),
      'interval': interval,
    };

    if (moduleType != null) {
      queryParams['module_type'] = moduleType;
    }
    if (fields != null && fields.isNotEmpty) {
      queryParams['fields'] = fields.join(',');
    }

    final uri = Uri.parse('${Api.baseUrl}${Api.fanHistory(deviceId)}')
        .replace(queryParameters: queryParams);

    return _fetchHistoryData(uri, deviceId);
  }

  /// 查询风机功率历史 (只查 Pt，ImpEp 风机图表暂不展示)
  Future<HistoryDataResult> queryFanPowerHistory({
    required String deviceId,
    required DateTime start,
    required DateTime end,
  }) {
    return queryFanHistory(
      deviceId: deviceId,
      start: start,
      end: end,
      moduleType: 'ElectricityMeter',
      fields: ['Pt'],
    );
  }

  // ============================================================
  // 内部方法
  // ============================================================

  /// 通用历史数据请求方法
  ///  修复: 使用 ApiClient 统一管理 HTTP 请求
  Future<HistoryDataResult> _fetchHistoryData(Uri uri, String deviceId) async {
    final client = ApiClient();

    try {
      //  构建查询参数 Map
      final params = <String, String>{};
      uri.queryParameters.forEach((key, value) {
        params[key] = value;
      });

      debugPrint(' 请求历史数据: ${uri.path}');
      final json =
          await client.get(uri.path, params: params.isNotEmpty ? params : null);

      if (json['success'] == true) {
        final data = json['data'];
        final dataList = data['data'] as List<dynamic>? ?? [];

        return HistoryDataResult(
          success: true,
          deviceId: deviceId,
          timeRange: TimeRange(
            start: DateTime.parse(data['time_range']['start']).toLocal(),
            end: DateTime.parse(data['time_range']['end']).toLocal(),
          ),
          interval: data['interval'] ?? '5m',
          dataPoints:
              dataList.map((e) => HistoryDataPoint.fromJson(e)).toList(),
        );
      } else {
        return HistoryDataResult(
          success: false,
          deviceId: deviceId,
          error: json['error'] ?? '查询失败',
        );
      }
    } on TimeoutException {
      debugPrint(' 历史数据请求超时');
      return HistoryDataResult(
        success: false,
        deviceId: deviceId,
        error: '请求超时，请检查网络连接',
      );
    } catch (e) {
      debugPrint(' 历史数据请求失败: $e');
      return HistoryDataResult(
        success: false,
        deviceId: deviceId,
        error: '网络错误: $e',
      );
    }
  }
}

// ============================================================
// 数据模型
// ============================================================

/// 历史数据查询结果
class HistoryDataResult {
  final bool success;
  final String deviceId;
  final TimeRange? timeRange;
  final String? interval;
  final List<HistoryDataPoint>? dataPoints;
  final String? error;

  HistoryDataResult({
    required this.success,
    required this.deviceId,
    this.timeRange,
    this.interval,
    this.dataPoints,
    this.error,
  });

  /// 数据点数量
  int get count => dataPoints?.length ?? 0;

  /// 是否有数据
  bool get hasData => dataPoints != null && dataPoints!.isNotEmpty;
}

/// 时间范围
class TimeRange {
  final DateTime start;
  final DateTime end;

  TimeRange({required this.start, required this.end});

  Duration get duration => end.difference(start);
}

class FeedingRecord {
  final DateTime time;
  final double amount;
  final String deviceId;

  FeedingRecord({
    required this.time,
    required this.amount,
    required this.deviceId,
  });

  /// 兼容新旧字段名: v5.0 返回 'amount', 旧版返回 'added_weight'
  factory FeedingRecord.fromJson(Map<String, dynamic> json) {
    final value = json['amount'] ?? json['added_weight'] ?? 0;
    return FeedingRecord(
      time: DateTime.parse(json['time']).toLocal(),
      amount: (value as num).toDouble(),
      deviceId: json['device_id'] as String,
    );
  }
}

/// 历史数据点
class HistoryDataPoint {
  final DateTime time;
  final String? moduleTag;
  final String? moduleType;
  final Map<String, dynamic> fields;

  HistoryDataPoint({
    required this.time,
    this.moduleTag,
    this.moduleType,
    required this.fields,
  });

  factory HistoryDataPoint.fromJson(Map<String, dynamic> json) {
    // 提取时间 - 转换为本地时间
    final timeStr = json['time'] as String;
    final time = DateTime.parse(timeStr).toLocal();

    // 提取字段值
    final fields = <String, dynamic>{};
    for (var entry in json.entries) {
      if (!['time', 'module_tag', 'module_type'].contains(entry.key)) {
        fields[entry.key] = entry.value;
      }
    }

    return HistoryDataPoint(
      time: time,
      moduleTag: json['module_tag'] as String?,
      moduleType: json['module_type'] as String?,
      fields: fields,
    );
  }

  /// 获取温度值
  double? get temperature => _getDouble('temperature');

  /// 获取功率值
  double? get power => _getDouble('Pt');

  /// 获取电能值
  double? get energy => _getDouble('ImpEp');

  /// 获取重量值
  double? get weight => _getDouble('weight');

  /// 获取下料速度 (feeding_cumulative measurement 的 display_feed_rate 字段)
  double? get feedRate => _getDouble('display_feed_rate');

  /// 获取流量
  double? get flowRate => _getDouble('flow_rate');

  /// 获取累计流量
  double? get totalFlow => _getDouble('total_flow');

  double? _getDouble(String key) {
    final value = fields[key];
    if (value == null) return null;
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is String) return double.tryParse(value);
    return null;
  }
}

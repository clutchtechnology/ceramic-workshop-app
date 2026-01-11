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

  /// 获取聚合间隔的预估数据点数（用于调试或UI显示）
  static int getEstimatedPoints(DateTime start, DateTime end) {
    final totalSeconds = end.difference(start).inSeconds;
    final interval = calculateAggregateInterval(start, end);
    final intervalSeconds = _parseIntervalToSeconds(interval);
    return (totalSeconds / intervalSeconds).round();
  }

  /// 将间隔字符串解析为秒数
  static int _parseIntervalToSeconds(String interval) {
    final value = int.tryParse(interval.substring(0, interval.length - 1)) ?? 1;
    final unit = interval[interval.length - 1];
    switch (unit) {
      case 's':
        return value;
      case 'm':
        return value * 60;
      case 'h':
        return value * 3600;
      case 'd':
        return value * 86400;
      default:
        return value;
    }
  }

  // ============================================================
  // 数据库时间戳查询
  // ============================================================

  /// 获取数据库中最新数据的时间戳
  ///
  /// 用于确定历史数据查询的时间范围基准点。
  /// 返回 null 表示数据库中暂无数据或查询失败。
  Future<DateTime?> getLatestDbTimestamp() async {
    try {
      final client = ApiClient();
      final response = await client
          .get(Api.healthLatestTimestamp)
          .timeout(const Duration(seconds: 5));

      if (response != null && response['success'] == true) {
        final data = response['data'];
        if (data != null &&
            data['has_data'] == true &&
            data['timestamp'] != null) {
          // 解析 ISO 格式时间戳 - 转换为本地时间
          return DateTime.parse(data['timestamp']).toLocal();
        }
      }
      return null;
    } catch (e) {
      debugPrint('获取数据库最新时间戳失败: $e');
      return null;
    }
  }

  // ============================================================
  // 料仓历史数据查询
  // ============================================================

  /// 查询料仓历史数据
  ///
  /// [deviceId] 设备ID（如 short_hopper_1）
  /// [start] 开始时间
  /// [end] 结束时间
  /// [moduleType] 模块类型（WeighSensor, TemperatureSensor, ElectricityMeter）
  /// [fields] 查询字段列表
  Future<HistoryDataResult> queryHopperHistory({
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

  /// 查询料仓称重历史（重量、下料速度）
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
      fields: ['weight', 'feed_rate'],
    );
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

  /// 🔧 查询料仓能耗历史 (ImpEp - 累积电能)
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

  /// 查询风机功率历史
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
      fields: ['Pt', 'ImpEp'],
    );
  }

  // ============================================================
  // 内部方法
  // ============================================================

  /// 通用历史数据请求方法
  /// 🔧 修复: 使用 ApiClient 统一管理 HTTP 请求
  Future<HistoryDataResult> _fetchHistoryData(Uri uri, String deviceId) async {
    final client = ApiClient();

    try {
      // 🔧 构建查询参数 Map
      final params = <String, String>{};
      uri.queryParameters.forEach((key, value) {
        params[key] = value;
      });

      debugPrint('📊 请求历史数据: ${uri.path}');
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
      debugPrint('❌ 历史数据请求超时');
      return HistoryDataResult(
        success: false,
        deviceId: deviceId,
        error: '请求超时，请检查网络连接',
      );
    } catch (e) {
      debugPrint('❌ 历史数据请求失败: $e');
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

  /// 获取下料速度
  double? get feedRate => _getDouble('feed_rate');

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

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../api/api.dart';

/// 历史数据服务
/// 用于查询后端历史数据API，支持动态聚合间隔
class HistoryDataService {
  static final HistoryDataService _instance = HistoryDataService._internal();
  factory HistoryDataService() => _instance;
  HistoryDataService._internal();

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

  /// 根据时间范围计算最佳聚合间隔
  ///
  /// 规则：
  /// - < 2分钟：5s（原始精度）
  /// - 2-10分钟：10s
  /// - 10-30分钟：30s
  /// - 30分钟-2小时：1m
  /// - 2-6小时：5m
  /// - 6-24小时：15m
  /// - 1-7天：1h
  /// - > 7天：6h
  static String calculateAggregateInterval(DateTime start, DateTime end) {
    final duration = end.difference(start);
    final minutes = duration.inMinutes;

    if (minutes < 2) {
      return '5s'; // 原始数据
    } else if (minutes < 10) {
      return '10s';
    } else if (minutes < 30) {
      return '30s';
    } else if (minutes < 120) {
      return '1m';
    } else if (minutes < 360) {
      return '5m';
    } else if (minutes < 1440) {
      return '15m';
    } else if (minutes < 10080) {
      return '1h';
    } else {
      return '6h';
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

    final queryParams = <String, String>{
      'start': start.toIso8601String(),
      'end': end.toIso8601String(),
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

    final queryParams = <String, String>{
      'start': start.toIso8601String(),
      'end': end.toIso8601String(),
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

    final queryParams = <String, String>{
      'start': start.toIso8601String(),
      'end': end.toIso8601String(),
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

    final queryParams = <String, String>{
      'start': start.toIso8601String(),
      'end': end.toIso8601String(),
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
  Future<HistoryDataResult> _fetchHistoryData(Uri uri, String deviceId) async {
    try {
      debugPrint('📊 请求历史数据: $uri');
      final response = await http.get(uri);

      if (response.statusCode == 200) {
        final json = jsonDecode(response.body);
        if (json['success'] == true) {
          final data = json['data'];
          final dataList = data['data'] as List<dynamic>? ?? [];

          return HistoryDataResult(
            success: true,
            deviceId: deviceId,
            timeRange: TimeRange(
              start: DateTime.parse(data['time_range']['start']),
              end: DateTime.parse(data['time_range']['end']),
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
      } else {
        return HistoryDataResult(
          success: false,
          deviceId: deviceId,
          error: 'HTTP ${response.statusCode}',
        );
      }
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
    // 提取时间
    final timeStr = json['time'] as String;
    final time = DateTime.parse(timeStr);

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

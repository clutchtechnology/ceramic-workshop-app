// ============================================================
// 文件说明: sensor_status_model.dart - 传感器状态位数据模型
// ============================================================
// 功能:
//   - 定义传感器状态位数据结构
//   - 提供JSON序列化/反序列化
// ============================================================

/// 单个传感器的状态数据
class SensorStatus {
  final String deviceId;
  final String deviceType;
  final String description;
  final bool done; // 通信完成
  final bool busy; // 通信忙
  final bool error; // 通信错误
  final int statusCode; // 状态码
  final DateTime? timestamp;

  SensorStatus({
    required this.deviceId,
    required this.deviceType,
    this.description = '',
    required this.done,
    required this.busy,
    required this.error,
    required this.statusCode,
    this.timestamp,
  });

  /// 从JSON创建
  factory SensorStatus.fromJson(Map<String, dynamic> json) {
    return SensorStatus(
      deviceId: json['device_id'] ?? '',
      deviceType: json['device_type'] ?? '',
      description: json['description'] ?? '',
      done: json['done'] ?? false,
      busy: json['busy'] ?? false,
      error: json['error'] ?? false,
      statusCode: json['status_code'] ?? 0,
      timestamp: json['timestamp'] != null
          ? DateTime.tryParse(json['timestamp'])
          : null,
    );
  }
}

/// 所有传感器状态的响应数据
class AllSensorStatusResponse {
  final bool success;
  final Map<String, SensorStatus>? data;
  final String? error;

  AllSensorStatusResponse({
    required this.success,
    this.data,
    this.error,
  });

  factory AllSensorStatusResponse.fromJson(Map<String, dynamic> json) {
    Map<String, SensorStatus>? statusMap;

    if (json['data'] != null && json['data'] is Map) {
      statusMap = {};
      (json['data'] as Map).forEach((key, value) {
        if (value is Map<String, dynamic>) {
          statusMap![key] = SensorStatus.fromJson(value);
        }
      });
    }

    return AllSensorStatusResponse(
      success: json['success'] ?? false,
      data: statusMap,
      error: json['error'],
    );
  }
}

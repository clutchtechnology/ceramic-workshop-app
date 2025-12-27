import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../api/api.dart';
import '../models/sensor_health_model.dart';

/// 传感器健康检测服务
class SensorHealthService {
  static final SensorHealthService _instance = SensorHealthService._internal();
  factory SensorHealthService() => _instance;
  SensorHealthService._internal();

  /// 获取所有传感器的健康状态
  /// [minutes] 检查时间范围（分钟），默认30分钟
  Future<ApiResponse<SensorHealthResponse>> getSensorHealth({
    int minutes = 30,
  }) async {
    try {
      final uri = Uri.parse('${Api.baseUrl}/api/health/sensors')
          .replace(queryParameters: {'minutes': minutes.toString()});

      debugPrint('🔍 请求传感器健康状态: $uri');

      final response = await http.get(uri).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final json = jsonDecode(response.body);

        if (json['success'] == true && json['data'] != null) {
          final healthResponse = SensorHealthResponse.fromJson(json['data']);
          return ApiResponse.success(healthResponse);
        } else {
          return ApiResponse.error(json['error'] ?? '获取健康状态失败');
        }
      } else {
        return ApiResponse.error('HTTP ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('❌ 获取传感器健康状态失败: $e');
      return ApiResponse.error('网络错误: $e');
    }
  }

  /// 获取健康状态摘要（仅异常设备）
  Future<ApiResponse<Map<String, dynamic>>> getSensorHealthSummary({
    int minutes = 30,
  }) async {
    try {
      final uri = Uri.parse('${Api.baseUrl}/api/health/sensors/summary')
          .replace(queryParameters: {'minutes': minutes.toString()});

      final response = await http.get(uri).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final json = jsonDecode(response.body);

        if (json['success'] == true && json['data'] != null) {
          return ApiResponse.success(json['data'] as Map<String, dynamic>);
        } else {
          return ApiResponse.error(json['error'] ?? '获取健康摘要失败');
        }
      } else {
        return ApiResponse.error('HTTP ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('❌ 获取传感器健康摘要失败: $e');
      return ApiResponse.error('网络错误: $e');
    }
  }
}

/// 通用 API 响应包装
class ApiResponse<T> {
  final bool success;
  final T? data;
  final String? error;

  ApiResponse._({required this.success, this.data, this.error});

  factory ApiResponse.success(T data) =>
      ApiResponse._(success: true, data: data);

  factory ApiResponse.error(String error) =>
      ApiResponse._(success: false, error: error);
}

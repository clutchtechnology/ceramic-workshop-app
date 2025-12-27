// ============================================================
// 文件说明: sensor_status_service.dart - 传感器状态位API服务
// ============================================================
// 功能:
//   - 获取所有传感器状态
//   - 按设备类型过滤状态
//   - 获取错误设备列表
// ============================================================

import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:ceramic_workshop_app/api/api.dart';
import 'package:ceramic_workshop_app/models/sensor_status_model.dart';

class SensorStatusService {
  /// 获取所有传感器的状态位数据
  Future<AllSensorStatusResponse> getAllStatus() async {
    try {
      final response = await http
          .get(Uri.parse('${Api.baseUrl}${Api.statusAll}'))
          .timeout(const Duration(seconds: 5));

      if (response.statusCode == 200) {
        final jsonData = json.decode(utf8.decode(response.bodyBytes));
        return AllSensorStatusResponse.fromJson(jsonData);
      } else {
        return AllSensorStatusResponse(
          success: false,
          error: '请求失败: ${response.statusCode}',
        );
      }
    } catch (e) {
      return AllSensorStatusResponse(
        success: false,
        error: '网络错误: $e',
      );
    }
  }

  /// 获取单个设备的状态
  Future<SensorStatus?> getDeviceStatus(String deviceId) async {
    try {
      final response = await http
          .get(Uri.parse('${Api.baseUrl}${Api.statusDevice(deviceId)}'))
          .timeout(const Duration(seconds: 5));

      if (response.statusCode == 200) {
        final jsonData = json.decode(utf8.decode(response.bodyBytes));
        if (jsonData['success'] == true && jsonData['data'] != null) {
          return SensorStatus.fromJson(jsonData['data']);
        }
      }
      return null;
    } catch (e) {
      print('获取设备状态失败: $e');
      return null;
    }
  }
}

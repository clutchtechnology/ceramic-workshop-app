// ============================================================================
// API 使用示例 - 数据导出接口
// ============================================================================
// 
// 本文件展示如何使用优化后的数据导出接口
// 
// 性能说明:
// - 后端已使用预计算数据（daily_summary）
// - 30天查询时间: ~8秒（优化前: ~24秒）
// - 性能提升: 66%
// 
// ============================================================================

import 'package:http/http.dart' as http;
import 'dart:convert';
import 'api.dart';

// ============================================================================
// 示例1: 综合数据导出（推荐使用）
// ============================================================================

/// 查询最近7天的综合数据
/// 
/// 包含: 电量、燃气、投料、运行时长
/// 设备: 22个设备（9个料仓 + 7个辊道窑 + 2个SCR + 2个风机 + 2个SCR燃气表）
Future<Map<String, dynamic>?> fetchComprehensiveData7Days() async {
  try {
    // 构建URL（使用优化版本）
    final url = Uri.parse('${Api.baseUrl}${Api.buildComprehensiveUrl(days: 7)}');
    
    // 发送请求（60秒超时）
    final response = await http.get(url).timeout(Api.exportTimeout);
    
    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      if (data['success'] == true) {
        return data['data'];
      }
    }
    return null;
  } catch (e) {
    print('查询失败: $e');
    return null;
  }
}

/// 查询最近30天的综合数据
/// 
/// 性能: ~8秒（优化版本）
Future<Map<String, dynamic>?> fetchComprehensiveData30Days() async {
  try {
    final url = Uri.parse('${Api.baseUrl}${Api.buildComprehensiveUrl(days: 30)}');
    final response = await http.get(url).timeout(Api.exportTimeout);
    
    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      if (data['success'] == true) {
        return data['data'];
      }
    }
    return null;
  } catch (e) {
    print('查询失败: $e');
    return null;
  }
}

/// 查询今天的综合数据
/// 
/// days=1: 今天0点到现在
Future<Map<String, dynamic>?> fetchComprehensiveDataToday() async {
  try {
    final url = Uri.parse('${Api.baseUrl}${Api.buildComprehensiveUrl(days: 1)}');
    final response = await http.get(url).timeout(Api.exportTimeout);
    
    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      if (data['success'] == true) {
        return data['data'];
      }
    }
    return null;
  } catch (e) {
    print('查询失败: $e');
    return null;
  }
}

// ============================================================================
// 示例2: 电量数据导出
// ============================================================================

/// 查询所有设备的电量数据
/// 
/// 包含: 电量消耗 + 运行时长
/// 设备: 20个设备（除燃气表外的所有设备）
Future<Map<String, dynamic>?> fetchElectricityData({int days = 7}) async {
  try {
    final url = Uri.parse('${Api.baseUrl}${Api.buildElectricityUrl(days: days)}');
    final response = await http.get(url).timeout(Api.exportTimeout);
    
    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      if (data['success'] == true) {
        return data['data'];
      }
    }
    return null;
  } catch (e) {
    print('查询失败: $e');
    return null;
  }
}

// ============================================================================
// 示例3: 燃气消耗导出
// ============================================================================

/// 查询SCR燃气表的燃气消耗
/// 
/// 设备: 2个SCR燃气表（scr_1, scr_2）
Future<Map<String, dynamic>?> fetchGasConsumption({int days = 7}) async {
  try {
    final url = Uri.parse('${Api.baseUrl}${Api.buildGasUrl(days: days)}');
    final response = await http.get(url).timeout(Api.exportTimeout);
    
    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      if (data['success'] == true) {
        return data['data'];
      }
    }
    return null;
  } catch (e) {
    print('查询失败: $e');
    return null;
  }
}

// ============================================================================
// 示例4: 投料量导出
// ============================================================================

/// 查询料仓的投料量
/// 
/// 设备: 7个带料仓的回转窑
Future<Map<String, dynamic>?> fetchFeedingAmount({int days = 7}) async {
  try {
    final url = Uri.parse('${Api.baseUrl}${Api.buildFeedingUrl(days: days)}');
    final response = await http.get(url).timeout(Api.exportTimeout);
    
    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      if (data['success'] == true) {
        return data['data'];
      }
    }
    return null;
  } catch (e) {
    print('查询失败: $e');
    return null;
  }
}

// ============================================================================
// 示例5: 运行时长导出
// ============================================================================

/// 查询所有设备的运行时长
/// 
/// 设备: 22个设备（所有设备）
Future<Map<String, dynamic>?> fetchRuntimeData({int days = 7}) async {
  try {
    final url = Uri.parse('${Api.baseUrl}${Api.buildRuntimeUrl(days: days)}');
    final response = await http.get(url).timeout(Api.exportTimeout);
    
    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      if (data['success'] == true) {
        return data['data'];
      }
    }
    return null;
  } catch (e) {
    print('查询失败: $e');
    return null;
  }
}

// ============================================================================
// 示例6: 数据解析
// ============================================================================

/// 解析综合数据
/// 
/// 返回结构:
/// ```json
/// {
///   "start_time": "2026-01-20T00:00:00Z",
///   "end_time": "2026-01-27T12:34:56Z",
///   "total_devices": 22,
///   "devices": [
///     {
///       "device_id": "short_hopper_1",
///       "device_type": "hopper",
///       "daily_records": [
///         {
///           "date": "2026-01-20",
///           "start_time": "2026-01-20T00:00:00Z",
///           "end_time": "2026-01-20T23:59:59Z",
///           "gas_consumption": 0.0,           // m³ (仅SCR有)
///           "feeding_amount": 123.45,         // kg (仅料仓有)
///           "electricity_consumption": 500.5, // kWh
///           "runtime_hours": 18.5             // h
///         }
///       ]
///     }
///   ]
/// }
/// ```
void parseComprehensiveData(Map<String, dynamic> data) {
  final startTime = data['start_time'];
  final endTime = data['end_time'];
  final totalDevices = data['total_devices'];
  final devices = data['devices'] as List;
  
  print('时间范围: $startTime ~ $endTime');
  print('设备总数: $totalDevices');
  
  for (var device in devices) {
    final deviceId = device['device_id'];
    final deviceType = device['device_type'];
    final dailyRecords = device['daily_records'] as List;
    
    print('\n设备: $deviceId ($deviceType)');
    
    for (var record in dailyRecords) {
      final date = record['date'];
      final elec = record['electricity_consumption'];
      final runtime = record['runtime_hours'];
      final gas = record['gas_consumption'];
      final feeding = record['feeding_amount'];
      
      print('  $date: 电量=${elec}kWh, 运行=${runtime}h, 燃气=${gas}m³, 投料=${feeding}kg');
    }
  }
}

// ============================================================================
// 示例7: 完整使用流程
// ============================================================================

/// 完整的数据查询和处理流程
Future<void> completeDataExportExample() async {
  print('开始查询数据...');
  
  // 1. 查询最近7天的综合数据
  final data = await fetchComprehensiveData7Days();
  
  if (data != null) {
    print('✅ 查询成功');
    
    // 2. 解析数据
    parseComprehensiveData(data);
    
    // 3. 提取特定设备的数据
    final devices = data['devices'] as List;
    final hopper1 = devices.firstWhere(
      (d) => d['device_id'] == 'short_hopper_1',
      orElse: () => null,
    );
    
    if (hopper1 != null) {
      print('\n料仓1数据:');
      final records = hopper1['daily_records'] as List;
      for (var record in records) {
        print('  ${record['date']}: ${record['electricity_consumption']}kWh');
      }
    }
  } else {
    print('❌ 查询失败');
  }
}

// ============================================================================
// 使用建议
// ============================================================================

/*
1. 推荐使用综合导出接口（Api.buildComprehensiveUrl）
   - 一次性获取所有数据
   - 性能优化（使用预计算数据）
   - 数据完整

2. 超时设置
   - 所有导出接口使用 Api.exportTimeout (60秒)
   - 实时接口使用 Api.defaultTimeout (10秒)

3. days 参数说明
   - days=1: 今天0点到现在
   - days=2: 昨天0点-23:59 + 今天0点-现在
   - days=7: 最近7天（6个完整天 + 1个不完整天）
   - days=30: 最近30天（29个完整天 + 1个不完整天）

4. 性能说明
   - 后端已使用预计算数据（daily_summary）
   - 完整天使用预计算（快速）
   - 不完整天实时计算（稍慢）
   - 30天查询约8秒（优化前24秒）

5. 错误处理
   - 使用 try-catch 捕获异常
   - 检查 response.statusCode
   - 检查 data['success']
   - 设置合理的超时时间

6. 数据缓存（可选）
   - 可以在前端缓存查询结果
   - 避免频繁请求相同数据
   - 定期刷新缓存
*/


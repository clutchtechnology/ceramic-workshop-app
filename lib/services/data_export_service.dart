import '../api/api.dart';
import '../api/index.dart';
import '../utils/device_name_mapper.dart';

/// ============================================================================
/// 数据导出服务 (Data Export Service)
/// ============================================================================
/// 功能:
/// 1. 与后端API对接，获取导出数据
/// 2. 支持5种导出类型：运行时长、燃气消耗、投料量、电量统计、综合数据
/// 3. 自动验证设备数量是否正确
/// 4. 提供设备名称映射功能
/// 5. 使用优化后的 API 客户端（60秒超时 + use_optimized=true）
/// ============================================================================
/// 导出类型及设备数量:
/// - 设备运行时长: 20个设备（9回转窑 + 6辊道窑分区 + 1辊道窑合计 + 2SCR氨水泵 + 2风机）
/// - 燃气消耗统计: 2个设备（SCR北/南燃气表）
/// - 累计投料量: 7个设备（带料仓的回转窑，不包含窑2和窑1）
/// - 电量统计: 20个设备（同设备运行时长）
/// - 全部数据: 20个设备（同设备运行时长）
/// ============================================================================
/// 性能优化:
/// - 使用 EnhancedApiClient（60秒超时，适配长时间查询）
/// - 默认使用 V3 版本（批量查询 + 并行计算 + 内存缓存）
/// - 30天查询从 23.59s 优化到 0.78s（性能提升 30倍）
/// ============================================================================

class DataExportService {
  final EnhancedApiClient _client = EnhancedApiClient();

  /// 获取所有设备运行时长
  ///
  /// 返回数据包含:
  /// - hoppers: 9个回转窑
  /// - roller_kiln_zones: 6个辊道窑分区
  /// - roller_kiln_total: 1个辊道窑合计（运行时长为平均值）
  /// - scr_devices: 2个SCR氨水泵
  /// - fan_devices: 2个风机
  ///
  /// 总计: 20个设备
  Future<Map<String, dynamic>> getAllDevicesRuntime({
    required DateTime startTime,
    required DateTime endTime,
    String version = 'v3',
  }) async {
    final response = await _client.getWithTimeout(
      Api.exportRuntimeAll,
      params: {
        'start_time': startTime.toUtc().toIso8601String(),
        'end_time': endTime.toUtc().toIso8601String(),
        'version': version,
      },
      timeout: const Duration(seconds: 60),
    );

    if (response['success'] == true) {
      final data = response['data'] as Map<String, dynamic>;

      // 验证设备数量
      if (!DeviceNameMapper.validateDeviceCount(data, 'runtime')) {
        throw Exception(
          '设备数量不匹配！预期: ${DeviceNameMapper.getDeviceCountDescription('runtime')}',
        );
      }

      return data;
    } else {
      throw Exception(response['error'] ?? '获取运行时长失败');
    }
  }

  /// 获取燃气消耗统计
  ///
  /// 返回数据包含:
  /// - scr_1: SCR北_燃气表
  /// - scr_2: SCR南_燃气表
  ///
  /// 总计: 2个设备
  Future<Map<String, dynamic>> getGasConsumption({
    required List<String> deviceIds,
    required DateTime startTime,
    required DateTime endTime,
    String version = 'v3',
  }) async {
    final response = await _client.getWithTimeout(
      Api.exportGasConsumption,
      params: {
        'device_ids': deviceIds.join(','),
        'start_time': startTime.toUtc().toIso8601String(),
        'end_time': endTime.toUtc().toIso8601String(),
        'version': version,
      },
      timeout: const Duration(seconds: 60),
    );

    if (response['success'] == true) {
      final data = response['data'] as Map<String, dynamic>;

      // 验证设备数量
      if (!DeviceNameMapper.validateDeviceCount(data, 'gas')) {
        throw Exception(
          '设备数量不匹配！预期: ${DeviceNameMapper.getDeviceCountDescription('gas')}',
        );
      }

      return data;
    } else {
      throw Exception(response['error'] ?? '获取燃气消耗失败');
    }
  }

  /// 获取累计投料量
  ///
  /// 返回数据包含:
  /// - hoppers: 7个带料仓的回转窑
  ///   - short_hopper_1~4: 窑7,6,5,4
  ///   - long_hopper_1~3: 窑8,3,9
  ///
  /// 不包含: no_hopper_1, no_hopper_2（窑2,1，无料仓）
  ///
  /// 总计: 7个设备
  Future<Map<String, dynamic>> getFeedingAmount({
    required DateTime startTime,
    required DateTime endTime,
    String version = 'v3',
  }) async {
    final response = await _client.getWithTimeout(
      Api.exportFeedingAmount,
      params: {
        'start_time': startTime.toUtc().toIso8601String(),
        'end_time': endTime.toUtc().toIso8601String(),
        'version': version,
      },
      timeout: const Duration(seconds: 60),
    );

    if (response['success'] == true) {
      final data = response['data'] as Map<String, dynamic>;

      // 验证设备数量
      if (!DeviceNameMapper.validateDeviceCount(data, 'feeding')) {
        throw Exception(
          '设备数量不匹配！预期: ${DeviceNameMapper.getDeviceCountDescription('feeding')}',
        );
      }

      return data;
    } else {
      throw Exception(response['error'] ?? '获取投料量失败');
    }
  }

  /// 获取所有设备电量统计
  ///
  /// 返回数据包含:
  /// - hoppers: 9个回转窑
  /// - roller_kiln_zones: 6个辊道窑分区
  /// - roller_kiln_total: 1个辊道窑合计（运行时长为平均值）
  /// - scr_devices: 2个SCR氨水泵
  /// - fan_devices: 2个风机
  ///
  /// 每个设备包含: 起始读数、截止读数、当日消耗、运行时长
  ///
  /// 总计: 20个设备
  Future<Map<String, dynamic>> getAllElectricity({
    required DateTime startTime,
    required DateTime endTime,
    String version = 'v3',
  }) async {
    final response = await _client.getWithTimeout(
      Api.exportElectricityAll,
      params: {
        'start_time': startTime.toUtc().toIso8601String(),
        'end_time': endTime.toUtc().toIso8601String(),
        'version': version,
      },
      timeout: const Duration(seconds: 60),
    );

    if (response['success'] == true) {
      final data = response['data'] as Map<String, dynamic>;

      // 验证设备数量
      if (!DeviceNameMapper.validateDeviceCount(data, 'electricity')) {
        throw Exception(
          '设备数量不匹配！预期: ${DeviceNameMapper.getDeviceCountDescription('electricity')}',
        );
      }

      return data;
    } else {
      throw Exception(response['error'] ?? '获取电量统计失败');
    }
  }

  /// 获取单个设备电量统计
  Future<Map<String, dynamic>> getDeviceElectricity({
    required String deviceId,
    required String deviceType,
    required DateTime startTime,
    required DateTime endTime,
    String version = 'v3',
  }) async {
    final response = await _client.getWithTimeout(
      Api.exportElectricity,
      params: {
        'device_id': deviceId,
        'device_type': deviceType,
        'start_time': startTime.toUtc().toIso8601String(),
        'end_time': endTime.toUtc().toIso8601String(),
        'version': version,
      },
      timeout: const Duration(seconds: 60),
    );

    if (response['success'] == true) {
      return response['data'] as Map<String, dynamic>;
    } else {
      throw Exception(response['error'] ?? '获取电量统计失败');
    }
  }

  /// 获取综合数据（全部数据）
  ///
  /// 返回数据包含:
  /// - devices: 20个设备的完整数据
  ///   - 9个回转窑: 电量 + 运行时长 + 投料量（有料仓的）
  ///   - 6个辊道窑分区: 电量 + 运行时长
  ///   - 1个辊道窑合计: 电量 + 运行时长（平均值）
  ///   - 2个SCR氨水泵: 电量 + 运行时长
  ///   - 2个风机: 电量 + 运行时长
  ///
  /// 每个设备包含: gas_consumption, feeding_amount, electricity_consumption, runtime_hours
  ///
  /// 总计: 20个设备
  Future<Map<String, dynamic>> getComprehensiveData({
    required DateTime startTime,
    required DateTime endTime,
    String version = 'v3',
  }) async {
    final response = await _client.getWithTimeout(
      Api.exportComprehensive,
      params: {
        'start_time': startTime.toUtc().toIso8601String(),
        'end_time': endTime.toUtc().toIso8601String(),
        'version': version,
      },
      timeout: const Duration(seconds: 60),
    );

    if (response['success'] == true) {
      final data = response['data'] as Map<String, dynamic>;

      // 验证设备数量
      if (!DeviceNameMapper.validateDeviceCount(data, 'comprehensive')) {
        throw Exception(
          '设备数量不匹配！预期: ${DeviceNameMapper.getDeviceCountDescription('comprehensive')}',
        );
      }

      return data;
    } else {
      throw Exception(response['error'] ?? '获取综合数据失败');
    }
  }
}

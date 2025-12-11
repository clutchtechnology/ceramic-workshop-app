import '../api/index.dart';
import '../api/api.dart';
import '../models/hopper_model.dart';

class HopperService {
  final ApiClient _client = ApiClient();

  // 获取所有料仓列表（可选类型筛选）
  Future<List<HopperDevice>> getHopperList({String? hopperType}) async {
    try {
      final response = await _client.get(
        Api.hopperList,
        params: hopperType != null ? {'hopper_type': hopperType} : null,
      );

      if (response['success'] == true) {
        final data = response['data'];
        if (data is List) {
          return data
              .whereType<Map<String, dynamic>>()
              .map(HopperDevice.fromJson)
              .toList();
        }
      }
      return [];
    } catch (e) {
      print('Error fetching hopper list: $e');
      return [];
    }
  }

  // 批量获取所有料仓实时数据 (新增)
  Future<Map<String, HopperData>> getHopperBatchData(
      {String? hopperType}) async {
    try {
      final response = await _client.get(
        Api.hopperRealtimeBatch,
        params: hopperType != null ? {'hopper_type': hopperType} : null,
      );

      print('🔍 料仓批量接口返回: $response');

      if (response['success'] == true) {
        final data = response['data'];
        if (data != null && data['devices'] is List) {
          print('📦 接收到 ${data['devices'].length} 个料仓数据');
          final Map<String, HopperData> result = {};
          for (var deviceData in data['devices']) {
            final hopperData = HopperData.fromJson(deviceData);
            result[hopperData.deviceId] = hopperData;
            print('  ✓ ${hopperData.deviceId}');
          }
          print('📊 最终解析出 ${result.length} 个料仓');
          return result;
        }
      }
      print('⚠️  批量接口返回数据格式错误');
      return {};
    } catch (e) {
      print('❌ Error fetching hopper batch data: $e');
      return {};
    }
  }

  // 获取单个料仓实时数据
  Future<HopperData?> getHopperData(String deviceId) async {
    try {
      final response = await _client.get(Api.hopperRealtime(deviceId));
      if (response['success'] == true && response['data'] != null) {
        return HopperData.fromJson(response['data']);
      }
      return null;
    } catch (e) {
      print('Error fetching hopper data for $deviceId: $e');
      return null;
    }
  }
}

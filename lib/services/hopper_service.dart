import '../api/index.dart';
import '../api/api.dart';
import '../models/hopper_model.dart';
import '../utils/app_logger.dart';

class HopperService {
  final ApiClient _client = ApiClient();

  // 批量获取所有料仓实时数据
  Future<Map<String, HopperData>> getHopperBatchData(
      {String? hopperType}) async {
    try {
      final response = await _client.get(
        Api.hopperRealtimeBatch,
        params: hopperType != null ? {'hopper_type': hopperType} : null,
      );

      if (response['success'] == true) {
        final data = response['data'];
        if (data != null && data['devices'] is List) {
          final Map<String, HopperData> result = {};
          for (var deviceData in data['devices']) {
            final hopperData = HopperData.fromJson(deviceData);
            result[hopperData.deviceId] = hopperData;
          }
          return result;
        }
      }
      return {};
    } catch (e) {
      logger.error('料仓批量数据获取失败', e);
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
      logger.error('料仓数据获取失败: $deviceId', e);
      return null;
    }
  }
}

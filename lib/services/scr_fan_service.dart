import '../api/index.dart';
import '../api/api.dart';
import '../models/scr_fan_model.dart';

class ScrFanService {
  final ApiClient _client = ApiClient();

  /// 批量获取SCR+风机实时数据
  Future<ScrFanBatchData?> getScrFanBatchData() async {
    try {
      final response = await _client.get(Api.scrFanRealtimeBatch);

      if (response['success'] == true && response['data'] != null) {
        return ScrFanBatchData.fromJson(response['data']);
      }
      return null;
    } catch (e) {
      print('Error fetching SCR+Fan batch data: $e');
      return null;
    }
  }
}

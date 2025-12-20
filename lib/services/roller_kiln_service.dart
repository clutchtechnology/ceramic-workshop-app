import '../api/index.dart';
import '../api/api.dart';
import '../models/roller_kiln_model.dart';
import 'package:flutter/foundation.dart';

class RollerKilnService {
  final ApiClient _client = ApiClient();

  /// 获取辊道窑格式化实时数据
  Future<RollerKilnData?> getRollerKilnRealtimeFormatted() async {
    try {
      final response = await _client.get(Api.rollerRealtimeFormatted);

      if (response['success'] == true && response['data'] != null) {
        return RollerKilnData.fromJson(response['data']);
      }
      return null;
    } catch (e) {
      if (kDebugMode) debugPrint('Error fetching roller kiln data: $e');
      return null;
    }
  }
}

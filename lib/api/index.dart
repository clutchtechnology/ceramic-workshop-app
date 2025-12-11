// 网络请求统一入口
// 用于处理全局的网络请求配置、拦截器、基础请求方法等

import 'package:http/http.dart' as http;
import 'dart:convert';
import 'api.dart';

class ApiClient {
  static final ApiClient _instance = ApiClient._internal();
  factory ApiClient() => _instance;
  ApiClient._internal();

  final String baseUrl = Api.baseUrl;

  Future<dynamic> get(String path, {Map<String, String>? params}) async {
    final uri = Uri.parse('$baseUrl$path').replace(queryParameters: params);
    final response = await http.get(uri);
    return _processResponse(response);
  }

  Future<dynamic> post(String path,
      {Map<String, String>? params, dynamic body}) async {
    final uri = Uri.parse('$baseUrl$path').replace(queryParameters: params);
    final response = await http.post(uri,
        body: jsonEncode(body), headers: {'Content-Type': 'application/json'});
    return _processResponse(response);
  }

  dynamic _processResponse(http.Response response) {
    if (response.statusCode >= 200 && response.statusCode < 300) {
      return jsonDecode(response.body);
    } else {
      throw Exception('网络请求错误: ${response.statusCode}');
    }
  }
}

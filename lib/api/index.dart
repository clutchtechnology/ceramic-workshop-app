// 网络请求统一入口
// 用于处理全局的网络请求配置、拦截器、基础请求方法等

import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:async';
import 'api.dart';
import '../utils/app_logger.dart';

class ApiClient {
  static final ApiClient _instance = ApiClient._internal();
  factory ApiClient() => _instance;
  ApiClient._internal();

  final String baseUrl = Api.baseUrl;

  // 🔧 修复1: 复用 HTTP Client，避免内存泄漏
  static final http.Client _httpClient = http.Client();

  // 🔧 修复2: 请求超时配置
  static const Duration _timeout = Duration(seconds: 10);

  // 连续失败计数（用于日志记录）
  int _consecutiveFailures = 0;

  Future<dynamic> get(String path, {Map<String, String>? params}) async {
    final uri = Uri.parse('$baseUrl$path').replace(queryParameters: params);

    try {
      // 🔧 修复3: 添加超时控制
      final response = await _httpClient.get(uri).timeout(_timeout);
      _consecutiveFailures = 0; // 成功后重置失败计数
      return _processResponse(response, uri.toString());
    } on TimeoutException {
      _handleError('GET', uri.toString(),
          'Request timeout after ${_timeout.inSeconds}s');
      rethrow;
    } on http.ClientException catch (e) {
      _handleError('GET', uri.toString(), 'Client error: $e');
      rethrow;
    } catch (e) {
      _handleError('GET', uri.toString(), e.toString());
      rethrow;
    }
  }

  Future<dynamic> post(String path,
      {Map<String, String>? params, dynamic body}) async {
    final uri = Uri.parse('$baseUrl$path').replace(queryParameters: params);

    try {
      final response = await _httpClient.post(
        uri,
        body: jsonEncode(body),
        headers: {'Content-Type': 'application/json'},
      ).timeout(_timeout);
      _consecutiveFailures = 0;
      return _processResponse(response, uri.toString());
    } on TimeoutException {
      _handleError('POST', uri.toString(),
          'Request timeout after ${_timeout.inSeconds}s');
      rethrow;
    } on http.ClientException catch (e) {
      _handleError('POST', uri.toString(), 'Client error: $e');
      rethrow;
    } catch (e) {
      _handleError('POST', uri.toString(), e.toString());
      rethrow;
    }
  }

  Future<dynamic> put(String path,
      {Map<String, String>? params, dynamic body}) async {
    final uri = Uri.parse('$baseUrl$path').replace(queryParameters: params);

    try {
      final response = await _httpClient.put(
        uri,
        body: jsonEncode(body),
        headers: {'Content-Type': 'application/json'},
      ).timeout(_timeout);
      _consecutiveFailures = 0;
      return _processResponse(response, uri.toString());
    } on TimeoutException {
      _handleError('PUT', uri.toString(),
          'Request timeout after ${_timeout.inSeconds}s');
      rethrow;
    } on http.ClientException catch (e) {
      _handleError('PUT', uri.toString(), 'Client error: $e');
      rethrow;
    } catch (e) {
      _handleError('PUT', uri.toString(), e.toString());
      rethrow;
    }
  }

  dynamic _processResponse(http.Response response, String url) {
    if (response.statusCode >= 200 && response.statusCode < 300) {
      // 🔧 记录成功的网络请求（仅在连续失败后恢复时记录）
      if (_consecutiveFailures > 0) {
        logger.network('RECOVERED', url, statusCode: response.statusCode);
      }
      // 🔧 安全的 JSON 解析，避免解析失败导致崩溃
      try {
        return jsonDecode(response.body);
      } catch (e) {
        logger.error('JSON 解析失败', e);
        return {'success': false, 'error': 'JSON 解析失败', 'data': null};
      }
    } else {
      _handleError('RESPONSE', url, 'HTTP ${response.statusCode}');
      throw Exception('网络请求错误: ${response.statusCode}');
    }
  }

  void _handleError(String method, String url, String error) {
    _consecutiveFailures++;

    // 🔧 记录网络错误到日志
    logger.network(method, url, error: error);

    // 连续失败5次以上，记录警告
    if (_consecutiveFailures >= 5 && _consecutiveFailures % 5 == 0) {
      logger.warning('网络连续失败 $_consecutiveFailures 次，请检查后端服务');
    }
  }

  /// 关闭 HTTP Client（应用退出时调用）
  static void dispose() {
    _httpClient.close();
  }
}

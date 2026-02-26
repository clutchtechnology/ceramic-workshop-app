// 网络请求统一入口

import 'package:http/http.dart' as http;
import 'package:http/io_client.dart';
import 'dart:convert';
import 'dart:async';
import 'dart:io';
import 'api.dart';
import '../utils/app_logger.dart';

class ApiClient {
  static final ApiClient _instance = ApiClient._internal();
  factory ApiClient() => _instance;
  ApiClient._internal();

  final String baseUrl = Api.baseUrl;

  // HTTP Client 配置
  static http.Client _httpClient = _createClient();
  static DateTime _lastRefresh = DateTime.now();
  static const Duration _refreshInterval = Duration(minutes: 10);
  static bool _isDisposed = false;

  static const Duration _timeout = Duration(seconds: 5);
  static const Duration _connectionTimeout = Duration(seconds: 3);

  static int _consecutiveFailures = 0;

  /// 创建带连接超时的 HTTP Client
  static http.Client _createClient() {
    final httpClient = HttpClient()
      ..connectionTimeout = _connectionTimeout
      ..idleTimeout = const Duration(seconds: 30);
    return IOClient(httpClient);
  }

  /// 获取 HTTP Client（自动刷新过期连接）
  static http.Client get _client {
    if (_isDisposed) {
      _httpClient = _createClient();
      _isDisposed = false;
      _lastRefresh = DateTime.now();
      _consecutiveFailures = 0;
    } else if (DateTime.now().difference(_lastRefresh) > _refreshInterval) {
      logger.info('HTTP Client 定期刷新（防止僵尸连接）');
      _httpClient.close();
      _httpClient = _createClient();
      _lastRefresh = DateTime.now();
      _consecutiveFailures = 0;
    } else if (_consecutiveFailures >= 3) {
      // 连续失败时刷新 Client
      logger.warning('连续失败 $_consecutiveFailures 次，强制刷新 HTTP Client');
      _httpClient.close();
      _httpClient = _createClient();
      _lastRefresh = DateTime.now();
      _consecutiveFailures = 0;
    }
    return _httpClient;
  }

  Future<dynamic> get(String path, {Map<String, String>? params}) async {
    final uri = Uri.parse('$baseUrl$path').replace(queryParameters: params);

    try {
      final response = await _client.get(uri).timeout(_timeout);
      _consecutiveFailures = 0;
      return _processResponse(response, uri.toString());
    } on TimeoutException {
      _handleError('GET', uri.toString(),
          'Request timeout after ${_timeout.inSeconds}s');
      rethrow;
    } on SocketException catch (e) {
      _handleError('GET', uri.toString(), 'Socket error: $e');
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
      final response = await _client.post(
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
    } on SocketException catch (e) {
      _handleError('POST', uri.toString(), 'Socket error: $e');
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
      final response = await _client.put(
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
    } on SocketException catch (e) {
      _handleError('PUT', uri.toString(), 'Socket error: $e');
      rethrow;
    } on http.ClientException catch (e) {
      _handleError('PUT', uri.toString(), 'Client error: $e');
      rethrow;
    } catch (e) {
      _handleError('PUT', uri.toString(), e.toString());
      rethrow;
    }
  }

  Future<dynamic> delete(String path, {Map<String, String>? params}) async {
    final uri = Uri.parse('$baseUrl$path').replace(queryParameters: params);

    try {
      final response = await _client.delete(uri).timeout(_timeout);
      _consecutiveFailures = 0;
      return _processResponse(response, uri.toString());
    } on TimeoutException {
      _handleError('DELETE', uri.toString(),
          'Request timeout after ${_timeout.inSeconds}s');
      rethrow;
    } on SocketException catch (e) {
      _handleError('DELETE', uri.toString(), 'Socket error: $e');
      rethrow;
    } on http.ClientException catch (e) {
      _handleError('DELETE', uri.toString(), 'Client error: $e');
      rethrow;
    } catch (e) {
      _handleError('DELETE', uri.toString(), e.toString());
      rethrow;
    }
  }

  dynamic _processResponse(http.Response response, String url) {
    if (response.statusCode >= 200 && response.statusCode < 300) {
      if (_consecutiveFailures > 0) {
        logger.network('RECOVERED', url, statusCode: response.statusCode);
      }
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

    logger.network(method, url, error: error);

    if (_consecutiveFailures >= 5 && _consecutiveFailures % 5 == 0) {
      logger.warning('网络连续失败 $_consecutiveFailures 次，请检查后端服务');
    }
  }

  /// 关闭 HTTP Client（应用退出时调用）
  static void dispose() {
    if (!_isDisposed) {
      _httpClient.close();
      _isDisposed = true;
      logger.info('HTTP Client 已关闭');
    }
  }
}

// 增强版 API 客户端（支持自定义超时）

class EnhancedApiClient {
  static final EnhancedApiClient _instance = EnhancedApiClient._internal();
  factory EnhancedApiClient() => _instance;
  EnhancedApiClient._internal();

  final String baseUrl = Api.baseUrl;

  /// GET 请求（支持自定义超时）
  Future<dynamic> getWithTimeout(
    String path, {
    Map<String, String>? params,
    Duration timeout = const Duration(seconds: 60),
  }) async {
    final uri = Uri.parse('$baseUrl$path').replace(queryParameters: params);

    try {
      final response = await ApiClient._client.get(uri).timeout(timeout);
      ApiClient._consecutiveFailures = 0;
      return _processResponse(response, uri.toString());
    } on TimeoutException {
      _handleError(
          'GET', uri.toString(), 'Request timeout after ${timeout.inSeconds}s');
      rethrow;
    } on SocketException catch (e) {
      _handleError('GET', uri.toString(), 'Socket error: $e');
      rethrow;
    } on http.ClientException catch (e) {
      _handleError('GET', uri.toString(), 'Client error: $e');
      rethrow;
    } catch (e) {
      _handleError('GET', uri.toString(), e.toString());
      rethrow;
    }
  }

  /// POST 请求（支持自定义超时）
  Future<dynamic> postWithTimeout(
    String path, {
    Map<String, String>? params,
    dynamic body,
    Duration timeout = const Duration(seconds: 60),
  }) async {
    final uri = Uri.parse('$baseUrl$path').replace(queryParameters: params);

    try {
      final response = await ApiClient._client.post(
        uri,
        body: jsonEncode(body),
        headers: {'Content-Type': 'application/json'},
      ).timeout(timeout);
      ApiClient._consecutiveFailures = 0;
      return _processResponse(response, uri.toString());
    } on TimeoutException {
      _handleError('POST', uri.toString(),
          'Request timeout after ${timeout.inSeconds}s');
      rethrow;
    } on SocketException catch (e) {
      _handleError('POST', uri.toString(), 'Socket error: $e');
      rethrow;
    } on http.ClientException catch (e) {
      _handleError('POST', uri.toString(), 'Client error: $e');
      rethrow;
    } catch (e) {
      _handleError('POST', uri.toString(), e.toString());
      rethrow;
    }
  }

  dynamic _processResponse(http.Response response, String url) {
    if (response.statusCode >= 200 && response.statusCode < 300) {
      if (ApiClient._consecutiveFailures > 0) {
        logger.network('RECOVERED', url, statusCode: response.statusCode);
      }
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
    ApiClient._consecutiveFailures++;
    logger.network(method, url, error: error);

    if (ApiClient._consecutiveFailures >= 5 &&
        ApiClient._consecutiveFailures % 5 == 0) {
      logger.warning('网络连续失败 ${ApiClient._consecutiveFailures} 次，请检查后端服务');
    }
  }
}

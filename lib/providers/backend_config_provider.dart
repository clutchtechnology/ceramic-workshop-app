import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../api/api.dart';
import '../api/index.dart';

/// 后端配置 Provider
/// 用于持久化存储服务器配置和PLC配置
///
/// 存储键值:
/// - 服务器配置: backend_server_config
/// - PLC配置: backend_plc_config

/// 服务器配置数据模型
class ServerConfigData {
  final String host;
  final int port;
  final bool debug;

  ServerConfigData({
    required this.host,
    required this.port,
    required this.debug,
  });

  factory ServerConfigData.fromJson(Map<String, dynamic> json) {
    return ServerConfigData(
      host: json['host'] as String? ?? '0.0.0.0',
      port: json['port'] as int? ?? 8080,
      debug: json['debug'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toJson() => {
        'host': host,
        'port': port,
        'debug': debug,
      };

  ServerConfigData copyWith({
    String? host,
    int? port,
    bool? debug,
  }) {
    return ServerConfigData(
      host: host ?? this.host,
      port: port ?? this.port,
      debug: debug ?? this.debug,
    );
  }
}

/// PLC配置数据模型
class PlcConfigData {
  String ipAddress;
  int rack;
  int slot;
  int timeoutMs;
  int pollInterval;

  PlcConfigData({
    required this.ipAddress,
    required this.rack,
    required this.slot,
    required this.timeoutMs,
    required this.pollInterval,
  });

  factory PlcConfigData.fromJson(Map<String, dynamic> json) {
    return PlcConfigData(
      ipAddress: json['ip_address'] as String? ?? '192.168.50.223',
      rack: json['rack'] as int? ?? 0,
      slot: json['slot'] as int? ?? 1,
      timeoutMs: json['timeout_ms'] as int? ?? 5000,
      pollInterval: json['poll_interval'] as int? ?? 5,
    );
  }

  Map<String, dynamic> toJson() => {
        'ip_address': ipAddress,
        'rack': rack,
        'slot': slot,
        'timeout_ms': timeoutMs,
        'poll_interval': pollInterval,
      };

  /// 用于PUT请求的JSON（只包含可修改字段）
  Map<String, dynamic> toUpdateJson() => {
        'ip_address': ipAddress,
        'poll_interval': pollInterval,
      };

  PlcConfigData copyWith({
    String? ipAddress,
    int? rack,
    int? slot,
    int? timeoutMs,
    int? pollInterval,
  }) {
    return PlcConfigData(
      ipAddress: ipAddress ?? this.ipAddress,
      rack: rack ?? this.rack,
      slot: slot ?? this.slot,
      timeoutMs: timeoutMs ?? this.timeoutMs,
      pollInterval: pollInterval ?? this.pollInterval,
    );
  }
}

/// 后端配置 Provider
/// 负责与后端API交互并持久化配置
class BackendConfigProvider extends ChangeNotifier {
  static const String _storageKey = 'backend_config_v1';
  static const String _serverConfigKey = 'backend_server_config';
  static const String _plcConfigKey = 'backend_plc_config';

  bool _isLoaded = false;
  bool get isLoaded => _isLoaded;

  ServerConfigData? _serverConfig;
  PlcConfigData? _plcConfig;
  bool _isLoading = false;
  String? _error;

  ServerConfigData? get serverConfig => _serverConfig;
  PlcConfigData? get plcConfig => _plcConfig;
  bool get isLoading => _isLoading;
  String? get error => _error;

  /// 初始化：先从本地加载，再从后端刷新
  Future<void> initialize() async {
    await _loadFromLocal();
    await refreshFromBackend();
    _isLoaded = true;
    notifyListeners();
  }

  /// 仅从本地加载配置（不连接后端）
  Future<void> loadConfig() async {
    await _loadFromLocal();
    _isLoaded = true;
    notifyListeners();
  }

  /// 从本地存储加载配置
  Future<void> _loadFromLocal() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      // 加载服务器配置
      final serverJson = prefs.getString(_serverConfigKey);
      if (serverJson != null) {
        _serverConfig = ServerConfigData.fromJson(jsonDecode(serverJson));
      }

      // 加载PLC配置
      final plcJson = prefs.getString(_plcConfigKey);
      if (plcJson != null) {
        _plcConfig = PlcConfigData.fromJson(jsonDecode(plcJson));
      }

      notifyListeners();
    } catch (e) {
      debugPrint('从本地加载配置失败: $e');
    }
  }

  /// 保存配置到本地存储
  Future<bool> _saveToLocal() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      if (_serverConfig != null) {
        await prefs.setString(
            _serverConfigKey, jsonEncode(_serverConfig!.toJson()));
      }

      if (_plcConfig != null) {
        await prefs.setString(_plcConfigKey, jsonEncode(_plcConfig!.toJson()));
      }
      return true;
    } catch (e) {
      debugPrint('保存配置到本地失败: $e');
      return false;
    }
  }

  /// 从后端刷新配置
  Future<void> refreshFromBackend() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    final client = ApiClient();

    try {
      // 获取服务器配置
      final serverData = await client.get(Api.configServer);
      if (serverData['success'] == true && serverData['data'] != null) {
        _serverConfig = ServerConfigData.fromJson(serverData['data']);
      }

      // 获取PLC配置
      final plcData = await client.get(Api.configPlc);
      if (plcData['success'] == true && plcData['data'] != null) {
        _plcConfig = PlcConfigData.fromJson(plcData['data']);
      }

      // 保存到本地
      await _saveToLocal();

      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _error = '无法连接到后端服务: $e';
      _isLoading = false;
      notifyListeners();
    }
  }

  /// 更新PLC配置
  Future<bool> updatePlcConfig(PlcConfigData newConfig) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    final client = ApiClient();

    try {
      final data = await client.put(
        Api.configPlc,
        body: newConfig.toUpdateJson(),
      );

      if (data['success'] == true) {
        // 更新本地配置
        _plcConfig = newConfig;
        await _saveToLocal();

        // 从后端刷新确认
        await refreshFromBackend();
        return true;
      } else {
        _error = data['error'] ?? '更新失败';
      }

      _isLoading = false;
      notifyListeners();
      return false;
    } catch (e) {
      _error = '网络错误: $e';
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  /// 测试PLC连接
  Future<Map<String, dynamic>> testPlcConnection() async {
    final client = ApiClient();

    try {
      final data = await client.post(Api.configPlcTest);

      return {
        'success': data['success'] == true,
        'message': data['data']?['message'] ?? data['error'] ?? '未知结果',
        'connected': data['data']?['connected'] ?? false,
      };
    } catch (e) {
      return {
        'success': false,
        'message': '网络错误: $e',
        'connected': false,
      };
    }
  }

  /// 保存配置（手动触发保存）
  Future<bool> saveConfig() async {
    return await _saveToLocal();
  }

  /// 重置为默认配置
  void resetToDefault() {
    _serverConfig = ServerConfigData(
      host: '0.0.0.0',
      port: 8080,
      debug: false,
    );
    _plcConfig = PlcConfigData(
      ipAddress: '192.168.50.223',
      rack: 0,
      slot: 1,
      timeoutMs: 5000,
      pollInterval: 5,
    );
    notifyListeners();
  }

  /// 清除错误
  void clearError() {
    _error = null;
    notifyListeners();
  }
}

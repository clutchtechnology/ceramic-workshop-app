/// 传感器健康状态数据模型
/// 用于检测传感器是否在最近N分钟内有数据

/// 单个模块的健康状态
class ModuleHealth {
  final String moduleType;
  final String name;
  final bool healthy;
  final DateTime? lastTime;

  ModuleHealth({
    required this.moduleType,
    required this.name,
    required this.healthy,
    this.lastTime,
  });

  factory ModuleHealth.fromJson(String moduleType, Map<String, dynamic> json) {
    return ModuleHealth(
      moduleType: moduleType,
      name: json['name'] ?? moduleType,
      healthy: json['healthy'] ?? false,
      lastTime: json['last_time'] != null
          ? DateTime.parse(json['last_time']).toLocal()
          : null,
    );
  }
}

/// 单个设备的健康状态
class DeviceHealth {
  final String deviceId;
  final String name;
  final bool healthy;
  final DateTime? lastSeen;
  final Map<String, ModuleHealth> modules;

  DeviceHealth({
    required this.deviceId,
    required this.name,
    required this.healthy,
    this.lastSeen,
    required this.modules,
  });

  factory DeviceHealth.fromJson(Map<String, dynamic> json) {
    final modulesJson = json['modules'] as Map<String, dynamic>? ?? {};
    final modules = <String, ModuleHealth>{};

    modulesJson.forEach((key, value) {
      modules[key] = ModuleHealth.fromJson(key, value);
    });

    return DeviceHealth(
      deviceId: json['device_id'] ?? '',
      name: json['name'] ?? '',
      healthy: json['healthy'] ?? false,
      lastSeen: json['last_seen'] != null
          ? DateTime.parse(json['last_seen']).toLocal()
          : null,
      modules: modules,
    );
  }

  /// 获取异常模块列表
  List<ModuleHealth> get unhealthyModules =>
      modules.values.where((m) => !m.healthy).toList();

  /// 获取正常模块列表
  List<ModuleHealth> get healthyModules =>
      modules.values.where((m) => m.healthy).toList();
}

/// 健康状态汇总
class HealthSummary {
  final int total;
  final int healthy;
  final int unhealthy;

  HealthSummary({
    required this.total,
    required this.healthy,
    required this.unhealthy,
  });

  factory HealthSummary.fromJson(Map<String, dynamic> json) {
    return HealthSummary(
      total: json['total'] ?? 0,
      healthy: json['healthy'] ?? 0,
      unhealthy: json['unhealthy'] ?? 0,
    );
  }

  double get healthyRate => total > 0 ? healthy / total : 0;
}

/// 传感器健康检测响应
class SensorHealthResponse {
  final int checkRangeMinutes;
  final DateTime checkTime;
  final HealthSummary summary;
  final List<DeviceHealth> devices;

  SensorHealthResponse({
    required this.checkRangeMinutes,
    required this.checkTime,
    required this.summary,
    required this.devices,
  });

  factory SensorHealthResponse.fromJson(Map<String, dynamic> json) {
    final devicesJson = json['devices'] as List<dynamic>? ?? [];

    return SensorHealthResponse(
      checkRangeMinutes: json['check_range_minutes'] ?? 30,
      checkTime: json['check_time'] != null
          ? DateTime.parse(json['check_time']).toLocal()
          : DateTime.now(),
      summary: HealthSummary.fromJson(json['summary'] ?? {}),
      devices: devicesJson.map((d) => DeviceHealth.fromJson(d)).toList(),
    );
  }

  /// 获取异常设备列表
  List<DeviceHealth> get unhealthyDevices =>
      devices.where((d) => !d.healthy).toList();

  /// 按设备类型分组
  Map<String, List<DeviceHealth>> get devicesByType {
    final result = <String, List<DeviceHealth>>{
      '回转窑': [],
      '辊道窑': [],
      'SCR设备': [],
      '风机': [],
    };

    for (final device in devices) {
      if (device.deviceId.contains('hopper')) {
        result['回转窑']!.add(device);
      } else if (device.deviceId.contains('roller')) {
        result['辊道窑']!.add(device);
      } else if (device.deviceId.contains('scr')) {
        result['SCR设备']!.add(device);
      } else if (device.deviceId.contains('fan')) {
        result['风机']!.add(device);
      }
    }

    return result;
  }
}

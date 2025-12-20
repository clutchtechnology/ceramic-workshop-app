/// 辊道窑数据模型
class RollerKilnData {
  final String deviceId;
  final String? timestamp;
  final List<RollerKilnZone> zones;
  final RollerKilnMeter mainMeter;

  RollerKilnData({
    required this.deviceId,
    this.timestamp,
    required this.zones,
    required this.mainMeter,
  });

  factory RollerKilnData.fromJson(Map<String, dynamic> json) {
    final zonesData = json['zones'] as List? ?? [];
    final mainMeterData = json['main_meter'] as Map<String, dynamic>? ?? {};

    return RollerKilnData(
      deviceId: json['device_id'] ?? '',
      timestamp: json['timestamp'],
      zones: zonesData.map((z) => RollerKilnZone.fromJson(z)).toList(),
      mainMeter: RollerKilnMeter.fromJson(mainMeterData),
    );
  }
}

/// 辊道窑温区数据 (精简版 - 只保留4个电表字段)
class RollerKilnZone {
  final String zoneId;
  final String zoneName;
  final double temperature;
  final double power; // 总功率 Pt
  final double energy; // 总能耗 ImpEp
  final double voltage; // A相电压 Ua_0
  final double current; // A相电流 I_0

  RollerKilnZone({
    required this.zoneId,
    required this.zoneName,
    required this.temperature,
    required this.power,
    required this.energy,
    required this.voltage,
    required this.current,
  });

  factory RollerKilnZone.fromJson(Map<String, dynamic> json) {
    return RollerKilnZone(
      zoneId: json['zone_id'] ?? '',
      zoneName: json['zone_name'] ?? '',
      temperature: (json['temperature'] as num?)?.toDouble() ?? 0.0,
      power: (json['power'] as num?)?.toDouble() ?? 0.0,
      energy: (json['energy'] as num?)?.toDouble() ?? 0.0,
      voltage: (json['voltage'] as num?)?.toDouble() ?? 0.0,
      current: (json['current'] as num?)?.toDouble() ?? 0.0,
    );
  }
}

/// 辊道窑主电表数据 (精简版 - 只保留4个字段)
class RollerKilnMeter {
  final double power; // 总功率 Pt
  final double energy; // 总能耗 ImpEp
  final double voltage; // A相电压 Ua_0
  final double current; // A相电流 I_0

  RollerKilnMeter({
    required this.power,
    required this.energy,
    required this.voltage,
    required this.current,
  });

  factory RollerKilnMeter.fromJson(Map<String, dynamic> json) {
    return RollerKilnMeter(
      power: (json['power'] as num?)?.toDouble() ?? 0.0,
      energy: (json['energy'] as num?)?.toDouble() ?? 0.0,
      voltage: (json['voltage'] as num?)?.toDouble() ?? 0.0,
      current: (json['current'] as num?)?.toDouble() ?? 0.0,
    );
  }
}

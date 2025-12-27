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

/// 辊道窑温区数据 (支持三相电流)
class RollerKilnZone {
  final String zoneId;
  final String zoneName;
  final double temperature;
  final double power; // 总功率 Pt
  final double energy; // 总能耗 ImpEp
  final double voltage; // A相电压 Ua_0
  final double currentA; // A相电流 I_0
  final double currentB; // B相电流 I_1
  final double currentC; // C相电流 I_2

  RollerKilnZone({
    required this.zoneId,
    required this.zoneName,
    required this.temperature,
    required this.power,
    required this.energy,
    required this.voltage,
    required this.currentA,
    required this.currentB,
    required this.currentC,
  });

  factory RollerKilnZone.fromJson(Map<String, dynamic> json) {
    return RollerKilnZone(
      zoneId: json['zone_id'] ?? '',
      zoneName: json['zone_name'] ?? '',
      temperature: (json['temperature'] as num?)?.toDouble() ?? 0.0,
      power: (json['power'] as num?)?.toDouble() ?? 0.0,
      energy: (json['energy'] as num?)?.toDouble() ?? 0.0,
      voltage: (json['voltage'] as num?)?.toDouble() ?? 0.0,
      currentA: (json['current_a'] as num?)?.toDouble() ?? 0.0,
      currentB: (json['current_b'] as num?)?.toDouble() ?? 0.0,
      currentC: (json['current_c'] as num?)?.toDouble() ?? 0.0,
    );
  }
}

/// 辊道窑主电表数据 (支持三相电流)
class RollerKilnMeter {
  final double power; // 总功率 Pt
  final double energy; // 总能耗 ImpEp
  final double voltage; // A相电压 Ua_0
  final double currentA; // A相电流 I_0
  final double currentB; // B相电流 I_1
  final double currentC; // C相电流 I_2

  RollerKilnMeter({
    required this.power,
    required this.energy,
    required this.voltage,
    required this.currentA,
    required this.currentB,
    required this.currentC,
  });

  factory RollerKilnMeter.fromJson(Map<String, dynamic> json) {
    return RollerKilnMeter(
      power: (json['power'] as num?)?.toDouble() ?? 0.0,
      energy: (json['energy'] as num?)?.toDouble() ?? 0.0,
      voltage: (json['voltage'] as num?)?.toDouble() ?? 0.0,
      currentA: (json['current_a'] as num?)?.toDouble() ?? 0.0,
      currentB: (json['current_b'] as num?)?.toDouble() ?? 0.0,
      currentC: (json['current_c'] as num?)?.toDouble() ?? 0.0,
    );
  }
}

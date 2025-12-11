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

/// 辊道窑温区数据
class RollerKilnZone {
  final String zoneId;
  final String zoneName;
  final double temperature;
  final double power;
  final double energy;
  final Map<String, double> voltage;
  final Map<String, double> current;

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
    final voltageData = json['voltage'] as Map<String, dynamic>? ?? {};
    final currentData = json['current'] as Map<String, dynamic>? ?? {};

    return RollerKilnZone(
      zoneId: json['zone_id'] ?? '',
      zoneName: json['zone_name'] ?? '',
      temperature: (json['temperature'] as num?)?.toDouble() ?? 0.0,
      power: (json['power'] as num?)?.toDouble() ?? 0.0,
      energy: (json['energy'] as num?)?.toDouble() ?? 0.0,
      voltage: {
        'Ua_0': (voltageData['Ua_0'] as num?)?.toDouble() ?? 0.0,
        'Ua_1': (voltageData['Ua_1'] as num?)?.toDouble() ?? 0.0,
        'Ua_2': (voltageData['Ua_2'] as num?)?.toDouble() ?? 0.0,
      },
      current: {
        'I_0': (currentData['I_0'] as num?)?.toDouble() ?? 0.0,
        'I_1': (currentData['I_1'] as num?)?.toDouble() ?? 0.0,
        'I_2': (currentData['I_2'] as num?)?.toDouble() ?? 0.0,
      },
    );
  }
}

/// 辊道窑主电表数据
class RollerKilnMeter {
  final double power;
  final double energy;
  final Map<String, double> voltage;
  final Map<String, double> current;

  RollerKilnMeter({
    required this.power,
    required this.energy,
    required this.voltage,
    required this.current,
  });

  factory RollerKilnMeter.fromJson(Map<String, dynamic> json) {
    final voltageData = json['voltage'] as Map<String, dynamic>? ?? {};
    final currentData = json['current'] as Map<String, dynamic>? ?? {};

    return RollerKilnMeter(
      power: (json['power'] as num?)?.toDouble() ?? 0.0,
      energy: (json['energy'] as num?)?.toDouble() ?? 0.0,
      voltage: {
        'Ua_0': (voltageData['Ua_0'] as num?)?.toDouble() ?? 0.0,
        'Ua_1': (voltageData['Ua_1'] as num?)?.toDouble() ?? 0.0,
        'Ua_2': (voltageData['Ua_2'] as num?)?.toDouble() ?? 0.0,
      },
      current: {
        'I_0': (currentData['I_0'] as num?)?.toDouble() ?? 0.0,
        'I_1': (currentData['I_1'] as num?)?.toDouble() ?? 0.0,
        'I_2': (currentData['I_2'] as num?)?.toDouble() ?? 0.0,
      },
    );
  }
}

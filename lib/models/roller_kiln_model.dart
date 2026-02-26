/// 辊道窑数据模型
class RollerKilnData {
  final String deviceId;
  final String? timestamp;
  final List<RollerKilnZone> zones;
  final RollerKilnTotal total;

  RollerKilnData({
    required this.deviceId,
    this.timestamp,
    required this.zones,
    required this.total,
  });

  factory RollerKilnData.fromJson(Map<String, dynamic> json) {
    final zonesData = json['zones'] as List? ?? [];
    final totalData = json['total'] as Map<String, dynamic>? ?? {};

    return RollerKilnData(
      deviceId: json['device_id'] ?? '',
      timestamp: json['timestamp'],
      zones: zonesData.map((z) => RollerKilnZone.fromJson(z)).toList(),
      total: RollerKilnTotal.fromJson(totalData),
    );
  }

  Map<String, dynamic> toJson() => {
        'device_id': deviceId,
        'timestamp': timestamp,
        'zones': zones.map((z) => z.toJson()).toList(),
        'total': total.toJson(),
      };
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
      power: (json['Pt'] as num?)?.toDouble() ?? 0.0,
      energy: (json['ImpEp'] as num?)?.toDouble() ?? 0.0,
      voltage: (json['Ua_0'] as num?)?.toDouble() ?? 0.0,
      currentA: (json['I_0'] as num?)?.toDouble() ?? 0.0,
      currentB: (json['I_1'] as num?)?.toDouble() ?? 0.0,
      currentC: (json['I_2'] as num?)?.toDouble() ?? 0.0,
    );
  }

  Map<String, dynamic> toJson() => {
        'zone_id': zoneId,
        'zone_name': zoneName,
        'temperature': temperature,
        'Pt': power,
        'ImpEp': energy,
        'Ua_0': voltage,
        'I_0': currentA,
        'I_1': currentB,
        'I_2': currentC,
      };
}

/// 辊道窑总表数据 (6个分区之和，由后端计算)
class RollerKilnTotal {
  final double power; // 总功率 Pt
  final double energy; // 总能耗 ImpEp
  final double voltage; // 平均电压 Ua_0
  final double currentA; // A相总电流 I_0
  final double currentB; // B相总电流 I_1
  final double currentC; // C相总电流 I_2

  RollerKilnTotal({
    required this.power,
    required this.energy,
    required this.voltage,
    required this.currentA,
    required this.currentB,
    required this.currentC,
  });

  factory RollerKilnTotal.fromJson(Map<String, dynamic> json) {
    return RollerKilnTotal(
      power: (json['Pt'] as num?)?.toDouble() ?? 0.0,
      energy: (json['ImpEp'] as num?)?.toDouble() ?? 0.0,
      voltage: (json['Ua_0'] as num?)?.toDouble() ?? 0.0,
      currentA: (json['I_0'] as num?)?.toDouble() ?? 0.0,
      currentB: (json['I_1'] as num?)?.toDouble() ?? 0.0,
      currentC: (json['I_2'] as num?)?.toDouble() ?? 0.0,
    );
  }

  Map<String, dynamic> toJson() => {
        'Pt': power,
        'ImpEp': energy,
        'Ua_0': voltage,
        'I_0': currentA,
        'I_1': currentB,
        'I_2': currentC,
      };
}

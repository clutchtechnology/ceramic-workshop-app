class HopperDevice {
  final String deviceId;
  final String deviceType;
  final String? dbNumber;

  HopperDevice({
    required this.deviceId,
    required this.deviceType,
    this.dbNumber,
  });

  factory HopperDevice.fromJson(Map<String, dynamic> json) {
    return HopperDevice(
      deviceId: json['device_id'] ?? '',
      deviceType: json['device_type'] ?? '',
      dbNumber: json['db_number']?.toString(),
    );
  }
}

class HopperData {
  final String deviceId;
  final String? timestamp;
  final WeighSensor? weighSensor;
  final TemperatureSensor? temperatureSensor;
  final TemperatureSensor? temperatureSensor1; // 长料仓第1个温度
  final TemperatureSensor? temperatureSensor2; // 长料仓第2个温度
  final ElectricityMeter? electricityMeter;

  HopperData({
    required this.deviceId,
    this.timestamp,
    this.weighSensor,
    this.temperatureSensor,
    this.temperatureSensor1,
    this.temperatureSensor2,
    this.electricityMeter,
  });

  factory HopperData.fromJson(Map<String, dynamic> json) {
    final modules = json['modules'] as Map<String, dynamic>? ?? {};

    return HopperData(
      deviceId: json['device_id'] ?? '',
      timestamp: json['timestamp'],
      weighSensor: modules.containsKey('weight')
          ? WeighSensor.fromJson(modules['weight']['fields'] ?? {})
          : (modules.containsKey('WeighSensor')
              ? WeighSensor.fromJson(modules['WeighSensor'])
              : null),
      temperatureSensor: modules.containsKey('temp')
          ? TemperatureSensor.fromJson(modules['temp']['fields'] ?? {})
          : (modules.containsKey('TemperatureSensor')
              ? TemperatureSensor.fromJson(modules['TemperatureSensor'])
              : null),
      // ✅ 长料仓温度1
      temperatureSensor1: modules.containsKey('temp1')
          ? TemperatureSensor.fromJson(modules['temp1']['fields'] ?? {})
          : null,
      // ✅ 长料仓温度2
      temperatureSensor2: modules.containsKey('temp2')
          ? TemperatureSensor.fromJson(modules['temp2']['fields'] ?? {})
          : null,
      // ✅ 修正：使用 'meter' 标签（与后端配置一致）
      electricityMeter: modules.containsKey('meter')
          ? ElectricityMeter.fromJson(modules['meter']['fields'] ?? {})
          : (modules.containsKey('elec')
              ? ElectricityMeter.fromJson(modules['elec']['fields'] ?? {})
              : (modules.containsKey('ElectricityMeter')
                  ? ElectricityMeter.fromJson(modules['ElectricityMeter'])
                  : null)),
    );
  }
}

class WeighSensor {
  final double weight;
  final double feedRate;

  WeighSensor({required this.weight, required this.feedRate});

  factory WeighSensor.fromJson(Map<String, dynamic> json) {
    return WeighSensor(
      weight: (json['weight'] as num?)?.toDouble() ?? 0.0,
      feedRate: (json['feed_rate'] as num?)?.toDouble() ?? 0.0,
    );
  }
}

class TemperatureSensor {
  final double temperature;

  TemperatureSensor({required this.temperature});

  factory TemperatureSensor.fromJson(Map<String, dynamic> json) {
    return TemperatureSensor(
      temperature: (json['temperature'] as num?)?.toDouble() ?? 0.0,
    );
  }
}

/// 电表数据模型 (精简版 - 7个关键字段)
/// 后端存储: Pt, ImpEp, Ua_0, I_0, I_1, I_2 (都除以10, 电流已乘变比)
class ElectricityMeter {
  final double pt; // 总有功功率 (kW)
  final double impEp; // 正向有功总电能 (kWh)
  final double voltage; // A相电压 (V) - 只保留A相
  final double currentA; // A相电流 (A)
  final double currentB; // B相电流 (A)
  final double currentC; // C相电流 (A)

  ElectricityMeter({
    required this.pt,
    required this.impEp,
    required this.voltage,
    required this.currentA,
    required this.currentB,
    required this.currentC,
  });

  factory ElectricityMeter.fromJson(Map<String, dynamic> json) {
    return ElectricityMeter(
      pt: (json['Pt'] as num?)?.toDouble() ?? 0.0,
      impEp: (json['ImpEp'] as num?)?.toDouble() ?? 0.0,
      voltage: (json['Ua_0'] as num?)?.toDouble() ?? 0.0,
      currentA: (json['I_0'] as num?)?.toDouble() ?? 0.0,
      currentB: (json['I_1'] as num?)?.toDouble() ?? 0.0,
      currentC: (json['I_2'] as num?)?.toDouble() ?? 0.0,
    );
  }
}

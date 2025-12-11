/// SCR+风机批量数据模型
class ScrFanBatchData {
  final int total;
  final ScrDevicesData scr;
  final FanDevicesData fan;

  ScrFanBatchData({
    required this.total,
    required this.scr,
    required this.fan,
  });

  factory ScrFanBatchData.fromJson(Map<String, dynamic> json) {
    return ScrFanBatchData(
      total: json['total'] ?? 0,
      scr: ScrDevicesData.fromJson(json['scr'] ?? {}),
      fan: FanDevicesData.fromJson(json['fan'] ?? {}),
    );
  }
}

/// SCR设备集合
class ScrDevicesData {
  final int total;
  final List<ScrDevice> devices;

  ScrDevicesData({
    required this.total,
    required this.devices,
  });

  factory ScrDevicesData.fromJson(Map<String, dynamic> json) {
    final devicesData = json['devices'] as List? ?? [];
    return ScrDevicesData(
      total: json['total'] ?? 0,
      devices: devicesData.map((d) => ScrDevice.fromJson(d)).toList(),
    );
  }
}

/// 风机设备集合
class FanDevicesData {
  final int total;
  final List<FanDevice> devices;

  FanDevicesData({
    required this.total,
    required this.devices,
  });

  factory FanDevicesData.fromJson(Map<String, dynamic> json) {
    final devicesData = json['devices'] as List? ?? [];
    return FanDevicesData(
      total: json['total'] ?? 0,
      devices: devicesData.map((d) => FanDevice.fromJson(d)).toList(),
    );
  }
}

/// SCR单个设备
class ScrDevice {
  final String deviceId;
  final String? timestamp;
  final ElectricityModule? elec;
  final GasModule? gas;

  ScrDevice({
    required this.deviceId,
    this.timestamp,
    this.elec,
    this.gas,
  });

  factory ScrDevice.fromJson(Map<String, dynamic> json) {
    final modules = json['modules'] as Map<String, dynamic>? ?? {};

    return ScrDevice(
      deviceId: json['device_id'] ?? '',
      timestamp: json['timestamp'],
      elec: modules.containsKey('elec')
          ? ElectricityModule.fromJson(modules['elec']['fields'] ?? {})
          : null,
      gas: modules.containsKey('gas')
          ? GasModule.fromJson(modules['gas']['fields'] ?? {})
          : null,
    );
  }
}

/// 风机单个设备
class FanDevice {
  final String deviceId;
  final String? timestamp;
  final ElectricityModule? elec;

  FanDevice({
    required this.deviceId,
    this.timestamp,
    this.elec,
  });

  factory FanDevice.fromJson(Map<String, dynamic> json) {
    final modules = json['modules'] as Map<String, dynamic>? ?? {};

    return FanDevice(
      deviceId: json['device_id'] ?? '',
      timestamp: json['timestamp'],
      elec: modules.containsKey('elec')
          ? ElectricityModule.fromJson(modules['elec']['fields'] ?? {})
          : null,
    );
  }
}

/// 电表模块
class ElectricityModule {
  final double pt;
  final double impEp;
  final double ua0;
  final double ua1;
  final double ua2;
  final double i0;
  final double i1;
  final double i2;

  ElectricityModule({
    required this.pt,
    required this.impEp,
    required this.ua0,
    required this.ua1,
    required this.ua2,
    required this.i0,
    required this.i1,
    required this.i2,
  });

  factory ElectricityModule.fromJson(Map<String, dynamic> json) {
    return ElectricityModule(
      pt: (json['Pt'] as num?)?.toDouble() ?? 0.0,
      impEp: (json['ImpEp'] as num?)?.toDouble() ?? 0.0,
      ua0: (json['Ua_0'] as num?)?.toDouble() ?? 0.0,
      ua1: (json['Ua_1'] as num?)?.toDouble() ?? 0.0,
      ua2: (json['Ua_2'] as num?)?.toDouble() ?? 0.0,
      i0: (json['I_0'] as num?)?.toDouble() ?? 0.0,
      i1: (json['I_1'] as num?)?.toDouble() ?? 0.0,
      i2: (json['I_2'] as num?)?.toDouble() ?? 0.0,
    );
  }
}

/// 燃气计模块
class GasModule {
  final double flowRate;
  final double totalFlow;

  GasModule({
    required this.flowRate,
    required this.totalFlow,
  });

  factory GasModule.fromJson(Map<String, dynamic> json) {
    return GasModule(
      flowRate: (json['flow_rate'] as num?)?.toDouble() ?? 0.0,
      totalFlow: (json['total_flow'] as num?)?.toDouble() ?? 0.0,
    );
  }
}

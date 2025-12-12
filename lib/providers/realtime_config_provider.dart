import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 实时数据配置 Provider
/// 用于持久化存储温度阈值、功率阈值等实时大屏的设置参数
///
/// 键值结构:
/// - 回转窑温度: {device_id}_temp (例: short_hopper_1_temp)
/// - 辊道窑温度: {zone_tag} (例: zone1_temp)
/// - 风机功率: {device_id}_power (例: fan_1_power)
/// - SCR氨水泵功率: {device_id}_meter (例: scr_1_meter)
/// - SCR燃气表流量: {device_id}_gas_meter (例: scr_1_gas_meter)

/// 固定颜色配置
class ThresholdColors {
  static const Color normal = Color(0xFF00ff88); // 绿色 - 正常
  static const Color warning = Color(0xFFffcc00); // 黄色 - 警告
  static const Color alarm = Color(0xFFff3b30); // 红色 - 危险/报警
}

/// 单个设备的阈值配置
class ThresholdConfig {
  final String key; // 设备键值
  final String displayName; // 显示名称
  double normalMax; // 正常上限
  double warningMax; // 警告上限（超过此值为报警）

  ThresholdConfig({
    required this.key,
    required this.displayName,
    this.normalMax = 0.0,
    this.warningMax = 0.0,
  });

  Map<String, dynamic> toJson() => {
        'key': key,
        'displayName': displayName,
        'normalMax': normalMax,
        'warningMax': warningMax,
      };

  factory ThresholdConfig.fromJson(Map<String, dynamic> json) {
    return ThresholdConfig(
      key: json['key'] as String,
      displayName: json['displayName'] as String,
      normalMax: (json['normalMax'] as num?)?.toDouble() ?? 0.0,
      warningMax: (json['warningMax'] as num?)?.toDouble() ?? 0.0,
    );
  }

  ThresholdConfig copyWith({
    double? normalMax,
    double? warningMax,
  }) {
    return ThresholdConfig(
      key: key,
      displayName: displayName,
      normalMax: normalMax ?? this.normalMax,
      warningMax: warningMax ?? this.warningMax,
    );
  }

  /// 判断设备是否启动（数值 >= normalMax 认为启动）
  bool isRunning(double value) {
    return value >= normalMax;
  }

  /// 根据数值获取状态颜色
  Color getColor(double value) {
    if (value <= normalMax) {
      return ThresholdColors.normal;
    } else if (value <= warningMax) {
      return ThresholdColors.warning;
    } else {
      return ThresholdColors.alarm;
    }
  }
}

/// 料仓容量配置（用于计算百分比）
class HopperCapacityConfig {
  final String key; // 设备键值
  final String displayName; // 显示名称
  double maxCapacity; // 最大容量 (kg)

  HopperCapacityConfig({
    required this.key,
    required this.displayName,
    this.maxCapacity = 1000.0,
  });

  Map<String, dynamic> toJson() => {
        'key': key,
        'displayName': displayName,
        'maxCapacity': maxCapacity,
      };

  factory HopperCapacityConfig.fromJson(Map<String, dynamic> json) {
    return HopperCapacityConfig(
      key: json['key'] as String,
      displayName: json['displayName'] as String,
      maxCapacity: (json['maxCapacity'] as num?)?.toDouble() ?? 1000.0,
    );
  }

  /// 根据当前重量计算百分比容量
  double calculatePercentage(double currentWeight) {
    if (maxCapacity <= 0) return 0.0;
    final percentage = (currentWeight / maxCapacity) * 100;
    return percentage.clamp(0.0, 100.0);
  }
}

/// 实时数据配置 Provider
class RealtimeConfigProvider extends ChangeNotifier {
  static const String _storageKey = 'realtime_threshold_config_v2';

  bool _isLoaded = false;
  bool get isLoaded => _isLoaded;

  // ============================================================
  // 回转窑温度配置 (9个设备)
  // 键值格式: {device_id}_temp
  // ============================================================
  final List<ThresholdConfig> rotaryKilnConfigs = [
    ThresholdConfig(
        key: 'short_hopper_1_temp',
        displayName: '1号短料仓回转窑',
        normalMax: 800.0,
        warningMax: 1000.0),
    ThresholdConfig(
        key: 'short_hopper_2_temp',
        displayName: '2号短料仓回转窑',
        normalMax: 800.0,
        warningMax: 1000.0),
    ThresholdConfig(
        key: 'short_hopper_3_temp',
        displayName: '3号短料仓回转窑',
        normalMax: 800.0,
        warningMax: 1000.0),
    ThresholdConfig(
        key: 'short_hopper_4_temp',
        displayName: '4号短料仓回转窑',
        normalMax: 800.0,
        warningMax: 1000.0),
    ThresholdConfig(
        key: 'no_hopper_1_temp',
        displayName: '1号无料仓回转窑',
        normalMax: 800.0,
        warningMax: 1000.0),
    ThresholdConfig(
        key: 'no_hopper_2_temp',
        displayName: '2号无料仓回转窑',
        normalMax: 800.0,
        warningMax: 1000.0),
    ThresholdConfig(
        key: 'long_hopper_1_temp',
        displayName: '1号长料仓回转窑',
        normalMax: 800.0,
        warningMax: 1000.0),
    ThresholdConfig(
        key: 'long_hopper_2_temp',
        displayName: '2号长料仓回转窑',
        normalMax: 800.0,
        warningMax: 1000.0),
    ThresholdConfig(
        key: 'long_hopper_3_temp',
        displayName: '3号长料仓回转窑',
        normalMax: 800.0,
        warningMax: 1000.0),
  ];

  // ============================================================
  // 辊道窑温度配置 (6个温区)
  // 键值格式: zone{n}_temp
  // ============================================================
  final List<ThresholdConfig> rollerKilnConfigs = [
    ThresholdConfig(
        key: 'zone1_temp',
        displayName: '1号区温度',
        normalMax: 1200.0,
        warningMax: 1400.0),
    ThresholdConfig(
        key: 'zone2_temp',
        displayName: '2号区温度',
        normalMax: 1200.0,
        warningMax: 1400.0),
    ThresholdConfig(
        key: 'zone3_temp',
        displayName: '3号区温度',
        normalMax: 1200.0,
        warningMax: 1400.0),
    ThresholdConfig(
        key: 'zone4_temp',
        displayName: '4号区温度',
        normalMax: 1200.0,
        warningMax: 1400.0),
    ThresholdConfig(
        key: 'zone5_temp',
        displayName: '5号区温度',
        normalMax: 1200.0,
        warningMax: 1400.0),
    ThresholdConfig(
        key: 'zone6_temp',
        displayName: '6号区温度',
        normalMax: 1200.0,
        warningMax: 1400.0),
  ];

  // ============================================================
  // 风机功率配置 (2个风机)
  // 键值格式: fan_{n}_power
  // ============================================================
  final List<ThresholdConfig> fanConfigs = [
    ThresholdConfig(
        key: 'fan_1_power',
        displayName: '1号风机功率',
        normalMax: 80.0,
        warningMax: 120.0),
    ThresholdConfig(
        key: 'fan_2_power',
        displayName: '2号风机功率',
        normalMax: 80.0,
        warningMax: 120.0),
  ];

  // ============================================================
  // SCR氨水泵功率配置 (2个)
  // 键值格式: scr_{n}_meter
  // ============================================================
  final List<ThresholdConfig> scrPumpConfigs = [
    ThresholdConfig(
        key: 'scr_1_meter',
        displayName: '1号SCR氨水泵功率',
        normalMax: 30.0,
        warningMax: 50.0),
    ThresholdConfig(
        key: 'scr_2_meter',
        displayName: '2号SCR氨水泵功率',
        normalMax: 30.0,
        warningMax: 50.0),
  ];

  // ============================================================
  // SCR燃气表流量配置 (2个)
  // 键值格式: scr_{n}_gas_meter
  // ============================================================
  final List<ThresholdConfig> scrGasConfigs = [
    ThresholdConfig(
        key: 'scr_1_gas_meter',
        displayName: '1号SCR燃气表流量',
        normalMax: 100.0,
        warningMax: 150.0),
    ThresholdConfig(
        key: 'scr_2_gas_meter',
        displayName: '2号SCR燃气表流量',
        normalMax: 100.0,
        warningMax: 150.0),
  ];

  // ============================================================
  // 料仓容量配置 (7个带料仓的回转窑: 1-4短料仓, 7-9长料仓)
  // 键值格式: {device_id}_capacity
  // ============================================================
  final List<HopperCapacityConfig> hopperCapacityConfigs = [
    HopperCapacityConfig(
        key: 'short_hopper_1_capacity',
        displayName: '1号短料仓',
        maxCapacity: 1000.0),
    HopperCapacityConfig(
        key: 'short_hopper_2_capacity',
        displayName: '2号短料仓',
        maxCapacity: 1000.0),
    HopperCapacityConfig(
        key: 'short_hopper_3_capacity',
        displayName: '3号短料仓',
        maxCapacity: 1000.0),
    HopperCapacityConfig(
        key: 'short_hopper_4_capacity',
        displayName: '4号短料仓',
        maxCapacity: 1000.0),
    HopperCapacityConfig(
        key: 'long_hopper_1_capacity',
        displayName: '1号长料仓',
        maxCapacity: 1500.0),
    HopperCapacityConfig(
        key: 'long_hopper_2_capacity',
        displayName: '2号长料仓',
        maxCapacity: 1500.0),
    HopperCapacityConfig(
        key: 'long_hopper_3_capacity',
        displayName: '3号长料仓',
        maxCapacity: 1500.0),
  ];

  /// 初始化加载配置
  Future<void> loadConfig() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonString = prefs.getString(_storageKey);

      if (jsonString != null) {
        final jsonData = jsonDecode(jsonString) as Map<String, dynamic>;
        _loadFromJson(jsonData);
      }
      _isLoaded = true;
      notifyListeners();
    } catch (e) {
      debugPrint('加载实时数据配置失败: $e');
      _isLoaded = true;
      notifyListeners();
    }
  }

  void _loadFromJson(Map<String, dynamic> json) {
    // 加载回转窑配置
    if (json['rotaryKiln'] != null) {
      final rotaryData = json['rotaryKiln'] as Map<String, dynamic>;
      for (var config in rotaryKilnConfigs) {
        if (rotaryData[config.key] != null) {
          final data = rotaryData[config.key] as Map<String, dynamic>;
          config.normalMax =
              (data['normalMax'] as num?)?.toDouble() ?? config.normalMax;
          config.warningMax =
              (data['warningMax'] as num?)?.toDouble() ?? config.warningMax;
        }
      }
    }

    // 加载辊道窑配置
    if (json['rollerKiln'] != null) {
      final rollerData = json['rollerKiln'] as Map<String, dynamic>;
      for (var config in rollerKilnConfigs) {
        if (rollerData[config.key] != null) {
          final data = rollerData[config.key] as Map<String, dynamic>;
          config.normalMax =
              (data['normalMax'] as num?)?.toDouble() ?? config.normalMax;
          config.warningMax =
              (data['warningMax'] as num?)?.toDouble() ?? config.warningMax;
        }
      }
    }

    // 加载风机配置
    if (json['fan'] != null) {
      final fanData = json['fan'] as Map<String, dynamic>;
      for (var config in fanConfigs) {
        if (fanData[config.key] != null) {
          final data = fanData[config.key] as Map<String, dynamic>;
          config.normalMax =
              (data['normalMax'] as num?)?.toDouble() ?? config.normalMax;
          config.warningMax =
              (data['warningMax'] as num?)?.toDouble() ?? config.warningMax;
        }
      }
    }

    // 加载SCR氨水泵配置
    if (json['scrPump'] != null) {
      final pumpData = json['scrPump'] as Map<String, dynamic>;
      for (var config in scrPumpConfigs) {
        if (pumpData[config.key] != null) {
          final data = pumpData[config.key] as Map<String, dynamic>;
          config.normalMax =
              (data['normalMax'] as num?)?.toDouble() ?? config.normalMax;
          config.warningMax =
              (data['warningMax'] as num?)?.toDouble() ?? config.warningMax;
        }
      }
    }

    // 加载SCR燃气表配置
    if (json['scrGas'] != null) {
      final gasData = json['scrGas'] as Map<String, dynamic>;
      for (var config in scrGasConfigs) {
        if (gasData[config.key] != null) {
          final data = gasData[config.key] as Map<String, dynamic>;
          config.normalMax =
              (data['normalMax'] as num?)?.toDouble() ?? config.normalMax;
          config.warningMax =
              (data['warningMax'] as num?)?.toDouble() ?? config.warningMax;
        }
      }
    }

    // 加载料仓容量配置
    if (json['hopperCapacity'] != null) {
      final capacityData = json['hopperCapacity'] as Map<String, dynamic>;
      for (var config in hopperCapacityConfigs) {
        if (capacityData[config.key] != null) {
          final data = capacityData[config.key] as Map<String, dynamic>;
          config.maxCapacity =
              (data['maxCapacity'] as num?)?.toDouble() ?? config.maxCapacity;
        }
      }
    }
  }

  Map<String, dynamic> _toJson() {
    return {
      'rotaryKiln': {
        for (var config in rotaryKilnConfigs)
          config.key: {
            'normalMax': config.normalMax,
            'warningMax': config.warningMax
          }
      },
      'rollerKiln': {
        for (var config in rollerKilnConfigs)
          config.key: {
            'normalMax': config.normalMax,
            'warningMax': config.warningMax
          }
      },
      'fan': {
        for (var config in fanConfigs)
          config.key: {
            'normalMax': config.normalMax,
            'warningMax': config.warningMax
          }
      },
      'scrPump': {
        for (var config in scrPumpConfigs)
          config.key: {
            'normalMax': config.normalMax,
            'warningMax': config.warningMax
          }
      },
      'scrGas': {
        for (var config in scrGasConfigs)
          config.key: {
            'normalMax': config.normalMax,
            'warningMax': config.warningMax
          }
      },
      'hopperCapacity': {
        for (var config in hopperCapacityConfigs)
          config.key: {'maxCapacity': config.maxCapacity}
      },
    };
  }

  /// 保存配置
  Future<bool> saveConfig() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonString = jsonEncode(_toJson());
      await prefs.setString(_storageKey, jsonString);
      notifyListeners();
      return true;
    } catch (e) {
      debugPrint('保存实时数据配置失败: $e');
      return false;
    }
  }

  /// 更新回转窑配置
  void updateRotaryKilnConfig(int index,
      {double? normalMax, double? warningMax}) {
    if (index >= 0 && index < rotaryKilnConfigs.length) {
      if (normalMax != null) rotaryKilnConfigs[index].normalMax = normalMax;
      if (warningMax != null) rotaryKilnConfigs[index].warningMax = warningMax;
      notifyListeners();
    }
  }

  /// 更新辊道窑配置
  void updateRollerKilnConfig(int index,
      {double? normalMax, double? warningMax}) {
    if (index >= 0 && index < rollerKilnConfigs.length) {
      if (normalMax != null) rollerKilnConfigs[index].normalMax = normalMax;
      if (warningMax != null) rollerKilnConfigs[index].warningMax = warningMax;
      notifyListeners();
    }
  }

  /// 更新风机配置
  void updateFanConfig(int index, {double? normalMax, double? warningMax}) {
    if (index >= 0 && index < fanConfigs.length) {
      if (normalMax != null) fanConfigs[index].normalMax = normalMax;
      if (warningMax != null) fanConfigs[index].warningMax = warningMax;
      notifyListeners();
    }
  }

  /// 更新SCR氨水泵配置
  void updateScrPumpConfig(int index, {double? normalMax, double? warningMax}) {
    if (index >= 0 && index < scrPumpConfigs.length) {
      if (normalMax != null) scrPumpConfigs[index].normalMax = normalMax;
      if (warningMax != null) scrPumpConfigs[index].warningMax = warningMax;
      notifyListeners();
    }
  }

  /// 更新SCR燃气表配置
  void updateScrGasConfig(int index, {double? normalMax, double? warningMax}) {
    if (index >= 0 && index < scrGasConfigs.length) {
      if (normalMax != null) scrGasConfigs[index].normalMax = normalMax;
      if (warningMax != null) scrGasConfigs[index].warningMax = warningMax;
      notifyListeners();
    }
  }

  /// 更新料仓容量配置
  void updateHopperCapacityConfig(int index, {double? maxCapacity}) {
    if (index >= 0 && index < hopperCapacityConfigs.length) {
      if (maxCapacity != null) {
        hopperCapacityConfigs[index].maxCapacity = maxCapacity;
      }
      notifyListeners();
    }
  }

  /// 重置为默认配置
  void resetToDefault() {
    // 重置回转窑
    for (var config in rotaryKilnConfigs) {
      config.normalMax = 800.0;
      config.warningMax = 1000.0;
    }
    // 重置辊道窑
    for (var config in rollerKilnConfigs) {
      config.normalMax = 1200.0;
      config.warningMax = 1400.0;
    }
    // 重置风机
    for (var config in fanConfigs) {
      config.normalMax = 80.0;
      config.warningMax = 120.0;
    }
    // 重置SCR氨水泵
    for (var config in scrPumpConfigs) {
      config.normalMax = 30.0;
      config.warningMax = 50.0;
    }
    // 重置SCR燃气表
    for (var config in scrGasConfigs) {
      config.normalMax = 100.0;
      config.warningMax = 150.0;
    }
    // 重置料仓容量 (短料仓1000kg, 长料仓1500kg)
    for (int i = 0; i < hopperCapacityConfigs.length; i++) {
      if (hopperCapacityConfigs[i].key.contains('short')) {
        hopperCapacityConfigs[i].maxCapacity = 1000.0;
      } else {
        hopperCapacityConfigs[i].maxCapacity = 1500.0;
      }
    }
    notifyListeners();
  }

  // ============================================================
  // 便捷获取颜色的方法
  // ============================================================

  /// 根据设备ID获取回转窑温度颜色
  /// deviceId: 例如 "short_hopper_1"
  Color getRotaryKilnTempColor(String deviceId, double temperature) {
    final key = '${deviceId}_temp';
    final config = rotaryKilnConfigs.firstWhere(
      (c) => c.key == key,
      orElse: () => ThresholdConfig(
          key: key, displayName: '', normalMax: 800.0, warningMax: 1000.0),
    );
    return config.getColor(temperature);
  }

  /// 根据温区tag获取辊道窑温度颜色
  /// zoneTag: 例如 "zone1_temp"
  Color getRollerKilnTempColor(String zoneTag, double temperature) {
    final config = rollerKilnConfigs.firstWhere(
      (c) => c.key == zoneTag,
      orElse: () => ThresholdConfig(
          key: zoneTag, displayName: '', normalMax: 1200.0, warningMax: 1400.0),
    );
    return config.getColor(temperature);
  }

  /// 根据温区索引获取辊道窑温度颜色 (1-6)
  Color getRollerKilnTempColorByIndex(int zoneIndex, double temperature) {
    final zoneTag = 'zone${zoneIndex}_temp';
    return getRollerKilnTempColor(zoneTag, temperature);
  }

  /// 根据风机ID获取功率颜色
  /// fanId: 例如 "fan_1"
  Color getFanPowerColor(String fanId, double power) {
    final key = '${fanId}_power';
    final config = fanConfigs.firstWhere(
      (c) => c.key == key,
      orElse: () => ThresholdConfig(
          key: key, displayName: '', normalMax: 80.0, warningMax: 120.0),
    );
    return config.getColor(power);
  }

  /// 根据SCR设备ID获取氨水泵功率颜色
  /// scrId: 例如 "scr_1"
  Color getScrPumpPowerColor(String scrId, double power) {
    final key = '${scrId}_meter';
    final config = scrPumpConfigs.firstWhere(
      (c) => c.key == key,
      orElse: () => ThresholdConfig(
          key: key, displayName: '', normalMax: 30.0, warningMax: 50.0),
    );
    return config.getColor(power);
  }

  /// 根据SCR设备ID获取燃气表流量颜色
  /// scrId: 例如 "scr_1"
  Color getScrGasFlowColor(String scrId, double flow) {
    final key = '${scrId}_gas_meter';
    final config = scrGasConfigs.firstWhere(
      (c) => c.key == key,
      orElse: () => ThresholdConfig(
          key: key, displayName: '', normalMax: 100.0, warningMax: 150.0),
    );
    return config.getColor(flow);
  }

  // ============================================================
  // 获取阈值配置的方法
  // ============================================================

  /// 获取回转窑阈值配置
  ThresholdConfig? getRotaryKilnThreshold(String deviceId) {
    final key = '${deviceId}_temp';
    try {
      return rotaryKilnConfigs.firstWhere((c) => c.key == key);
    } catch (e) {
      return null;
    }
  }

  /// 获取辊道窑阈值配置
  ThresholdConfig? getRollerKilnThreshold(String zoneTag) {
    try {
      return rollerKilnConfigs.firstWhere((c) => c.key == zoneTag);
    } catch (e) {
      return null;
    }
  }

  /// 获取风机阈值配置
  ThresholdConfig? getFanThreshold(String fanId) {
    final key = '${fanId}_power';
    try {
      return fanConfigs.firstWhere((c) => c.key == key);
    } catch (e) {
      return null;
    }
  }

  /// 获取SCR氨水泵阈值配置
  ThresholdConfig? getScrPumpThreshold(String scrId) {
    final key = '${scrId}_meter';
    try {
      return scrPumpConfigs.firstWhere((c) => c.key == key);
    } catch (e) {
      return null;
    }
  }

  /// 获取SCR燃气表阈值配置
  ThresholdConfig? getScrGasThreshold(String scrId) {
    final key = '${scrId}_gas_meter';
    try {
      return scrGasConfigs.firstWhere((c) => c.key == key);
    } catch (e) {
      return null;
    }
  }

  // ============================================================
  // 判断设备运行状态的方法
  // ============================================================

  /// 判断风机是否运行（功率 >= minThreshold）
  /// fanIndex: 风机索引 (1 或 2)
  bool isFanRunning(int fanIndex, double power) {
    if (fanIndex < 1 || fanIndex > fanConfigs.length) return power > 0;
    final config = fanConfigs[fanIndex - 1];
    return config.isRunning(power);
  }

  /// 判断SCR氨水泵是否运行（功率 >= minThreshold）
  /// scrIndex: SCR索引 (1 或 2)
  bool isScrPumpRunning(int scrIndex, double power) {
    if (scrIndex < 1 || scrIndex > scrPumpConfigs.length) return power > 0;
    final config = scrPumpConfigs[scrIndex - 1];
    return config.isRunning(power);
  }

  /// 判断SCR燃气表是否运行（流量 >= minThreshold）
  /// scrIndex: SCR索引 (1 或 2)
  bool isScrGasRunning(int scrIndex, double flowRate) {
    if (scrIndex < 1 || scrIndex > scrGasConfigs.length) return flowRate > 0;
    final config = scrGasConfigs[scrIndex - 1];
    return config.isRunning(flowRate);
  }

  // ============================================================
  // 料仓容量相关方法
  // ============================================================

  /// 根据设备ID获取料仓容量百分比
  /// deviceId: 例如 "short_hopper_1", "long_hopper_2"
  /// currentWeight: 当前重量 (kg)
  /// 返回: 百分比 (0-100)
  double getHopperCapacityPercentage(String deviceId, double currentWeight) {
    final key = '${deviceId}_capacity';
    final config = hopperCapacityConfigs.firstWhere(
      (c) => c.key == key,
      orElse: () =>
          HopperCapacityConfig(key: key, displayName: '', maxCapacity: 1000.0),
    );
    return config.calculatePercentage(currentWeight);
  }

  /// 根据设备ID获取料仓最大容量
  /// deviceId: 例如 "short_hopper_1", "long_hopper_2"
  double getHopperMaxCapacity(String deviceId) {
    final key = '${deviceId}_capacity';
    final config = hopperCapacityConfigs.firstWhere(
      (c) => c.key == key,
      orElse: () =>
          HopperCapacityConfig(key: key, displayName: '', maxCapacity: 1000.0),
    );
    return config.maxCapacity;
  }

  /// 获取料仓容量配置
  HopperCapacityConfig? getHopperCapacityConfig(String deviceId) {
    final key = '${deviceId}_capacity';
    try {
      return hopperCapacityConfigs.firstWhere((c) => c.key == key);
    } catch (e) {
      return null;
    }
  }

  /// 根据设备ID获取料仓容量比例 (0.0 - 1.0)
  /// 用于进度条显示
  /// deviceId: 例如 "short_hopper_1", "long_hopper_2"
  /// currentWeight: 当前重量 (kg)
  /// 返回: 比例 (0.0 - 1.0)
  double getHopperPercentage(String deviceId, double currentWeight) {
    final percentage = getHopperCapacityPercentage(deviceId, currentWeight);
    return (percentage / 100.0).clamp(0.0, 1.0);
  }
}

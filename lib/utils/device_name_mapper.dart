/// ============================================================================
/// 设备名称映射工具类 (Device Name Mapper)
/// ============================================================================
/// 功能:
/// 1. 将后端 device_id 映射为前端显示名称
/// 2. 提供设备类型判断方法
/// 3. 提供设备分组信息
/// ============================================================================

class DeviceNameMapper {
  /// 设备名称映射表
  static const Map<String, String> deviceNameMap = {
    // 回转窑（9个）
    'short_hopper_1': '窑7',
    'short_hopper_2': '窑6',
    'short_hopper_3': '窑5',
    'short_hopper_4': '窑4',
    'no_hopper_1': '窑2',
    'no_hopper_2': '窑1',
    'long_hopper_1': '窑8',
    'long_hopper_2': '窑3',
    'long_hopper_3': '窑9',

    // 辊道窑（7个：6个分区 + 1个合计）
    'zone1': '辊道窑分区1',
    'zone2': '辊道窑分区2',
    'zone3': '辊道窑分区3',
    'zone4': '辊道窑分区4',
    'zone5': '辊道窑分区5',
    'zone6': '辊道窑分区6',
    'roller_kiln_total': '辊道窑合计',

    // SCR燃气表（2个）
    'scr_1': 'SCR北_燃气表',
    'scr_2': 'SCR南_燃气表',

    // SCR氨水泵（2个）
    'scr_1_pump': 'SCR北_氨水泵',
    'scr_2_pump': 'SCR南_氨水泵',

    // 风机（2个）
    'fan_1': 'SCR北_风机',
    'fan_2': 'SCR南_风机',
  };

  /// 获取设备显示名称
  static String getDeviceName(String deviceId) {
    return deviceNameMap[deviceId] ?? deviceId;
  }

  /// 判断是否有料仓（用于累计投料量）
  static bool hasHopper(String deviceId) {
    return deviceId.startsWith('short_hopper_') ||
        deviceId.startsWith('long_hopper_');
  }

  /// 判断是否是燃气表（用于燃气消耗统计）
  static bool isGasMeter(String deviceId) {
    return deviceId == 'scr_1' || deviceId == 'scr_2';
  }

  /// 判断是否是辊道窑分区
  static bool isRollerKilnZone(String deviceId) {
    return deviceId.startsWith('zone') && deviceId != 'roller_kiln_total';
  }

  /// 判断是否是辊道窑合计
  static bool isRollerKilnTotal(String deviceId) {
    return deviceId == 'roller_kiln_total';
  }

  /// 判断是否是回转窑
  static bool isRotaryKiln(String deviceId) {
    return deviceId.contains('hopper');
  }

  /// 判断是否是SCR氨水泵
  static bool isScrPump(String deviceId) {
    return deviceId.endsWith('_pump');
  }

  /// 判断是否是风机
  static bool isFan(String deviceId) {
    return deviceId.startsWith('fan_');
  }

  /// 获取设备类型显示名称
  static String getDeviceType(String deviceId) {
    if (isRotaryKiln(deviceId)) return '回转窑';
    if (isRollerKilnZone(deviceId)) return '辊道窑分区';
    if (isRollerKilnTotal(deviceId)) return '辊道窑合计';
    if (isGasMeter(deviceId)) return 'SCR燃气表';
    if (isScrPump(deviceId)) return 'SCR氨水泵';
    if (isFan(deviceId)) return '风机';
    return '未知设备';
  }

  /// 获取设备排序权重（用于导出时排序）
  static int getDeviceSortOrder(String deviceId) {
    // 回转窑: 窑7,6,5,4,2,1,8,3,9
    const hopperOrder = {
      'short_hopper_1': 1, // 窑7
      'short_hopper_2': 2, // 窑6
      'short_hopper_3': 3, // 窑5
      'short_hopper_4': 4, // 窑4
      'no_hopper_1': 5, // 窑2
      'no_hopper_2': 6, // 窑1
      'long_hopper_1': 7, // 窑8
      'long_hopper_2': 8, // 窑3
      'long_hopper_3': 9, // 窑9
    };

    // 辊道窑分区: 1-6
    const zoneOrder = {
      'zone1': 10,
      'zone2': 11,
      'zone3': 12,
      'zone4': 13,
      'zone5': 14,
      'zone6': 15,
      'roller_kiln_total': 16,
    };

    // SCR氨水泵
    const scrPumpOrder = {
      'scr_1_pump': 17,
      'scr_2_pump': 18,
    };

    // 风机
    const fanOrder = {
      'fan_1': 19,
      'fan_2': 20,
    };

    // SCR燃气表
    const gasMeterOrder = {
      'scr_1': 21,
      'scr_2': 22,
    };

    return hopperOrder[deviceId] ??
        zoneOrder[deviceId] ??
        scrPumpOrder[deviceId] ??
        fanOrder[deviceId] ??
        gasMeterOrder[deviceId] ??
        999;
  }

  /// 获取所有回转窑设备ID（按顺序）
  static List<String> getAllRotaryKilnIds() {
    return [
      'short_hopper_1', // 窑7
      'short_hopper_2', // 窑6
      'short_hopper_3', // 窑5
      'short_hopper_4', // 窑4
      'no_hopper_1', // 窑2
      'no_hopper_2', // 窑1
      'long_hopper_1', // 窑8
      'long_hopper_2', // 窑3
      'long_hopper_3', // 窑9
    ];
  }

  /// 获取所有带料仓的回转窑设备ID（按顺序）
  static List<String> getHopperKilnIds() {
    return [
      'short_hopper_1', // 窑7
      'short_hopper_2', // 窑6
      'short_hopper_3', // 窑5
      'short_hopper_4', // 窑4
      'long_hopper_1', // 窑8
      'long_hopper_2', // 窑3
      'long_hopper_3', // 窑9
    ];
  }

  /// 获取所有辊道窑分区设备ID（按顺序）
  static List<String> getRollerKilnZoneIds() {
    return ['zone1', 'zone2', 'zone3', 'zone4', 'zone5', 'zone6'];
  }

  /// 获取所有SCR燃气表设备ID（按顺序）
  static List<String> getGasMeterIds() {
    return ['scr_1', 'scr_2'];
  }

  /// 获取所有SCR氨水泵设备ID（按顺序）
  static List<String> getScrPumpIds() {
    return ['scr_1_pump', 'scr_2_pump'];
  }

  /// 获取所有风机设备ID（按顺序）
  static List<String> getFanIds() {
    return ['fan_1', 'fan_2'];
  }

  /// 验证设备数量是否正确
  static bool validateDeviceCount(
    Map<String, dynamic> data,
    String exportType,
  ) {
    int expectedCount;

    switch (exportType) {
      case 'runtime': // 设备运行时长
      case 'electricity': // 电量统计
        expectedCount = 20; // 9回转窑 + 6辊道窑分区 + 1辊道窑合计 + 2SCR氨水泵 + 2风机
        break;
      case 'comprehensive': // 全部数据
        expectedCount = 22; // 9回转窑 + 6辊道窑分区 + 1辊道窑合计 + 2SCR燃气表 + 2SCR氨水泵 + 2风机
        break;
      case 'gas': // 燃气消耗统计
        expectedCount = 2; // 2个SCR燃气表
        break;
      case 'feeding': // 累计投料量
        expectedCount = 7; // 7个带料仓的回转窑
        break;
      default:
        return true; // 未知类型，跳过验证
    }

    int actualCount = _countDevices(data, exportType);
    return actualCount == expectedCount;
  }

  /// 计算实际设备数量
  static int _countDevices(Map<String, dynamic> data, String exportType) {
    int count = 0;

    switch (exportType) {
      case 'runtime':
      case 'electricity':
        // 格式: { hoppers: [], roller_kiln_zones: [], roller_kiln_total: {}, scr_devices: [], fan_devices: [] }
        count += (data['hoppers'] as List?)?.length ?? 0;
        count += (data['roller_kiln_zones'] as List?)?.length ?? 0;
        count += data['roller_kiln_total'] != null ? 1 : 0;
        count += (data['scr_devices'] as List?)?.length ?? 0;
        count += (data['fan_devices'] as List?)?.length ?? 0;
        break;

      case 'gas':
        // 格式: { scr_1: {...}, scr_2: {...} }
        count = data.keys.length;
        break;

      case 'feeding':
        // 格式: { hoppers: [...] }
        count = (data['hoppers'] as List?)?.length ?? 0;
        break;

      case 'comprehensive':
        // 格式: { devices: [...] }
        count = (data['devices'] as List?)?.length ?? 0;
        break;
    }

    return count;
  }

  /// 获取设备数量说明
  static String getDeviceCountDescription(String exportType) {
    switch (exportType) {
      case 'runtime':
        return '20个设备（9回转窑 + 6辊道窑分区 + 1辊道窑合计 + 2SCR氨水泵 + 2风机）';
      case 'gas':
        return '2个设备（SCR北/南燃气表）';
      case 'feeding':
        return '7个设备（带料仓的回转窑，不包含窑2和窑1）';
      case 'electricity':
        return '20个设备（9回转窑 + 6辊道窑分区 + 1辊道窑合计 + 2SCR氨水泵 + 2风机）';
      case 'comprehensive':
        return '22个设备（9回转窑 + 6辊道窑分区 + 1辊道窑合计 + 2SCR燃气表 + 2SCR氨水泵 + 2风机）';
      default:
        return '未知';
    }
  }
}

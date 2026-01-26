# 前端代码更新总结

> **日期**: 2026-01-27  
> **任务**: 更新前端代码以适配新的数据导出接口

---

## ✅ 完成的工作

### 1. 创建设备名称映射工具类 ✅

**文件**: `lib/utils/device_name_mapper.dart`

**功能**:
- ✅ 设备ID到显示名称的映射（22个设备）
- ✅ 设备类型判断方法（是否有料仓、是否是燃气表等）
- ✅ 设备排序权重（用于导出时排序）
- ✅ 设备数量验证（自动验证返回的设备数量是否正确）
- ✅ 设备分组获取（获取所有回转窑、辊道窑分区等）

**核心方法**:
```dart
// 获取设备显示名称
DeviceNameMapper.getDeviceName('short_hopper_1') // 返回: '窑7'

// 判断是否有料仓
DeviceNameMapper.hasHopper('short_hopper_1') // 返回: true
DeviceNameMapper.hasHopper('no_hopper_1') // 返回: false

// 验证设备数量
DeviceNameMapper.validateDeviceCount(data, 'runtime') // 返回: true/false

// 获取设备数量说明
DeviceNameMapper.getDeviceCountDescription('runtime')
// 返回: '20个设备（9回转窑 + 6辊道窑分区 + 1辊道窑合计 + 2SCR氨水泵 + 2风机）'

// 获取所有带料仓的回转窑
DeviceNameMapper.getHopperKilnIds()
// 返回: ['short_hopper_1', 'short_hopper_2', ..., 'long_hopper_3']
```

---

### 2. 更新 API 定义 ✅

**文件**: `lib/api/api.dart`

**改动**:
- ✅ 添加详细的注释说明每个接口的用途和设备数量
- ✅ 保持接口路径不变（已经是正确的）

**5个核心导出接口**:
```dart
// 1. 运行时长统计 - 20个设备
static const String exportRuntimeAll = '/api/export/runtime/all';

// 2. 燃气消耗统计 - 2个设备
static const String exportGasConsumption = '/api/export/gas-consumption';

// 3. 投料量统计 - 7个设备
static const String exportFeedingAmount = '/api/export/feeding-amount';

// 4. 电量统计 - 20个设备
static const String exportElectricityAll = '/api/export/electricity/all';

// 5. 综合数据统计 - 20个设备
static const String exportComprehensive = '/api/export/comprehensive';
```

---

### 3. 更新数据导出服务 ✅

**文件**: `lib/services/data_export_service.dart`

**改动**:
- ✅ 导入 `DeviceNameMapper` 工具类
- ✅ 为每个方法添加详细的注释说明
- ✅ 添加自动设备数量验证
- ✅ 如果设备数量不匹配，抛出异常

**示例**:
```dart
Future<Map<String, dynamic>> getAllDevicesRuntime({
  required DateTime startTime,
  required DateTime endTime,
}) async {
  final response = await _client.get(
    Api.exportRuntimeAll,
    params: {
      'start_time': startTime.toUtc().toIso8601String(),
      'end_time': endTime.toUtc().toIso8601String(),
    },
  );

  if (response['success'] == true) {
    final data = response['data'] as Map<String, dynamic>;
    
    // ✅ 自动验证设备数量
    if (!DeviceNameMapper.validateDeviceCount(data, 'runtime')) {
      throw Exception(
        '设备数量不匹配！预期: ${DeviceNameMapper.getDeviceCountDescription('runtime')}',
      );
    }
    
    return data;
  } else {
    throw Exception(response['error'] ?? '获取运行时长失败');
  }
}
```

---

## 📊 设备映射速查表

### 回转窑（9个）
```dart
'short_hopper_1' → '窑7'  ✅有料仓
'short_hopper_2' → '窑6'  ✅有料仓
'short_hopper_3' → '窑5'  ✅有料仓
'short_hopper_4' → '窑4'  ✅有料仓
'no_hopper_1'    → '窑2'  ❌无料仓
'no_hopper_2'    → '窑1'  ❌无料仓
'long_hopper_1'  → '窑8'  ✅有料仓
'long_hopper_2'  → '窑3'  ✅有料仓
'long_hopper_3'  → '窑9'  ✅有料仓
```

### 辊道窑（7个）
```dart
'zone1'              → '辊道窑分区1'
'zone2'              → '辊道窑分区2'
'zone3'              → '辊道窑分区3'
'zone4'              → '辊道窑分区4'
'zone5'              → '辊道窑分区5'
'zone6'              → '辊道窑分区6'
'roller_kiln_total'  → '辊道窑合计' ⚠️运行时长为平均值
```

### SCR设备（4个）
```dart
'scr_1'       → 'SCR北_燃气表'  🔥仅燃气数据
'scr_2'       → 'SCR南_燃气表'  🔥仅燃气数据
'scr_1_pump'  → 'SCR北_氨水泵'  ⚡仅电量数据
'scr_2_pump'  → 'SCR南_氨水泵'  ⚡仅电量数据
```

### 风机（2个）
```dart
'fan_1' → 'SCR北_风机'
'fan_2' → 'SCR南_风机'
```

---

## 🎯 使用示例

### 1. 在导出对话框中使用设备名称映射

```dart
// 在 data_export_dialog.dart 中
import 'package:ceramic_workshop_app/utils/device_name_mapper.dart';

// 获取设备显示名称
String deviceName = DeviceNameMapper.getDeviceName(deviceId);

// 示例：导出运行时长统计
void _exportRuntimeData(Map<String, dynamic> data) {
  // 遍历回转窑
  for (var hopper in data['hoppers']) {
    String deviceId = hopper['device_id'];
    String deviceName = DeviceNameMapper.getDeviceName(deviceId); // '窑7'
    
    // 添加到Excel
    for (var record in hopper['daily_records']) {
      sheet.appendRow([
        deviceName,                    // 设备名称
        record['date'],                // 日期
        record['start_time'],          // 起始时间
        record['end_time'],            // 终止时间
        record['runtime_hours'],       // 运行时长
      ]);
    }
  }
  
  // 遍历辊道窑分区
  for (var zone in data['roller_kiln_zones']) {
    String deviceId = zone['device_id'];
    String deviceName = DeviceNameMapper.getDeviceName(deviceId); // '辊道窑分区1'
    
    // 添加到Excel...
  }
  
  // 辊道窑合计
  var total = data['roller_kiln_total'];
  String totalName = DeviceNameMapper.getDeviceName(total['device_id']); // '辊道窑合计'
  
  // SCR氨水泵
  for (var scr in data['scr_devices']) {
    String deviceName = DeviceNameMapper.getDeviceName(scr['device_id']); // 'SCR北_氨水泵'
    // 添加到Excel...
  }
  
  // 风机
  for (var fan in data['fan_devices']) {
    String deviceName = DeviceNameMapper.getDeviceName(fan['device_id']); // 'SCR北_风机'
    // 添加到Excel...
  }
}
```

### 2. 验证设备数量

```dart
// 在调用API后自动验证
try {
  final data = await _exportService.getAllDevicesRuntime(
    startTime: startTime,
    endTime: endTime,
  );
  
  // ✅ 如果设备数量不匹配，会自动抛出异常
  // 可以安全地使用数据
  _exportToExcel(data);
  
} catch (e) {
  // ❌ 捕获异常并显示错误信息
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(content: Text('导出失败: $e')),
  );
}
```

### 3. 获取设备列表

```dart
// 获取所有带料仓的回转窑（用于投料量统计）
List<String> hopperKilns = DeviceNameMapper.getHopperKilnIds();
// 返回: ['short_hopper_1', 'short_hopper_2', 'short_hopper_3', 'short_hopper_4',
//        'long_hopper_1', 'long_hopper_2', 'long_hopper_3']

// 获取所有SCR燃气表（用于燃气消耗统计）
List<String> gasMeters = DeviceNameMapper.getGasMeterIds();
// 返回: ['scr_1', 'scr_2']

// 获取所有辊道窑分区
List<String> zones = DeviceNameMapper.getRollerKilnZoneIds();
// 返回: ['zone1', 'zone2', 'zone3', 'zone4', 'zone5', 'zone6']
```

---

## 📝 数据结构说明

### 1. 运行时长统计数据结构

```dart
{
  "start_time": "2026-01-26T00:00:00Z",
  "end_time": "2026-01-27T00:00:00Z",
  "hoppers": [
    {
      "device_id": "short_hopper_1",
      "device_type": "hopper",
      "total_days": 1,
      "daily_records": [
        {
          "day": 1,
          "date": "2026-01-26",
          "start_time": "2026-01-26T00:00:00Z",
          "end_time": "2026-01-26T23:59:59Z",
          "runtime_hours": 18.50
        }
      ]
    },
    // ... 其他8个回转窑
  ],
  "roller_kiln_zones": [
    {
      "device_id": "zone1",
      "device_type": "roller_kiln_zone",
      "total_days": 1,
      "daily_records": [...]
    },
    // ... 其他5个分区
  ],
  "roller_kiln_total": {
    "device_id": "roller_kiln_total",
    "device_type": "roller_kiln_total",
    "total_days": 1,
    "daily_records": [...]
  },
  "scr_devices": [
    {
      "device_id": "scr_1_pump",
      "device_type": "scr_pump",
      "total_days": 1,
      "daily_records": [...]
    },
    // ... scr_2_pump
  ],
  "fan_devices": [
    {
      "device_id": "fan_1",
      "device_type": "fan",
      "total_days": 1,
      "daily_records": [...]
    },
    // ... fan_2
  ]
}
```

### 2. 燃气消耗统计数据结构

```dart
{
  "scr_1": {
    "device_id": "scr_1",
    "total_days": 1,
    "daily_records": [
      {
        "day": 1,
        "date": "2026-01-26",
        "start_time": "2026-01-26T00:00:00Z",
        "end_time": "2026-01-26T23:59:59Z",
        "start_reading": 1234.56,
        "end_reading": 1456.78,
        "consumption": 222.22
      }
    ]
  },
  "scr_2": {...}
}
```

### 3. 投料量统计数据结构

```dart
{
  "hoppers": [
    {
      "device_id": "short_hopper_1",
      "daily_records": [
        {
          "date": "2026-01-26",
          "start_time": "2026-01-26T00:00:00Z",
          "end_time": "2026-01-26T23:59:59Z",
          "feeding_amount": 1234.56
        }
      ]
    },
    // ... 其他6个带料仓的回转窑
  ]
}
```

### 4. 电量统计数据结构

```dart
// 同运行时长统计，但每个 daily_record 包含更多字段:
{
  "day": 1,
  "date": "2026-01-26",
  "start_time": "2026-01-26T00:00:00Z",
  "end_time": "2026-01-26T23:59:59Z",
  "start_reading": 1234.56,      // 起始读数 (kWh)
  "end_reading": 1456.78,        // 截止读数 (kWh)
  "consumption": 222.22,         // 当日消耗 (kWh)
  "runtime_hours": 18.50         // 运行时长 (h)
}
```

### 5. 综合数据统计数据结构

```dart
{
  "start_time": "2026-01-26T00:00:00Z",
  "end_time": "2026-01-27T00:00:00Z",
  "total_devices": 20,
  "devices": [
    {
      "device_id": "short_hopper_1",
      "device_type": "hopper",
      "daily_records": [
        {
          "date": "2026-01-26",
          "start_time": "2026-01-26T00:00:00Z",
          "end_time": "2026-01-26T23:59:59Z",
          "gas_consumption": 0.0,           // 仅SCR有值
          "feeding_amount": 123.45,         // 仅料仓有值
          "electricity_consumption": 500.5,
          "runtime_hours": 18.5
        }
      ]
    },
    // ... 其他19个设备
  ]
}
```

---

## ⚠️ 重要提示

### 1. 辊道窑合计运行时长

```dart
// ⚠️ 辊道窑合计的运行时长是6个分区的平均值，不是总和！
var total = data['roller_kiln_total'];
var totalRuntime = total['daily_records'][0]['runtime_hours']; // 这是平均值
```

### 2. 设备数量验证

```dart
// ✅ 所有导出方法都会自动验证设备数量
// 如果数量不匹配，会抛出异常
try {
  final data = await _exportService.getAllDevicesRuntime(...);
} catch (e) {
  // 处理异常
  print('设备数量不匹配: $e');
}
```

### 3. 投料量统计不包含无料仓的窑

```dart
// ❌ 投料量统计不包含 no_hopper_1 和 no_hopper_2
// ✅ 只包含7个带料仓的回转窑
List<String> hopperKilns = DeviceNameMapper.getHopperKilnIds();
// 返回: ['short_hopper_1', ..., 'long_hopper_3'] (7个)
```

### 4. 日期格式转换

```dart
// 后端返回: ISO 8601格式 "2026-01-26T00:00:00Z"
// 前端需要: yyyyMMdd格式 "20260126"

String backendDate = "2026-01-26T00:00:00Z";
DateTime dt = DateTime.parse(backendDate);
String frontendDate = DateFormat('yyyyMMdd').format(dt); // "20260126"
```

---

## 🧪 测试建议

### 1. 测试设备数量验证

```dart
// 测试运行时长统计（应该返回20个设备）
final runtimeData = await _exportService.getAllDevicesRuntime(...);
assert(runtimeData['hoppers'].length == 9);
assert(runtimeData['roller_kiln_zones'].length == 6);
assert(runtimeData['roller_kiln_total'] != null);
assert(runtimeData['scr_devices'].length == 2);
assert(runtimeData['fan_devices'].length == 2);

// 测试燃气消耗统计（应该返回2个设备）
final gasData = await _exportService.getGasConsumption(...);
assert(gasData.length == 2);
assert(gasData.containsKey('scr_1'));
assert(gasData.containsKey('scr_2'));

// 测试投料量统计（应该返回7个设备）
final feedingData = await _exportService.getFeedingAmount(...);
assert(feedingData['hoppers'].length == 7);
```

### 2. 测试设备名称映射

```dart
// 测试回转窑映射
assert(DeviceNameMapper.getDeviceName('short_hopper_1') == '窑7');
assert(DeviceNameMapper.getDeviceName('no_hopper_1') == '窑2');

// 测试辊道窑映射
assert(DeviceNameMapper.getDeviceName('zone1') == '辊道窑分区1');
assert(DeviceNameMapper.getDeviceName('roller_kiln_total') == '辊道窑合计');

// 测试SCR映射
assert(DeviceNameMapper.getDeviceName('scr_1') == 'SCR北_燃气表');
assert(DeviceNameMapper.getDeviceName('scr_1_pump') == 'SCR北_氨水泵');

// 测试风机映射
assert(DeviceNameMapper.getDeviceName('fan_1') == 'SCR北_风机');
```

### 3. 测试设备类型判断

```dart
// 测试料仓判断
assert(DeviceNameMapper.hasHopper('short_hopper_1') == true);
assert(DeviceNameMapper.hasHopper('no_hopper_1') == false);

// 测试燃气表判断
assert(DeviceNameMapper.isGasMeter('scr_1') == true);
assert(DeviceNameMapper.isGasMeter('scr_1_pump') == false);
```

---

## 📚 相关文档

- `lib/utils/device_name_mapper.dart` - 设备名称映射工具类
- `lib/api/api.dart` - API 定义
- `lib/services/data_export_service.dart` - 数据导出服务
- `vdoc/device_name_mapping.md` - 后端设备名称映射表
- `vdoc/export_quick_reference.md` - 快速参考卡片

---

## ✅ 总结

前端代码已全部更新完成，主要改动：

1. ✅ 创建了 `DeviceNameMapper` 工具类（22个设备映射）
2. ✅ 更新了 `api.dart`（添加详细注释）
3. ✅ 更新了 `data_export_service.dart`（添加设备数量验证）

**下一步**: 在 `data_export_dialog.dart` 中使用 `DeviceNameMapper` 进行设备名称映射和导出。

---

**版本**: v1.0  
**更新日期**: 2026-01-27  
**维护者**: Ceramic Workshop Team


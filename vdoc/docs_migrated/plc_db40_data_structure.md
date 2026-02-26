# PLC DB40 数据块结构定义 - 磨料车间

## 数据块概述

**数据块编号**: DB40  
**数据块名称**: 磨料车间监控数据 (Grinding Workshop Monitoring Data)  
**总大小**: 约 400 字节  
**字节序**: Big Endian (西门子 S7-1200 标准)  
**刷新频率**: ≤ 5 秒

---

## 数据结构表

| 从站结构体名 | 功能名称 | 功能子项 | 名称 | 地址偏移量 | 格式 | 备注 |
|------------|---------|---------|------|-----------|------|------|
| **Hopper** | Weight | CurrentWeight | 料仓1实时重量 | 0 | REAL | 单位：kg，精度：0.1kg |
| | | CapacityPercent | 料仓1容量百分比 | 4 | REAL | 范围：0.0-100.0，单位：% |
| | | TotalCapacity | 料仓1总容量 | 8 | REAL | 单位：kg，用于计算百分比 |
| | | WeightLowAlarm | 料仓1重量低限告警 | 12 | BOOL | bit 0: 1=告警，0=正常 |
| | | Reserved1 | 预留 | 13 | BYTE | 预留字节 |
| | | Reserved2 | 预留 | 14 | WORD | 预留字 |
| **Hopper** | Weight | CurrentWeight | 料仓2实时重量 | 16 | REAL | 单位：kg，精度：0.1kg |
| | | CapacityPercent | 料仓2容量百分比 | 20 | REAL | 范围：0.0-100.0，单位：% |
| | | TotalCapacity | 料仓2总容量 | 24 | REAL | 单位：kg |
| | | WeightLowAlarm | 料仓2重量低限告警 | 28 | BOOL | bit 0: 1=告警，0=正常 |
| | | Reserved1 | 预留 | 29 | BYTE | 预留字节 |
| | | Reserved2 | 预留 | 30 | WORD | 预留字 |
| **Hopper** | Weight | CurrentWeight | 料仓3实时重量 | 32 | REAL | 单位：kg，精度：0.1kg |
| | | CapacityPercent | 料仓3容量百分比 | 36 | REAL | 范围：0.0-100.0，单位：% |
| | | TotalCapacity | 料仓3总容量 | 40 | REAL | 单位：kg |
| | | WeightLowAlarm | 料仓3重量低限告警 | 44 | BOOL | bit 0: 1=告警，0=正常 |
| | | Reserved1 | 预留 | 45 | BYTE | 预留字节 |
| | | Reserved2 | 预留 | 46 | WORD | 预留字 |
| **SCR_Unit1** | Fan | Power | 风机1-1功率 | 48 | REAL | 单位：kW，精度：0.01kW |
| | | AccumEnergy | 风机1-1累计电量 | 52 | REAL | 单位：kWh，精度：0.1kWh |
| | | Status | 风机1-1运行状态 | 56 | BOOL | bit 0: 1=运行，0=停止 |
| | | Reserved | 预留 | 57 | BYTE | 预留字节 |
| | | Reserved | 预留 | 58 | WORD | 预留字 |
| **SCR_Unit1** | Fan | Power | 风机1-2功率 | 60 | REAL | 单位：kW |
| | | AccumEnergy | 风机1-2累计电量 | 64 | REAL | 单位：kWh |
| | | Status | 风机1-2运行状态 | 68 | BOOL | bit 0: 1=运行，0=停止 |
| | | Reserved | 预留 | 69 | BYTE | 预留字节 |
| | | Reserved | 预留 | 70 | WORD | 预留字 |
| **SCR_Unit1** | Fan | Power | 风机1-3功率 | 72 | REAL | 单位：kW（如只有2台风机，此字段预留） |
| | | AccumEnergy | 风机1-3累计电量 | 76 | REAL | 单位：kWh |
| | | Status | 风机1-3运行状态 | 80 | BOOL | bit 0: 1=运行，0=停止 |
| | | Reserved | 预留 | 81 | BYTE | 预留字节 |
| | | Reserved | 预留 | 82 | WORD | 预留字 |
| **SCR_Unit1** | Pump | Power | 氨水泵1功率 | 84 | REAL | 单位：kW，精度：0.01kW |
| | | AccumEnergy | 氨水泵1累计电量 | 88 | REAL | 单位：kWh，精度：0.1kWh |
| | | Status | 氨水泵1运行状态 | 92 | BOOL | bit 0: 1=运行，0=停止 |
| | | Reserved | 预留 | 93 | BYTE | 预留字节 |
| | | Reserved | 预留 | 94 | WORD | 预留字 |
| **SCR_Unit1** | Gas | FlowRate | 燃气管路1-1流速 | 96 | REAL | 单位：m³/h，精度：0.01m³/h |
| | | AccumConsumption | 燃气管路1-1累计消耗 | 100 | REAL | 单位：m³，精度：0.1m³ |
| | | FlowRate | 燃气管路1-2流速 | 104 | REAL | 单位：m³/h |
| | | AccumConsumption | 燃气管路1-2累计消耗 | 108 | REAL | 单位：m³ |
| **SCR_Unit2** | Fan | Power | 风机2-1功率 | 112 | REAL | 单位：kW，精度：0.01kW |
| | | AccumEnergy | 风机2-1累计电量 | 116 | REAL | 单位：kWh，精度：0.1kWh |
| | | Status | 风机2-1运行状态 | 120 | BOOL | bit 0: 1=运行，0=停止 |
| | | Reserved | 预留 | 121 | BYTE | 预留字节 |
| | | Reserved | 预留 | 122 | WORD | 预留字 |
| **SCR_Unit2** | Fan | Power | 风机2-2功率 | 124 | REAL | 单位：kW |
| | | AccumEnergy | 风机2-2累计电量 | 128 | REAL | 单位：kWh |
| | | Status | 风机2-2运行状态 | 132 | BOOL | bit 0: 1=运行，0=停止 |
| | | Reserved | 预留 | 133 | BYTE | 预留字节 |
| | | Reserved | 预留 | 134 | WORD | 预留字 |
| **SCR_Unit2** | Fan | Power | 风机2-3功率 | 136 | REAL | 单位：kW（如只有2台风机，此字段预留） |
| | | AccumEnergy | 风机2-3累计电量 | 140 | REAL | 单位：kWh |
| | | Status | 风机2-3运行状态 | 144 | BOOL | bit 0: 1=运行，0=停止 |
| | | Reserved | 预留 | 145 | BYTE | 预留字节 |
| | | Reserved | 预留 | 146 | WORD | 预留字 |
| **SCR_Unit2** | Pump | Power | 氨水泵2功率 | 148 | REAL | 单位：kW，精度：0.01kW |
| | | AccumEnergy | 氨水泵2累计电量 | 152 | REAL | 单位：kWh，精度：0.1kWh |
| | | Status | 氨水泵2运行状态 | 156 | BOOL | bit 0: 1=运行，0=停止 |
| | | Reserved | 预留 | 157 | BYTE | 预留字节 |
| | | Reserved | 预留 | 158 | WORD | 预留字 |
| **SCR_Unit2** | Gas | FlowRate | 燃气管路2-1流速 | 160 | REAL | 单位：m³/h，精度：0.01m³/h |
| | | AccumConsumption | 燃气管路2-1累计消耗 | 164 | REAL | 单位：m³，精度：0.1m³ |
| | | FlowRate | 燃气管路2-2流速 | 168 | REAL | 单位：m³/h |
| | | AccumConsumption | 燃气管路2-2累计消耗 | 172 | REAL | 单位：m³ |
| **System** | Status | DataValid | 数据有效性标志 | 176 | BOOL | bit 0: 1=有效，0=无效 |
| | | UpdateTime | 数据更新时间戳 | 177 | DWORD | Unix时间戳（秒），用于数据同步 |
| | | Reserved | 预留区域 | 181 | BYTE[19] | 预留19字节，用于扩展 |

---

## 数据结构说明

### 1. 料仓重量数据 (Hopper)

- **料仓数量**: 3个（可根据实际需求扩展）
- **每个料仓占用**: 16字节
- **字段说明**:
  - `CurrentWeight`: 实时重量，单位 kg，精度 0.1kg
  - `CapacityPercent`: 容量百分比 = (CurrentWeight / TotalCapacity) × 100
  - `TotalCapacity`: 料仓总容量，用于计算百分比和告警阈值
  - `WeightLowAlarm`: 当 CurrentWeight < 告警阈值时，PLC 置位此标志

### 2. SCR设备单元1 (SCR_Unit1)

#### 2.1 风机数据 (Fan)
- **风机数量**: 最多3台（可根据实际配置调整）
- **每台风机占用**: 12字节
- **字段说明**:
  - `Power`: 实时功率，单位 kW
  - `AccumEnergy`: 累计电量，单位 kWh，PLC 每秒累加
  - `Status`: 运行状态，1=运行，0=停止

#### 2.2 氨水泵数据 (Pump)
- **水泵数量**: 1台
- **占用**: 12字节
- **字段说明**: 同风机数据格式

#### 2.3 燃气数据 (Gas)
- **管路数量**: 2条
- **每条管路占用**: 8字节（流速4字节 + 累计消耗4字节）
- **字段说明**:
  - `FlowRate`: 实时流速，单位 m³/h
  - `AccumConsumption`: 累计消耗，单位 m³，PLC 每秒累加

### 3. SCR设备单元2 (SCR_Unit2)

结构同 SCR_Unit1，独立存储第二套设备数据。

### 4. 系统状态 (System)

- **数据有效性标志**: 用于标识 PLC 数据是否有效
- **更新时间戳**: Unix 时间戳（秒），便于数据同步和历史查询

---

## 数据读取示例

### Flutter/Dart 代码示例

```dart
// 读取料仓1重量数据
final hopper1Weight = await dataService.readReal(40, 0);      // 实时重量
final hopper1Percent = await dataService.readReal(40, 4);     // 容量百分比
final hopper1Alarm = await dataService.readBool(40, 12, 0);   // 告警状态

// 读取SCR单元1风机1数据
final fan1Power = await dataService.readReal(40, 48);        // 功率
final fan1Energy = await dataService.readReal(40, 52);       // 累计电量
final fan1Status = await dataService.readBool(40, 56, 0);    // 运行状态

// 批量读取料仓数据
final parser = await dataService.readDataBlockParsed(40, 0, 48);
final hopper1Weight = parser.getReal(0);
final hopper2Weight = parser.getReal(16);
final hopper3Weight = parser.getReal(32);
```

---

## 数据块总览

| 区域 | 起始偏移 | 结束偏移 | 大小 | 说明 |
|------|---------|---------|------|------|
| 料仓数据区 | 0 | 47 | 48字节 | 3个料仓 × 16字节 |
| SCR单元1 | 48 | 111 | 64字节 | 风机(36) + 水泵(12) + 燃气(16) |
| SCR单元2 | 112 | 175 | 64字节 | 风机(36) + 水泵(12) + 燃气(16) |
| 系统状态 | 176 | 199 | 24字节 | 状态标志 + 时间戳 + 预留 |
| **总计** | **0** | **199** | **200字节** | **建议预留至256字节** |

---

## PLC 编程注意事项

1. **字节序**: 所有多字节数据类型使用 Big Endian（西门子 S7-1200 标准）
2. **REAL 类型**: 32位 IEEE 754 浮点数，Big Endian
3. **BOOL 类型**: 使用字节的指定位，建议使用 bit 0
4. **数据更新**: PLC 程序应每1秒更新一次数据，确保刷新频率 ≤ 5秒
5. **累计量计算**: 累计电量和累计消耗应在 PLC 中每秒累加，避免上位机计算误差
6. **告警逻辑**: 重量低限告警应在 PLC 中判断并置位，上位机仅读取状态
7. **预留字段**: 预留字段初始化为 0，不要写入随机数据

---

## 扩展建议

1. **料仓数量扩展**: 如需增加料仓，按每16字节递增偏移量
2. **风机数量扩展**: 如需增加风机，按每12字节递增偏移量
3. **历史数据**: 建议在 PLC 中增加循环缓冲区，存储最近N分钟的历史数据
4. **数据校验**: 建议在数据块末尾增加 CRC16 校验字段

---

## 版本历史

| 版本 | 日期 | 修改内容 | 作者 |
|------|------|---------|------|
| 1.0 | 2025-01-XX | 初始版本，定义DB40数据结构 | - |


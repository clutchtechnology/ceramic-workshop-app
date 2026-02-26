# PLC 数据块结构分析报告

## 📋 当前数据结构概览

根据提供的Excel表格，数据结构如下：

### TempSensor1 (温度传感器1)
- **Temp** (温度): offset 0, uint16, 十分位
- **Humi** (湿度): offset 2, uint16, 十分位  
- **isOnline** (状态): offset 4, uint16

### TempSensor2 (温度传感器2)
- **Temp**: offset 6, uint16, 十分位
- **Humi**: offset 8, uint16, 十分位
- **isOnline**: offset 10, uint16

### Motor (电机)
**Status组:**
- **Temp** (温度): offset 12, uint16, 十分位
- **Power** (有功功率): offset 14, uint16
- **Voltage** (电压): offset 16, uint16, 十分位
- **Amp** (电流): offset 18, uint16, 十分位

**Control组:**
- **Speed** (最大速度): offset 20, uint16
- **Position** (目标位置): offset 22, uint64
- **Torque** (最大力矩): offset 30, uint16

---

##  合理的地方

### 1. **地址对齐合理**
- uint16 数据按 2 字节对齐 ✓
- uint64 数据按 8 字节对齐（Position 从 22 开始，到 30，正好 8 字节）✓
- 没有地址重叠 ✓

### 2. **数据组织清晰**
- 按设备分组（TempSensor1, TempSensor2, Motor）✓
- Motor 内部按功能分组（Status, Control）✓

### 3. **数据类型选择基本合理**
- 温度、湿度、电压、电流使用 uint16 + 十分位，精度足够 ✓
- Position 使用 uint64，支持大范围位置值 ✓

---

##  存在的问题和建议

### 🔴 **严重问题**

#### 1. **isOnline 使用 uint16 浪费空间**
```dart
// 当前设计
isOnline: offset 4, uint16  // 浪费 2 字节，只用 1 bit

// 建议改进
isOnline: offset 4, BOOL (bit 0)  // 只占 1 bit
// 或者如果必须用字节，至少用 BYTE (uint8)
isOnline: offset 4, BYTE  // 只占 1 字节
```

**影响：** 浪费存储空间，如果传感器数量多，浪费会累积

#### 2. **缺少数据校验字段**
```dart
// 建议添加
CRC16: offset 32, uint16  // 数据校验和
// 或者
Checksum: offset 32, BYTE  // 简单校验
```

**影响：** 无法检测数据传输错误，可能导致错误数据被使用

#### 3. **缺少时间戳**
```dart
// 建议添加
Timestamp: offset 34, DWORD  // Unix时间戳（秒）
// 或者
Timestamp: offset 34, LREAL  // 高精度时间戳
```

**影响：** 无法追踪数据采集时间，不利于历史数据分析和故障排查

---

### 🟡 **中等问题**

#### 4. **数据类型不一致**
- TempSensor 的 isOnline 用 uint16
- Motor 的状态信息分散在不同字段
- 建议统一状态字段格式

**建议：**
```dart
// 统一状态结构
struct DeviceStatus {
    BYTE flags;      // bit0: isOnline, bit1: isError, bit2: isWarning
    BYTE errorCode;  // 错误代码
    WORD reserved;   // 预留
}
```

#### 5. **缺少单位说明**
- Excel 中只有"十分位"说明，缺少：
  - 温度单位（℃/℉）
  - 功率单位（W/kW）
  - 速度单位（rpm/rad/s）
  - 位置单位（mm/脉冲数）

**建议：** 在备注中明确单位

#### 6. **uint16 精度可能不足**
- 温度范围：如果使用 uint16 + 十分位，范围是 0-6553.5
- 对于工业应用可能足够，但如果需要更高精度或更大范围，建议使用 REAL (float32)

**建议：**
```dart
// 高精度方案
Temp: offset 0, REAL  // 32位浮点数，精度更高
```

---

### 🟢 **轻微问题**

#### 7. **缺少预留空间**
- 数据结构紧凑，没有预留扩展空间
- 如果后续需要添加字段，可能需要重新设计整个DB块

**建议：**
```dart
// 在每个设备结构末尾预留空间
TempSensor1: 0-5 (实际使用) + 6-15 (预留)
TempSensor2: 6-11 (实际使用) + 12-21 (预留)
Motor: 12-31 (实际使用) + 32-63 (预留)
```

#### 8. **功能分组不够清晰**
- Motor 的 Status 和 Control 混在一起
- 建议明确区分只读状态和可写控制参数

**建议：**
```dart
// 明确分组
MotorStatus: offset 12-19  // 只读状态
MotorControl: offset 20-31  // 可写控制参数
```

---

##  改进建议的数据结构

### 方案A：优化当前结构（最小改动）

```dart
// TempSensor1 (8字节，预留2字节)
struct TempSensor1 {
    WORD Temp;        // offset 0, 十分位
    WORD Humi;        // offset 2, 十分位
    BYTE Status;      // offset 4, bit0: isOnline, bit1-7: 预留
    BYTE Reserved;    // offset 5, 预留
    WORD CRC;         // offset 6, 校验和（可选）
}

// TempSensor2 (8字节)
struct TempSensor2 {
    WORD Temp;        // offset 8
    WORD Humi;        // offset 10
    BYTE Status;      // offset 12
    BYTE Reserved;    // offset 13
    WORD CRC;         // offset 14
}

// Motor Status (12字节)
struct MotorStatus {
    WORD Temp;        // offset 16, 十分位
    WORD Power;       // offset 18
    WORD Voltage;     // offset 20, 十分位
    WORD Amp;         // offset 22, 十分位
    BYTE Status;      // offset 24, bit0: isRunning, bit1: isError
    BYTE ErrorCode;   // offset 25
    WORD Reserved;    // offset 26
    WORD CRC;         // offset 28
}

// Motor Control (16字节)
struct MotorControl {
    WORD Speed;       // offset 30
    LREAL Position;   // offset 32 (8字节对齐)
    WORD Torque;      // offset 40
    WORD Reserved;    // offset 42
    DWORD Timestamp;  // offset 44, 最后更新时间
}

// 总大小：48字节 + 预留空间
```

### 方案B：使用REAL类型（更高精度）

```dart
// TempSensor (16字节)
struct TempSensor {
    REAL Temp;        // offset 0, 直接浮点数
    REAL Humi;        // offset 4
    BYTE Status;      // offset 8
    BYTE Reserved[3]; // offset 9-11
    DWORD Timestamp;  // offset 12
}

// Motor Status (24字节)
struct MotorStatus {
    REAL Temp;        // offset 0
    REAL Power;       // offset 4
    REAL Voltage;     // offset 8
    REAL Amp;         // offset 12
    BYTE Status;      // offset 16
    BYTE ErrorCode;   // offset 17
    WORD Reserved;    // offset 18
    DWORD Timestamp;  // offset 20
}
```

---

##  最终建议

### 优先级1（必须改进）
1.  **isOnline 改为 BOOL 或 BYTE** - 节省空间
2.  **添加数据校验字段** - 保证数据可靠性
3.  **添加时间戳** - 支持历史数据分析

### 优先级2（强烈建议）
4.  **统一状态字段格式** - 提高可维护性
5.  **明确单位说明** - 避免理解偏差
6.  **预留扩展空间** - 便于后续扩展

### 优先级3（可选优化）
7.  **考虑使用 REAL 类型** - 如果精度要求高
8.  **明确读写权限** - 区分状态和控制参数

---

##  与现有代码的兼容性

当前代码使用 `S7DataParser` 可以支持：
-  uint16 (WORD) - `getWord()`
-  uint64 (LREAL) - `getLReal()` (但注意：LREAL是double，不是uint64)
-  uint32 (DWORD) - `getDWord()`
-  BOOL - `getBool()`

**注意：** 如果 Position 真的是 uint64，需要添加 `getUint64()` 方法。

---

## 🔄 迁移建议

如果决定改进数据结构：

1. **版本控制：** 在DB块开头添加版本号字段
   ```dart
   Version: offset 0, BYTE  // 数据结构版本号
   ```

2. **向后兼容：** 保留旧字段，新字段追加到末尾

3. **数据迁移脚本：** 编写PLC程序将旧数据迁移到新结构

---

## 📌 总结

| 评估项 | 评分 | 说明 |
|--------|------|------|
| **地址对齐** |  | 完美对齐 |
| **数据类型选择** |  | 基本合理，但有优化空间 |
| **空间利用** |  | isOnline浪费空间 |
| **可扩展性** |  | 缺少预留空间 |
| **数据可靠性** |  | 缺少校验和时间戳 |
| **文档完整性** |  | 基本清晰，但缺少单位说明 |

**总体评价：** 结构基本合理，但需要优化空间利用和数据可靠性。





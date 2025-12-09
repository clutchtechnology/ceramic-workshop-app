# Ceramic Workshop Digital Twin System - AI Coding Instructions

> **Reading Priority for AI:**
>
> 1. **[CRITICAL]** - Hard constraints, must strictly follow
> 2. **[IMPORTANT]** - Key specifications
> 3. Other content - Reference information

---

## 1. Project Overview

| Property          | Value                                                                                        |
| ----------------- | -------------------------------------------------------------------------------------------- |
| **Type**          | Windows Desktop Industrial Monitoring App                                                    |
| **Stack**         | Flutter 3.22.x + Dart                                                                        |
| **Protocol**      | Siemens S7-1200 PLC (dart_snap7)                                                             |
| **Target**        | 21" Industrial Touch Panel (1536×864)                                                        |
| **Core Features** | Digital Twin visualization, Temperature monitoring, Energy consumption, Material feed system |

---

## 2. Project Structure

```
lib/
├── main.dart           # App entry point
├── pages/              # UI pages (Tab-based navigation)
│   └── digital_twin_page.dart
├── widgets/            # Reusable UI components
│   └── tech_line_widgets.dart
├── models/             # Data models
├── services/           # Business logic & API services
└── utils/              # Utility functions & helpers
```

---

## 3. Equipment Configuration

### 3.1 Roller Kiln (辊道窑)

```yaml
Roller Kiln:
  quantity: 1 (long kiln body)
  zones: Multiple temperature zones
  monitoring:
    - Zone temperatures (2D/3D visualization)
    - Energy consumption (V, A, kW)
  features:
    - Real-time temperature display on model
    - Historical temperature curves
    - Energy trend charts
```

### 3.2 Rotary Kiln (回转窑)

```yaml
Rotary Kiln:
  quantity: 3 units
  zones: 8 temperature zones per unit
  monitoring:
    - Zone temperatures (2D/3D visualization)
    - Energy consumption (V, A, kW)
    - Feed speed (kg/h)
    - Hopper weight (with capacity %)
  features:
    - Real-time temperature on model
    - Feed speed curve
    - Low weight alarm
    - Historical data query (hour/day/week/month)
```

### 3.3 SCR Equipment (SCR 设备)

```yaml
SCR Equipment:
  quantity: 2 sets
  components:
    - Fans (multiple per set)
    - Ammonia pumps
    - Gas pipelines (2 per set)
  monitoring:
    - Fan power & cumulative energy
    - Pump power & cumulative energy
    - Gas flow rate (2 pipelines)
    - Running status (ON/OFF)
  features:
    - Daily/Monthly/Yearly statistics
    - Multi-device comparison
    - Historical trend charts (bar/line)
```

---

## 4. [CRITICAL] UI/Navigation Requirements

### 4.1 Tab-Based Navigation

- **[CRITICAL]** All modules organized as Tabs
- Click tab title to switch modules
- Modules: Roller Kiln | Rotary Kiln | SCR Equipment | Settings

### 4.2 Window Configuration

```dart
// [CRITICAL] Fixed window size, no resize
const fixedSize = Size(1536, 864);
await windowManager.setResizable(false);
titleBarStyle: TitleBarStyle.hidden
```

### 4.3 Layout Pattern

```
┌─────────────────────────────────────────────────────────┐
│  Tab Bar: [Roller Kiln] [Rotary Kiln] [SCR] [Settings]  │
├─────────────────────────────────────────────────────────┤
│                                                         │
│   2D/3D Digital Twin Model                              │
│   (Temperature zones displayed on model)                │
│                                                         │
├─────────────────────────────────────────────────────────┤
│  Real-time Data Cards    │    Historical Charts         │
│  - Temperature values    │    - Time range selector     │
│  - Energy (V/A/kW)       │    - Trend curves            │
│  - Status indicators     │    - Data comparison         │
└─────────────────────────────────────────────────────────┘
```

---

## 5. [CRITICAL] Data Specifications

### 5.1 Refresh Rates

| Data Type       | Refresh Rate | Sync Delay |
| --------------- | ------------ | ---------- |
| Temperature     | ≤5 seconds   | ≤3 seconds |
| Energy (V/A/kW) | ≤5 seconds   | -          |
| Feed Speed      | ≤5 seconds   | -          |
| Hopper Weight   | ≤5 seconds   | -          |
| Gas Flow        | ≤5 seconds   | -          |

### 5.2 Display Format

- **Text + Icon**: All real-time values shown with icon + numeric value
- **Units**: Always display units (°C, V, A, kW, kg/h, %)
- **Status**: Running (green) / Stopped (gray) indicators

### 5.3 Historical Data Query

```yaml
Features:
  - Custom time range selection (start/end)
  - Multi-dimension: hour, day, week, month, year
  - Chart types: Line chart, Bar chart, Data table
  - Multi-device comparison support
```

---

## 6. [IMPORTANT] UI Design - Industrial HMI/SCADA Style

### 6.1 Design Principles

**Functionality > Clarity > Reliability > Aesthetics**

### 6.2 Color System (Tech/Sci-Fi Style)

```dart
class TechColors {
  // Backgrounds
  static const bgDeep = Color(0xFF0d1117);
  static const bgDark = Color(0xFF161b22);
  static const bgMedium = Color(0xFF21262d);

  // Glow effects
  static const glowCyan = Color(0xFF00d4ff);
  static const glowGreen = Color(0xFF00ff88);
  static const glowOrange = Color(0xFFff9500);
  static const glowRed = Color(0xFFff3b30);

  // Text
  static const textPrimary = Color(0xFFe6edf3);
  static const textSecondary = Color(0xFF8b949e);

  // Status (ISA-101 Standard)
  static const statusNormal = Color(0xFF00ff88);   // Green: Running
  static const statusWarning = Color(0xFFffcc00);  // Yellow: Warning
  static const statusAlarm = Color(0xFFff3b30);    // Red: Alarm (blink)
  static const statusOffline = Color(0xFF484f58);  // Gray: Stopped
}
```

### 6.3 Component Specs

| Component        | Size        | Font                        |
| ---------------- | ----------- | --------------------------- |
| KPI Card         | 160×80px    | Roboto Mono, 24-48px        |
| Value Display    | -           | 32-48px, weight 500-700     |
| Status Indicator | 12-16px dot | Solid fill, pulse animation |
| Data Table       | 28-32px row | Label 12-14px               |

---

## 7. Settings Module Requirements

### 7.1 Configuration Options

```yaml
Server Config:
  - IP address
  - Port number

PLC Config:
  - IP address
  - Port
  - Communication protocol parameters

Database Config:
  - Connection address
  - Port
  - Username/Password

Sensor Config:
  - Batch or individual sensor addresses
  - Modbus addresses
  - Data points
```

### 7.2 Configuration Features

- **[IMPORTANT]** Auto connection test after modification
- **[IMPORTANT]** Save config persistently (survive restart)
- **[IMPORTANT]** Admin permission required for access

---

## 8. Technical Conventions

### 8.1 Dependencies

```yaml
charts: fl_chart
state_management: StatefulWidget (current) / flutter_bloc (recommended)
database: sqflite_common_ffi (Windows SQLite)
plc_communication: dart_snap7
window_management: window_manager
```

### 8.2 Data Types (S7 Protocol)

```
BOOL, BYTE, WORD, DWORD, INT, DINT, REAL
[CRITICAL] All data uses Big Endian byte order
```

### 8.3 UI Fixed Values (Before PLC Integration)

**说明：** 在 PLC 数据接入前，所有数据显示使用固定值，仅用于 UI 调试和界面开发。

```yaml
产线概览 (Production Line Overview):
  产品一:
    progress: 0.0        # 完成率（待PLC数据）
    orderQty: 0          # 订单量（待PLC数据）
    completedQty: 0      # 成品量（待PLC数据）
  产品二:
    progress: 0.0
    orderQty: 0
    completedQty: 0
  总体生产情况:
    计划: 0              # 计划产量（待PLC数据）
    完成: 0              # 完成产量（待PLC数据）
    进度: "0%"           # 进度百分比（待PLC数据）

设备情况 (Equipment Status):
  - 所有设备默认状态: offline (灰色离线状态，待PLC数据)
  - 设备列表:
    - VTC-16A-11 (立式加工中心)
    - VTC-16A-12 (立式加工中心)
    - XH-718A (卧式加工中心)
    - XH2420C (龙门加工中心)

环境指标 (Environment Data):
  temperature: 0.0     # 环境温度 °C（待PLC数据）
  humidity: 0.0        # 环境湿度 %（待PLC数据）
  power: 0.0           # 实时电量 kW·h（待PLC数据）
  ratedPower: 0.0      # 额定功率 kW（待PLC数据）
  actualPower: 0.0     # 实际功率 kW（待PLC数据）

警报信息 (Alarm Data):
  - 固定显示3条示例警报（仅用于UI展示）
  - 警报类型: "紧急设备", "故障设备"
  - 内容: "危险情况及原因", "故障情况及原因", "解决建议"
  - 严重级别: alarm (红色闪烁), warning (黄色)

订单预测 (Order Prediction):
  订单产品一: "0h0min"  # 预测完成时间（待PLC数据）
  订单产品二: "0h0min"
  订单产品三: "0h0min"

产量预测图表 (Production Chart):
  - 显示8个柱状条
  - 仅用于UI样式展示，暂无实际数据
```

**[IMPORTANT] 数据接入说明：**

- 所有固定值字段均标注"待 PLC 数据"
- UI 开发完成后，需在 `lib/services/` 创建 PLC 数据服务
- 数据更新逻辑需符合 5.1 节刷新率要求（≤5 秒）
- 状态变化需实时反映：离线 → 运行 → 警告 → 故障

---

## 9. File Organization Guidelines

### 9.1 Pages (`lib/pages/`)

- One file per tab/module
- Naming: `{module_name}_page.dart`
- Example: `roller_kiln_page.dart`, `rotary_kiln_page.dart`, `scr_page.dart`, `settings_page.dart`

### 9.2 Widgets (`lib/widgets/`)

- Reusable UI components
- Naming: `{component_type}_widget.dart`
- Example: `temperature_card.dart`, `energy_chart.dart`, `status_indicator.dart`

### 9.3 Models (`lib/models/`)

- Data structures and entities
- Naming: `{entity_name}_model.dart`
- Example: `kiln_data.dart`, `sensor_config.dart`

### 9.4 Services (`lib/services/`)

- Business logic and API calls
- Naming: `{service_name}_service.dart`
- Example: `plc_service.dart`, `database_service.dart`, `config_service.dart`

### 9.5 Utils (`lib/utils/`)

- Helper functions and constants
- Example: `constants.dart`, `formatters.dart`, `validators.dart`

---

## 10. Development Commands

```powershell
# Run in development mode
flutter run -d windows

# Build release version
flutter build windows

# Analyze code
flutter analyze
```

---

## 11. Alarm System

### 11.1 Alarm Types

| Type                  | Condition          | Action               |
| --------------------- | ------------------ | -------------------- |
| Low Hopper Weight     | Weight < threshold | Visual + Sound alert |
| Temperature Deviation | Out of range       | Warning indicator    |
| Communication Lost    | PLC disconnect     | Status indicator     |

### 11.2 Alarm Display

- Flash animation for critical alarms
- Alarm summary in header
- Historical alarm log

---

## 12. Troubleshooting

| Issue                 | Solution                                              |
| --------------------- | ----------------------------------------------------- |
| VS 2019 required      | Flutter 3.22.x needs VS 2019 Build Tools              |
| libsnap7.dll missing  | Place 64-bit DLL in `build\windows\x64\runner\Debug\` |
| PLC connection failed | Check IP and rack/slot (S7-1200: rack=0, slot=1)      |
| Data parsing error    | Ensure Big Endian byte order                          |

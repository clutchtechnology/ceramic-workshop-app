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

## 12. [CRITICAL] Flutter 性能优化与内存泄漏防止 (奥卡姆剃刀原则)

> **核心原则**: 如无必要，勿增实体。代码越简单，bug 越少，内存泄漏风险越低。

### 12.1 Timer 生命周期管理 ⏱️

**问题根源**: Timer 是工控 App 卡死的**头号杀手**。未正确销毁的 Timer 会在后台持续运行，累积导致内存泄漏和 UI 卡死。

```dart
// ❌ 致命错误：Timer 未取消
class _MyPageState extends State<MyPage> {
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(Duration(seconds: 5), (_) => _fetchData());
  }
  // 缺少 dispose() - Timer 永远不会停止！
}

// ✅ 正确做法：完整的生命周期管理
class _MyPageState extends State<MyPage> {
  Timer? _timer;
  bool _isPolling = false;

  @override
  void initState() {
    super.initState();
    _startPolling();
  }

  void _startPolling() {
    if (_isPolling) return; // 防止重复启动
    _isPolling = true;
    _timer = Timer.periodic(Duration(seconds: 5), (_) {
      if (mounted) _fetchData(); // 检查 mounted 状态
    });
  }

  void pausePolling() {
    _timer?.cancel();
    _timer = null;
    _isPolling = false;
  }

  void resumePolling() {
    if (!_isPolling) _startPolling();
  }

  @override
  void dispose() {
    pausePolling(); // 确保 Timer 被取消
    super.dispose();
  }
}
```

**[CRITICAL] Timer 检查清单**:

- [ ] 每个 Timer.periodic 必须有对应的 cancel()
- [ ] dispose() 中必须取消所有 Timer
- [ ] Timer 回调必须检查 `mounted` 状态
- [ ] Tab 切换时暂停非活跃页面的 Timer
- [ ] **禁止**使用 `Stream.periodic` 替代 Timer（更难控制生命周期）

### 12.2 HTTP Client 连接管理 🌐

**问题根源**: HTTP 连接池耗尽或连接卡死导致后续请求超时，最终 UI 无响应。

```dart
// ❌ 错误：每次请求创建新 Client
Future<void> fetchData() async {
  final client = http.Client();
  final response = await client.get(Uri.parse(url));
  // client 从未关闭，连接泄漏！
}

// ❌ 错误：static final 无重连机制
class ApiClient {
  static final _client = http.Client(); // 永不更新的连接
}

// ✅ 正确做法：单例 + 超时 + 重连机制
class ApiClient {
  static final ApiClient _instance = ApiClient._internal();
  factory ApiClient() => _instance;
  ApiClient._internal();

  http.Client _client = http.Client();
  DateTime _lastRefresh = DateTime.now();
  static const _refreshInterval = Duration(minutes: 30);

  http.Client get client {
    if (DateTime.now().difference(_lastRefresh) > _refreshInterval) {
      _client.close();
      _client = http.Client();
      _lastRefresh = DateTime.now();
    }
    return _client;
  }

  Future<http.Response> get(String path) async {
    return client.get(Uri.parse('$baseUrl$path'))
        .timeout(const Duration(seconds: 10)); // 必须设置超时！
  }

  void dispose() {
    _client.close();
  }
}
```

**[CRITICAL] HTTP 检查清单**:

- [ ] 所有 HTTP 请求必须设置 `timeout`（建议 10-15 秒）
- [ ] 使用单例 ApiClient，避免创建多个 Client
- [ ] 定期刷新 HTTP Client（建议 30 分钟）
- [ ] 异常捕获必须包含 `TimeoutException` 和 `SocketException`

### 12.3 导航架构选择 🧭

**问题根源**: `IndexedStack` 会同时保持所有子页面存活，每个页面的 Timer 都在后台运行！

```dart
// ⚠️ 危险：IndexedStack 保持所有页面存活
IndexedStack(
  index: _currentIndex,
  children: [
    Page1(), // Timer 运行中
    Page2(), // Timer 运行中
    Page3(), // Timer 运行中
    Page4(), // Timer 运行中
  ], // 4个页面的 Timer 同时运行！
)

// ✅ 正确做法1：使用 GlobalKey 控制页面状态
final _page1Key = GlobalKey<_Page1State>();
final _page2Key = GlobalKey<_Page2State>();

void _onTabChanged(int index) {
  // 暂停所有页面的轮询
  _page1Key.currentState?.pausePolling();
  _page2Key.currentState?.pausePolling();

  // 只恢复当前页面的轮询
  switch (index) {
    case 0: _page1Key.currentState?.resumePolling(); break;
    case 1: _page2Key.currentState?.resumePolling(); break;
  }
}

// ✅ 正确做法2：使用 PageView 按需加载
PageView(
  controller: _pageController,
  children: pages,
  onPageChanged: (index) {
    // 只有当前页面存活
  },
)
```

**[CRITICAL] 导航检查清单**:

- [ ] IndexedStack 必须配合 GlobalKey + pausePolling/resumePolling
- [ ] Tab 切换必须调用 `pausePolling()` 暂停非活跃页
- [ ] **禁止**使用 `AutomaticKeepAliveClientMixin`（除非有明确理由）

### 12.4 State 生命周期与 dispose() ♻️

**问题根源**: Windows 桌面应用关闭时，进程被直接杀死，`dispose()` 可能**永远不会执行**！

```dart
// ❌ 错误假设：dispose() 总会被调用
class _MyAppState extends State<MyApp> {
  @override
  void dispose() {
    ApiClient().dispose(); // Windows 关闭时可能不执行！
    super.dispose();
  }
}

// ✅ 正确做法：使用 WidgetsBindingObserver 监听生命周期
class _MyAppState extends State<MyApp> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached) {
      // 在这里清理资源
      _cleanupResources();
    }
  }

  void _cleanupResources() {
    // 取消所有 Timer
    // 关闭数据库连接
    // 关闭 HTTP Client
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _cleanupResources();
    super.dispose();
  }
}
```

### 12.5 奥卡姆剃刀代码审查清单 🔪

**每次代码审查必须检查以下项目**:

| 检查项    | 危险信号                        | 正确做法                             |
| --------- | ------------------------------- | ------------------------------------ |
| Timer     | `Timer.periodic` 无 `cancel()`  | 必须配对 `cancel()` + `mounted` 检查 |
| HTTP      | `http.get()` 无 `timeout`       | 所有请求设置 10-15s 超时             |
| Stream    | `Stream.periodic`               | 改用 `Timer.periodic`                |
| KeepAlive | `AutomaticKeepAliveClientMixin` | 删除，使用 GlobalKey 控制            |
| 导航      | `IndexedStack` 无暂停机制       | 添加 `pausePolling/resumePolling`    |
| 异常      | `try-catch` 吞掉异常            | 必须记录日志                         |
| 单例      | 多处 `new http.Client()`        | 使用 `ApiClient` 单例                |

### 12.6 工控机专用优化 🏭

```dart
// 工控机环境特点：
// - 长时间运行（7x24小时）
// - 内存有限（通常 4-8GB）
// - 触摸屏操作
// - 网络可能不稳定

// [CRITICAL] 必须实现的功能：
// 1. 定期 GC 强制回收
Timer.periodic(Duration(minutes: 10), (_) {
  // 手动触发 GC（仅限 Debug 模式分析）
  debugPrint('Memory cleanup triggered');
});

// 2. 网络重连机制
int _retryCount = 0;
Future<void> _fetchWithRetry() async {
  try {
    await _fetchData();
    _retryCount = 0;
  } catch (e) {
    _retryCount++;
    if (_retryCount < 3) {
      await Future.delayed(Duration(seconds: _retryCount * 2));
      return _fetchWithRetry();
    }
    // 3次失败后显示离线状态
  }
}

// 3. 心跳检测
Timer.periodic(Duration(seconds: 30), (_) {
  _checkConnection();
});
```

---

## 13. Troubleshooting

| Issue                 | Solution                                              |
| --------------------- | ----------------------------------------------------- |
| VS 2019 required      | Flutter 3.22.x needs VS 2019 Build Tools              |
| libsnap7.dll missing  | Place 64-bit DLL in `build\windows\x64\runner\Debug\` |
| PLC connection failed | Check IP and rack/slot (S7-1200: rack=0, slot=1)      |
| Data parsing error    | Ensure Big Endian byte order                          |
| **App 卡死 (Freeze)** | **检查 12.1-12.4 的所有检查清单项**                   |
| **内存持续增长**      | **检查 Timer 累积、HTTP Client 泄漏、IndexedStack**   |
| **UI 无响应**         | **检查 HTTP 超时设置、异步操作阻塞主线程**            |
中文回答我的需求.
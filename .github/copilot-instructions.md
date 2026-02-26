---
alwaysApply: true
---

# 磨料车间 Flutter 监控应用规范

> **核心原则**: WebSocket 实时通信 + 奥卡姆剃刀 - 简单、直接、够用即可

---

## 1. 项目定义

```yaml
项目名称: ceramic-workshop-app
应用类型: Windows 桌面工业监控 (全屏触摸屏)
目标分辨率: 1920×1080
数据源: WebSocket 实时推送 (主要) + HTTP API (降级)
后端地址: http://localhost:8080 (HTTP) / ws://localhost:8080/ws/realtime (WebSocket)
核心理念: WebSocket 0.1s 推送 + 工业风格 UI + 固定分辨率设计
```

---

## 2. 监控设备清单

| 设备类型 | 数量 | 关键参数 | 数据块 | 刷新周期 |
|---------|------|---------|--------|---------|
| 回转窑 | 9台 | 温度+功率+料仓+下料 | DB3 | 5秒 |
| 辊道窑 | 1台 | 6温区×(温度+功率+电流) | DB7 | 5秒 |
| SCR设备 | 2套 | 功率+能耗+流量 | DB11 | 5秒 |
| 风机 | 2台 | 功率+能耗+电流 | DB11 | 5秒 |

**设备映射**:
- 回转窑: 窑7,6,5,4 (短料仓) + 窑2,1 (无料仓) + 窑8,3,9 (长料仓)
- 辊道窑: 6个温区 (zone1-zone6)
- SCR: SCR1(表63) + SCR2(表64)
- 风机: 风机1(表65) + 风机2(表66)

---

## 3. 架构规范 (WebSocket + 奥卡姆剃刀)

### 目录结构
```
lib/
├── main.dart                 # 入口 + 窗口初始化 + 全局资源管理
├── api/
│   ├── api.dart             # API 端点定义
│   └── index.dart           # HTTP Client (单例)
├── models/                   # 数据模型 (纯数据类)
│   ├── hopper_model.dart    # 回转窑数据
│   ├── roller_kiln_model.dart  # 辊道窑数据
│   ├── scr_fan_model.dart   # SCR+风机数据
│   └── ws_messages.dart     # ★ WebSocket 消息模型
├── services/                 # 数据获取层
│   ├── websocket_service.dart        # ★ WebSocket 服务 (核心)
│   ├── hopper_service.dart           # 回转窑服务 (HTTP 降级)
│   ├── roller_kiln_service.dart      # 辊道窑服务 (HTTP 降级)
│   ├── scr_fan_service.dart          # SCR/风机服务 (HTTP 降级)
│   └── history_data_service.dart     # 历史数据服务 (HTTP)
├── providers/                # 配置管理 (Provider)
│   ├── realtime_config_provider.dart  # 阈值配置
│   └── admin_provider.dart            # 管理员密码
├── pages/                    # 页面 (4个)
│   ├── top_bar.dart         # 顶部导航 + 页面切换
│   ├── realtime_dashboard_page.dart  # 实时大屏
│   ├── data_history_page.dart        # 历史数据
│   ├── sensor_status_page.dart       # 状态监控
│   └── settings_page.dart            # 系统配置
├── widgets/                  # 可复用组件
│   ├── realtime_dashboard/  # 实时大屏组件
│   ├── data_display/        # 历史数据组件
│   └── icons/               # 自定义图标
└── utils/                    # 工具类
    ├── app_logger.dart      # 日志系统
    └── constants.dart       # 常量定义
```

### 数据流架构 (WebSocket 优先)

```
Backend WebSocket (0.1s) → WebSocketService (单例) → Callbacks → UI Update
                                                    ↓
                                            ValueNotifier
                                                    ↓
                                            本地缓存 (离线恢复)

Backend HTTP API → Service → ValueNotifier → UI (历史数据查询)
```

**核心规则**:
1. **实时数据**: 必须使用 WebSocket，0.1s 推送间隔
2. **历史数据**: 使用 HTTP API 按需查询
3. **单例模式**: WebSocketService 全局唯一，避免多连接
4. **状态管理**: ValueNotifier 替代 setState，减少重建
5. **资源释放**: dispose 中清理回调，但不断开 WebSocket（全局共享）

### 核心依赖
```yaml
dependencies:
  provider: ^6.1.2           # 状态管理 (配置数据)
  fl_chart: ^0.68.0          # 图表
  window_manager: ^0.3.9     # 窗口控制
  web_socket_channel: ^2.4.0 # ★ WebSocket 客户端
  http: ^1.2.0               # HTTP Client (降级)
  shared_preferences: ^2.2.3 # 本地存储
  path_provider: ^2.1.3      # 文件路径
  logger: ^2.3.0             # 日志
```

**不使用**:
- [禁止] Riverpod (过度复杂)
- [禁止] Dio (http 包足够)
- [禁止] GetX (不符合 Flutter 规范)
- [禁止] BLoC (过度抽象)
- [禁止] Socket.IO (使用原生 WebSocket)

---

## 4. UI 设计规范 (工业 HMI 风格)

### 配色 (深色主题)
```dart
// 背景
bgPrimary: #0a0e14, bgSecondary: #111820, bgCard: #1a2332

// 状态 (ISA-101标准)
normal: #00e676 (绿), warning: #ffea00 (黄), alarm: #ff1744 (红), off: #616161 (灰)

// 文字
textPrimary: #e8eaed, textSecondary: #9aa0a6

// 数据曲线
blue: #2196f3, cyan: #00bcd4, orange: #ff9800, purple: #9c27b0
```

### 布局模板 (单页面整合)
```
┌─────────────────────────────────────────────────────┐
│ Header (48px): 标题 | 时间 | 连接状态 | 报警        │
├─────────────────────────┬───────────────────────────┤
│ 左侧实时数据 (60%)      │ 右侧历史图表 (40%)        │
│ - 设备1 卡片组          │ - 时间选择器              │
│ - 设备2 卡片组          │ - 趋势图表                │
│ - 设备N 卡片组          │ - 参数选择                │
├─────────────────────────┴───────────────────────────┤
│ Footer (32px): 连接状态 | 刷新时间 | 版本           │
└────────────────────────────────────────────────────┘
```

### 组件规范
| 组件 | 尺寸 | 字体 |
|-----|------|-----|
| KPI卡片 | 160×80px | Roboto Mono, 32-48px |
| 状态指示 | 12-16px圆点 | - |
| 按钮 | 高36-44px | 16px, weight 500 |

---

## 5. WebSocket 通信规范

### 1. WebSocket 优先策略

- **实时通信**: 使用 WebSocket 替代 HTTP 轮询，实现 0.1s 级别的数据推送
- **自动重连**: 指数退避重连策略 (1s → 2s → 4s → 8s → 16s → 30s)
- **心跳保活**: 客户端每 15s 发送心跳，防止连接超时
- **消息订阅**: 支持 `realtime` (实时数据) 和 `device_status` (设备状态) 两个频道

### 2. WebSocket 服务层

**文件**: `lib/services/websocket_service.dart`

- **单例模式**: 全局唯一的 WebSocket 连接管理器
- **连接状态**: `disconnected`, `connecting`, `connected`, `reconnecting`
- **消息类型**: 
  - `realtime_data`: 实时数据推送 (9台回转窑 + 1台辊道窑 + 2套SCR + 2台风机)
  - `device_status`: 设备通信状态
  - `heartbeat`: 心跳消息
  - `error`: 错误消息
- **回调机制**:
  - `onRealtimeDataUpdate`: 实时数据更新回调
  - `onDeviceStatusUpdate`: 设备状态更新回调
  - `onStateChanged`: 连接状态变化回调
  - `onError`: 错误回调

### 3. 数据推送周期

| 数据类型 | 推送方式 | 周期 | 说明 |
|---------|---------|------|-----|
| 实时数据 | WebSocket 推送 | 0.1秒 | 温度/功率/流量/重量 |
| 设备状态 | WebSocket 推送 | 0.1秒 | 通信状态/故障标志 |
| 历史数据 | HTTP 查询 | 按需 | 用户触发查询 |

### 4. 趋势图表
- 默认窗口: 60秒 (600个数据点，0.1s间隔)
- 刷新方式: 滚动更新 (FIFO)
- Y轴: 自适应范围
- 数据来源: WebSocket 实时推送

---

## 6. 状态管理 (2 层结构)

### 层 1: 实时数据 (ValueNotifier + WebSocket)
```dart
// 页面级状态，WebSocket 0.1s 推送
final ValueNotifier<WorkshopRealtimeData?> _realtimeDataNotifier = ValueNotifier(null);

// WebSocket 回调更新
_wsService.onRealtimeDataUpdate = (data) {
  if (mounted) {
    _realtimeDataNotifier.value = data;
  }
};
```

### 层 2: 配置数据 (Provider)
```dart
// 全局配置，启动时加载，手动保存
RealtimeConfigProvider: 温度阈值、功率阈值、料仓容量
AdminProvider: 管理员密码
BackendConfigProvider: 后端地址
```

**规则**:
- 实时数据用 ValueNotifier + WebSocket 回调 (0.1s 推送)
- 配置数据用 Provider (偶尔变化)
- 历史数据用 FutureBuilder + HTTP API (按需查询)
- 不混用，不嵌套

---

## 7. 代码模式 (3 个模板)

### 模板 1: WebSocket Service (核心)
```dart
// lib/services/websocket_service.dart
class WebSocketService {
  static final WebSocketService _instance = WebSocketService._internal();
  factory WebSocketService() => _instance;
  
  WebSocketChannel? _channel;
  WebSocketState _state = WebSocketState.disconnected;
  
  // 回调函数
  Function(WorkshopRealtimeData)? onRealtimeDataUpdate;
  Function(DeviceStatusData)? onDeviceStatusUpdate;
  Function(WebSocketState)? onStateChanged;
  Function(String)? onError;
  
  // 1. 连接到服务器
  Future<void> connect() async {
    if (_state == WebSocketState.connected) return;
    
    try {
      _state = WebSocketState.connecting;
      onStateChanged?.call(_state);
      
      _channel = WebSocketChannel.connect(
        Uri.parse('ws://localhost:8080/ws/realtime'),
      );
      
      _channel!.stream.listen(
        _handleMessage,
        onError: _handleError,
        onDone: _handleDisconnect,
      );
      
      _state = WebSocketState.connected;
      onStateChanged?.call(_state);
      
      // 启动心跳
      _startHeartbeat();
    } catch (e) {
      _handleError(e);
    }
  }
  
  // 2. 订阅实时数据
  void subscribeRealtime() {
    send({'type': 'subscribe', 'channel': 'realtime'});
  }
  
  // 3. 处理消息
  void _handleMessage(dynamic message) {
    final data = jsonDecode(message);
    switch (data['type']) {
      case 'realtime_data':
        onRealtimeDataUpdate?.call(WorkshopRealtimeData.fromJson(data['data']));
        break;
      case 'device_status':
        onDeviceStatusUpdate?.call(DeviceStatusData.fromJson(data['data']));
        break;
    }
  }
  
  // 4. 发送消息
  void send(Map<String, dynamic> message) {
    if (_state == WebSocketState.connected) {
      _channel?.sink.add(jsonEncode(message));
    }
  }
}
```

### 模板 2: Page (WebSocket 订阅)
```dart
class RealtimeDashboardPage extends StatefulWidget {
  @override
  State<RealtimeDashboardPage> createState() => _RealtimeDashboardPageState();
}

class _RealtimeDashboardPageState extends State<RealtimeDashboardPage> {
  final ValueNotifier<WorkshopRealtimeData?> _dataNotifier = ValueNotifier(null);
  late final WebSocketService _wsService;
  late final RealtimeConfigProvider _config;

  @override
  void initState() {
    super.initState();
    
    // 1. 缓存 Provider 引用
    _config = context.read<RealtimeConfigProvider>();
    
    // 2. 初始化 WebSocket
    _wsService = WebSocketService();
    _wsService.onRealtimeDataUpdate = _handleRealtimeData;
    _wsService.onStateChanged = _handleStateChanged;
    _wsService.connect();
    _wsService.subscribeRealtime();
  }

  // 3. 处理实时数据更新
  void _handleRealtimeData(WorkshopRealtimeData data) {
    if (mounted) {
      _dataNotifier.value = data;
    }
  }
  
  // 4. 处理连接状态变化
  void _handleStateChanged(WebSocketState state) {
    if (mounted) {
      setState(() {
        _connectionState = state;
      });
    }
  }

  @override
  void dispose() {
    // 清理回调，但不断开 WebSocket（全局共享）
    _wsService.onRealtimeDataUpdate = null;
    _wsService.onStateChanged = null;
    _dataNotifier.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<WorkshopRealtimeData?>(
      valueListenable: _dataNotifier,
      builder: (context, data, child) {
        return WorkshopDashboard(data: data, config: _config);
      },
    );
  }
}
```

### 模板 3: Widget (UI 组件)
```dart
class WorkshopDashboard extends StatelessWidget {
  final WorkshopRealtimeData? data;
  final RealtimeConfigProvider config;

  const WorkshopDashboard({required this.data, required this.config});

  @override
  Widget build(BuildContext context) {
    if (data == null) {
      return Center(child: CircularProgressIndicator());
    }
    
    return Row(
      children: [
        Expanded(
          flex: 60,
          child: HopperGrid(hoppers: data!.hoppers, config: config),
        ),
        Expanded(
          flex: 40,
          child: RollerKilnPanel(kiln: data!.rollerKiln, config: config),
        ),
      ],
    );
  }
}
```

---

## 8. 业务规则 (3 条核心逻辑)

### 规则 1: 设备运行判断
```dart
// 功率 >= 阈值 → 运行中
bool isRunning = power >= config.normalMax;
```

### 规则 2: 状态颜色映射 (ISA-101 标准)
```dart
if (value <= normalMax) return Color(0xFF00e676);  // 绿色 - 正常
if (value <= warningMax) return Color(0xFFffea00); // 黄色 - 警告
return Color(0xFFff1744);                          // 红色 - 报警
```

### 规则 3: 料仓容量计算
```dart
// 当前重量 / 最大容量 × 100%
double percentage = (currentWeight / maxCapacity) * 100;
```

---

## 9. 性能优化 (4 个关键点)

### 优化 1: WebSocket 连接管理
```dart
// [正确] 单例模式，全局共享连接
final wsService = WebSocketService();

// [正确] 页面切换时不断开连接
@override
void dispose() {
  // 只清理回调，不调用 wsService.disconnect()
  wsService.onRealtimeDataUpdate = null;
  super.dispose();
}

// [错误] 每个页面创建新连接
final wsService = WebSocketService()..connect();  // 会创建多个连接
```

### 优化 2: 减少重建
```dart
// [正确] 使用 ValueNotifier 减少重建
final ValueNotifier<WorkshopRealtimeData?> _dataNotifier = ValueNotifier(null);

// WebSocket 回调更新
_wsService.onRealtimeDataUpdate = (data) {
  if (mounted) {
    _dataNotifier.value = data;  // 只重建监听的 Widget
  }
};

// [错误] 频繁调用 setState 重建整个页面
void _updateData(data) {
  setState(() {  // 重建整个页面
    _allData = data;
  });
}
```

### 优化 3: 缓存查找
```dart
// [正确] initState 缓存 Provider
late final config = context.read<RealtimeConfigProvider>();

// [错误] 每次 build 查找
context.read<Provider>().getConfig(id);
```

### 优化 4: 图表性能优化
```dart
// [正确] 限制数据点数量
List<FlSpot> _prepareChartData(List<RealtimePoint> data) {
  if (data.length > 600) {
    // 采样：每 N 个点取 1 个
    final step = data.length ~/ 600;
    return data
        .where((point) => data.indexOf(point) % step == 0)
        .map((point) => FlSpot(point.x, point.y))
        .toList();
  }
  return data.map((point) => FlSpot(point.x, point.y)).toList();
}
```

---

## 10. 错误处理 (3 级容错)

### 级别 1: WebSocket 自动重连
```dart
// WebSocketService 内部处理
void _handleDisconnect() {
  _state = WebSocketState.reconnecting;
  onStateChanged?.call(_state);
  
  // 指数退避重连
  _reconnectAttempts++;
  final delay = min(30, pow(2, _reconnectAttempts).toInt());
  
  Future.delayed(Duration(seconds: delay), () {
    if (_state == WebSocketState.reconnecting) {
      connect();
    }
  });
}
```

### 级别 2: 静默失败 (保持旧数据)
```dart
// WebSocket 回调中处理
void _handleRealtimeData(WorkshopRealtimeData data) {
  if (mounted && data.isValid) {
    _dataNotifier.value = data; // 更新
  }
  // 如果无效，保持旧数据不变
}
```

### 级别 3: 用户提示 (连接失败)
```dart
// 显示连接状态
void _handleStateChanged(WebSocketState state) {
  if (state == WebSocketState.disconnected) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('WebSocket 连接断开，正在重连...')),
    );
  }
}
```

---

## 11. 代码审查清单

### 必查项
- [ ] WebSocket 回调在 dispose 时清理（设为 null）
- [ ] 所有 setState 前检查 mounted
- [ ] WebSocket 连接使用单例模式
- [ ] 所有 ValueNotifier 在 dispose 时释放
- [ ] 所有 Provider 在 initState 时缓存
- [ ] WebSocket 错误有重连机制

### 禁止项
- [ ] [禁止] 在 build() 中调用 context.read()
- [ ] [禁止] 在 initState() 中调用 setState()
- [ ] [禁止] 在 dispose() 后访问 State
- [ ] [禁止] 在循环中创建 Widget
- [ ] [禁止] 在 WebSocket 回调中不检查 mounted
- [ ] [禁止] 每个页面创建新的 WebSocket 连接
- [ ] [禁止] 在 dispose 中断开 WebSocket（全局共享）

---

## 12. 开发命令

```powershell
# 开发运行
flutter run -d windows

# 生产构建
flutter build windows --release

# 代码分析
flutter analyze

# 诊断问题
.\diagnose.ps1
```

---

## 13. 常见问题

| 问题 | 原因 | 解决方案 |
|------|------|---------|
| WebSocket 连接失败 | 后端未启动/URL错误 | 检查后端服务，确认 ws://localhost:8080/ws/realtime |
| 数据不更新 | 未订阅频道 | 调用 wsService.subscribeRealtime() |
| 应用卡死 | setState 过多 | 改用 ValueNotifier + WebSocket 回调 |
| 内存泄漏 | 回调未清理 | dispose 中设置回调为 null |
| 数据丢失 | 空数据覆盖 | 检查 isValid 再更新 |
| 连接频繁断开 | 心跳超时 | 检查心跳间隔 < 45s |
| UI 不更新 | 未用 Builder | 包裹 ValueListenableBuilder |
| 多个连接 | 未用单例 | 使用 WebSocketService() 单例 |

---

## 14. 禁止事项 (奥卡姆剃刀)

### [禁止] 过度设计
```dart
// 不需要: 复杂的状态机、事件总线、依赖注入框架
// 只需要: ValueNotifier + Provider
```

### [禁止] 过早优化
```dart
// 不需要: Isolate、缓存池、对象池
// 只需要: 减少 setState、缓存 Provider
```

### [禁止] 过度抽象
```dart
// 不需要: BaseService、BaseProvider、BaseWidget
// 只需要: 3 个模板 (Service/Page/Widget)
```

### [禁止] 过度配置
```dart
// 不需要: 环境变量、配置文件、特性开关
// 只需要: 硬编码 + SharedPreferences
```

### [禁止] 随意生成文档
```
// 禁止: 未经用户明确要求，主动创建 README.md、CHANGELOG.md、TODO.md 等文档
// 原则: 只在用户明确要求时才创建文档文件
// 例外: 代码注释和 inline 文档始终允许
```

**重要规则**:
- [禁止] 不要主动创建 `*.md` 文件（除非用户明确要求）
- [禁止] 不要主动创建 `docs/` 目录
- [禁止] 不要主动创建 `README.md`、`CHANGELOG.md`、`TODO.md`
- [允许] 可以在代码中添加注释和文档字符串
- [允许] 可以在对话中提供文档内容（但不写入文件）
- [允许] 只有当用户明确说"创建文档"、"生成 README"时才创建

### [严格禁止] 在代码注释中使用 Emoji 表情符号

**原则**: 所有代码文件（包括 .dart、.py、.yaml、.md 等）的注释中，严格禁止使用任何 emoji 图标或表情符号。

**禁止的符号示例**:
```
禁止使用:           等任何 emoji
```

**正确的注释风格**:
```dart
// [正确] 初始化 WebSocket 服务
// [错误] 连接失败
// [注意] 这里需要检查连接状态
// [警告] 不要在主线程执行耗时操作
// [成功] 数据加载完成
```

**错误的注释风格（严格禁止）**:
```dart
//  初始化 WebSocket 服务  // 禁止
//  连接失败              // 禁止
//  注意事项              // 禁止
//  启动服务              // 禁止
```

**原因说明**:
1. **编码兼容性**: Emoji 可能在某些编辑器或终端中显示异常
2. **代码审查**: 纯文本注释更易于代码审查和搜索
3. **专业性**: 工业控制系统代码应保持严谨的专业风格
4. **版本控制**: Emoji 在 Git diff 中可能显示为乱码
5. **跨平台**: 不同操作系统对 Emoji 的支持程度不同
6. **可读性**: 纯文本注释在所有环境下都能正确显示

**替代方案**:
- 使用 `[正确]` 替代 ``
- 使用 `[错误]` 替代 ``
- 使用 `[注意]` 替代 ``
- 使用 `[警告]` 替代 ``
- 使用 `[成功]` 替代 ``
- 使用 `[禁止]` 替代 ``
- 使用 `[允许]` 替代 ``
- 使用 `[重要]` 替代 ``
- 使用 `[提示]` 替代 ``

**文档目录规范**:
-  所有项目文档统一存放在 `vdoc/` 目录
-  文档命名规则：小写字母 + 下划线（如 `performance_fixes.md`）
- 📚 现有文档清单：
  - `batch_api_integration.md` - 批量 API 集成文档
  - `http_request_optimization.md` - HTTP 请求优化文档
  - `performance_fixes.md` - 性能修复文档
  - `testing_checklist.md` - 测试清单
  - `widget_rebuild_optimization.md` - Widget 重建优化文档
  - `refactor.md` - 重构记录
  - `readme_solution.md` - 解决方案说明
  - `plc_data_structure_analysis.md` - PLC 数据结构分析
  - `plc_db40_data_structure.md` - PLC DB40 数据结构
  - `rotary_kiln_ui_design_ascii.md` - 回转窑 UI 设计
  - `pages_directory_structure.md` - 页面目录结构
  - `pages_directory_organization_summary.md` - 页面目录组织总结

---

### [禁止敷衍] 对于我的想法或者实现架构的话,需要严格的代码审查后,如果有更好的优化方案或者错误,必须指出.
## 15. 快速参考

### WebSocket 连接
```dart
// 初始化 WebSocket
final wsService = WebSocketService();
wsService.onRealtimeDataUpdate = _handleRealtimeData;
wsService.connect();
wsService.subscribeRealtime();

// 清理回调
@override
void dispose() {
  wsService.onRealtimeDataUpdate = null;
  super.dispose();
}
```

### 状态更新
```dart
// WebSocket 回调更新
void _handleRealtimeData(WorkshopRealtimeData data) {
  if (mounted) {
    _dataNotifier.value = data;
  }
}

// 监听数据
ValueListenableBuilder(
  valueListenable: _dataNotifier,
  builder: (context, data, child) => Widget(data),
)
```

### 配置读取
```dart
// 缓存 Provider
late final config = context.read<RealtimeConfigProvider>();

// 读取配置
final color = config.getRotaryKilnTempColor(deviceId, temperature);
final isRunning = config.isRotaryKilnRunning(deviceId, power);
```

---

**文档版本**: v2.0  
**适用项目**: ceramic-workshop-app  
**核心原则**: 奥卡姆剃刀 - 简单、直接、够用即可  
**更新日期**: 2026-01-26

# ceramic_workshop_app

# Ceramic Workshop PLC Renovation (陶瓷磨料车间 PLC 改造)

## 项目简介 (Project Overview)

本项目是为 **山东英格瓷四砂泰山磨料有限公司** 开发的陶瓷磨料车间信息化改造软件。
该系统专为 **Windows 系统的工业触控一体机** 设计开发，旨在通过与 PLC 系统通信，实时监控辊道窑、回转窑及 SCR 设备的运行状态、温度、能耗及下料速度等关键指标，并提供历史数据查询与可视化分析功能。

**委托方:** 山东英格瓷四砂泰山磨料有限公司  
**受托方:** 科乐驰（青岛）信息技术有限公司  
**项目启动日期:** 2025年11月17日  
**目标运行环境:** Windows 10/11 工业触控一体机

## 核心功能 (Key Features)

系统采用选项卡 (Tab) 结构组织以下功能模块：

### 1. 辊道窑监控 (Roller Kiln)
*   **温度采集与分区显示:** 
    *   2D/3D 可视化模型展示各分区结构。
    *   实时显示各分区温度（刷新率 ≤ 5s）。
    *   支持查看各区域历史温度变化曲线。
*   **能耗监控:**
    *   实时显示设备总能耗（V, A, kW）。
    *   能耗趋势图表展示。

### 2. 回转窑监控 (Rotary Kiln)
*   **温度与能耗:** 同辊道窑，支持分区温度及实时能耗展示。
*   **下料速度:** 实时显示下料速度 (kg/h) 及动态曲线。
*   **料仓管理:** 
    *   可视化展示料仓重量及容量百分比。
    *   低重量自动告警功能。
*   **历史查询:** 支持按小时/日/周/月查询速度与重量趋势。

### 3. SCR 设备监控 (SCR Equipment)
*   **风机能耗:** 实时显示功率、累计电量及启停状态。
*   **氨水泵能耗:** 实时显示功率、累计电量及启停状态。
*   **燃气监测:** 实时显示燃气流速及日/月/年累计消耗。
*   *(注: SCR部分目前仅保留 UI 和数据接口，传感器暂未接入)*

### 4. 系统配置 (Configuration)
*   **连接配置:** 服务器 IP、PLC IP/端口、数据库连接配置。
*   **传感器配置:** Modbus/PLC 点位地址映射配置。
*   **权限控制:** 管理员权限验证。

## 技术栈 (Tech Stack)

*   **开发框架:** [Flutter](https://flutter.dev/) (Dart) - 专注于 Windows 桌面端构建
*   **目标平台:** Windows (x64)
*   **工业通信:** `dart_snap7` (用于连接 Siemens S7系列 PLC)
*   **图表库:** `fl_chart` (用于绘制温度/能耗/速度曲线)
*   **本地数据库:** `sqflite_common_ffi` (Windows 端 SQLite 支持) / `drift`

## 开发环境设置 (Setup)

1.  **前置要求:**
    *   Flutter SDK (建议版本 >= 3.24)
    *   **Visual Studio 2022** (必须安装 "Desktop development with C++" 工作负载) - 用于编译 Windows 可执行文件 (.exe)

2.  **安装依赖:**
    ```bash
    flutter pub get
    ```

3.  **部署与运行 (Deployment):**

    *   **启动 PLC 模拟器（用于开发测试）:**
        ```bash
        # 方式1: 使用 PowerShell 脚本
        .\start_plc_simulator.ps1
        
        # 方式2: 直接运行 Dart
        dart run bin/plc_simulator.dart
        ```
        
        注意：端口 102 可能需要管理员权限。如遇权限问题，请以管理员身份运行。

    *   **调试运行应用:**
        ```bash
        flutter run -d windows
        ```
    
    *   **打包发布:**
        生成 Release 版本的 Windows 可执行文件：
        ```bash
        flutter build windows
        ```
        构建产物位于: `build\windows\runner\Release\`

## 开发测试流程

### 第一步：启动 PLC 模拟器
```bash
# 在一个终端窗口中启动
dart run bin/plc_simulator.dart
```

模拟器会自动生成以下数据：
- **DB10 (辊道窑)**: 10个温区温度、电压、电流、功率
- **DB20 (回转窑)**: 8个温区温度、下料速度、料仓重量
- **DB30 (SCR设备)**: 风机功率、氨水泵功率、燃气流速

数据每秒自动更新，模拟真实 PLC 的行为。

### 第二步：运行 Flutter 应用
```bash
# 在另一个终端窗口中
flutter run -d windows
```

### 第三步：测试连接
1. 在应用中切换到"系统配置"选项卡
2. 输入配置：
   - IP: `127.0.0.1`
   - Rack: `0`
   - Slot: `0`
3. 点击"测试连接"按钮

## 目录结构 (Directory Structure)

```
lib/
├── config/             # 路由、主题、全局配置
├── core/               # 核心工具类 (网络、存储、日志)
├── data/               # 数据层
│   ├── datasources/    # 数据源 (PLC接口, 本地DB)
│   ├── models/         # 数据模型 (TemperatureModel, EnergyModel)
│   └── repositories/   # 仓库层 (数据处理逻辑)
├── domain/             # 业务领域层 (UseCases)
├── presentation/       # UI 层
│   ├── pages/          # 主要页面 (RollerKiln, RotaryKiln, SCR, Settings)
│   ├── widgets/        # 通用组件 (仪表盘, 图表组件, 状态卡片)
│   └── state/          # 状态管理 (Providers/Blocs)
└── main.dart           # 入口文件
```

## 注意事项 (Notes)

*   **工控机适配:**
    *   **分辨率:** 工业一体机通常为 1920x1080 或 1280x800。UI 设计需严格适配横屏，并考虑到触摸操作的便捷性（按钮尺寸适度放大）。
    *   **触摸支持:** Flutter Windows 默认支持触摸点击，但需注意手势交互（如拖拽图表）的体验优化。
    *   **全屏模式:** 生产环境建议配置软件全屏运行或无边框窗口模式。
*   **PLC 连接:** 开发阶段若无真实 PLC，请使用 `MockPlcService` 生成模拟数据。
*   **异常处理:** 需重点处理网络断开、PLC 连接超时等工业现场常见异常。

## 许可证 (License)

Private Proprietary - Clutch Technology

## Getting Started

This project is a starting point for a Flutter application.

A few resources to get you started if this is your first Flutter project:

- [Lab: Write your first Flutter app](https://docs.flutter.dev/get-started/codelab)
- [Cookbook: Useful Flutter samples](https://docs.flutter.dev/cookbook)

For help getting started with Flutter development, view the
[online documentation](https://docs.flutter.dev/), which offers tutorials,
samples, guidance on mobile development, and a full API reference.

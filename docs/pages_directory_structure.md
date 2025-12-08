# 页面目录结构整理说明

## 目录结构设计原则

### 1. 按功能模块分组
- **设备监控模块**：每个设备类型一个子目录
- **通用功能模块**：通用页面放在 `common/` 目录
- **导航模块**：导航相关页面放在 `navigation/` 目录

### 2. 命名规范
- 目录名：小写，下划线分隔（如 `rotary_kiln`）
- 文件名：小写，下划线分隔（如 `rotary_kiln_page_fixed.dart`）
- 类名：大驼峰（如 `RotaryKilnPageFixed`）

### 3. 保留在根目录的页面
以下页面保留在 `pages/` 根目录，因为它们是：
- **应用入口页面**：`main_navigation_page.dart` - 主导航，应用入口
- **通用工具页面**：`digital_twin_page.dart`, `hmi_demo_page.dart` - 跨模块使用的通用功能

## 最终目录结构

```
pages/
├── roller_kiln/                    # 辊道窑模块
│   ├── roller_kiln_page.dart       # 辊道窑页面（旧版）
│   └── roller_kiln_page_v2.dart    # 辊道窑页面（新版）
│
├── rotary_kiln/                    # 回转窑模块
│   ├── rotary_kiln_page_fixed.dart # 回转窑页面（固定布局）
│   └── rotary_kiln_page_v2.dart    # 回转窑页面（滚动布局）
│
├── scr_equipment/                  # SCR设备模块
│   └── scr_equipment_page.dart
│
├── workshop_monitor/               # 综合监控模块
│   └── workshop_monitor_page.dart
│
├── grinding_workshop/              # 磨料车间模块
│   ├── grinding_workshop_page.dart
│   └── material_feed_page.dart     # 下料监控页面
│
├── settings/                       # 系统设置模块
│   ├── settings_page.dart          # 设置页面（旧版）
│   ├── settings_page_v2.dart       # 设置页面（新版）
│   └── grinding_workshop_settings_page.dart
│
├── common/                         # 通用页面
│   ├── digital_twin_page.dart      # 数字孪生页面（通用功能）
│   └── hmi_demo_page.dart          # HMI演示页面（开发/测试用）
│
├── navigation/                     # 导航相关页面
│   └── home_page.dart              # 旧版主页（可能已废弃）
│
└── main_navigation_page.dart       # 主导航页面（应用入口，保留在根目录）
```

## 为什么某些页面保留在根目录？

### `main_navigation_page.dart` - 保留在根目录
- **原因**：这是应用的入口页面，被 `main.dart` 直接引用
- **作用**：作为整个应用的导航容器，管理所有子页面
- **类比**：类似 `main.dart` 在项目根目录，作为入口文件

### `common/` 目录中的页面 - 跨模块通用功能
- **`digital_twin_page.dart`**：数字孪生功能，可能被多个模块使用
- **`hmi_demo_page.dart`**：HMI组件演示，开发/测试用，不属于具体业务模块

## 文件移动计划

1. ✅ `rotary_kiln/` - 已存在
2. ✅ `roller_kiln/` - 已存在
3. ✅ `scr_equipment/` - 已存在
4. ✅ `settings/` - 已存在
5. ⏳ 创建 `workshop_monitor/` 并移动 `workshop_monitor_page.dart`
6. ⏳ 创建 `grinding_workshop/` 并移动相关文件
7. ⏳ 创建 `common/` 并移动通用页面
8. ⏳ 创建 `navigation/` 并移动 `home_page.dart`
9. ⏳ 更新所有导入引用


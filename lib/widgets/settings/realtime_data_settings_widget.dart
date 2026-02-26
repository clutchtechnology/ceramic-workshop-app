import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../providers/realtime_config_provider.dart';
import '../data_display/data_tech_line_widgets.dart';

/// 实时数据设置页面
/// 用于配置各设备的温度/功率/流量阈值
/// 颜色固定: 正常=绿色, 警告=黄色, 报警=红色
class RealtimeDataSettingsWidget extends StatefulWidget {
  const RealtimeDataSettingsWidget({super.key});

  @override
  State<RealtimeDataSettingsWidget> createState() =>
      _RealtimeDataSettingsWidgetState();
}

class _RealtimeDataSettingsWidgetState
    extends State<RealtimeDataSettingsWidget> {
  // ============================================================
  // 状态变量
  // ============================================================

  // 1, 当前展开的配置区块索引 (-1 表示全部折叠)
  int _expandedIndex = 0;

  // 2, 输入框控制器集合 (key格式: "{configKey}_{fieldType}")
  final Map<String, TextEditingController> _controllers = {};

  // ============================================================
  // 生命周期
  // ============================================================

  @override
  void initState() {
    super.initState();
    // 延迟初始化，确保 Provider 已经准备好
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _initControllers();
    });
  }

  /// 初始化所有输入框控制器
  void _initControllers() {
    if (!mounted) return;

    // 安全获取 Provider，避免在 Widget 树未稳定时访问
    final RealtimeConfigProvider provider;
    try {
      provider = context.read<RealtimeConfigProvider>();
    } catch (e) {
      // Provider 未就绪，延迟重试
      Future.delayed(const Duration(milliseconds: 100), () {
        if (mounted) _initControllers();
      });
      return;
    }

    // 2, 初始化阈值配置控制器 (回转窑/辊道窑/风机/SCR泵/SCR燃气)
    _initThresholdControllers(provider.rotaryKilnConfigs);
    _initThresholdControllers(provider.rotaryKilnPowerConfigs); // 新增
    _initThresholdControllers(provider.rollerKilnConfigs);
    _initThresholdControllers(provider.fanConfigs);
    _initThresholdControllers(provider.scrPumpConfigs);
    _initThresholdControllers(provider.scrGasConfigs);

    // 2, 初始化料仓容量控制器
    for (var config in provider.hopperCapacityConfigs) {
      _controllers['${config.key}_maxCapacity'] =
          TextEditingController(text: config.maxCapacity.toString());
    }

    setState(() {});
  }

  /// 初始化阈值配置控制器 (复用逻辑)
  void _initThresholdControllers(List<ThresholdConfig> configs) {
    for (var config in configs) {
      _controllers['${config.key}_normal'] =
          TextEditingController(text: config.normalMax.toString());
      _controllers['${config.key}_warning'] =
          TextEditingController(text: config.warningMax.toString());
    }
  }

  /// 从 Provider 更新所有控制器的值 (重置时调用)
  void _updateControllersFromConfig() {
    final provider = context.read<RealtimeConfigProvider>();

    // 2, 更新阈值配置控制器
    _updateThresholdControllers(provider.rotaryKilnConfigs);
    _updateThresholdControllers(provider.rotaryKilnPowerConfigs); // 新增
    _updateThresholdControllers(provider.rollerKilnConfigs);
    _updateThresholdControllers(provider.fanConfigs);
    _updateThresholdControllers(provider.scrPumpConfigs);
    _updateThresholdControllers(provider.scrGasConfigs);

    // 2, 更新料仓容量控制器
    for (var config in provider.hopperCapacityConfigs) {
      _controllers['${config.key}_maxCapacity']?.text =
          config.maxCapacity.toString();
    }
  }

  /// 更新阈值配置控制器 (复用逻辑)
  void _updateThresholdControllers(List<ThresholdConfig> configs) {
    for (var config in configs) {
      _controllers['${config.key}_normal']?.text = config.normalMax.toString();
      _controllers['${config.key}_warning']?.text =
          config.warningMax.toString();
    }
  }

  @override
  void dispose() {
    // 2, 释放所有输入框控制器
    for (var controller in _controllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    //  [CRITICAL] 使用 context.watch 替代 Consumer
    // Consumer 在 IndexedStack/Offstage 环境中会导致 '_dependents.isEmpty' 错误
    // 因为 Consumer 的依赖关系在页面隐藏时不会被正确清理
    final RealtimeConfigProvider provider;
    try {
      provider = context.watch<RealtimeConfigProvider>();
    } catch (e) {
      // Provider 未就绪时显示加载状态
      return const Center(
        child: CircularProgressIndicator(
          valueColor: AlwaysStoppedAnimation<Color>(TechColors.glowCyan),
        ),
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 颜色说明
          _buildColorLegend(),
          const SizedBox(height: 20),

          // 回转窑温度配置（窑1有减100度开关）
          _buildRotaryKilnTempConfigSection(
            index: 0,
            title: '回转窑温度阈值配置',
            subtitle: '9个回转窑设备 (窑1支持减100°C显示)',
            icon: Icons.whatshot,
            accentColor: TechColors.glowOrange,
            unit: '℃',
            configs: provider.rotaryKilnConfigs,
            onUpdate: (index, normalMax, warningMax, subtractTemp100) {
              provider.updateRotaryKilnConfig(index,
                  normalMax: normalMax,
                  warningMax: warningMax,
                  subtractTemp100: subtractTemp100);
            },
          ),

          const SizedBox(height: 12),

          // 回转窑功率配置 (新增)
          _buildConfigSection(
            index: 1,
            title: '回转窑功率阈值配置',
            subtitle: '9个回转窑设备 (判断运行状态)',
            icon: Icons.flash_on,
            accentColor: TechColors.glowPurple,
            unit: 'kW',
            configs: provider.rotaryKilnPowerConfigs,
            onUpdate: (index, normalMax, warningMax) {
              provider.updateRotaryKilnPowerConfig(index,
                  normalMax: normalMax, warningMax: warningMax);
            },
          ),

          const SizedBox(height: 12),

          // 辊道窑温度配置
          _buildConfigSection(
            index: 2,
            title: '辊道窑温度阈值配置',
            subtitle: '6个温区',
            icon: Icons.local_fire_department,
            accentColor: TechColors.glowRed,
            unit: '℃',
            configs: provider.rollerKilnConfigs,
            onUpdate: (index, normalMax, warningMax) {
              provider.updateRollerKilnConfig(index,
                  normalMax: normalMax, warningMax: warningMax);
            },
          ),

          const SizedBox(height: 12),

          // 风机功率配置
          _buildConfigSection(
            index: 3,
            title: '风机功率阈值配置',
            subtitle: '2个风机',
            icon: Icons.air,
            accentColor: TechColors.glowCyan,
            unit: 'kW',
            configs: provider.fanConfigs,
            onUpdate: (index, normalMax, warningMax) {
              provider.updateFanConfig(index,
                  normalMax: normalMax, warningMax: warningMax);
            },
          ),

          const SizedBox(height: 12),

          // SCR氨水泵功率配置
          _buildConfigSection(
            index: 4,
            title: 'SCR氨水泵功率阈值配置',
            subtitle: '2个氨水泵',
            icon: Icons.water_drop,
            accentColor: TechColors.glowBlue,
            unit: 'kW',
            configs: provider.scrPumpConfigs,
            onUpdate: (index, normalMax, warningMax) {
              provider.updateScrPumpConfig(index,
                  normalMax: normalMax, warningMax: warningMax);
            },
          ),

          const SizedBox(height: 12),

          // SCR燃气表流量配置
          _buildConfigSection(
            index: 5,
            title: 'SCR燃气表流量阈值配置',
            subtitle: '2个燃气表',
            icon: Icons.gas_meter,
            accentColor: TechColors.glowGreen,
            unit: 'm³/h',
            configs: provider.scrGasConfigs,
            onUpdate: (index, normalMax, warningMax) {
              provider.updateScrGasConfig(index,
                  normalMax: normalMax, warningMax: warningMax);
            },
          ),

          const SizedBox(height: 12),

          // 料仓容量配置
          _buildHopperCapacitySection(
            index: 6,
            title: '料仓容量配置',
            subtitle: '7个带料仓的回转窑',
            icon: Icons.inventory_2,
            accentColor: TechColors.glowPurple,
            configs: provider.hopperCapacityConfigs,
            onUpdate: (index, maxCapacity) {
              provider.updateHopperCapacityConfig(index,
                  maxCapacity: maxCapacity);
            },
          ),

          const SizedBox(height: 24),
          _buildActionButtons(provider),
        ],
      ),
    );
  }

  /// 颜色说明
  Widget _buildColorLegend() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: TechColors.bgMedium.withOpacity(0.5),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: TechColors.borderDark),
      ),
      child: Row(
        children: [
          const Icon(Icons.info_outline, color: TechColors.glowCyan, size: 20),
          const SizedBox(width: 12),
          const Expanded(
            child: Text(
              '状态颜色固定: ',
              style: TextStyle(color: TechColors.textSecondary, fontSize: 12),
            ),
          ),
          _buildColorItem('正常', ThresholdColors.normal),
          const SizedBox(width: 16),
          _buildColorItem('警告', ThresholdColors.warning),
          const SizedBox(width: 16),
          _buildColorItem('报警', ThresholdColors.alarm),
        ],
      ),
    );
  }

  Widget _buildColorItem(String label, Color color) {
    return Row(
      children: [
        Container(
          width: 16,
          height: 16,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(2),
            boxShadow: [
              BoxShadow(color: color.withOpacity(0.5), blurRadius: 4),
            ],
          ),
        ),
        const SizedBox(width: 4),
        Text(label,
            style: TextStyle(
                color: color, fontSize: 12, fontWeight: FontWeight.w500)),
      ],
    );
  }

  /// 配置区块（可展开）
  Widget _buildConfigSection({
    required int index,
    required String title,
    required String subtitle,
    required IconData icon,
    required Color accentColor,
    required String unit,
    required List<ThresholdConfig> configs,
    required Function(int index, double? normalMax, double? warningMax)
        onUpdate,
  }) {
    final isExpanded = _expandedIndex == index;

    return Container(
      decoration: BoxDecoration(
        color: TechColors.bgMedium.withOpacity(0.5),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(
          color:
              isExpanded ? accentColor.withOpacity(0.5) : TechColors.borderDark,
        ),
      ),
      child: Column(
        children: [
          // 标题栏
          InkWell(
            onTap: () {
              setState(() {
                _expandedIndex = isExpanded ? -1 : index;
              });
            },
            borderRadius: BorderRadius.circular(4),
            child: Container(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: accentColor.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Icon(icon, color: accentColor, size: 20),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: const TextStyle(
                            color: TechColors.textPrimary,
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          subtitle,
                          style: const TextStyle(
                            color: TechColors.textSecondary,
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Icon(
                    isExpanded ? Icons.expand_less : Icons.expand_more,
                    color: TechColors.textSecondary,
                  ),
                ],
              ),
            ),
          ),
          // 展开内容 - 表格
          if (isExpanded) ...[
            Container(height: 1, color: TechColors.borderDark),
            Padding(
              padding: const EdgeInsets.all(12),
              child: _buildConfigTable(configs, unit, onUpdate),
            ),
          ],
        ],
      ),
    );
  }

  /// 回转窑温度配置区块（带减100度开关）
  Widget _buildRotaryKilnTempConfigSection({
    required int index,
    required String title,
    required String subtitle,
    required IconData icon,
    required Color accentColor,
    required String unit,
    required List<ThresholdConfig> configs,
    required Function(int index, double? normalMax, double? warningMax,
            bool? subtractTemp100)
        onUpdate,
  }) {
    final isExpanded = _expandedIndex == index;

    return Container(
      decoration: BoxDecoration(
        color: TechColors.bgMedium.withOpacity(0.5),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(
          color:
              isExpanded ? accentColor.withOpacity(0.5) : TechColors.borderDark,
        ),
      ),
      child: Column(
        children: [
          // 标题栏
          InkWell(
            onTap: () {
              setState(() {
                _expandedIndex = isExpanded ? -1 : index;
              });
            },
            borderRadius: BorderRadius.circular(4),
            child: Container(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: accentColor.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Icon(icon, color: accentColor, size: 20),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: const TextStyle(
                            color: TechColors.textPrimary,
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          subtitle,
                          style: const TextStyle(
                            color: TechColors.textSecondary,
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Icon(
                    isExpanded ? Icons.expand_less : Icons.expand_more,
                    color: TechColors.textSecondary,
                  ),
                ],
              ),
            ),
          ),
          // 展开内容 - 表格（带减100度开关）
          if (isExpanded) ...[
            Container(height: 1, color: TechColors.borderDark),
            Padding(
              padding: const EdgeInsets.all(12),
              child: _buildRotaryKilnTempConfigTable(configs, unit, onUpdate),
            ),
          ],
        ],
      ),
    );
  }

  /// 回转窑温度配置表格（只有窑1有减100度开关）
  Widget _buildRotaryKilnTempConfigTable(
    List<ThresholdConfig> configs,
    String unit,
    Function(int index, double? normalMax, double? warningMax,
            bool? subtractTemp100)
        onUpdate,
  ) {
    return Column(
      children: [
        // 表头
        Container(
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
          decoration: BoxDecoration(
            color: TechColors.bgDeep.withOpacity(0.5),
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(4),
              topRight: Radius.circular(4),
            ),
          ),
          child: Row(
            children: [
              const Expanded(
                flex: 3,
                child: Text(
                  '设备名称',
                  style: TextStyle(
                    color: TechColors.textSecondary,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              Expanded(
                flex: 2,
                child: Row(
                  children: [
                    Container(
                      width: 10,
                      height: 10,
                      decoration: BoxDecoration(
                        color: ThresholdColors.normal,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '正常上限 ($unit)',
                      style: const TextStyle(
                        color: TechColors.textSecondary,
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                flex: 2,
                child: Row(
                  children: [
                    Container(
                      width: 10,
                      height: 10,
                      decoration: BoxDecoration(
                        color: ThresholdColors.warning,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '警告上限 ($unit)',
                      style: const TextStyle(
                        color: TechColors.textSecondary,
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              // 只有窑1需要减100度开关，表头留空
              const Expanded(
                flex: 1,
                child: SizedBox(),
              ),
            ],
          ),
        ),
        // 表格行
        ...configs.asMap().entries.map((entry) {
          final idx = entry.key;
          final config = entry.value;
          return _buildRotaryKilnTempConfigRow(idx, config, unit, onUpdate);
        }),
      ],
    );
  }

  /// 回转窑温度配置表格行（只有窑1有减100度开关）
  Widget _buildRotaryKilnTempConfigRow(
    int index,
    ThresholdConfig config,
    String unit,
    Function(int index, double? normalMax, double? warningMax,
            bool? subtractTemp100)
        onUpdate,
  ) {
    final normalController = _controllers['${config.key}_normal'];
    final warningController = _controllers['${config.key}_warning'];

    // 只有窑1 (no_hopper_2) 显示减100度开关
    final isKiln1 = config.key == 'no_hopper_2_temp';

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 12),
      decoration: BoxDecoration(
        color: index.isEven
            ? TechColors.bgDeep.withOpacity(0.3)
            : TechColors.bgMedium.withOpacity(0.3),
        border: Border(
          bottom: BorderSide(color: TechColors.borderDark.withOpacity(0.5)),
        ),
      ),
      child: Row(
        children: [
          // 设备名称
          Expanded(
            flex: 3,
            child: Text(
              config.displayName,
              style: const TextStyle(
                color: TechColors.textPrimary,
                fontSize: 12,
              ),
            ),
          ),
          // 正常上限输入框
          Expanded(
            flex: 2,
            child: _buildInputField(
              controller: normalController,
              color: ThresholdColors.normal,
              onChanged: (value) {
                final v = double.tryParse(value);
                if (v != null) {
                  onUpdate(index, v, null, null);
                }
              },
            ),
          ),
          // 警告上限输入框
          Expanded(
            flex: 2,
            child: _buildInputField(
              controller: warningController,
              color: ThresholdColors.warning,
              onChanged: (value) {
                final v = double.tryParse(value);
                if (v != null) {
                  onUpdate(index, null, v, null);
                }
              },
            ),
          ),
          // 只有窑1显示减100度开关
          Expanded(
            flex: 1,
            child: isKiln1
                ? Center(
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text(
                          '-100°C',
                          style: TextStyle(
                            color: TechColors.textSecondary,
                            fontSize: 10,
                          ),
                        ),
                        Switch(
                          value: config.subtractTemp100,
                          onChanged: (value) {
                            onUpdate(index, null, null, value);
                          },
                          activeColor: TechColors.glowCyan,
                          activeTrackColor:
                              TechColors.glowCyan.withOpacity(0.5),
                          inactiveThumbColor: TechColors.textSecondary,
                          inactiveTrackColor: TechColors.bgDeep,
                          materialTapTargetSize:
                              MaterialTapTargetSize.shrinkWrap,
                        ),
                      ],
                    ),
                  )
                : const SizedBox(),
          ),
        ],
      ),
    );
  }

  /// 配置表格
  Widget _buildConfigTable(
    List<ThresholdConfig> configs,
    String unit,
    Function(int index, double? normalMax, double? warningMax) onUpdate,
  ) {
    return Column(
      children: [
        // 表头
        Container(
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
          decoration: BoxDecoration(
            color: TechColors.bgDeep.withOpacity(0.5),
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(4),
              topRight: Radius.circular(4),
            ),
          ),
          child: Row(
            children: [
              const Expanded(
                flex: 3,
                child: Text(
                  '设备名称',
                  style: TextStyle(
                    color: TechColors.textSecondary,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              Expanded(
                flex: 2,
                child: Row(
                  children: [
                    Container(
                      width: 10,
                      height: 10,
                      decoration: BoxDecoration(
                        color: ThresholdColors.normal,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '正常上限 ($unit)',
                      style: const TextStyle(
                        color: TechColors.textSecondary,
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                flex: 2,
                child: Row(
                  children: [
                    Container(
                      width: 10,
                      height: 10,
                      decoration: BoxDecoration(
                        color: ThresholdColors.warning,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '警告上限 ($unit)',
                      style: const TextStyle(
                        color: TechColors.textSecondary,
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        // 表格行
        ...configs.asMap().entries.map((entry) {
          final idx = entry.key;
          final config = entry.value;
          return _buildConfigRow(idx, config, unit, onUpdate);
        }),
      ],
    );
  }

  /// 配置表格行
  Widget _buildConfigRow(
    int index,
    ThresholdConfig config,
    String unit,
    Function(int index, double? normalMax, double? warningMax) onUpdate,
  ) {
    final normalController = _controllers['${config.key}_normal'];
    final warningController = _controllers['${config.key}_warning'];

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 12),
      decoration: BoxDecoration(
        color: index.isEven
            ? TechColors.bgDeep.withOpacity(0.3)
            : TechColors.bgMedium.withOpacity(0.3),
        border: Border(
          bottom: BorderSide(color: TechColors.borderDark.withOpacity(0.5)),
        ),
      ),
      child: Row(
        children: [
          // 设备名称
          Expanded(
            flex: 3,
            child: Text(
              config.displayName,
              style: const TextStyle(
                color: TechColors.textPrimary,
                fontSize: 12,
              ),
            ),
          ),
          // 正常上限输入框
          Expanded(
            flex: 2,
            child: _buildInputField(
              controller: normalController,
              color: ThresholdColors.normal,
              onChanged: (value) {
                final v = double.tryParse(value);
                if (v != null) {
                  onUpdate(index, v, null);
                }
              },
            ),
          ),
          // 警告上限输入框
          Expanded(
            flex: 2,
            child: _buildInputField(
              controller: warningController,
              color: ThresholdColors.warning,
              onChanged: (value) {
                final v = double.tryParse(value);
                if (v != null) {
                  onUpdate(index, null, v);
                }
              },
            ),
          ),
        ],
      ),
    );
  }

  /// 输入框
  Widget _buildInputField({
    required TextEditingController? controller,
    required Color color,
    required Function(String) onChanged,
  }) {
    if (controller == null) return const SizedBox();

    return Container(
      margin: const EdgeInsets.only(right: 8),
      child: TextField(
        controller: controller,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        inputFormatters: [
          FilteringTextInputFormatter.allow(RegExp(r'[\d.]')),
        ],
        style: const TextStyle(
          color: TechColors.textPrimary,
          fontSize: 12,
          fontFamily: 'Roboto Mono',
        ),
        onChanged: onChanged,
        decoration: InputDecoration(
          isDense: true,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
          filled: true,
          fillColor: TechColors.bgDeep,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(4),
            borderSide: BorderSide(color: color.withOpacity(0.3)),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(4),
            borderSide: BorderSide(color: color.withOpacity(0.3)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(4),
            borderSide: BorderSide(color: color, width: 1.5),
          ),
        ),
      ),
    );
  }

  /// 操作按钮
  Widget _buildActionButtons(RealtimeConfigProvider provider) {
    return Row(
      children: [
        ElevatedButton.icon(
          onPressed: () async {
            final success = await provider.saveConfig();
            if (!mounted) return;

            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Row(
                  children: [
                    Icon(
                      success ? Icons.check_circle : Icons.error,
                      color: success
                          ? ThresholdColors.normal
                          : ThresholdColors.alarm,
                      size: 20,
                    ),
                    const SizedBox(width: 12),
                    Text(
                      success ? '配置保存成功！' : '配置保存失败，请重试',
                      style: const TextStyle(color: TechColors.textPrimary),
                    ),
                  ],
                ),
                backgroundColor: TechColors.bgMedium,
                duration: const Duration(seconds: 2),
              ),
            );
          },
          icon: const Icon(Icons.save, size: 18),
          label: const Text('保存配置'),
          style: ElevatedButton.styleFrom(
            backgroundColor: TechColors.glowCyan.withOpacity(0.2),
            foregroundColor: TechColors.glowCyan,
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(4),
              side: BorderSide(color: TechColors.glowCyan.withOpacity(0.5)),
            ),
          ),
        ),
        const SizedBox(width: 12),
        OutlinedButton.icon(
          onPressed: () {
            provider.resetToDefault();
            _updateControllersFromConfig();

            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Row(
                  children: [
                    Icon(Icons.info, color: TechColors.glowCyan, size: 20),
                    SizedBox(width: 12),
                    Text('配置已重置为默认值',
                        style: TextStyle(color: TechColors.textPrimary)),
                  ],
                ),
                backgroundColor: TechColors.bgMedium,
                duration: Duration(seconds: 2),
              ),
            );
          },
          icon: const Icon(Icons.refresh, size: 18),
          label: const Text('重置默认'),
          style: OutlinedButton.styleFrom(
            foregroundColor: TechColors.textSecondary,
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            side: const BorderSide(color: TechColors.borderDark),
          ),
        ),
      ],
    );
  }

  /// 料仓容量配置区块（可展开）
  Widget _buildHopperCapacitySection({
    required int index,
    required String title,
    required String subtitle,
    required IconData icon,
    required Color accentColor,
    required List<HopperCapacityConfig> configs,
    required Function(int index, double? maxCapacity) onUpdate,
  }) {
    final isExpanded = _expandedIndex == index;

    return Container(
      decoration: BoxDecoration(
        color: TechColors.bgMedium.withOpacity(0.5),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(
          color:
              isExpanded ? accentColor.withOpacity(0.5) : TechColors.borderDark,
        ),
      ),
      child: Column(
        children: [
          // 标题栏
          InkWell(
            onTap: () {
              setState(() {
                _expandedIndex = isExpanded ? -1 : index;
              });
            },
            borderRadius: BorderRadius.circular(4),
            child: Container(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: accentColor.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Icon(icon, color: accentColor, size: 20),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: const TextStyle(
                            color: TechColors.textPrimary,
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          subtitle,
                          style: const TextStyle(
                            color: TechColors.textSecondary,
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Icon(
                    isExpanded ? Icons.expand_less : Icons.expand_more,
                    color: TechColors.textSecondary,
                  ),
                ],
              ),
            ),
          ),
          // 展开内容 - 表格
          if (isExpanded) ...[
            Container(height: 1, color: TechColors.borderDark),
            Padding(
              padding: const EdgeInsets.all(12),
              child: _buildHopperCapacityTable(configs, onUpdate),
            ),
          ],
        ],
      ),
    );
  }

  /// 料仓容量配置表格
  Widget _buildHopperCapacityTable(
    List<HopperCapacityConfig> configs,
    Function(int index, double? maxCapacity) onUpdate,
  ) {
    return Column(
      children: [
        // 表头
        Container(
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
          decoration: BoxDecoration(
            color: TechColors.bgDeep.withOpacity(0.5),
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(4),
              topRight: Radius.circular(4),
            ),
          ),
          child: Row(
            children: [
              const Expanded(
                flex: 3,
                child: Text(
                  '料仓名称',
                  style: TextStyle(
                    color: TechColors.textSecondary,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              Expanded(
                flex: 2,
                child: Row(
                  children: [
                    Container(
                      width: 10,
                      height: 10,
                      decoration: BoxDecoration(
                        color: TechColors.glowCyan,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    const SizedBox(width: 4),
                    const Text(
                      '最大容量 (kg)',
                      style: TextStyle(
                        color: TechColors.textSecondary,
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        // 表格行
        ...configs.asMap().entries.map((entry) {
          final idx = entry.key;
          final config = entry.value;
          return _buildHopperCapacityRow(idx, config, onUpdate);
        }),
      ],
    );
  }

  /// 料仓容量配置表格行
  Widget _buildHopperCapacityRow(
    int index,
    HopperCapacityConfig config,
    Function(int index, double? maxCapacity) onUpdate,
  ) {
    final maxCapacityController = _controllers['${config.key}_maxCapacity'];

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 12),
      decoration: BoxDecoration(
        color: index.isEven
            ? TechColors.bgDeep.withOpacity(0.3)
            : TechColors.bgMedium.withOpacity(0.3),
        border: Border(
          bottom: BorderSide(color: TechColors.borderDark.withOpacity(0.5)),
        ),
      ),
      child: Row(
        children: [
          // 料仓名称
          Expanded(
            flex: 3,
            child: Text(
              config.displayName,
              style: const TextStyle(
                color: TechColors.textPrimary,
                fontSize: 12,
              ),
            ),
          ),
          // 最大容量输入框
          Expanded(
            flex: 2,
            child: _buildInputField(
              controller: maxCapacityController,
              color: TechColors.glowCyan,
              onChanged: (value) {
                final v = double.tryParse(value);
                if (v != null && v > 0) {
                  onUpdate(index, v);
                }
              },
            ),
          ),
        ],
      ),
    );
  }
}

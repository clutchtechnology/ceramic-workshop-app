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
  // 当前展开的配置项
  int _expandedIndex = 0;

  // 控制器 Map，用于管理所有输入框
  final Map<String, TextEditingController> _controllers = {};

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initControllers();
    });
  }

  void _initControllers() {
    final provider = context.read<RealtimeConfigProvider>();

    // 初始化回转窑控制器
    for (var config in provider.rotaryKilnConfigs) {
      _controllers['${config.key}_normal'] =
          TextEditingController(text: config.normalMax.toString());
      _controllers['${config.key}_warning'] =
          TextEditingController(text: config.warningMax.toString());
    }

    // 初始化辊道窑控制器
    for (var config in provider.rollerKilnConfigs) {
      _controllers['${config.key}_normal'] =
          TextEditingController(text: config.normalMax.toString());
      _controllers['${config.key}_warning'] =
          TextEditingController(text: config.warningMax.toString());
    }

    // 初始化风机控制器
    for (var config in provider.fanConfigs) {
      _controllers['${config.key}_normal'] =
          TextEditingController(text: config.normalMax.toString());
      _controllers['${config.key}_warning'] =
          TextEditingController(text: config.warningMax.toString());
    }

    // 初始化SCR氨水泵控制器
    for (var config in provider.scrPumpConfigs) {
      _controllers['${config.key}_normal'] =
          TextEditingController(text: config.normalMax.toString());
      _controllers['${config.key}_warning'] =
          TextEditingController(text: config.warningMax.toString());
    }

    // 初始化SCR燃气表控制器
    for (var config in provider.scrGasConfigs) {
      _controllers['${config.key}_normal'] =
          TextEditingController(text: config.normalMax.toString());
      _controllers['${config.key}_warning'] =
          TextEditingController(text: config.warningMax.toString());
    }

    setState(() {});
  }

  void _updateControllersFromConfig() {
    final provider = context.read<RealtimeConfigProvider>();

    for (var config in provider.rotaryKilnConfigs) {
      _controllers['${config.key}_normal']?.text = config.normalMax.toString();
      _controllers['${config.key}_warning']?.text =
          config.warningMax.toString();
    }
    for (var config in provider.rollerKilnConfigs) {
      _controllers['${config.key}_normal']?.text = config.normalMax.toString();
      _controllers['${config.key}_warning']?.text =
          config.warningMax.toString();
    }
    for (var config in provider.fanConfigs) {
      _controllers['${config.key}_normal']?.text = config.normalMax.toString();
      _controllers['${config.key}_warning']?.text =
          config.warningMax.toString();
    }
    for (var config in provider.scrPumpConfigs) {
      _controllers['${config.key}_normal']?.text = config.normalMax.toString();
      _controllers['${config.key}_warning']?.text =
          config.warningMax.toString();
    }
    for (var config in provider.scrGasConfigs) {
      _controllers['${config.key}_normal']?.text = config.normalMax.toString();
      _controllers['${config.key}_warning']?.text =
          config.warningMax.toString();
    }
  }

  @override
  void dispose() {
    for (var controller in _controllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<RealtimeConfigProvider>(
      builder: (context, provider, child) {
        return SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 颜色说明
              _buildColorLegend(),
              const SizedBox(height: 20),

              // 回转窑温度配置
              _buildConfigSection(
                index: 0,
                title: '回转窑温度阈值配置',
                subtitle: '9个回转窑设备',
                icon: Icons.whatshot,
                accentColor: TechColors.glowOrange,
                unit: '℃',
                configs: provider.rotaryKilnConfigs,
                onUpdate: (index, normalMax, warningMax) {
                  provider.updateRotaryKilnConfig(index,
                      normalMax: normalMax, warningMax: warningMax);
                },
              ),

              const SizedBox(height: 12),

              // 辊道窑温度配置
              _buildConfigSection(
                index: 1,
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
                index: 2,
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
                index: 3,
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
                index: 4,
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

              const SizedBox(height: 24),
              _buildActionButtons(provider),
            ],
          ),
        );
      },
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
}

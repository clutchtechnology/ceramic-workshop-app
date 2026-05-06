import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../providers/realtime_config_provider.dart';
import '../data_display/data_tech_line_widgets.dart';

/// 启停阈值设置子页面
class RunningThresholdSettingsWidget extends StatefulWidget {
  const RunningThresholdSettingsWidget({super.key});

  @override
  State<RunningThresholdSettingsWidget> createState() =>
      _RunningThresholdSettingsWidgetState();
}

class _RunningThresholdSettingsWidgetState
    extends State<RunningThresholdSettingsWidget> {
  int _expandedIndex = 0;
  final Map<String, TextEditingController> _controllers = {};

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _initControllers();
      }
    });
  }

  void _initControllers() {
    final provider = context.read<RealtimeConfigProvider>();
    _initRunningControllers(provider.rotaryKilnRunningConfigs);
    _initRunningControllers(provider.fanRunningConfigs);
    _initRunningControllers(provider.scrPumpRunningConfigs);
    _initRunningControllers(provider.scrGasRunningConfigs);
    setState(() {});
  }

  void _initRunningControllers(List<RunningThresholdConfig> configs) {
    for (var config in configs) {
      _controllers[config.key] =
          TextEditingController(text: config.runningThreshold.toString());
    }
  }

  void _refreshControllers() {
    final provider = context.read<RealtimeConfigProvider>();
    _syncControllers(provider.rotaryKilnRunningConfigs);
    _syncControllers(provider.fanRunningConfigs);
    _syncControllers(provider.scrPumpRunningConfigs);
    _syncControllers(provider.scrGasRunningConfigs);
  }

  void _syncControllers(List<RunningThresholdConfig> configs) {
    for (var config in configs) {
      _controllers[config.key]?.text = config.runningThreshold.toString();
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
    final provider = context.watch<RealtimeConfigProvider>();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildTips(),
          const SizedBox(height: 20),
          _buildSection(
            index: 0,
            title: '回转窑运行阈值',
            subtitle: '9台回转窑，依据功率判定运行/停止',
            icon: Icons.local_fire_department,
            accentColor: TechColors.glowOrange,
            unit: 'kW',
            configs: provider.rotaryKilnRunningConfigs,
            onUpdate: (index, value) {
              provider.updateRotaryKilnRunningConfig(index,
                  runningThreshold: value);
            },
          ),
          const SizedBox(height: 12),
          _buildSection(
            index: 1,
            title: '风机运行阈值',
            subtitle: '2台风机，依据功率判定运行/停止',
            icon: Icons.air,
            accentColor: TechColors.glowCyan,
            unit: 'kW',
            configs: provider.fanRunningConfigs,
            onUpdate: (index, value) {
              provider.updateFanRunningConfig(index, runningThreshold: value);
            },
          ),
          const SizedBox(height: 12),
          _buildSection(
            index: 2,
            title: 'SCR氨水泵运行阈值',
            subtitle: '2台氨水泵，依据功率判定运行/停止',
            icon: Icons.water_drop,
            accentColor: TechColors.glowBlue,
            unit: 'kW',
            configs: provider.scrPumpRunningConfigs,
            onUpdate: (index, value) {
              provider.updateScrPumpRunningConfig(index,
                  runningThreshold: value);
            },
          ),
          const SizedBox(height: 12),
          _buildSection(
            index: 3,
            title: 'SCR燃气表运行阈值',
            subtitle: '2块燃气表，依据流量判定运行/停止',
            icon: Icons.gas_meter,
            accentColor: TechColors.glowGreen,
            unit: 'm³/h',
            configs: provider.scrGasRunningConfigs,
            onUpdate: (index, value) {
              provider.updateScrGasRunningConfig(index,
                  runningThreshold: value);
            },
          ),
          const SizedBox(height: 24),
          _buildActionButtons(provider),
        ],
      ),
    );
  }

  Widget _buildTips() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: TechColors.bgMedium.withOpacity(0.5),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: TechColors.borderDark),
      ),
      child: const Row(
        children: [
          Icon(Icons.info_outline, color: TechColors.glowCyan, size: 20),
          SizedBox(width: 10),
          Expanded(
            child: Text(
              '判定规则统一为: 实时值 >= 运行阈值 即显示“运行”，否则显示“停止”。',
              style: TextStyle(color: TechColors.textSecondary, fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSection({
    required int index,
    required String title,
    required String subtitle,
    required IconData icon,
    required Color accentColor,
    required String unit,
    required List<RunningThresholdConfig> configs,
    required Function(int index, double? value) onUpdate,
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
          if (isExpanded) ...[
            Container(height: 1, color: TechColors.borderDark),
            Padding(
              padding: const EdgeInsets.all(12),
              child: _buildTable(configs, unit, onUpdate),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildTable(
    List<RunningThresholdConfig> configs,
    String unit,
    Function(int index, double? value) onUpdate,
  ) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
          decoration: BoxDecoration(
            color: TechColors.bgDeep.withOpacity(0.5),
            borderRadius: BorderRadius.circular(4),
          ),
          child: const Row(
            children: [
              Expanded(
                flex: 5,
                child: Text(
                  '设备',
                  style: TextStyle(
                    color: TechColors.textSecondary,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              Expanded(
                flex: 4,
                child: Text(
                  '运行阈值',
                  style: TextStyle(
                    color: TechColors.textSecondary,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        ...List.generate(configs.length, (index) {
          final config = configs[index];
          return Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              children: [
                Expanded(
                  flex: 5,
                  child: Text(
                    config.displayName,
                    style: const TextStyle(
                      color: TechColors.textPrimary,
                      fontSize: 12,
                    ),
                  ),
                ),
                Expanded(
                  flex: 4,
                  child: _buildInputField(
                    controller: _controllers[config.key],
                    unit: unit,
                    onChanged: (value) {
                      onUpdate(index, value);
                    },
                  ),
                ),
              ],
            ),
          );
        }),
      ],
    );
  }

  Widget _buildInputField({
    required TextEditingController? controller,
    required String unit,
    required Function(double? value) onChanged,
  }) {
    return SizedBox(
      height: 34,
      child: TextField(
        controller: controller,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        inputFormatters: [
          FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*')),
        ],
        style: const TextStyle(
          color: TechColors.glowCyan,
          fontSize: 12,
          fontFamily: 'Roboto Mono',
        ),
        decoration: InputDecoration(
          isDense: true,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
          suffixText: unit,
          suffixStyle: const TextStyle(
            color: TechColors.textSecondary,
            fontSize: 11,
          ),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(4),
            borderSide: const BorderSide(color: TechColors.borderDark),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(4),
            borderSide: const BorderSide(color: TechColors.borderDark),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(4),
            borderSide:
                const BorderSide(color: TechColors.glowCyan, width: 1.2),
          ),
          filled: true,
          fillColor: TechColors.bgDeep.withOpacity(0.6),
        ),
        onChanged: (text) {
          final value = double.tryParse(text);
          onChanged(value);
        },
      ),
    );
  }

  Widget _buildActionButtons(RealtimeConfigProvider provider) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        OutlinedButton.icon(
          onPressed: () async {
            final ok = await provider.saveConfig();
            if (!mounted) return;
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(ok ? '启停阈值已保存' : '保存失败，请重试'),
                backgroundColor: ok ? Colors.green : Colors.red,
              ),
            );
          },
          icon: const Icon(Icons.save, size: 16),
          label: const Text('保存配置'),
          style: OutlinedButton.styleFrom(
            foregroundColor: TechColors.glowGreen,
            side: const BorderSide(color: TechColors.glowGreen),
          ),
        ),
        const SizedBox(width: 12),
        OutlinedButton.icon(
          onPressed: () {
            provider.resetToDefault();
            _refreshControllers();
            if (!mounted) return;
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('已恢复默认阈值'),
                backgroundColor: Colors.orange,
              ),
            );
          },
          icon: const Icon(Icons.restore, size: 16),
          label: const Text('恢复默认'),
          style: OutlinedButton.styleFrom(
            foregroundColor: TechColors.glowOrange,
            side: const BorderSide(color: TechColors.glowOrange),
          ),
        ),
      ],
    );
  }
}

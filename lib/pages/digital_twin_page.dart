import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../widgets/tech_line_widgets.dart';
import 'realtime_dashboard_page.dart';
import 'data_display_page.dart';
import 'settings_page.dart';

/// 智能生产线数字孪生系统页面
/// 参考工业 SCADA/数字孪生可视化设计
class DigitalTwinPage extends StatefulWidget {
  const DigitalTwinPage({super.key});

  @override
  State<DigitalTwinPage> createState() => _DigitalTwinPageState();
}

class _DigitalTwinPageState extends State<DigitalTwinPage> {
  int _selectedNavIndex = 0;

  // UI固定数据 - 产线概览（待接入PLC数据）
  final List<_ProductionLine> _productionLines = [
    _ProductionLine(name: '产品一', progress: 0.0, orderQty: 0, completedQty: 0),
    _ProductionLine(name: '产品二', progress: 0.0, orderQty: 0, completedQty: 0),
  ];

  // UI固定数据 - 设备状态（待接入PLC数据）
  final List<_EquipmentData> _equipments = [
    _EquipmentData(
        code: 'VTC-16A-11', name: '立式加工中心', status: EquipmentStatus.offline),
    _EquipmentData(
        code: 'VTC-16A-12', name: '立式加工中心', status: EquipmentStatus.offline),
    _EquipmentData(
        code: 'XH-718A', name: '卧式加工中心', status: EquipmentStatus.offline),
    _EquipmentData(
        code: 'XH2420C', name: '龙门加工中心', status: EquipmentStatus.offline),
  ];

  // UI固定数据 - 环境指标（待接入PLC数据）
  final _EnvironmentData _envData = _EnvironmentData(
    temperature: 0.0,
    humidity: 0.0,
    power: 0.0,
    ratedPower: 0.0,
    actualPower: 0.0,
  );

  // UI固定数据 - 警报信息（待接入PLC数据）
  final List<_AlarmData> _alarms = [
    _AlarmData(
      type: '紧急设备',
      device: '危险情况及原因',
      message: '解决建议',
      level: AlarmLevel.alarm,
    ),
    _AlarmData(
      type: '故障设备',
      device: '故障情况及原因',
      message: '解决建议',
      level: AlarmLevel.warning,
    ),
    _AlarmData(
      type: '故障设备',
      device: '故障情况及原因',
      message: '解决建议',
      level: AlarmLevel.warning,
    ),
  ];

  @override
  void initState() {
    super.initState();
    // TODO: 接入PLC数据后，在此处初始化数据连接
  }

  @override
  void dispose() {
    // TODO: 接入PLC数据后，在此处释放数据连接
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: TechColors.bgDeep,
      body: AnimatedGridBackground(
        gridColor: TechColors.borderDark.withOpacity(0.3),
        gridSize: 40,
        child: Column(
          children: [
            // 顶部导航栏
            _buildTopNavBar(),
            // 主内容区 - 根据选择的Tab显示不同页面
            Expanded(
              child: _buildSelectedView(),
            ),
          ],
        ),
      ),
    );
  }

  /// 根据选中的导航项构建对应视图
  Widget _buildSelectedView() {
    switch (_selectedNavIndex) {
      case 0:
        // 实时大屏
        return const RealtimeDashboardPage();
      case 1:
        // 数据展示
        return const DataDisplayPage();
      case 2:
        // 系统配置
        return const SettingsPage();
      default:
        // 实时大屏（默认）
        return const RealtimeDashboardPage();
    }
  }

  /// 数字孪生视图（原页面内容）
  Widget _buildDigitalTwinView() {
    return Column(
      children: [
        Expanded(
          child: Row(
            children: [
              // 左侧面板
              _buildLeftPanel(),
              // 中间3D视图区
              Expanded(
                flex: 3,
                child: _buildCenterView(),
              ),
              // 右侧面板
              _buildRightPanel(),
            ],
          ),
        ),
        // 底部面板
        _buildBottomPanel(),
      ],
    );
  }

  /// 顶部导航栏
  Widget _buildTopNavBar() {
    final navItems = ['实时大屏', '数据展示', '系统配置'];

    return Container(
      height: 50,
      padding: const EdgeInsets.symmetric(horizontal: 20),
      decoration: BoxDecoration(
        color: TechColors.bgDark.withOpacity(0.9),
        border: Border(
          bottom: BorderSide(
            color: TechColors.glowCyan.withOpacity(0.3),
          ),
        ),
      ),
      child: Row(
        children: [
          // Logo/标题
          Row(
            children: [
              Container(
                width: 4,
                height: 24,
                decoration: BoxDecoration(
                  color: TechColors.glowCyan,
                  borderRadius: BorderRadius.circular(2),
                  boxShadow: [
                    BoxShadow(
                      color: TechColors.glowCyan.withOpacity(0.5),
                      blurRadius: 8,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              ShaderMask(
                shaderCallback: (bounds) => const LinearGradient(
                  colors: [TechColors.glowCyan, TechColors.glowCyanLight],
                ).createShader(bounds),
                child: const Text(
                  'Ceramic Workshop Digital Twin',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 2,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(width: 40),
          // 导航项
          ...List.generate(navItems.length, (index) {
            final isSelected = _selectedNavIndex == index;
            return GestureDetector(
              onTap: () => setState(() => _selectedNavIndex = index),
              child: Container(
                margin: const EdgeInsets.only(right: 8),
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: isSelected
                      ? TechColors.glowCyan.withOpacity(0.15)
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(
                    color: isSelected
                        ? TechColors.glowCyan.withOpacity(0.5)
                        : Colors.transparent,
                  ),
                ),
                child: Text(
                  navItems[index],
                  style: TextStyle(
                    color: isSelected
                        ? TechColors.glowCyan
                        : TechColors.textSecondary,
                    fontSize: 13,
                    fontWeight: isSelected ? FontWeight.w500 : FontWeight.w400,
                  ),
                ),
              ),
            );
          }),
          const Spacer(),
          // 时间显示
          _buildClockDisplay(),
        ],
      ),
    );
  }

  Widget _buildClockDisplay() {
    return StreamBuilder(
      stream: Stream.periodic(const Duration(seconds: 1)),
      builder: (context, snapshot) {
        final now = DateTime.now();
        final timeStr =
            '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}:${now.second.toString().padLeft(2, '0')}';
        final dateStr =
            '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';

        return Row(
          children: [
            Text(
              dateStr,
              style: const TextStyle(
                color: TechColors.textSecondary,
                fontSize: 12,
                fontFamily: 'Roboto Mono',
              ),
            ),
            const SizedBox(width: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: BoxDecoration(
                color: TechColors.bgMedium,
                borderRadius: BorderRadius.circular(4),
                border: Border.all(
                  color: TechColors.glowCyan.withOpacity(0.3),
                ),
              ),
              child: Text(
                timeStr,
                style: TextStyle(
                  color: TechColors.glowCyan,
                  fontSize: 14,
                  fontFamily: 'Roboto Mono',
                  fontWeight: FontWeight.w500,
                  shadows: [
                    Shadow(
                      color: TechColors.glowCyan.withOpacity(0.5),
                      blurRadius: 8,
                    ),
                  ],
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  /// 左侧面板 - 产线概览
  Widget _buildLeftPanel() {
    return Container(
      width: 220,
      margin: const EdgeInsets.all(12),
      child: TechPanel(
        title: '产线概览',
        accentColor: TechColors.glowCyan,
        child: SingleChildScrollView(
          child: Column(
            children: [
              ..._productionLines.map((line) => _buildProductionLineCard(line)),
              const SizedBox(height: 16),
              // 总体生产情况
              _buildTotalProductionInfo(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildProductionLineCard(_ProductionLine line) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: TechColors.bgMedium.withOpacity(0.3),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: TechColors.borderDark),
      ),
      child: Row(
        children: [
          // 圆形进度
          TechCircularProgress(
            value: line.progress,
            size: 60,
            color: TechColors.glowCyan,
            label: '完成率',
          ),
          const SizedBox(width: 12),
          // 信息
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  line.name,
                  style: const TextStyle(
                    color: TechColors.textPrimary,
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 8),
                _buildInfoRow('订单量', '${line.orderQty}'),
                _buildInfoRow('成品量', '${line.completedQty}'),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        children: [
          Text(
            '$label: ',
            style: const TextStyle(
              color: TechColors.textSecondary,
              fontSize: 11,
            ),
          ),
          Text(
            value,
            style: const TextStyle(
              color: TechColors.textPrimary,
              fontSize: 11,
              fontFamily: 'Roboto Mono',
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTotalProductionInfo() {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: TechColors.bgMedium.withOpacity(0.5),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(
          color: TechColors.glowCyan.withOpacity(0.3),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 3,
                height: 12,
                decoration: BoxDecoration(
                  color: TechColors.glowCyan,
                  borderRadius: BorderRadius.circular(1),
                ),
              ),
              const SizedBox(width: 8),
              const Text(
                '总体生产情况',
                style: TextStyle(
                  color: TechColors.textPrimary,
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // 生产指标网格
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              _buildMiniMetric('计划', '0'),
              _buildMiniMetric('完成', '0'),
              _buildMiniMetric('进度', '0%'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMiniMetric(String label, String value) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: TechColors.bgDark,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            value,
            style: TextStyle(
              color: TechColors.glowCyan,
              fontSize: 12,
              fontWeight: FontWeight.w600,
              fontFamily: 'Roboto Mono',
              shadows: [
                Shadow(
                  color: TechColors.glowCyan.withOpacity(0.3),
                  blurRadius: 4,
                ),
              ],
            ),
          ),
          Text(
            label,
            style: const TextStyle(
              color: TechColors.textSecondary,
              fontSize: 9,
            ),
          ),
        ],
      ),
    );
  }

  /// 中间3D视图区
  Widget _buildCenterView() {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 12),
      child: ScanLineContainer(
        scanColor: TechColors.glowCyan,
        duration: const Duration(seconds: 4),
        child: Stack(
          children: [
            // 3D 工厂模型占位 (实际项目中可使用 flutter_gl 或 model_viewer)
            Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.factory,
                    size: 120,
                    color: TechColors.glowCyan.withOpacity(0.3),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    '3D 生产线模型',
                    style: TextStyle(
                      color: TechColors.textSecondary,
                      fontSize: 14,
                      letterSpacing: 2,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '(可集成 three.js / Unity WebGL)',
                    style: TextStyle(
                      color: TechColors.textMuted,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            // 数据流动线条装饰
            Positioned(
              left: 20,
              top: 100,
              child: DataFlowLine(
                width: 150,
                height: 2,
                color: TechColors.glowCyan,
              ),
            ),
            Positioned(
              right: 20,
              bottom: 100,
              child: DataFlowLine(
                width: 150,
                height: 2,
                color: TechColors.glowGreen,
              ),
            ),
            Positioned(
              left: 50,
              bottom: 50,
              child: DataFlowLine(
                width: 2,
                height: 80,
                direction: Axis.vertical,
                color: TechColors.glowOrange,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 右侧面板 - 设备情况 + 环境指标
  Widget _buildRightPanel() {
    return Container(
      width: 220,
      margin: const EdgeInsets.all(12),
      child: SingleChildScrollView(
        child: Column(
          children: [
            // 设备情况
            SizedBox(
              height: 320,
              child: TechPanel(
                title: '设备情况',
                accentColor: TechColors.glowGreen,
                child: SingleChildScrollView(
                  child: Column(
                    children: _equipments
                        .map((eq) => Padding(
                              padding: const EdgeInsets.only(bottom: 8),
                              child: EquipmentStatusIndicator(
                                name: eq.name,
                                code: eq.code,
                                status: eq.status,
                              ),
                            ))
                        .toList(),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
            // 环境指标
            SizedBox(
              height: 280,
              child: TechPanel(
                title: '环境指标',
                accentColor: TechColors.glowBlue,
                child: SingleChildScrollView(
                  child: Column(
                    children: [
                      DataMetricCard(
                        label: '环境温度',
                        value: '${_envData.temperature}',
                        unit: '℃',
                        icon: Icons.thermostat,
                      ),
                      const SizedBox(height: 8),
                      DataMetricCard(
                        label: '环境湿度',
                        value: '${_envData.humidity}',
                        unit: '%',
                        icon: Icons.water_drop,
                      ),
                      const SizedBox(height: 8),
                      DataMetricCard(
                        label: '实时电量',
                        value: '${_envData.power}',
                        unit: 'kW·h',
                        icon: Icons.bolt,
                        valueColor: TechColors.glowOrange,
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: DataMetricCard(
                              label: '额定功率',
                              value: '${_envData.ratedPower}',
                              unit: 'kW',
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: DataMetricCard(
                              label: '实际功率',
                              value: '${_envData.actualPower}',
                              unit: 'kW',
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 底部面板 - 警报 + 预测
  Widget _buildBottomPanel() {
    return Container(
      height: 180,
      margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
      child: Row(
        children: [
          // 产线警报
          Expanded(
            flex: 2,
            child: TechPanel(
              title: '产线警报',
              accentColor: TechColors.statusWarning,
              headerActions: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: TechColors.statusAlarm.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    '${_alarms.length}',
                    style: const TextStyle(
                      color: TechColors.statusAlarm,
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
              child: ListView(
                children: _alarms
                    .map((alarm) => AlarmListItem(
                          type: alarm.type,
                          device: alarm.device,
                          message: alarm.message,
                          solution: '解决建议',
                          level: alarm.level,
                        ))
                    .toList(),
              ),
            ),
          ),
          const SizedBox(width: 12),
          // 产量预测
          Expanded(
            flex: 2,
            child: TechPanel(
              title: '产量预测',
              accentColor: TechColors.glowCyan,
              headerActions: [
                Row(
                  children: [
                    _buildPredictionTab('产量', true),
                    _buildPredictionTab('定位', false),
                    _buildPredictionTab('预测', false),
                  ],
                ),
              ],
              child: _buildProductionChart(),
            ),
          ),
          const SizedBox(width: 12),
          // 订单预测
          Expanded(
            flex: 1,
            child: TechPanel(
              title: '订单预测完成时间',
              accentColor: TechColors.glowGreen,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _buildOrderPrediction('订单产品一', '预测:', '0h0min'),
                    const SizedBox(height: 6),
                    _buildOrderPrediction('订单产品二', '预测:', '0h0min'),
                    const SizedBox(height: 6),
                    _buildOrderPrediction('订单产品三', '预测:', '0h0min'),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPredictionTab(String label, bool isActive) {
    return Container(
      margin: const EdgeInsets.only(right: 4),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: isActive
            ? TechColors.glowCyan.withOpacity(0.2)
            : Colors.transparent,
        borderRadius: BorderRadius.circular(3),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: isActive ? TechColors.glowCyan : TechColors.textSecondary,
          fontSize: 10,
        ),
      ),
    );
  }

  Widget _buildProductionChart() {
    // 简化的条形图
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: List.generate(8, (index) {
        final height = 20.0 + (index * 8) + (index % 3 * 15);
        return Container(
          width: 20,
          height: height,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.bottomCenter,
              end: Alignment.topCenter,
              colors: [
                TechColors.glowCyan,
                TechColors.glowCyan.withOpacity(0.3),
              ],
            ),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(2)),
            boxShadow: [
              BoxShadow(
                color: TechColors.glowCyan.withOpacity(0.3),
                blurRadius: 8,
                offset: const Offset(0, -2),
              ),
            ],
          ),
        );
      }),
    );
  }

  Widget _buildOrderPrediction(String product, String label, String time) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: TechColors.bgMedium.withOpacity(0.3),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            product,
            style: const TextStyle(
              color: TechColors.textPrimary,
              fontSize: 11,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              Text(
                label,
                style: const TextStyle(
                  color: TechColors.textSecondary,
                  fontSize: 10,
                ),
              ),
              const Spacer(),
              Text(
                time,
                style: TextStyle(
                  color: TechColors.glowGreen,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  fontFamily: 'Roboto Mono',
                  shadows: [
                    Shadow(
                      color: TechColors.glowGreen.withOpacity(0.5),
                      blurRadius: 4,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ============================================================================
// 数据模型
// ============================================================================

class _ProductionLine {
  final String name;
  final double progress;
  final int orderQty;
  final int completedQty;

  _ProductionLine({
    required this.name,
    required this.progress,
    required this.orderQty,
    required this.completedQty,
  });
}

class _EquipmentData {
  final String code;
  final String name;
  final EquipmentStatus status;

  _EquipmentData({
    required this.code,
    required this.name,
    required this.status,
  });
}

class _EnvironmentData {
  final double temperature;
  final double humidity;
  final double power;
  final double ratedPower;
  final double actualPower;

  _EnvironmentData({
    required this.temperature,
    required this.humidity,
    required this.power,
    required this.ratedPower,
    required this.actualPower,
  });
}

class _AlarmData {
  final String type;
  final String device;
  final String message;
  final AlarmLevel level;

  _AlarmData({
    required this.type,
    required this.device,
    required this.message,
    required this.level,
  });
}

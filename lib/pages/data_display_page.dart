import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../widgets/tech_line_widgets.dart';

/// 数据展示页面
/// 包含三个设备容器：回转窑、辊道窑、SCR设备
class DataDisplayPage extends StatefulWidget {
  const DataDisplayPage({super.key});

  @override
  State<DataDisplayPage> createState() => _DataDisplayPageState();
}

class _DataDisplayPageState extends State<DataDisplayPage> {
  // 时间范围选择
  DateTime _startTime = DateTime.now().subtract(const Duration(hours: 24));
  DateTime _endTime = DateTime.now();

  // 7个回转窑的选择状态
  final List<bool> _selectedKilns = List.generate(7, (_) => true);

  // 模拟温度数据（待接入PLC）- 7个回转窑
  final Map<int, List<FlSpot>> _temperatureData = {};

  // 模拟下料速度数据（待接入PLC）- 7个回转窑
  final Map<int, List<FlSpot>> _feedSpeedData = {};

  // 模拟料仓重量数据（待接入PLC）- 7个回转窑
  final Map<int, List<FlSpot>> _hopperWeightData = {};

  // 辊道窑的选择状态（3个辊道窑）
  final List<bool> _selectedRollerKilns = List.generate(3, (_) => true);

  // 模拟辊道窑温度数据（待接入PLC）- 3个辊道窑
  final Map<int, List<FlSpot>> _rollerTemperatureData = {};

  // 模拟辊道窑能耗数据（待接入PLC）- 3个辊道窑
  final Map<int, List<FlSpot>> _rollerEnergyData = {};

  // 模拟辊道窑功率数据（待接入PLC）- 3个辊道窑
  final Map<int, List<FlSpot>> _rollerPowerData = {};

  // SCR设备的选择状态（2个水泵，2个风机）
  final List<bool> _selectedPumps = List.generate(2, (_) => true);
  final List<bool> _selectedFans = List.generate(2, (_) => true);

  // 模拟SCR水泵能耗数据（待接入PLC）- 2个水泵
  final Map<int, List<FlSpot>> _pumpEnergyData = {};

  // 模拟SCR风机能耗数据（待接入PLC）- 2个风机
  final Map<int, List<FlSpot>> _fanEnergyData = {};

  // 7种不同的颜色用于区分不同回转窑
  final List<Color> _kilnColors = [
    TechColors.glowOrange,
    TechColors.glowCyan,
    TechColors.glowGreen,
    const Color(0xFFff3b30), // Red
    const Color(0xFFffcc00), // Yellow
    const Color(0xFFaf52de), // Purple
    const Color(0xFF00d4ff), // Light Blue
  ];

  // 3种不同的颜色用于区分不同辊道窑
  final List<Color> _rollerKilnColors = [
    TechColors.glowCyan,
    TechColors.glowGreen,
    const Color(0xFFaf52de), // Purple
  ];

  // 2种不同的颜色用于区分SCR设备
  final List<Color> _scrColors = [
    TechColors.glowGreen,
    TechColors.glowOrange,
  ];

  @override
  void initState() {
    super.initState();
    _generateMockData();
  }

  // 生成模拟数据 - 为7个回转窑生成数据
  void _generateMockData() {
    for (int kiln = 0; kiln < 7; kiln++) {
      _temperatureData[kiln] = List.generate(24, (index) {
        return FlSpot(
          index.toDouble(),
          800 + (index * 10) + (index % 5 * 20) + (kiln * 30),
        );
      });

      _feedSpeedData[kiln] = List.generate(24, (index) {
        return FlSpot(
          index.toDouble(),
          100 + (index * 5) + (index % 4 * 10) + (kiln * 15),
        );
      });

      _hopperWeightData[kiln] = List.generate(24, (index) {
        return FlSpot(
          index.toDouble(),
          500 - (index * 15) + (index % 3 * 20) + (kiln * 10),
        );
      });
    }

    // 为3个辊道窑生成模拟数据
    for (int kiln = 0; kiln < 3; kiln++) {
      _rollerTemperatureData[kiln] = List.generate(24, (index) {
        return FlSpot(
          index.toDouble(),
          900 + (index * 8) + (index % 6 * 15) + (kiln * 25),
        );
      });

      _rollerEnergyData[kiln] = List.generate(24, (index) {
        return FlSpot(
          index.toDouble(),
          200 + (index * 6) + (index % 5 * 12) + (kiln * 20),
        );
      });

      _rollerPowerData[kiln] = List.generate(24, (index) {
        return FlSpot(
          index.toDouble(),
          150 + (index * 4) + (index % 4 * 8) + (kiln * 18),
        );
      });
    }

    // 为2个水泵生成模拟能耗数据
    for (int pump = 0; pump < 2; pump++) {
      _pumpEnergyData[pump] = List.generate(24, (index) {
        return FlSpot(
          index.toDouble(),
          50 + (index * 3) + (index % 4 * 8) + (pump * 12),
        );
      });
    }

    // 为2个风机生成模拟能耗数据
    for (int fan = 0; fan < 2; fan++) {
      _fanEnergyData[fan] = List.generate(24, (index) {
        return FlSpot(
          index.toDouble(),
          80 + (index * 4) + (index % 5 * 10) + (fan * 15),
        );
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: TechColors.bgDeep,
      child: Row(
        children: [
          // 左侧：回转窑容器（2/5宽度，全高）
          Expanded(
            flex: 2,
            child: Container(
              margin: const EdgeInsets.all(12),
              child: TechPanel(
                title: '回转窑',
                accentColor: TechColors.glowOrange,
                child: Column(
                  children: [
                    // 时间选择器
                    _buildTimeRangeSelector(),
                    const SizedBox(height: 12),
                    // 历史温度曲线
                    Expanded(
                      child: _buildTemperatureChart(),
                    ),
                    const SizedBox(height: 12),
                    // 下料速度曲线
                    Expanded(
                      child: _buildFeedSpeedChart(),
                    ),
                    const SizedBox(height: 12),
                    // 料仓重量曲线
                    Expanded(
                      child: _buildHopperWeightChart(),
                    ),
                  ],
                ),
              ),
            ),
          ),
          // 右侧：辊道窑和SCR设备（3/5宽度）
          Expanded(
            flex: 3,
            child: Column(
              children: [
                // 上部：辊道窑容器（3/5高度）
                Expanded(
                  flex: 3,
                  child: Container(
                    margin: const EdgeInsets.fromLTRB(0, 12, 12, 6),
                    child: TechPanel(
                      title: '辊道窑',
                      accentColor: TechColors.glowCyan,
                      child: Column(
                        children: [
                          // 时间选择器
                          _buildRollerTimeRangeSelector(),
                          const SizedBox(height: 12),
                          // 三个图表横向排列
                          Expanded(
                            child: Row(
                              children: [
                                // 历史温度曲线
                                Expanded(
                                  child: _buildRollerTemperatureChart(),
                                ),
                                const SizedBox(width: 12),
                                // 历史能耗曲线
                                Expanded(
                                  child: _buildRollerEnergyChart(),
                                ),
                                const SizedBox(width: 12),
                                // 历史功率曲线
                                Expanded(
                                  child: _buildRollerPowerChart(),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                // 下部：SCR设备容器（2/5高度）
                Expanded(
                  flex: 2,
                  child: Container(
                    margin: const EdgeInsets.fromLTRB(0, 6, 12, 12),
                    child: TechPanel(
                      title: 'SCR设备',
                      accentColor: TechColors.glowGreen,
                      child: Column(
                        children: [
                          // 时间选择器
                          _buildScrTimeRangeSelector(),
                          const SizedBox(height: 12),
                          // 两个图表横向排列
                          Expanded(
                            child: Row(
                              children: [
                                // 水泵能耗曲线
                                Expanded(
                                  child: _buildPumpEnergyChart(),
                                ),
                                const SizedBox(width: 12),
                                // 风机能耗曲线
                                Expanded(
                                  child: _buildFanEnergyChart(),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// 时间范围选择器
  Widget _buildTimeRangeSelector() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: TechColors.bgMedium.withOpacity(0.5),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(
          color: TechColors.glowOrange.withOpacity(0.3),
        ),
      ),
      child: Row(
        children: [
          Icon(
            Icons.date_range,
            size: 16,
            color: TechColors.glowOrange,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: GestureDetector(
              onTap: () => _selectStartTime(),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: TechColors.bgDark,
                  borderRadius: BorderRadius.circular(3),
                ),
                child: Text(
                  _formatDateTime(_startTime),
                  style: const TextStyle(
                    color: TechColors.textPrimary,
                    fontSize: 11,
                    fontFamily: 'Roboto Mono',
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          const Text(
            '~',
            style: TextStyle(
              color: TechColors.textSecondary,
              fontSize: 12,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: GestureDetector(
              onTap: () => _selectEndTime(),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: TechColors.bgDark,
                  borderRadius: BorderRadius.circular(3),
                ),
                child: Text(
                  _formatDateTime(_endTime),
                  style: const TextStyle(
                    color: TechColors.textPrimary,
                    fontSize: 11,
                    fontFamily: 'Roboto Mono',
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// 历史温度曲线图
  Widget _buildTemperatureChart() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: TechColors.bgMedium.withOpacity(0.3),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: TechColors.borderDark),
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
                  color: TechColors.glowOrange,
                  borderRadius: BorderRadius.circular(1),
                ),
              ),
              const SizedBox(width: 8),
              const Text(
                '历史温度曲线',
                style: TextStyle(
                  color: TechColors.textPrimary,
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const Spacer(),
              // 回转窑多选下拉框
              _buildKilnSelector(),
            ],
          ),
          const SizedBox(height: 12),
          Expanded(
            child: LineChart(
              LineChartData(
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: true,
                  horizontalInterval: 50,
                  verticalInterval: 4,
                  getDrawingHorizontalLine: (value) {
                    return FlLine(
                      color: TechColors.borderDark.withOpacity(0.3),
                      strokeWidth: 1,
                    );
                  },
                  getDrawingVerticalLine: (value) {
                    return FlLine(
                      color: TechColors.borderDark.withOpacity(0.3),
                      strokeWidth: 1,
                    );
                  },
                ),
                titlesData: FlTitlesData(
                  leftTitles: AxisTitles(
                    axisNameWidget: const Text(
                      '温度(°C)',
                      style: TextStyle(
                        color: TechColors.textSecondary,
                        fontSize: 10,
                      ),
                    ),
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 40,
                      getTitlesWidget: (value, meta) {
                        return Text(
                          value.toInt().toString(),
                          style: const TextStyle(
                            color: TechColors.textSecondary,
                            fontSize: 9,
                          ),
                        );
                      },
                    ),
                  ),
                  bottomTitles: AxisTitles(
                    axisNameWidget: const Text(
                      '时间(h)',
                      style: TextStyle(
                        color: TechColors.textSecondary,
                        fontSize: 10,
                      ),
                    ),
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 24,
                      interval: 4,
                      getTitlesWidget: (value, meta) {
                        return Text(
                          value.toInt().toString(),
                          style: const TextStyle(
                            color: TechColors.textSecondary,
                            fontSize: 9,
                          ),
                        );
                      },
                    ),
                  ),
                  rightTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  topTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                ),
                borderData: FlBorderData(
                  show: true,
                  border: Border.all(
                    color: TechColors.borderDark.withOpacity(0.5),
                  ),
                ),
                lineBarsData: _getSelectedKilnData(_temperatureData),
                minY: 700,
                maxY: 1200,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// 下料速度曲线图
  Widget _buildFeedSpeedChart() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: TechColors.bgMedium.withOpacity(0.3),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: TechColors.borderDark),
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
                '下料速度曲线',
                style: TextStyle(
                  color: TechColors.textPrimary,
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const Spacer(),
              // 回转窑多选下拉框
              _buildKilnSelector(),
            ],
          ),
          const SizedBox(height: 12),
          Expanded(
            child: LineChart(
              LineChartData(
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: true,
                  horizontalInterval: 50,
                  verticalInterval: 4,
                  getDrawingHorizontalLine: (value) {
                    return FlLine(
                      color: TechColors.borderDark.withOpacity(0.3),
                      strokeWidth: 1,
                    );
                  },
                  getDrawingVerticalLine: (value) {
                    return FlLine(
                      color: TechColors.borderDark.withOpacity(0.3),
                      strokeWidth: 1,
                    );
                  },
                ),
                titlesData: FlTitlesData(
                  leftTitles: AxisTitles(
                    axisNameWidget: const Text(
                      '速度(kg/h)',
                      style: TextStyle(
                        color: TechColors.textSecondary,
                        fontSize: 10,
                      ),
                    ),
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 40,
                      getTitlesWidget: (value, meta) {
                        return Text(
                          value.toInt().toString(),
                          style: const TextStyle(
                            color: TechColors.textSecondary,
                            fontSize: 9,
                          ),
                        );
                      },
                    ),
                  ),
                  bottomTitles: AxisTitles(
                    axisNameWidget: const Text(
                      '时间(h)',
                      style: TextStyle(
                        color: TechColors.textSecondary,
                        fontSize: 10,
                      ),
                    ),
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 24,
                      interval: 4,
                      getTitlesWidget: (value, meta) {
                        return Text(
                          value.toInt().toString(),
                          style: const TextStyle(
                            color: TechColors.textSecondary,
                            fontSize: 9,
                          ),
                        );
                      },
                    ),
                  ),
                  rightTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  topTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                ),
                borderData: FlBorderData(
                  show: true,
                  border: Border.all(
                    color: TechColors.borderDark.withOpacity(0.5),
                  ),
                ),
                lineBarsData: _getSelectedKilnData(_feedSpeedData),
                minY: 0,
                maxY: 300,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// 料仓重量曲线图
  Widget _buildHopperWeightChart() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: TechColors.bgMedium.withOpacity(0.3),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: TechColors.borderDark),
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
                  color: TechColors.glowGreen,
                  borderRadius: BorderRadius.circular(1),
                ),
              ),
              const SizedBox(width: 8),
              const Text(
                '料仓重量曲线',
                style: TextStyle(
                  color: TechColors.textPrimary,
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const Spacer(),
              // 回转窑多选下拉框
              _buildKilnSelector(),
            ],
          ),
          const SizedBox(height: 12),
          Expanded(
            child: LineChart(
              LineChartData(
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: true,
                  horizontalInterval: 100,
                  verticalInterval: 4,
                  getDrawingHorizontalLine: (value) {
                    return FlLine(
                      color: TechColors.borderDark.withOpacity(0.3),
                      strokeWidth: 1,
                    );
                  },
                  getDrawingVerticalLine: (value) {
                    return FlLine(
                      color: TechColors.borderDark.withOpacity(0.3),
                      strokeWidth: 1,
                    );
                  },
                ),
                titlesData: FlTitlesData(
                  leftTitles: AxisTitles(
                    axisNameWidget: const Text(
                      '重量(kg)',
                      style: TextStyle(
                        color: TechColors.textSecondary,
                        fontSize: 10,
                      ),
                    ),
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 40,
                      getTitlesWidget: (value, meta) {
                        return Text(
                          value.toInt().toString(),
                          style: const TextStyle(
                            color: TechColors.textSecondary,
                            fontSize: 9,
                          ),
                        );
                      },
                    ),
                  ),
                  bottomTitles: AxisTitles(
                    axisNameWidget: const Text(
                      '时间(h)',
                      style: TextStyle(
                        color: TechColors.textSecondary,
                        fontSize: 10,
                      ),
                    ),
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 24,
                      interval: 4,
                      getTitlesWidget: (value, meta) {
                        return Text(
                          value.toInt().toString(),
                          style: const TextStyle(
                            color: TechColors.textSecondary,
                            fontSize: 9,
                          ),
                        );
                      },
                    ),
                  ),
                  rightTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  topTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                ),
                borderData: FlBorderData(
                  show: true,
                  border: Border.all(
                    color: TechColors.borderDark.withOpacity(0.5),
                  ),
                ),
                lineBarsData: _getSelectedKilnData(_hopperWeightData),
                minY: 0,
                maxY: 800,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// 回转窑多选下拉框
  Widget _buildKilnSelector() {
    return PopupMenuButton<int>(
      color: TechColors.bgMedium,
      icon: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: TechColors.bgDark,
          borderRadius: BorderRadius.circular(3),
          border: Border.all(
            color: TechColors.glowOrange.withOpacity(0.3),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '选择回转窑',
              style: const TextStyle(
                color: TechColors.textPrimary,
                fontSize: 10,
              ),
            ),
            const SizedBox(width: 4),
            const Icon(
              Icons.arrow_drop_down,
              size: 16,
              color: TechColors.textSecondary,
            ),
          ],
        ),
      ),
      itemBuilder: (context) {
        return List.generate(7, (index) {
          return PopupMenuItem<int>(
            value: index,
            enabled: false,
            child: StatefulBuilder(
              builder: (context, setState) {
                return InkWell(
                  onTap: () {
                    setState(() {
                      _selectedKilns[index] = !_selectedKilns[index];
                    });
                    this.setState(() {});
                  },
                  child: Row(
                    children: [
                      Container(
                        width: 16,
                        height: 16,
                        decoration: BoxDecoration(
                          color: _selectedKilns[index]
                              ? _kilnColors[index]
                              : Colors.transparent,
                          border: Border.all(
                            color: _kilnColors[index],
                            width: 2,
                          ),
                          borderRadius: BorderRadius.circular(3),
                        ),
                        child: _selectedKilns[index]
                            ? const Icon(
                                Icons.check,
                                size: 12,
                                color: TechColors.bgDeep,
                              )
                            : null,
                      ),
                      const SizedBox(width: 8),
                      Container(
                        width: 12,
                        height: 12,
                        decoration: BoxDecoration(
                          color: _kilnColors[index],
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '回转窑 ${index + 1}',
                        style: const TextStyle(
                          color: TechColors.textPrimary,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          );
        });
      },
    );
  }

  /// 获取选中的回转窑数据
  List<LineChartBarData> _getSelectedKilnData(Map<int, List<FlSpot>> dataMap) {
    List<LineChartBarData> result = [];
    for (int i = 0; i < 7; i++) {
      if (_selectedKilns[i] && dataMap.containsKey(i)) {
        result.add(
          LineChartBarData(
            spots: dataMap[i]!,
            isCurved: true,
            color: _kilnColors[i],
            barWidth: 2,
            dotData: const FlDotData(show: false),
          ),
        );
      }
    }
    return result;
  }

  /// 能耗折线图（已移除）
  Widget _buildEnergyChart() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: TechColors.bgMedium.withOpacity(0.3),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: TechColors.borderDark),
      ),
      child: const Center(
        child: Text(
          '此图表已移除',
          style: TextStyle(
            color: TechColors.textSecondary,
            fontSize: 12,
          ),
        ),
      ),
    );
  }

  /// 选择开始时间
  Future<void> _selectStartTime() async {
    final DateTime? pickedDate = await showDatePicker(
      context: context,
      initialDate: _startTime,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      builder: (context, child) {
        return Theme(
          data: ThemeData.dark().copyWith(
            colorScheme: const ColorScheme.dark(
              primary: TechColors.glowOrange,
              surface: TechColors.bgMedium,
            ),
          ),
          child: child!,
        );
      },
    );

    if (pickedDate != null) {
      final TimeOfDay? pickedTime = await showTimePicker(
        context: context,
        initialTime: TimeOfDay.fromDateTime(_startTime),
        builder: (context, child) {
          return Theme(
            data: ThemeData.dark().copyWith(
              colorScheme: const ColorScheme.dark(
                primary: TechColors.glowOrange,
                surface: TechColors.bgMedium,
              ),
            ),
            child: child!,
          );
        },
      );

      if (pickedTime != null) {
        setState(() {
          _startTime = DateTime(
            pickedDate.year,
            pickedDate.month,
            pickedDate.day,
            pickedTime.hour,
            pickedTime.minute,
          );
          // TODO: 根据新的时间范围重新加载数据
          _generateMockData();
        });
      }
    }
  }

  /// 选择结束时间
  Future<void> _selectEndTime() async {
    final DateTime? pickedDate = await showDatePicker(
      context: context,
      initialDate: _endTime,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      builder: (context, child) {
        return Theme(
          data: ThemeData.dark().copyWith(
            colorScheme: const ColorScheme.dark(
              primary: TechColors.glowOrange,
              surface: TechColors.bgMedium,
            ),
          ),
          child: child!,
        );
      },
    );

    if (pickedDate != null) {
      final TimeOfDay? pickedTime = await showTimePicker(
        context: context,
        initialTime: TimeOfDay.fromDateTime(_endTime),
        builder: (context, child) {
          return Theme(
            data: ThemeData.dark().copyWith(
              colorScheme: const ColorScheme.dark(
                primary: TechColors.glowOrange,
                surface: TechColors.bgMedium,
              ),
            ),
            child: child!,
          );
        },
      );

      if (pickedTime != null) {
        setState(() {
          _endTime = DateTime(
            pickedDate.year,
            pickedDate.month,
            pickedDate.day,
            pickedTime.hour,
            pickedTime.minute,
          );
          // TODO: 根据新的时间范围重新加载数据
          _generateMockData();
        });
      }
    }
  }

  /// 格式化时间显示
  String _formatDateTime(DateTime dateTime) {
    return '${dateTime.month.toString().padLeft(2, '0')}-${dateTime.day.toString().padLeft(2, '0')} ${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}';
  }

  /// 辊道窑时间范围选择器
  Widget _buildRollerTimeRangeSelector() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: TechColors.bgMedium.withOpacity(0.5),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(
          color: TechColors.glowCyan.withOpacity(0.3),
        ),
      ),
      child: Row(
        children: [
          Icon(
            Icons.date_range,
            size: 16,
            color: TechColors.glowCyan,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: GestureDetector(
              onTap: () => _selectStartTime(),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: TechColors.bgDark,
                  borderRadius: BorderRadius.circular(3),
                ),
                child: Text(
                  _formatDateTime(_startTime),
                  style: const TextStyle(
                    color: TechColors.textPrimary,
                    fontSize: 11,
                    fontFamily: 'Roboto Mono',
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          const Text(
            '~',
            style: TextStyle(
              color: TechColors.textSecondary,
              fontSize: 12,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: GestureDetector(
              onTap: () => _selectEndTime(),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: TechColors.bgDark,
                  borderRadius: BorderRadius.circular(3),
                ),
                child: Text(
                  _formatDateTime(_endTime),
                  style: const TextStyle(
                    color: TechColors.textPrimary,
                    fontSize: 11,
                    fontFamily: 'Roboto Mono',
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// 辊道窑历史温度曲线图
  Widget _buildRollerTemperatureChart() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: TechColors.bgMedium.withOpacity(0.3),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: TechColors.borderDark),
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
                '历史温度曲线',
                style: TextStyle(
                  color: TechColors.textPrimary,
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const Spacer(),
              _buildRollerKilnSelector(),
            ],
          ),
          const SizedBox(height: 12),
          Expanded(
            child: LineChart(
              LineChartData(
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: true,
                  horizontalInterval: 50,
                  verticalInterval: 4,
                  getDrawingHorizontalLine: (value) {
                    return FlLine(
                      color: TechColors.borderDark.withOpacity(0.3),
                      strokeWidth: 1,
                    );
                  },
                  getDrawingVerticalLine: (value) {
                    return FlLine(
                      color: TechColors.borderDark.withOpacity(0.3),
                      strokeWidth: 1,
                    );
                  },
                ),
                titlesData: FlTitlesData(
                  leftTitles: AxisTitles(
                    axisNameWidget: const Text(
                      '温度(°C)',
                      style: TextStyle(
                        color: TechColors.textSecondary,
                        fontSize: 10,
                      ),
                    ),
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 40,
                      getTitlesWidget: (value, meta) {
                        return Text(
                          value.toInt().toString(),
                          style: const TextStyle(
                            color: TechColors.textSecondary,
                            fontSize: 9,
                          ),
                        );
                      },
                    ),
                  ),
                  bottomTitles: AxisTitles(
                    axisNameWidget: const Text(
                      '时间(h)',
                      style: TextStyle(
                        color: TechColors.textSecondary,
                        fontSize: 10,
                      ),
                    ),
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 24,
                      interval: 4,
                      getTitlesWidget: (value, meta) {
                        return Text(
                          value.toInt().toString(),
                          style: const TextStyle(
                            color: TechColors.textSecondary,
                            fontSize: 9,
                          ),
                        );
                      },
                    ),
                  ),
                  rightTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  topTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                ),
                borderData: FlBorderData(
                  show: true,
                  border: Border.all(
                    color: TechColors.borderDark.withOpacity(0.5),
                  ),
                ),
                lineBarsData:
                    _getSelectedRollerKilnData(_rollerTemperatureData),
                minY: 800,
                maxY: 1200,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// 辊道窑历史能耗曲线图
  Widget _buildRollerEnergyChart() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: TechColors.bgMedium.withOpacity(0.3),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: TechColors.borderDark),
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
                  color: TechColors.glowGreen,
                  borderRadius: BorderRadius.circular(1),
                ),
              ),
              const SizedBox(width: 8),
              const Text(
                '历史能耗曲线',
                style: TextStyle(
                  color: TechColors.textPrimary,
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const Spacer(),
              _buildRollerKilnSelector(),
            ],
          ),
          const SizedBox(height: 12),
          Expanded(
            child: LineChart(
              LineChartData(
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: true,
                  horizontalInterval: 50,
                  verticalInterval: 4,
                  getDrawingHorizontalLine: (value) {
                    return FlLine(
                      color: TechColors.borderDark.withOpacity(0.3),
                      strokeWidth: 1,
                    );
                  },
                  getDrawingVerticalLine: (value) {
                    return FlLine(
                      color: TechColors.borderDark.withOpacity(0.3),
                      strokeWidth: 1,
                    );
                  },
                ),
                titlesData: FlTitlesData(
                  leftTitles: AxisTitles(
                    axisNameWidget: const Text(
                      '能耗(kW·h)',
                      style: TextStyle(
                        color: TechColors.textSecondary,
                        fontSize: 10,
                      ),
                    ),
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 40,
                      getTitlesWidget: (value, meta) {
                        return Text(
                          value.toInt().toString(),
                          style: const TextStyle(
                            color: TechColors.textSecondary,
                            fontSize: 9,
                          ),
                        );
                      },
                    ),
                  ),
                  bottomTitles: AxisTitles(
                    axisNameWidget: const Text(
                      '时间(h)',
                      style: TextStyle(
                        color: TechColors.textSecondary,
                        fontSize: 10,
                      ),
                    ),
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 24,
                      interval: 4,
                      getTitlesWidget: (value, meta) {
                        return Text(
                          value.toInt().toString(),
                          style: const TextStyle(
                            color: TechColors.textSecondary,
                            fontSize: 9,
                          ),
                        );
                      },
                    ),
                  ),
                  rightTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  topTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                ),
                borderData: FlBorderData(
                  show: true,
                  border: Border.all(
                    color: TechColors.borderDark.withOpacity(0.5),
                  ),
                ),
                lineBarsData: _getSelectedRollerKilnData(_rollerEnergyData),
                minY: 0,
                maxY: 400,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// 辊道窑历史功率曲线图
  Widget _buildRollerPowerChart() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: TechColors.bgMedium.withOpacity(0.3),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: TechColors.borderDark),
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
                  color: TechColors.glowOrange,
                  borderRadius: BorderRadius.circular(1),
                ),
              ),
              const SizedBox(width: 8),
              const Text(
                '历史功率曲线',
                style: TextStyle(
                  color: TechColors.textPrimary,
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const Spacer(),
              _buildRollerKilnSelector(),
            ],
          ),
          const SizedBox(height: 12),
          Expanded(
            child: LineChart(
              LineChartData(
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: true,
                  horizontalInterval: 50,
                  verticalInterval: 4,
                  getDrawingHorizontalLine: (value) {
                    return FlLine(
                      color: TechColors.borderDark.withOpacity(0.3),
                      strokeWidth: 1,
                    );
                  },
                  getDrawingVerticalLine: (value) {
                    return FlLine(
                      color: TechColors.borderDark.withOpacity(0.3),
                      strokeWidth: 1,
                    );
                  },
                ),
                titlesData: FlTitlesData(
                  leftTitles: AxisTitles(
                    axisNameWidget: const Text(
                      '功率(kW)',
                      style: TextStyle(
                        color: TechColors.textSecondary,
                        fontSize: 10,
                      ),
                    ),
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 40,
                      getTitlesWidget: (value, meta) {
                        return Text(
                          value.toInt().toString(),
                          style: const TextStyle(
                            color: TechColors.textSecondary,
                            fontSize: 9,
                          ),
                        );
                      },
                    ),
                  ),
                  bottomTitles: AxisTitles(
                    axisNameWidget: const Text(
                      '时间(h)',
                      style: TextStyle(
                        color: TechColors.textSecondary,
                        fontSize: 10,
                      ),
                    ),
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 24,
                      interval: 4,
                      getTitlesWidget: (value, meta) {
                        return Text(
                          value.toInt().toString(),
                          style: const TextStyle(
                            color: TechColors.textSecondary,
                            fontSize: 9,
                          ),
                        );
                      },
                    ),
                  ),
                  rightTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  topTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                ),
                borderData: FlBorderData(
                  show: true,
                  border: Border.all(
                    color: TechColors.borderDark.withOpacity(0.5),
                  ),
                ),
                lineBarsData: _getSelectedRollerKilnData(_rollerPowerData),
                minY: 0,
                maxY: 300,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// 辊道窑多选下拉框
  Widget _buildRollerKilnSelector() {
    return PopupMenuButton<int>(
      color: TechColors.bgMedium,
      icon: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: TechColors.bgDark,
          borderRadius: BorderRadius.circular(3),
          border: Border.all(
            color: TechColors.glowCyan.withOpacity(0.3),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '选择辊道窑',
              style: const TextStyle(
                color: TechColors.textPrimary,
                fontSize: 10,
              ),
            ),
            const SizedBox(width: 4),
            const Icon(
              Icons.arrow_drop_down,
              size: 16,
              color: TechColors.textSecondary,
            ),
          ],
        ),
      ),
      itemBuilder: (context) {
        return List.generate(3, (index) {
          return PopupMenuItem<int>(
            value: index,
            enabled: false,
            child: StatefulBuilder(
              builder: (context, setState) {
                return InkWell(
                  onTap: () {
                    setState(() {
                      _selectedRollerKilns[index] =
                          !_selectedRollerKilns[index];
                    });
                    this.setState(() {});
                  },
                  child: Row(
                    children: [
                      Container(
                        width: 16,
                        height: 16,
                        decoration: BoxDecoration(
                          color: _selectedRollerKilns[index]
                              ? _rollerKilnColors[index]
                              : Colors.transparent,
                          border: Border.all(
                            color: _rollerKilnColors[index],
                            width: 2,
                          ),
                          borderRadius: BorderRadius.circular(3),
                        ),
                        child: _selectedRollerKilns[index]
                            ? const Icon(
                                Icons.check,
                                size: 12,
                                color: TechColors.bgDeep,
                              )
                            : null,
                      ),
                      const SizedBox(width: 8),
                      Container(
                        width: 12,
                        height: 12,
                        decoration: BoxDecoration(
                          color: _rollerKilnColors[index],
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '辊道窑 ${index + 1}',
                        style: const TextStyle(
                          color: TechColors.textPrimary,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          );
        });
      },
    );
  }

  /// 获取选中的辊道窑数据
  List<LineChartBarData> _getSelectedRollerKilnData(
      Map<int, List<FlSpot>> dataMap) {
    List<LineChartBarData> result = [];
    for (int i = 0; i < 3; i++) {
      if (_selectedRollerKilns[i] && dataMap.containsKey(i)) {
        result.add(
          LineChartBarData(
            spots: dataMap[i]!,
            isCurved: true,
            color: _rollerKilnColors[i],
            barWidth: 2,
            dotData: const FlDotData(show: false),
          ),
        );
      }
    }
    return result;
  }

  /// SCR设备时间范围选择器
  Widget _buildScrTimeRangeSelector() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: TechColors.bgMedium.withOpacity(0.5),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(
          color: TechColors.glowGreen.withOpacity(0.3),
        ),
      ),
      child: Row(
        children: [
          Icon(
            Icons.date_range,
            size: 16,
            color: TechColors.glowGreen,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: GestureDetector(
              onTap: () => _selectStartTime(),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: TechColors.bgDark,
                  borderRadius: BorderRadius.circular(3),
                ),
                child: Text(
                  _formatDateTime(_startTime),
                  style: const TextStyle(
                    color: TechColors.textPrimary,
                    fontSize: 11,
                    fontFamily: 'Roboto Mono',
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          const Text(
            '~',
            style: TextStyle(
              color: TechColors.textSecondary,
              fontSize: 12,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: GestureDetector(
              onTap: () => _selectEndTime(),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: TechColors.bgDark,
                  borderRadius: BorderRadius.circular(3),
                ),
                child: Text(
                  _formatDateTime(_endTime),
                  style: const TextStyle(
                    color: TechColors.textPrimary,
                    fontSize: 11,
                    fontFamily: 'Roboto Mono',
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// 水泵能耗曲线图
  Widget _buildPumpEnergyChart() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: TechColors.bgMedium.withOpacity(0.3),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: TechColors.borderDark),
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
                  color: TechColors.glowGreen,
                  borderRadius: BorderRadius.circular(1),
                ),
              ),
              const SizedBox(width: 8),
              const Text(
                '水泵',
                style: TextStyle(
                  color: TechColors.textPrimary,
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const Spacer(),
              _buildPumpSelector(),
            ],
          ),
          const SizedBox(height: 12),
          Expanded(
            child: LineChart(
              LineChartData(
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: true,
                  horizontalInterval: 20,
                  verticalInterval: 4,
                  getDrawingHorizontalLine: (value) {
                    return FlLine(
                      color: TechColors.borderDark.withOpacity(0.3),
                      strokeWidth: 1,
                    );
                  },
                  getDrawingVerticalLine: (value) {
                    return FlLine(
                      color: TechColors.borderDark.withOpacity(0.3),
                      strokeWidth: 1,
                    );
                  },
                ),
                titlesData: FlTitlesData(
                  leftTitles: AxisTitles(
                    axisNameWidget: const Text(
                      '能耗(kW·h)',
                      style: TextStyle(
                        color: TechColors.textSecondary,
                        fontSize: 10,
                      ),
                    ),
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 40,
                      getTitlesWidget: (value, meta) {
                        return Text(
                          value.toInt().toString(),
                          style: const TextStyle(
                            color: TechColors.textSecondary,
                            fontSize: 9,
                          ),
                        );
                      },
                    ),
                  ),
                  bottomTitles: AxisTitles(
                    axisNameWidget: const Text(
                      '时间(h)',
                      style: TextStyle(
                        color: TechColors.textSecondary,
                        fontSize: 10,
                      ),
                    ),
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 24,
                      interval: 4,
                      getTitlesWidget: (value, meta) {
                        return Text(
                          value.toInt().toString(),
                          style: const TextStyle(
                            color: TechColors.textSecondary,
                            fontSize: 9,
                          ),
                        );
                      },
                    ),
                  ),
                  rightTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  topTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                ),
                borderData: FlBorderData(
                  show: true,
                  border: Border.all(
                    color: TechColors.borderDark.withOpacity(0.5),
                  ),
                ),
                lineBarsData: _getSelectedPumpData(),
                minY: 0,
                maxY: 150,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// 风机能耗曲线图
  Widget _buildFanEnergyChart() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: TechColors.bgMedium.withOpacity(0.3),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: TechColors.borderDark),
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
                  color: TechColors.glowOrange,
                  borderRadius: BorderRadius.circular(1),
                ),
              ),
              const SizedBox(width: 8),
              const Text(
                '风机',
                style: TextStyle(
                  color: TechColors.textPrimary,
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const Spacer(),
              _buildFanSelector(),
            ],
          ),
          const SizedBox(height: 12),
          Expanded(
            child: LineChart(
              LineChartData(
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: true,
                  horizontalInterval: 30,
                  verticalInterval: 4,
                  getDrawingHorizontalLine: (value) {
                    return FlLine(
                      color: TechColors.borderDark.withOpacity(0.3),
                      strokeWidth: 1,
                    );
                  },
                  getDrawingVerticalLine: (value) {
                    return FlLine(
                      color: TechColors.borderDark.withOpacity(0.3),
                      strokeWidth: 1,
                    );
                  },
                ),
                titlesData: FlTitlesData(
                  leftTitles: AxisTitles(
                    axisNameWidget: const Text(
                      '能耗(kW·h)',
                      style: TextStyle(
                        color: TechColors.textSecondary,
                        fontSize: 10,
                      ),
                    ),
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 40,
                      getTitlesWidget: (value, meta) {
                        return Text(
                          value.toInt().toString(),
                          style: const TextStyle(
                            color: TechColors.textSecondary,
                            fontSize: 9,
                          ),
                        );
                      },
                    ),
                  ),
                  bottomTitles: AxisTitles(
                    axisNameWidget: const Text(
                      '时间(h)',
                      style: TextStyle(
                        color: TechColors.textSecondary,
                        fontSize: 10,
                      ),
                    ),
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 24,
                      interval: 4,
                      getTitlesWidget: (value, meta) {
                        return Text(
                          value.toInt().toString(),
                          style: const TextStyle(
                            color: TechColors.textSecondary,
                            fontSize: 9,
                          ),
                        );
                      },
                    ),
                  ),
                  rightTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  topTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                ),
                borderData: FlBorderData(
                  show: true,
                  border: Border.all(
                    color: TechColors.borderDark.withOpacity(0.5),
                  ),
                ),
                lineBarsData: _getSelectedFanData(),
                minY: 0,
                maxY: 200,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// 水泵多选下拉框
  Widget _buildPumpSelector() {
    return PopupMenuButton<int>(
      color: TechColors.bgMedium,
      icon: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: TechColors.bgDark,
          borderRadius: BorderRadius.circular(3),
          border: Border.all(
            color: TechColors.glowGreen.withOpacity(0.3),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '选择水泵',
              style: const TextStyle(
                color: TechColors.textPrimary,
                fontSize: 10,
              ),
            ),
            const SizedBox(width: 4),
            const Icon(
              Icons.arrow_drop_down,
              size: 16,
              color: TechColors.textSecondary,
            ),
          ],
        ),
      ),
      itemBuilder: (context) {
        return List.generate(2, (index) {
          return PopupMenuItem<int>(
            value: index,
            enabled: false,
            child: StatefulBuilder(
              builder: (context, setState) {
                return InkWell(
                  onTap: () {
                    setState(() {
                      _selectedPumps[index] = !_selectedPumps[index];
                    });
                    this.setState(() {});
                  },
                  child: Row(
                    children: [
                      Container(
                        width: 16,
                        height: 16,
                        decoration: BoxDecoration(
                          color: _selectedPumps[index]
                              ? _scrColors[index]
                              : Colors.transparent,
                          border: Border.all(
                            color: _scrColors[index],
                            width: 2,
                          ),
                          borderRadius: BorderRadius.circular(3),
                        ),
                        child: _selectedPumps[index]
                            ? const Icon(
                                Icons.check,
                                size: 12,
                                color: TechColors.bgDeep,
                              )
                            : null,
                      ),
                      const SizedBox(width: 8),
                      Container(
                        width: 12,
                        height: 12,
                        decoration: BoxDecoration(
                          color: _scrColors[index],
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '水泵 ${index + 1}',
                        style: const TextStyle(
                          color: TechColors.textPrimary,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          );
        });
      },
    );
  }

  /// 风机多选下拉框
  Widget _buildFanSelector() {
    return PopupMenuButton<int>(
      color: TechColors.bgMedium,
      icon: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: TechColors.bgDark,
          borderRadius: BorderRadius.circular(3),
          border: Border.all(
            color: TechColors.glowOrange.withOpacity(0.3),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '选择风机',
              style: const TextStyle(
                color: TechColors.textPrimary,
                fontSize: 10,
              ),
            ),
            const SizedBox(width: 4),
            const Icon(
              Icons.arrow_drop_down,
              size: 16,
              color: TechColors.textSecondary,
            ),
          ],
        ),
      ),
      itemBuilder: (context) {
        return List.generate(2, (index) {
          return PopupMenuItem<int>(
            value: index,
            enabled: false,
            child: StatefulBuilder(
              builder: (context, setState) {
                return InkWell(
                  onTap: () {
                    setState(() {
                      _selectedFans[index] = !_selectedFans[index];
                    });
                    this.setState(() {});
                  },
                  child: Row(
                    children: [
                      Container(
                        width: 16,
                        height: 16,
                        decoration: BoxDecoration(
                          color: _selectedFans[index]
                              ? _scrColors[index]
                              : Colors.transparent,
                          border: Border.all(
                            color: _scrColors[index],
                            width: 2,
                          ),
                          borderRadius: BorderRadius.circular(3),
                        ),
                        child: _selectedFans[index]
                            ? const Icon(
                                Icons.check,
                                size: 12,
                                color: TechColors.bgDeep,
                              )
                            : null,
                      ),
                      const SizedBox(width: 8),
                      Container(
                        width: 12,
                        height: 12,
                        decoration: BoxDecoration(
                          color: _scrColors[index],
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '风机 ${index + 1}',
                        style: const TextStyle(
                          color: TechColors.textPrimary,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          );
        });
      },
    );
  }

  /// 获取选中的水泵数据
  List<LineChartBarData> _getSelectedPumpData() {
    List<LineChartBarData> result = [];
    for (int i = 0; i < 2; i++) {
      if (_selectedPumps[i] && _pumpEnergyData.containsKey(i)) {
        result.add(
          LineChartBarData(
            spots: _pumpEnergyData[i]!,
            isCurved: true,
            color: _scrColors[i],
            barWidth: 2,
            dotData: const FlDotData(show: false),
          ),
        );
      }
    }
    return result;
  }

  /// 获取选中的风机数据
  List<LineChartBarData> _getSelectedFanData() {
    List<LineChartBarData> result = [];
    for (int i = 0; i < 2; i++) {
      if (_selectedFans[i] && _fanEnergyData.containsKey(i)) {
        result.add(
          LineChartBarData(
            spots: _fanEnergyData[i]!,
            isCurved: true,
            color: _scrColors[i],
            barWidth: 2,
            dotData: const FlDotData(show: false),
          ),
        );
      }
    }
    return result;
  }
}

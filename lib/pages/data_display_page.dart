import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../widgets/tech_line_widgets.dart';
import '../widgets/time_range_selector.dart';
import '../widgets/tech_line_chart.dart';
import '../widgets/tech_bar_chart.dart';

/// 数据展示页面
/// 包含三个设备容器：回转窑、辊道窑、SCR设备
class DataDisplayPage extends StatefulWidget {
  const DataDisplayPage({super.key});

  @override
  State<DataDisplayPage> createState() => _DataDisplayPageState();
}

class _DataDisplayPageState extends State<DataDisplayPage>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;
  // 时间范围选择
  DateTime _startTime = DateTime.now().subtract(const Duration(hours: 24));
  DateTime _endTime = DateTime.now();

  // 7个有料仓的回转窑的选择状态（窑1,2,4,5,6,7,9，排除窑3,8）
  int _selectedFeedKiln = 0; // 单选，默认选择第一个（窑1）
  int _selectedHopperKiln = 0; // 单选，默认选择第一个（窑1）

  // 12个温度区域的选择状态（窑1-3,6-8各1个，窑4,5,9各2个）
  int _selectedTemperatureZone = 0; // 单选，默认选择第一个

  // 模拟温度数据（待接入PLC）- 12个温度区域
  final Map<int, List<FlSpot>> _temperatureData = {};

  // 模拟下料速度数据（待接入PLC）- 9个回转窑
  final Map<int, List<FlSpot>> _feedSpeedData = {};

  // 模拟料仓重量数据（待接入PLC）- 9个回转窑
  final Map<int, List<FlSpot>> _hopperWeightData = {};

  // 辊道窑的选择状态（6个辊道窑区域）
  final List<bool> _selectedRollerKilns = List.generate(6, (_) => true);

  // 模拟辊道窑温度数据（待接入PLC）- 6个辊道窑区域
  final Map<int, List<FlSpot>> _rollerTemperatureData = {};

  // 模拟辊道窑能耗数据（待接入PLC）- 6个辊道窑区域
  final Map<int, List<FlSpot>> _rollerEnergyData = {};

  // 模拟辊道窑功率数据（待接入PLC）- 6个辊道窑区域
  final Map<int, List<FlSpot>> _rollerPowerData = {};

  // SCR设备的选择状态（2个水泵，2个风机）
  final List<bool> _selectedPumps = List.generate(2, (_) => true);
  final List<bool> _selectedFans = List.generate(2, (_) => true);

  // 模拟SCR水泵能耗数据（待接入PLC）- 2个水泵
  final Map<int, List<FlSpot>> _pumpEnergyData = {};

  // 模拟SCR风机能耗数据（待接入PLC）- 2个风机
  final Map<int, List<FlSpot>> _fanEnergyData = {};

  // 12种颜色用于区分不同温度区域（允许重复）
  final List<Color> _temperatureColors = [
    TechColors.glowOrange, // 窑1
    TechColors.glowCyan, // 窑2
    TechColors.glowGreen, // 窑3
    const Color(0xFFff3b30), // 窑4(1)
    const Color(0xFFff6b60), // 窑4(2) - 稍亮的红色
    const Color(0xFFffcc00), // 窑5(1)
    const Color(0xFFffe44d), // 窑5(2) - 稍亮的黄色
    const Color(0xFFaf52de), // 窑6
    const Color(0xFF00d4ff), // 窑7
    TechColors.glowOrange, // 窑8
    TechColors.glowCyan, // 窑9(1)
    const Color(0xFF00ffaa), // 窑9(2) - 亮绿色
  ];

  // 9种颜色用于区分不同回转窑（下料速度、料仓重量）
  final List<Color> _kilnColors = [
    TechColors.glowOrange,
    TechColors.glowCyan,
    TechColors.glowGreen,
    const Color(0xFFff3b30), // Red
    const Color(0xFFffcc00), // Yellow
    const Color(0xFFaf52de), // Purple
    const Color(0xFF00d4ff), // Light Blue
    TechColors.glowOrange, // 重复颜色
    TechColors.glowCyan, // 重复颜色
  ];

  // 6种颜色用于区分不同辊道窑区域（允许重复）
  final List<Color> _rollerKilnColors = [
    TechColors.glowCyan,
    TechColors.glowGreen,
    const Color(0xFFaf52de), // Purple
    TechColors.glowOrange,
    const Color(0xFFffcc00), // Yellow
    const Color(0xFF00d4ff), // Light Blue
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

  // 生成模拟数据
  void _generateMockData() {
    // 为12个温度区域生成数据
    for (int zone = 0; zone < 12; zone++) {
      _temperatureData[zone] = List.generate(24, (index) {
        return FlSpot(
          index.toDouble(),
          800 + (index * 10) + (index % 5 * 20) + (zone * 25),
        );
      });
    }

    // 为7个有料仓的回转窑生成下料速度和料仓重量数据（窑1,2,4,5,6,7,9）
    for (int kiln = 0; kiln < 7; kiln++) {
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

    // 为6个辊道窑区域生成模拟数据
    for (int kiln = 0; kiln < 6; kiln++) {
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
    super.build(context); // 必须调用以支持 AutomaticKeepAliveClientMixin
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
                headerActions: [
                  SizedBox(
                    width: 280,
                    child: _buildTimeRangeSelector(),
                  ),
                ],
                child: Column(
                  children: [
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
                      headerActions: [
                        SizedBox(
                          width: 280,
                          child: _buildRollerTimeRangeSelector(),
                        ),
                      ],
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
                  ),
                ),
                // 下部：SCR设备容器（2/5高度）
                Expanded(
                  flex: 2,
                  child: Container(
                    margin: const EdgeInsets.fromLTRB(0, 6, 12, 12),
                    child: TechPanel(
                      title: 'SCR设备和风机',
                      accentColor: TechColors.glowGreen,
                      headerActions: [
                        SizedBox(
                          width: 280,
                          child: _buildScrTimeRangeSelector(),
                        ),
                      ],
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
    return TimeRangeSelector(
      startTime: _startTime,
      endTime: _endTime,
      onStartTimeTap: _selectStartTime,
      onEndTimeTap: _selectEndTime,
      accentColor: TechColors.glowOrange,
    );
  }

  /// 历史温度曲线图
  Widget _buildTemperatureChart() {
    return TechLineChart(
      title: '历史温度曲线',
      accentColor: TechColors.glowOrange,
      yAxisLabel: '温度(°C)',
      xAxisLabel: '时间(h)',
      minY: 700,
      maxY: 1200,
      yInterval: 50,
      xInterval: 4,
      dataMap: _temperatureData,
      isSingleSelect: true,
      selectedIndex: _selectedTemperatureZone,
      itemColors: _temperatureColors,
      itemCount: 12,
      getItemLabel: _getTemperatureZoneLabel,
      selectorLabel: '选择温度区域',
      onItemSelect: (index) {
        setState(() {
          _selectedTemperatureZone = index;
        });
      },
    );
  }

  /// 获取温度区域标签
  String _getTemperatureZoneLabel(int index) {
    // 窑1-3: 索引0-2
    // 窑4(1), 窑4(2): 索引3-4
    // 窑5(1), 窑5(2): 索引5-6
    // 窑6-8: 索引7-9
    // 窑9(1), 窑9(2): 索引10-11

    if (index <= 2) {
      return '窑${index + 1}';
    } else if (index == 3) {
      return '窑4(1)';
    } else if (index == 4) {
      return '窑4(2)';
    } else if (index == 5) {
      return '窑5(1)';
    } else if (index == 6) {
      return '窑5(2)';
    } else if (index <= 9) {
      return '窑${index + 1}';
    } else if (index == 10) {
      return '窑9(1)';
    } else {
      return '窑9(2)';
    }
  }

  /// 获取下料/料仓窑标签（窑1,2,4,5,6,7,9，排除窑3,8）
  String _getFeedKilnLabel(int index) {
    // 索引 0-6 对应窑 1,2,4,5,6,7,9
    const kilnNumbers = [1, 2, 4, 5, 6, 7, 9];
    return '窑${kilnNumbers[index]}';
  }

  /// 下料速度曲线图
  Widget _buildFeedSpeedChart() {
    return TechLineChart(
      title: '下料速度曲线',
      accentColor: TechColors.glowCyan,
      yAxisLabel: '速度(kg/h)',
      xAxisLabel: '时间(h)',
      minY: 0,
      maxY: 300,
      yInterval: 50,
      xInterval: 4,
      dataMap: _feedSpeedData,
      isSingleSelect: true,
      selectedIndex: _selectedFeedKiln,
      itemColors: _kilnColors,
      itemCount: 7,
      getItemLabel: _getFeedKilnLabel,
      selectorLabel: '选择回转窑',
      onItemSelect: (index) {
        setState(() {
          _selectedFeedKiln = index;
        });
      },
    );
  }

  /// 料仓重量曲线图
  Widget _buildHopperWeightChart() {
    return TechLineChart(
      title: '料仓重量曲线',
      accentColor: TechColors.glowGreen,
      yAxisLabel: '重量(kg)',
      xAxisLabel: '时间(h)',
      minY: 0,
      maxY: 800,
      yInterval: 100,
      xInterval: 4,
      dataMap: _hopperWeightData,
      isSingleSelect: true,
      selectedIndex: _selectedHopperKiln,
      itemColors: _kilnColors,
      itemCount: 7,
      getItemLabel: _getFeedKilnLabel,
      selectorLabel: '选择回转窑',
      onItemSelect: (index) {
        setState(() {
          _selectedHopperKiln = index;
        });
      },
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

  /// 辊道窑时间范围选择器
  Widget _buildRollerTimeRangeSelector() {
    return TimeRangeSelector(
      startTime: _startTime,
      endTime: _endTime,
      onStartTimeTap: _selectStartTime,
      onEndTimeTap: _selectEndTime,
      accentColor: TechColors.glowCyan,
    );
  }

  /// 辊道窑历史温度曲线图
  Widget _buildRollerTemperatureChart() {
    return TechLineChart(
      title: '历史温度曲线',
      accentColor: TechColors.glowCyan,
      yAxisLabel: '温度(°C)',
      xAxisLabel: '时间(h)',
      minY: 800,
      maxY: 1200,
      yInterval: 50,
      xInterval: 4,
      dataMap: _rollerTemperatureData,
      selectedItems: _selectedRollerKilns,
      itemColors: _rollerKilnColors,
      itemCount: 6,
      getItemLabel: (index) => '辊道窑区域 ${index + 1}',
      selectorLabel: '选择辊道窑区域',
      onItemToggle: (index) {
        setState(() {
          _selectedRollerKilns[index] = !_selectedRollerKilns[index];
        });
      },
    );
  }

  /// 辊道窑历史能耗折线图
  Widget _buildRollerEnergyChart() {
    return TechBarChart(
      title: '历史能耗折线',
      accentColor: TechColors.glowGreen,
      yAxisLabel: '能耗(kW·h)',
      xAxisLabel: '时间(h)',
      minY: 0,
      maxY: 400,
      yInterval: 50,
      xInterval: 4,
      dataMap: _rollerEnergyData,
      selectedItems: _selectedRollerKilns,
      itemColors: _rollerKilnColors,
      itemCount: 6,
      getItemLabel: (index) => '辊道窑区域 ${index + 1}',
      selectorLabel: '选择辊道窑区域',
      onItemToggle: (index) {
        setState(() {
          _selectedRollerKilns[index] = !_selectedRollerKilns[index];
        });
      },
    );
  }

  /// 辊道窑历史功率折线图
  Widget _buildRollerPowerChart() {
    return TechBarChart(
      title: '历史功率折线',
      accentColor: TechColors.glowOrange,
      yAxisLabel: '功率(kW)',
      xAxisLabel: '时间(h)',
      minY: 0,
      maxY: 300,
      yInterval: 50,
      xInterval: 4,
      dataMap: _rollerPowerData,
      selectedItems: _selectedRollerKilns,
      itemColors: _rollerKilnColors,
      itemCount: 6,
      getItemLabel: (index) => '辊道窑区域 ${index + 1}',
      selectorLabel: '选择辊道窑区域',
      onItemToggle: (index) {
        setState(() {
          _selectedRollerKilns[index] = !_selectedRollerKilns[index];
        });
      },
    );
  }

  /// SCR设备时间范围选择器
  Widget _buildScrTimeRangeSelector() {
    return TimeRangeSelector(
      startTime: _startTime,
      endTime: _endTime,
      onStartTimeTap: _selectStartTime,
      onEndTimeTap: _selectEndTime,
      accentColor: TechColors.glowGreen,
    );
  }

  /// 水泵能耗折线图
  Widget _buildPumpEnergyChart() {
    return TechBarChart(
      title: '水泵能耗折线',
      accentColor: TechColors.glowGreen,
      yAxisLabel: '能耗(kW·h)',
      xAxisLabel: '时间(h)',
      minY: 0,
      maxY: 150,
      yInterval: 20,
      xInterval: 4,
      dataMap: _pumpEnergyData,
      selectedItems: _selectedPumps,
      itemColors: _scrColors,
      itemCount: 2,
      getItemLabel: (index) => '水泵 ${index + 1}',
      selectorLabel: '选择水泵',
      onItemToggle: (index) {
        setState(() {
          _selectedPumps[index] = !_selectedPumps[index];
        });
      },
    );
  }

  /// 风机能耗折线图
  Widget _buildFanEnergyChart() {
    return TechBarChart(
      title: '风机能耗折线',
      accentColor: TechColors.glowOrange,
      yAxisLabel: '能耗(kW·h)',
      xAxisLabel: '时间(h)',
      minY: 0,
      maxY: 200,
      yInterval: 30,
      xInterval: 4,
      dataMap: _fanEnergyData,
      selectedItems: _selectedFans,
      itemColors: _scrColors,
      itemCount: 2,
      getItemLabel: (index) => '风机 ${index + 1}',
      selectorLabel: '选择风机',
      onItemToggle: (index) {
        setState(() {
          _selectedFans[index] = !_selectedFans[index];
        });
      },
    );
  }
}

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../widgets/data_display/data_tech_line_widgets.dart';
import '../widgets/data_display/data_time_range_selector.dart';
import '../widgets/data_display/data_tech_line_chart.dart';
import '../widgets/data_display/data_tech_bar_chart.dart';
import '../services/history_data_service.dart';

/// 数据展示页面
/// 包含三个设备容器：回转窑、辊道窑、SCR设备
///
/// 默认显示最近120秒的历史数据（静态展示，不自动更新）
class DataDisplayPage extends StatefulWidget {
  const DataDisplayPage({super.key});

  @override
  State<DataDisplayPage> createState() => _DataDisplayPageState();
}

class _DataDisplayPageState extends State<DataDisplayPage>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  // 历史数据服务
  final HistoryDataService _historyService = HistoryDataService();

  // 加载状态
  bool _isLoading = true;

  // 默认时间范围：最近120秒
  static const Duration _defaultTimeRange = Duration(seconds: 120);

  // ==================== 8个图表的独立时间范围 ====================
  // 回转窑3个图表（默认最近120秒）
  late DateTime _tempChartStartTime;
  late DateTime _tempChartEndTime;
  late DateTime _feedSpeedChartStartTime;
  late DateTime _feedSpeedChartEndTime;
  late DateTime _hopperWeightChartStartTime;
  late DateTime _hopperWeightChartEndTime;

  // 辊道窑3个图表（默认最近120秒）
  late DateTime _rollerTempChartStartTime;
  late DateTime _rollerTempChartEndTime;
  late DateTime _rollerEnergyChartStartTime;
  late DateTime _rollerEnergyChartEndTime;
  late DateTime _rollerPowerChartStartTime;
  late DateTime _rollerPowerChartEndTime;

  // SCR设备2个图表（默认最近120秒）
  late DateTime _pumpEnergyChartStartTime;
  late DateTime _pumpEnergyChartEndTime;
  late DateTime _fanEnergyChartStartTime;
  late DateTime _fanEnergyChartEndTime;

  // ==================== 设备选择状态 ====================
  // 回转窑选择（对应 device_id 映射）
  // 索引0-8对应：short_hopper_1~4, no_hopper_1~2, long_hopper_1~3
  int _selectedHopperIndex = 0; // 默认选择第一个

  // 辊道窑温区选择（6个温区）
  final List<bool> _selectedRollerZones = List.generate(6, (_) => true);

  // SCR设备选择（2个）
  final List<bool> _selectedScrs = List.generate(2, (_) => true);

  // 风机选择（2个）
  final List<bool> _selectedFans = List.generate(2, (_) => true);

  // ==================== 图表数据 ====================
  // 回转窑温度数据
  final Map<int, List<FlSpot>> _temperatureData = {};

  // 回转窑下料速度数据
  final Map<int, List<FlSpot>> _feedSpeedData = {};

  // 回转窑料仓重量数据
  final Map<int, List<FlSpot>> _hopperWeightData = {};

  // 辊道窑温度数据（6个温区）
  final Map<int, List<FlSpot>> _rollerTemperatureData = {};

  // 辊道窑能耗数据（6个温区）
  final Map<int, List<FlSpot>> _rollerEnergyData = {};

  // 辊道窑功率数据（6个温区）
  final Map<int, List<FlSpot>> _rollerPowerData = {};

  // SCR功率数据（2个）
  final Map<int, List<FlSpot>> _scrPowerData = {};

  // 风机功率数据（2个）
  final Map<int, List<FlSpot>> _fanPowerData = {};

  // 9种颜色用于区分不同回转窑
  final List<Color> _hopperColors = [
    TechColors.glowOrange, // short_hopper_1
    TechColors.glowCyan, // short_hopper_2
    TechColors.glowGreen, // short_hopper_3
    const Color(0xFFff3b30), // short_hopper_4
    const Color(0xFFffcc00), // no_hopper_1
    const Color(0xFFaf52de), // no_hopper_2
    const Color(0xFF00d4ff), // long_hopper_1
    const Color(0xFF00ffaa), // long_hopper_2
    const Color(0xFFff6b60), // long_hopper_3
  ];

  // 6种颜色用于区分不同辊道窑温区
  final List<Color> _rollerZoneColors = [
    TechColors.glowCyan, // zone1
    TechColors.glowGreen, // zone2
    const Color(0xFFaf52de), // zone3
    TechColors.glowOrange, // zone4
    const Color(0xFFffcc00), // zone5
    const Color(0xFF00d4ff), // zone6
  ];

  // 2种颜色用于区分SCR/风机设备
  final List<Color> _deviceColors = [
    TechColors.glowGreen,
    TechColors.glowOrange,
  ];

  @override
  void initState() {
    super.initState();
    _initializeTimeRanges();
    _loadAllHistoryData();
  }

  @override
  void dispose() {
    super.dispose();
  }

  /// 初始化所有图表的时间范围为最近120秒
  void _initializeTimeRanges() {
    final now = DateTime.now();
    final start = now.subtract(_defaultTimeRange);

    // 回转窑
    _tempChartStartTime = start;
    _tempChartEndTime = now;
    _feedSpeedChartStartTime = start;
    _feedSpeedChartEndTime = now;
    _hopperWeightChartStartTime = start;
    _hopperWeightChartEndTime = now;

    // 辊道窑
    _rollerTempChartStartTime = start;
    _rollerTempChartEndTime = now;
    _rollerEnergyChartStartTime = start;
    _rollerEnergyChartEndTime = now;
    _rollerPowerChartStartTime = start;
    _rollerPowerChartEndTime = now;

    // SCR/风机
    _pumpEnergyChartStartTime = start;
    _pumpEnergyChartEndTime = now;
    _fanEnergyChartStartTime = start;
    _fanEnergyChartEndTime = now;
  }

  /// 加载所有历史数据
  Future<void> _loadAllHistoryData() async {
    setState(() => _isLoading = true);

    await Future.wait([
      _loadHopperTemperatureData(),
      _loadHopperWeightData(),
      _loadRollerData(),
      _loadScrFanData(),
    ]);

    if (mounted) {
      setState(() => _isLoading = false);
    }
  }

  /// 加载回转窑温度历史数据
  Future<void> _loadHopperTemperatureData() async {
    // 加载当前选中设备的温度数据
    final deviceId =
        HistoryDataService.hopperDeviceIds[_selectedHopperIndex + 1]!;

    final result = await _historyService.queryHopperTemperatureHistory(
      deviceId: deviceId,
      start: _tempChartStartTime,
      end: _tempChartEndTime,
    );

    if (result.success && result.hasData) {
      final spots = _convertToFlSpots(result.dataPoints!, 'temperature');
      if (mounted) {
        setState(() {
          _temperatureData[_selectedHopperIndex] = spots;
        });
      }
    } else {
      debugPrint('❌ 加载温度数据失败: ${result.error}');
    }
  }

  /// 加载回转窑称重历史数据（重量和下料速度）
  Future<void> _loadHopperWeightData() async {
    final deviceId =
        HistoryDataService.hopperDeviceIds[_selectedHopperIndex + 1]!;

    final result = await _historyService.queryHopperWeightHistory(
      deviceId: deviceId,
      start: _hopperWeightChartStartTime,
      end: _hopperWeightChartEndTime,
    );

    if (result.success && result.hasData) {
      final weightSpots = _convertToFlSpots(result.dataPoints!, 'weight');
      final feedSpots = _convertToFlSpots(result.dataPoints!, 'feed_rate');

      if (mounted) {
        setState(() {
          _hopperWeightData[_selectedHopperIndex] = weightSpots;
          _feedSpeedData[_selectedHopperIndex] = feedSpots;
        });
      }
    } else {
      debugPrint('❌ 加载称重数据失败: ${result.error}');
    }
  }

  /// 加载辊道窑历史数据
  Future<void> _loadRollerData() async {
    // 加载所有选中温区的数据
    for (int i = 0; i < 6; i++) {
      if (!_selectedRollerZones[i]) continue;

      final zoneId = HistoryDataService.rollerZoneIds[i + 1]!;

      // 温度
      final tempResult = await _historyService.queryRollerTemperatureHistory(
        start: _rollerTempChartStartTime,
        end: _rollerTempChartEndTime,
        zone: zoneId,
      );

      if (tempResult.success && tempResult.hasData) {
        final spots = _convertToFlSpots(tempResult.dataPoints!, 'temperature');
        if (mounted) {
          setState(() => _rollerTemperatureData[i] = spots);
        }
      }

      // 功率
      final powerResult = await _historyService.queryRollerPowerHistory(
        start: _rollerPowerChartStartTime,
        end: _rollerPowerChartEndTime,
        zone: zoneId,
      );

      if (powerResult.success && powerResult.hasData) {
        final powerSpots = _convertToFlSpots(powerResult.dataPoints!, 'Pt');
        final energySpots = _convertToFlSpots(powerResult.dataPoints!, 'ImpEp');
        if (mounted) {
          setState(() {
            _rollerPowerData[i] = powerSpots;
            _rollerEnergyData[i] = energySpots;
          });
        }
      }
    }
  }

  /// 加载SCR和风机历史数据
  Future<void> _loadScrFanData() async {
    // SCR功率数据
    for (int i = 0; i < 2; i++) {
      if (!_selectedScrs[i]) continue;

      final deviceId = HistoryDataService.scrDeviceIds[i + 1]!;
      final result = await _historyService.queryScrPowerHistory(
        deviceId: deviceId,
        start: _pumpEnergyChartStartTime,
        end: _pumpEnergyChartEndTime,
      );

      if (result.success && result.hasData) {
        final spots = _convertToFlSpots(result.dataPoints!, 'Pt');
        if (mounted) {
          setState(() => _scrPowerData[i] = spots);
        }
      }
    }

    // 风机功率数据
    for (int i = 0; i < 2; i++) {
      if (!_selectedFans[i]) continue;

      final deviceId = HistoryDataService.fanDeviceIds[i + 1]!;
      final result = await _historyService.queryFanPowerHistory(
        deviceId: deviceId,
        start: _fanEnergyChartStartTime,
        end: _fanEnergyChartEndTime,
      );

      if (result.success && result.hasData) {
        final spots = _convertToFlSpots(result.dataPoints!, 'Pt');
        if (mounted) {
          setState(() => _fanPowerData[i] = spots);
        }
      }
    }
  }

  /// 将历史数据点转换为FlSpot列表
  List<FlSpot> _convertToFlSpots(
      List<HistoryDataPoint> dataPoints, String field) {
    if (dataPoints.isEmpty) return [];

    return dataPoints.asMap().entries.map((entry) {
      final index = entry.key;
      final point = entry.value;

      // X轴：时间索引
      final x = index.toDouble();

      // Y轴：字段值
      double y = 0;
      switch (field) {
        case 'temperature':
          y = point.temperature ?? 0;
          break;
        case 'weight':
          y = point.weight ?? 0;
          break;
        case 'feed_rate':
          y = point.feedRate ?? 0;
          break;
        case 'Pt':
          y = point.power ?? 0;
          break;
        case 'ImpEp':
          y = point.energy ?? 0;
          break;
        case 'flow_rate':
          y = point.flowRate ?? 0;
          break;
        default:
          y = point.fields[field]?.toDouble() ?? 0;
      }

      return FlSpot(x, y);
    }).toList();
  }

  /// 获取回转窑设备显示名称
  String _getHopperLabel(int index) {
    final deviceId = HistoryDataService.hopperDeviceIds[index + 1];
    if (deviceId == null) return '设备${index + 1}';

    if (deviceId.startsWith('short_hopper')) {
      final num = deviceId.split('_').last;
      return '短料仓$num';
    } else if (deviceId.startsWith('no_hopper')) {
      final num = deviceId.split('_').last;
      return '无料仓$num';
    } else if (deviceId.startsWith('long_hopper')) {
      final num = deviceId.split('_').last;
      return '长料仓$num';
    }
    return deviceId;
  }

  /// 获取辊道窑温区显示名称
  String _getRollerZoneLabel(int index) => '温区${index + 1}';

  @override
  Widget build(BuildContext context) {
    super.build(context); // 必须调用以支持 AutomaticKeepAliveClientMixin

    // 显示加载状态
    if (_isLoading) {
      return Container(
        color: TechColors.bgDeep,
        child: const Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(TechColors.glowCyan),
              ),
              SizedBox(height: 16),
              Text(
                '加载历史数据...',
                style: TextStyle(
                  color: TechColors.textSecondary,
                  fontSize: 14,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Container(
      color: TechColors.bgDeep,
      padding: const EdgeInsets.all(12),
      child: Row(
        children: [
          // 左侧：回转窑容器（38%宽度，全高）
          Expanded(
            flex: 19,
            child: TechPanel(
              title: '回转窑',
              accentColor: TechColors.glowOrange,
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
          const SizedBox(width: 12),
          // 右侧：辊道窑和SCR设备（62%宽度）
          Expanded(
            flex: 31,
            child: Column(
              children: [
                // 上部：辊道窑容器（3/5高度）
                Expanded(
                  flex: 3,
                  child: TechPanel(
                    title: '辊道窑',
                    accentColor: TechColors.glowCyan,
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
                const SizedBox(height: 12),
                // 下部：SCR设备容器（2/5高度）
                Expanded(
                  flex: 2,
                  child: TechPanel(
                    title: 'SCR设备和风机',
                    accentColor: TechColors.glowGreen,
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
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// 历史温度曲线图（料仓温度）
  Widget _buildTemperatureChart() {
    return TechLineChart(
      title: '料仓温度曲线',
      accentColor: TechColors.glowOrange,
      yAxisLabel: '温度(°C)',
      xAxisLabel: '数据点',
      xInterval: 5,
      dataMap: _temperatureData,
      isSingleSelect: true,
      selectedIndex: _selectedHopperIndex,
      itemColors: _hopperColors,
      itemCount: 9,
      getItemLabel: _getHopperLabel,
      selectorLabel: '选择料仓',
      headerActions: [
        TimeRangeSelector(
          startTime: _tempChartStartTime,
          endTime: _tempChartEndTime,
          onStartTimeTap: () => _selectChartStartTime('temp'),
          onEndTimeTap: () => _selectChartEndTime('temp'),
          onCancel: () => _refreshChartData('temp'),
          accentColor: TechColors.glowOrange,
        ),
      ],
      onItemSelect: (index) {
        setState(() {
          _selectedHopperIndex = index;
        });
        _loadHopperTemperatureData();
      },
    );
  }

  /// 下料速度曲线图
  Widget _buildFeedSpeedChart() {
    return TechLineChart(
      title: '下料速度曲线',
      accentColor: TechColors.glowCyan,
      yAxisLabel: '速度(kg/s)',
      xAxisLabel: '数据点',
      xInterval: 5,
      dataMap: _feedSpeedData,
      isSingleSelect: true,
      selectedIndex: _selectedHopperIndex,
      itemColors: _hopperColors,
      itemCount: 9,
      getItemLabel: _getHopperLabel,
      selectorLabel: '选择料仓',
      headerActions: [
        TimeRangeSelector(
          startTime: _feedSpeedChartStartTime,
          endTime: _feedSpeedChartEndTime,
          onStartTimeTap: () => _selectChartStartTime('feedSpeed'),
          onEndTimeTap: () => _selectChartEndTime('feedSpeed'),
          onCancel: () => _refreshChartData('feedSpeed'),
          accentColor: TechColors.glowCyan,
        ),
      ],
      onItemSelect: (index) {
        setState(() {
          _selectedHopperIndex = index;
        });
        _loadHopperWeightData();
      },
    );
  }

  /// 料仓重量曲线图
  Widget _buildHopperWeightChart() {
    return TechLineChart(
      title: '料仓重量曲线',
      accentColor: TechColors.glowGreen,
      yAxisLabel: '重量(kg)',
      xAxisLabel: '数据点',
      xInterval: 5,
      dataMap: _hopperWeightData,
      isSingleSelect: true,
      selectedIndex: _selectedHopperIndex,
      itemColors: _hopperColors,
      itemCount: 9,
      getItemLabel: _getHopperLabel,
      selectorLabel: '选择料仓',
      headerActions: [
        TimeRangeSelector(
          startTime: _hopperWeightChartStartTime,
          endTime: _hopperWeightChartEndTime,
          onStartTimeTap: () => _selectChartStartTime('hopperWeight'),
          onEndTimeTap: () => _selectChartEndTime('hopperWeight'),
          onCancel: () => _refreshChartData('hopperWeight'),
          accentColor: TechColors.glowGreen,
        ),
      ],
      onItemSelect: (index) {
        setState(() {
          _selectedHopperIndex = index;
        });
        _loadHopperWeightData();
      },
    );
  }

  /// 辊道窑温度曲线图
  Widget _buildRollerTemperatureChart() {
    return TechLineChart(
      title: '辊道窑温度曲线',
      accentColor: TechColors.glowCyan,
      yAxisLabel: '温度(°C)',
      xAxisLabel: '数据点',
      xInterval: 5,
      dataMap: _rollerTemperatureData,
      selectedItems: _selectedRollerZones,
      itemColors: _rollerZoneColors,
      itemCount: 6,
      getItemLabel: _getRollerZoneLabel,
      selectorLabel: '选择温区',
      compact: true,
      headerActions: [
        TimeRangeSelector(
          startTime: _rollerTempChartStartTime,
          endTime: _rollerTempChartEndTime,
          onStartTimeTap: () => _selectChartStartTime('rollerTemp'),
          onEndTimeTap: () => _selectChartEndTime('rollerTemp'),
          onCancel: () => _refreshChartData('rollerTemp'),
          accentColor: TechColors.glowCyan,
          compact: true,
        ),
      ],
      onItemToggle: (index) {
        setState(() {
          _selectedRollerZones[index] = !_selectedRollerZones[index];
        });
        _loadRollerData();
      },
    );
  }

  /// 辊道窑能耗曲线图
  Widget _buildRollerEnergyChart() {
    return TechBarChart(
      title: '辊道窑能耗曲线',
      accentColor: TechColors.glowGreen,
      yAxisLabel: '能耗(kW·h)',
      xAxisLabel: '数据点',
      xInterval: 5,
      dataMap: _rollerEnergyData,
      selectedItems: _selectedRollerZones,
      itemColors: _rollerZoneColors,
      itemCount: 6,
      getItemLabel: _getRollerZoneLabel,
      selectorLabel: '选择温区',
      compact: true,
      headerActions: [
        TimeRangeSelector(
          startTime: _rollerEnergyChartStartTime,
          endTime: _rollerEnergyChartEndTime,
          onStartTimeTap: () => _selectChartStartTime('rollerEnergy'),
          onEndTimeTap: () => _selectChartEndTime('rollerEnergy'),
          onCancel: () => _refreshChartData('rollerEnergy'),
          accentColor: TechColors.glowGreen,
          compact: true,
        ),
      ],
      onItemToggle: (index) {
        setState(() {
          _selectedRollerZones[index] = !_selectedRollerZones[index];
        });
        _loadRollerData();
      },
    );
  }

  /// 辊道窑功率曲线图
  Widget _buildRollerPowerChart() {
    return TechBarChart(
      title: '辊道窑功率曲线',
      accentColor: TechColors.glowOrange,
      yAxisLabel: '功率(kW)',
      xAxisLabel: '数据点',
      xInterval: 5,
      dataMap: _rollerPowerData,
      selectedItems: _selectedRollerZones,
      itemColors: _rollerZoneColors,
      itemCount: 6,
      getItemLabel: _getRollerZoneLabel,
      selectorLabel: '选择温区',
      compact: true,
      headerActions: [
        TimeRangeSelector(
          startTime: _rollerPowerChartStartTime,
          endTime: _rollerPowerChartEndTime,
          onStartTimeTap: () => _selectChartStartTime('rollerPower'),
          onEndTimeTap: () => _selectChartEndTime('rollerPower'),
          onCancel: () => _refreshChartData('rollerPower'),
          accentColor: TechColors.glowOrange,
          compact: true,
        ),
      ],
      onItemToggle: (index) {
        setState(() {
          _selectedRollerZones[index] = !_selectedRollerZones[index];
        });
        _loadRollerData();
      },
    );
  }

  /// SCR功率曲线图
  Widget _buildPumpEnergyChart() {
    return TechBarChart(
      title: 'SCR功率曲线',
      accentColor: TechColors.glowGreen,
      yAxisLabel: '功率(kW)',
      xAxisLabel: '数据点',
      xInterval: 5,
      dataMap: _scrPowerData,
      selectedItems: _selectedScrs,
      itemColors: _deviceColors,
      itemCount: 2,
      getItemLabel: (index) => 'SCR ${index + 1}',
      selectorLabel: '选择SCR',
      headerActions: [
        TimeRangeSelector(
          startTime: _pumpEnergyChartStartTime,
          endTime: _pumpEnergyChartEndTime,
          onStartTimeTap: () => _selectChartStartTime('pumpEnergy'),
          onEndTimeTap: () => _selectChartEndTime('pumpEnergy'),
          onCancel: () => _refreshChartData('pumpEnergy'),
          accentColor: TechColors.glowGreen,
        ),
      ],
      onItemToggle: (index) {
        setState(() {
          _selectedScrs[index] = !_selectedScrs[index];
        });
        _loadScrFanData();
      },
    );
  }

  /// 风机功率曲线图
  Widget _buildFanEnergyChart() {
    return TechBarChart(
      title: '风机功率曲线',
      accentColor: TechColors.glowOrange,
      yAxisLabel: '功率(kW)',
      xAxisLabel: '数据点',
      xInterval: 5,
      dataMap: _fanPowerData,
      selectedItems: _selectedFans,
      itemColors: _deviceColors,
      itemCount: 2,
      getItemLabel: (index) => '风机 ${index + 1}',
      selectorLabel: '选择风机',
      headerActions: [
        TimeRangeSelector(
          startTime: _fanEnergyChartStartTime,
          endTime: _fanEnergyChartEndTime,
          onStartTimeTap: () => _selectChartStartTime('fanEnergy'),
          onEndTimeTap: () => _selectChartEndTime('fanEnergy'),
          onCancel: () => _refreshChartData('fanEnergy'),
          accentColor: TechColors.glowOrange,
        ),
      ],
      onItemToggle: (index) {
        setState(() {
          _selectedFans[index] = !_selectedFans[index];
        });
        _loadScrFanData();
      },
    );
  }

  // ==================== 通用图表时间选择方法 ====================

  /// 获取图表对应的强调色
  Color _getChartAccentColor(String chartType) {
    switch (chartType) {
      case 'temp':
        return TechColors.glowOrange;
      case 'feedSpeed':
        return TechColors.glowCyan;
      case 'hopperWeight':
        return TechColors.glowGreen;
      case 'rollerTemp':
        return TechColors.glowCyan;
      case 'rollerEnergy':
        return TechColors.glowGreen;
      case 'rollerPower':
        return TechColors.glowOrange;
      case 'pumpEnergy':
        return TechColors.glowGreen;
      case 'fanEnergy':
        return TechColors.glowOrange;
      default:
        return TechColors.glowCyan;
    }
  }

  /// 获取图表开始时间
  DateTime _getChartStartTime(String chartType) {
    switch (chartType) {
      case 'temp':
        return _tempChartStartTime;
      case 'feedSpeed':
        return _feedSpeedChartStartTime;
      case 'hopperWeight':
        return _hopperWeightChartStartTime;
      case 'rollerTemp':
        return _rollerTempChartStartTime;
      case 'rollerEnergy':
        return _rollerEnergyChartStartTime;
      case 'rollerPower':
        return _rollerPowerChartStartTime;
      case 'pumpEnergy':
        return _pumpEnergyChartStartTime;
      case 'fanEnergy':
        return _fanEnergyChartStartTime;
      default:
        return DateTime.now().subtract(const Duration(hours: 24));
    }
  }

  /// 设置图表开始时间
  void _setChartStartTime(String chartType, DateTime time) {
    switch (chartType) {
      case 'temp':
        _tempChartStartTime = time;
        break;
      case 'feedSpeed':
        _feedSpeedChartStartTime = time;
        break;
      case 'hopperWeight':
        _hopperWeightChartStartTime = time;
        break;
      case 'rollerTemp':
        _rollerTempChartStartTime = time;
        break;
      case 'rollerEnergy':
        _rollerEnergyChartStartTime = time;
        break;
      case 'rollerPower':
        _rollerPowerChartStartTime = time;
        break;
      case 'pumpEnergy':
        _pumpEnergyChartStartTime = time;
        break;
      case 'fanEnergy':
        _fanEnergyChartStartTime = time;
        break;
    }
  }

  /// 获取图表结束时间
  DateTime _getChartEndTime(String chartType) {
    switch (chartType) {
      case 'temp':
        return _tempChartEndTime;
      case 'feedSpeed':
        return _feedSpeedChartEndTime;
      case 'hopperWeight':
        return _hopperWeightChartEndTime;
      case 'rollerTemp':
        return _rollerTempChartEndTime;
      case 'rollerEnergy':
        return _rollerEnergyChartEndTime;
      case 'rollerPower':
        return _rollerPowerChartEndTime;
      case 'pumpEnergy':
        return _pumpEnergyChartEndTime;
      case 'fanEnergy':
        return _fanEnergyChartEndTime;
      default:
        return DateTime.now();
    }
  }

  /// 设置图表结束时间
  void _setChartEndTime(String chartType, DateTime time) {
    switch (chartType) {
      case 'temp':
        _tempChartEndTime = time;
        break;
      case 'feedSpeed':
        _feedSpeedChartEndTime = time;
        break;
      case 'hopperWeight':
        _hopperWeightChartEndTime = time;
        break;
      case 'rollerTemp':
        _rollerTempChartEndTime = time;
        break;
      case 'rollerEnergy':
        _rollerEnergyChartEndTime = time;
        break;
      case 'rollerPower':
        _rollerPowerChartEndTime = time;
        break;
      case 'pumpEnergy':
        _pumpEnergyChartEndTime = time;
        break;
      case 'fanEnergy':
        _fanEnergyChartEndTime = time;
        break;
    }
  }

  /// 选择图表开始时间
  Future<void> _selectChartStartTime(String chartType) async {
    final accentColor = _getChartAccentColor(chartType);
    final startTime = _getChartStartTime(chartType);

    final DateTime? pickedDate = await showDatePicker(
      context: context,
      initialDate: startTime,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      builder: (context, child) {
        return Theme(
          data: ThemeData.dark().copyWith(
            colorScheme: ColorScheme.dark(
              primary: accentColor,
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
        initialTime: TimeOfDay.fromDateTime(startTime),
        builder: (context, child) {
          return Theme(
            data: ThemeData.dark().copyWith(
              colorScheme: ColorScheme.dark(
                primary: accentColor,
                surface: TechColors.bgMedium,
              ),
            ),
            child: child!,
          );
        },
      );

      if (pickedTime != null) {
        setState(() {
          final newTime = DateTime(
            pickedDate.year,
            pickedDate.month,
            pickedDate.day,
            pickedTime.hour,
            pickedTime.minute,
          );
          _setChartStartTime(chartType, newTime);
          _refreshChartData(chartType);
        });
      }
    }
  }

  /// 选择图表结束时间
  Future<void> _selectChartEndTime(String chartType) async {
    final accentColor = _getChartAccentColor(chartType);
    final endTime = _getChartEndTime(chartType);

    final DateTime? pickedDate = await showDatePicker(
      context: context,
      initialDate: endTime,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      builder: (context, child) {
        return Theme(
          data: ThemeData.dark().copyWith(
            colorScheme: ColorScheme.dark(
              primary: accentColor,
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
        initialTime: TimeOfDay.fromDateTime(endTime),
        builder: (context, child) {
          return Theme(
            data: ThemeData.dark().copyWith(
              colorScheme: ColorScheme.dark(
                primary: accentColor,
                surface: TechColors.bgMedium,
              ),
            ),
            child: child!,
          );
        },
      );

      if (pickedTime != null) {
        setState(() {
          final newTime = DateTime(
            pickedDate.year,
            pickedDate.month,
            pickedDate.day,
            pickedTime.hour,
            pickedTime.minute,
          );
          _setChartEndTime(chartType, newTime);
          _refreshChartData(chartType);
        });
      }
    }
  }

  /// 刷新图表数据（从API获取）
  void _refreshChartData(String chartType) {
    // 根据图表类型刷新对应数据
    if (chartType == 'temp') {
      _loadHopperTemperatureData();
    } else if (chartType == 'feedSpeed' || chartType == 'hopperWeight') {
      _loadHopperWeightData();
    } else if (chartType == 'rollerTemp' ||
        chartType == 'rollerEnergy' ||
        chartType == 'rollerPower') {
      _loadRollerData();
    } else if (chartType == 'pumpEnergy' || chartType == 'fanEnergy') {
      _loadScrFanData();
    }
  }

  /// 重置图表为默认120秒时间范围
  void _resetChartToDefault(String chartType) {
    final now = DateTime.now();
    final defaultStart = now.subtract(const Duration(seconds: 120));

    setState(() {
      _setChartStartTime(chartType, defaultStart);
      _setChartEndTime(chartType, now);
    });

    _refreshChartData(chartType);
  }
}

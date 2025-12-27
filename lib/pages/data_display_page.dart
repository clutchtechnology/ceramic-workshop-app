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
/// 默认显示数据库中最新数据时间戳往前50秒的历史数据
/// 逻辑：先查询数据库最新时间戳作为 end，然后 start = end - 50s
///
/// 回退逻辑（无法获取时间戳时）：200秒前 到 150秒前
/// 原因：后端采用批量写入（30次轮询 × 5秒 = 150秒延迟）
///
/// 每次进入页面自动刷新历史数据，10秒防抖机制防止重复调用
class DataDisplayPage extends StatefulWidget {
  const DataDisplayPage({super.key});

  @override
  DataDisplayPageState createState() => DataDisplayPageState();
}

/// DataDisplayPage 的 State 类（公开以便通过 GlobalKey 访问）
class DataDisplayPageState extends State<DataDisplayPage>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  // 历史数据服务
  final HistoryDataService _historyService = HistoryDataService();

  // 加载状态
  bool _isLoading = true;

  // ==================== 批量写入延迟补偿 ====================
  // 由于后端采用批量写入（30次轮询 × 6秒 = 180秒后才写入），
  // 最近180秒的数据可能还未写入数据库，因此需要跳过这段时间

  /// 批量写入延迟：最近180秒的数据可能还未写入
  static const Duration _batchWriteDelay = Duration(seconds: 180);

  /// 查询时间窗口：查询50秒的历史数据（200秒前 到 150秒前）
  static const Duration _queryWindow = Duration(seconds: 50);

  /// 默认时间范围：24小时（用于历史查询）
  static const Duration _defaultTimeRange = Duration(hours: 24);

  // ==================== 刷新防抖机制 ====================
  /// 上次刷新历史数据的时间戳
  DateTime? _lastRefreshTime;

  /// 刷新防抖间隔：10秒内不重复刷新
  static const Duration _refreshDebounceInterval = Duration(seconds: 10);

  // ==================== 8个图表的独立时间范围 ====================
  // 回转窑3个图表共用一个时间范围（默认最近24小时）
  late DateTime _hopperChartStartTime;
  late DateTime _hopperChartEndTime;

  // 辊道窑3个图表共用一个时间范围（默认最近24小时）
  late DateTime _rollerChartStartTime;
  late DateTime _rollerChartEndTime;

  // SCR设备2个图表（默认最近24小时）
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
    // 首次加载时强制刷新（异步初始化时间范围后加载数据）
    _refreshHistoryDataWithDebounce(forceRefresh: true);
  }

  @override
  void dispose() {
    super.dispose();
  }

  /// 页面进入时调用的刷新方法（由父组件调用）
  /// 自动获取最近24小时历史数据，超过10秒才会真正刷新
  void onPageEnter() {
    _refreshHistoryDataWithDebounce();
  }

  /// 带防抖机制的历史数据刷新
  /// [forceRefresh] 是否强制刷新（忽略防抖间隔）
  void _refreshHistoryDataWithDebounce({bool forceRefresh = false}) {
    final now = DateTime.now();

    // 检查是否需要刷新：首次加载 或 强制刷新 或 距离上次刷新超过10秒
    final shouldRefresh = forceRefresh ||
        _lastRefreshTime == null ||
        now.difference(_lastRefreshTime!) > _refreshDebounceInterval;

    if (shouldRefresh) {
      debugPrint(
          '📊 刷新历史数据 (上次: ${_lastRefreshTime ?? "首次"}, 间隔: ${_lastRefreshTime != null ? now.difference(_lastRefreshTime!).inSeconds : 0}秒)');
      _lastRefreshTime = now;

      // 异步初始化时间范围后加载历史数据
      _initializeTimeRangesAndLoadData();
    } else {
      final elapsed = now.difference(_lastRefreshTime!).inSeconds;
      debugPrint(
          '📊 跳过刷新 (距上次刷新仅 $elapsed 秒，需超过 ${_refreshDebounceInterval.inSeconds} 秒)');
    }
  }

  /// 初始化所有图表的时间范围
  ///
  /// 优先从数据库获取最新数据时间戳作为结束时间，
  /// 开始时间 = 结束时间 - 查询窗口（50秒）
  ///
  /// 如果无法获取数据库时间戳，则回退到旧逻辑：
  /// - 结束时间：150秒前（跳过未写入的数据）
  /// - 开始时间：200秒前（查询50秒的时间窗口）
  Future<void> _initializeTimeRanges() async {
    DateTime end;
    DateTime start;

    // 尝试从数据库获取最新时间戳
    final latestTimestamp = await _historyService.getLatestDbTimestamp();

    if (latestTimestamp != null) {
      // 使用数据库最新时间戳作为结束时间
      end = latestTimestamp;
      start = end.subtract(_queryWindow); // 往前50秒
      debugPrint(
          '📊 使用数据库最新时间戳: ${end.toString()}, 查询范围: ${start.toString()} ~ ${end.toString()}');
    } else {
      // 回退到旧逻辑：200秒前 到 150秒前
      final now = DateTime.now();
      end = now.subtract(_batchWriteDelay); // 150秒前
      start = end.subtract(_queryWindow); // 200秒前
      debugPrint(
          '📊 无法获取数据库时间戳，使用回退逻辑: ${start.toString()} ~ ${end.toString()} (跳过最近150秒)');
    }

    // 回转窑（3个图表共用一个时间范围）
    _hopperChartStartTime = start;
    _hopperChartEndTime = end;

    // 辊道窑（3个图表共用一个时间范围）
    _rollerChartStartTime = start;
    _rollerChartEndTime = end;

    // SCR/风机
    _pumpEnergyChartStartTime = start;
    _pumpEnergyChartEndTime = end;
    _fanEnergyChartStartTime = start;
    _fanEnergyChartEndTime = end;
  }

  /// 初始化时间范围并加载数据（组合方法）
  Future<void> _initializeTimeRangesAndLoadData() async {
    await _initializeTimeRanges();
    await _loadAllHistoryData();
  }

  /// 加载所有历史数据
  Future<void> _loadAllHistoryData() async {
    if (!mounted) return;
    setState(() => _isLoading = true);

    try {
      await Future.wait([
        _loadHopperTemperatureData(),
        _loadHopperWeightData(),
        _loadRollerData(),
        _loadScrFanData(),
      ]).timeout(const Duration(seconds: 30));
    } catch (e) {
      debugPrint('加载历史数据超时或失败: $e');
    }

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
      start: _hopperChartStartTime,
      end: _hopperChartEndTime,
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
      start: _hopperChartStartTime,
      end: _hopperChartEndTime,
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

      // 温度（使用统一的辊道窑时间范围）
      final tempResult = await _historyService.queryRollerTemperatureHistory(
        start: _rollerChartStartTime,
        end: _rollerChartEndTime,
        zone: zoneId,
      );

      if (tempResult.success && tempResult.hasData) {
        final spots = _convertToFlSpots(tempResult.dataPoints!, 'temperature');
        if (mounted) {
          setState(() => _rollerTemperatureData[i] = spots);
        }
      }

      // 功率（使用统一的辊道窑时间范围）
      final powerResult = await _historyService.queryRollerPowerHistory(
        start: _rollerChartStartTime,
        end: _rollerChartEndTime,
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
  /// 所有数值保留两位小数
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

      // 保留两位小数
      y = double.parse(y.toStringAsFixed(2));

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
                  // 历史温度曲线（包含选择器，高度稍大）
                  Expanded(
                    flex: 4,
                    child: _buildTemperatureChart(),
                  ),
                  const SizedBox(height: 8),
                  // 下料速度曲线（无选择器）
                  Expanded(
                    flex: 3,
                    child: _buildFeedSpeedChart(),
                  ),
                  const SizedBox(height: 8),
                  // 料仓重量曲线（无选择器）
                  Expanded(
                    flex: 3,
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
  /// 回转窑3个图表共用这个选择器
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
      selectorLabel: '选择回转窑',
      headerActions: [
        TimeRangeSelector(
          startTime: _hopperChartStartTime,
          endTime: _hopperChartEndTime,
          onStartTimeTap: () => _selectChartStartTime('hopper'),
          onEndTimeTap: () => _selectChartEndTime('hopper'),
          onCancel: () => _refreshChartData('hopper'),
          accentColor: TechColors.glowOrange,
        ),
      ],
      onItemSelect: (index) {
        setState(() {
          _selectedHopperIndex = index;
        });
        // 切换料仓时，同时刷新三个图表的数据
        _loadHopperTemperatureData();
        _loadHopperWeightData();
      },
    );
  }

  /// 下料速度曲线图（不显示选择器，与温度图共用选择器）
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
      selectorLabel: '选择回转窑',
      showSelector: false, // 不显示选择器
      onItemSelect: (index) {},
    );
  }

  /// 料仓重量曲线图（不显示选择器，与温度图共用选择器）
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
      selectorLabel: '选择回转窑',
      showSelector: false, // 不显示选择器
      onItemSelect: (index) {},
    );
  }

  /// 辊道窑温度曲线图（不显示选择器，与功率图共用选择器）
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
      selectorLabel: '选择分区',
      showSelector: false, // 不显示选择器
      onItemToggle: (index) {},
    );
  }

  /// 辊道窑能耗曲线图（不显示选择器，与功率图共用选择器）
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
      selectorLabel: '选择分区',
      showSelector: false, // 不显示选择器
      onItemToggle: (index) {},
    );
  }

  /// 辊道窑功率曲线图（包含选择器，3个图表共用）
  Widget _buildRollerPowerChart() {
    return TechBarChart(
      title: '辊道窑功率曲线',
      accentColor: TechColors.glowCyan,
      yAxisLabel: '功率(kW)',
      xAxisLabel: '数据点',
      xInterval: 5,
      dataMap: _rollerPowerData,
      selectedItems: _selectedRollerZones,
      itemColors: _rollerZoneColors,
      itemCount: 6,
      getItemLabel: _getRollerZoneLabel,
      selectorLabel: '选择分区',
      headerActions: [
        TimeRangeSelector(
          startTime: _rollerChartStartTime,
          endTime: _rollerChartEndTime,
          onStartTimeTap: () => _selectChartStartTime('roller'),
          onEndTimeTap: () => _selectChartEndTime('roller'),
          onCancel: () => _refreshChartData('roller'),
          accentColor: TechColors.glowCyan,
        ),
      ],
      onItemToggle: (index) {
        setState(() {
          _selectedRollerZones[index] = !_selectedRollerZones[index];
        });
        // 切换温区时刷新所有辊道窑数据
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
      accentColor: TechColors.glowGreen,
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
          accentColor: TechColors.glowGreen,
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
      case 'hopper': // 回转窑3个图表统一使用
        return TechColors.glowOrange;
      case 'roller': // 辊道窑3个图表统一使用
        return TechColors.glowCyan;
      case 'pumpEnergy':
        return TechColors.glowGreen;
      case 'fanEnergy':
        return TechColors.glowGreen;
      default:
        return TechColors.glowCyan;
    }
  }

  /// 获取图表开始时间
  DateTime _getChartStartTime(String chartType) {
    switch (chartType) {
      case 'hopper': // 回转窑3个图表统一使用
        return _hopperChartStartTime;
      case 'roller': // 辊道窑3个图表统一使用
        return _rollerChartStartTime;
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
      case 'hopper': // 回转窑3个图表统一使用
        _hopperChartStartTime = time;
        break;
      case 'roller': // 辊道窑3个图表统一使用
        _rollerChartStartTime = time;
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
      case 'hopper': // 回转窑3个图表统一使用
        return _hopperChartEndTime;
      case 'roller': // 辊道窑3个图表统一使用
        return _rollerChartEndTime;
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
      case 'hopper': // 回转窑3个图表统一使用
        _hopperChartEndTime = time;
        break;
      case 'roller': // 辊道窑3个图表统一使用
        _rollerChartEndTime = time;
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

  /// 刷新图表数据（从 API 获取）
  void _refreshChartData(String chartType) {
    // 根据图表类型刷新对应数据
    if (chartType == 'hopper') {
      // 回转窑：同时刷新温度和称重数据
      _loadHopperTemperatureData();
      _loadHopperWeightData();
    } else if (chartType == 'roller') {
      // 辊道窑：刷新所有温区数据
      _loadRollerData();
    } else if (chartType == 'pumpEnergy' || chartType == 'fanEnergy') {
      _loadScrFanData();
    }
  }

  /// 重置图表为默认时间范围（200秒前 到 150秒前）
  void _resetChartToDefault(String chartType) {
    final now = DateTime.now();
    final defaultEnd = now.subtract(_batchWriteDelay); // 150秒前
    final defaultStart = defaultEnd.subtract(_queryWindow); // 200秒前

    setState(() {
      _setChartStartTime(chartType, defaultStart);
      _setChartEndTime(chartType, defaultEnd);
    });

    _refreshChartData(chartType);
  }
}

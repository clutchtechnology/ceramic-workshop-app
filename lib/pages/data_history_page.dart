import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../widgets/data_display/data_tech_line_widgets.dart';
import '../widgets/data_display/data_time_range_selector.dart';
import '../widgets/data_display/data_tech_line_chart.dart';
import '../widgets/data_display/data_tech_bar_chart.dart';
import '../widgets/data_display/quick_time_range_selector.dart';
import '../widgets/data_display/data_single_select_dropdown.dart';
import '../widgets/data_display/data_multi_select_dropdown.dart';
import '../widgets/data_display/data_export_dialog.dart';
import '../services/history_data_service.dart';

/// 历史数据页面
/// 包含三个设备容器：回转窑、辊道窑、SCR设备

/// 每次进入页面自动刷新历史数据，10秒防抖机制防止重复调用
class HistoryDataPage extends StatefulWidget {
  const HistoryDataPage({super.key});

  @override
  HistoryDataPageState createState() => HistoryDataPageState();
}

/// HistoryDataPageState 的 State 类（公开以便通过 GlobalKey 访问）
class HistoryDataPageState extends State<HistoryDataPage>
    with AutomaticKeepAliveClientMixin {
  // 🔧 [CRITICAL] 使用 KeepAlive 避免页面切换时重建，但需注意内存占用
  @override
  bool get wantKeepAlive => true;

  // ============================================================
  // 1, 历史数据服务 (API 调用封装)
  // ============================================================
  final HistoryDataService _historyService = HistoryDataService();

  // 2, 加载状态标识 (控制 Loading UI 显示)
  bool _isLoading = true;

  // 3, 批量写入延迟：最近180秒的数据可能还未写入
  static const Duration _batchWriteDelay = Duration(seconds: 180);

  // 4, 查询时间窗口：查询24小时的历史数据
  static const Duration _queryWindow = Duration(hours: 24);

  // ==================== 刷新防抖机制 ====================
  // 5, 上次刷新历史数据的时间戳 (用于防抖)
  DateTime? _lastRefreshTime;

  // 6, 刷新防抖间隔：10秒内不重复刷新
  static const Duration _refreshDebounceInterval = Duration(seconds: 10);

  // ==================== 图表时间范围 ====================
  // 7, 回转窑3个图表共用时间范围
  late DateTime _hopperChartStartTime;
  late DateTime _hopperChartEndTime;

  // 8, 辊道窑3个图表共用时间范围
  late DateTime _rollerChartStartTime;
  late DateTime _rollerChartEndTime;

  // 9, SCR图表时间范围
  late DateTime _scrChartStartTime;
  late DateTime _scrChartEndTime;

  // 10, 风机图表时间范围
  late DateTime _fanChartStartTime;
  late DateTime _fanChartEndTime;

  // ==================== 设备选择状态 ====================
  // 11, 回转窑选择索引 (0-8 对应 9 个回转窑)
  int _selectedHopperIndex = 0;

  // 12, 辊道窑温区选择 (6个温区的显示/隐藏状态)
  List<bool> _selectedRollerZones = List.generate(6, (_) => true);

  // 13, SCR设备选择索引
  int _selectedPumpIndex = 0;

  // 14, 风机选择索引 (多选)
  List<bool> _selectedFanIndexes = [true, false];

  // ==================== 图表数据 ====================
  // 15, 回转窑温度数据 (key: 设备索引, value: 数据点列表)
  final Map<int, List<FlSpot>> _temperatureData = {};

  // 15.5, 长料仓第二温度数据 (key: 设备索引, value: 数据点列表)
  final Map<int, List<FlSpot>> _temperatureData2 = {};

  // 16, SCR燃气流量数据
  final Map<int, List<FlSpot>> _scrGasFlowData = {};
  final Map<int, List<FlSpot>> _scrGasTotalData = {};

  // 17, SCR显示模式 (false: 水泵功率, true: 燃气流量)
  bool _showScrGas = false;

  // 16, 回转窑下料速度数据
  final Map<int, List<FlSpot>> _feedSpeedData = {};

  // 17, 回转窑料仓重量数据
  final Map<int, List<FlSpot>> _hopperWeightData = {};

  // 18, 回转窑能耗数据
  final Map<int, List<FlSpot>> _hopperEnergyData = {};

  // 18.5, 回转窑投料总量数据 (累计投料 weight)
  final Map<int, List<FlSpot>> _hopperFeedingData = {};

  // 19, 辊道窑温度数据 (key: 温区索引 0-5)
  final Map<int, List<FlSpot>> _rollerTemperatureData = {};

  // 19, 辊道窑能耗数据
  final Map<int, List<FlSpot>> _rollerEnergyData = {};

  // 20, 辊道窑功率数据
  final Map<int, List<FlSpot>> _rollerPowerData = {};

  // 21, SCR功率数据 (key: 0 或 1)
  final Map<int, List<FlSpot>> _scrPowerData = {};

  // 22, 风机功率数据 (key: 0 或 1)
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
  /// 开始时间 = 结束时间 - 查询窗口（24小时）
  ///
  /// 如果无法获取数据库时间戳，则回退到旧逻辑：
  /// - 结束时间：180秒前（跳过未写入的数据）
  /// - 开始时间：24小时前（查询24小时的时间窗口）
  Future<void> _initializeTimeRanges() async {
    DateTime end;
    DateTime start;

    // 尝试从数据库获取最新时间戳
    final latestTimestamp = await _historyService.getLatestDbTimestamp();

    if (latestTimestamp != null) {
      // 使用数据库最新时间戳作为结束时间
      end = latestTimestamp;
      start = end.subtract(_queryWindow); // 往前24小时
      debugPrint(
          '📊 使用数据库最新时间戳: ${end.toString()}, 查询范围: ${start.toString()} ~ ${end.toString()}');
    } else {
      // 回退到旧逻辑：24小时前 到 180秒前
      final now = DateTime.now();
      end = now.subtract(_batchWriteDelay); // 180秒前
      start = end.subtract(_queryWindow); // 24小时前
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
    _scrChartStartTime = start;
    _scrChartEndTime = end;
    _fanChartStartTime = start;
    _fanChartEndTime = end;
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
        _loadHopperEnergyData(), // 🔧 新增：加载回转窑能耗数据
        _loadHopperFeedingData(), // 🔧 新增：加载投料累计数据
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

  void _handleQuickTimeSelect(String chartType, Duration duration) {
    setState(() {
      final now = DateTime.now();
      // 使用一致的时间逻辑：当前时间减去批处理写入延迟作为结束时间
      // 这样可以确保选中的"最近X天"是有数据的最新区间
      final effectiveEnd = now.subtract(_batchWriteDelay);
      final effectiveStart = effectiveEnd.subtract(duration);

      _setChartStartTime(chartType, effectiveStart);
      _setChartEndTime(chartType, effectiveEnd);
      _refreshChartData(chartType);
    });
  }

  /// 显示数据导出弹窗（新版）
  void _showDataExportDialog() {
    showDialog(
      context: context,
      builder: (context) => const DataExportDialog(),
    );
  }

  /// 加载回转窑温度历史数据
  Future<void> _loadHopperTemperatureData() async {
    final deviceId =
        HistoryDataService.hopperDeviceIds[_selectedHopperIndex + 1]!;

    final result = await _historyService.queryHopperTemperatureHistory(
      deviceId: deviceId,
      start: _hopperChartStartTime,
      end: _hopperChartEndTime,
    );

    if (!mounted) return;
    if (result.success && result.hasData) {
      // 检查是否为长料仓（索引 6, 7, 8）
      final isLongHopper = _selectedHopperIndex >= 6;

      if (isLongHopper) {
        // 分离 temp1 和 temp2 数据
        final temp1Points = result.dataPoints!
            .where((p) => p.moduleTag == 'temp1' || p.moduleTag == 'temp')
            .toList();

        // 如果后端对于长料仓返回了统一的'temperature'且没有moduleTag区分，
        // 则尝试直接取'temperature'字段。但根据yaml配置，长料仓有temp1和temp2标签。
        // 如果数据混合在一起且没有区分标签，图表会乱。
        // 假设HistoryDataService返回的数据点均包含moduleTag。

        final temp2Points =
            result.dataPoints!.where((p) => p.moduleTag == 'temp2').toList();

        final spots1 = _convertToFlSpots(temp1Points, 'temperature');
        final spots2 = _convertToFlSpots(temp2Points, 'temperature');

        setState(() {
          _temperatureData[_selectedHopperIndex] = spots1;
          _temperatureData2[_selectedHopperIndex] = spots2;
        });
      } else {
        // 普通料仓，只处理 temp (或无标签)
        final spots = _convertToFlSpots(result.dataPoints!, 'temperature');
        setState(() {
          _temperatureData[_selectedHopperIndex] = spots;
          // 清空第二路数据
          if (_temperatureData2.containsKey(_selectedHopperIndex)) {
            _temperatureData2.remove(_selectedHopperIndex);
          }
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

    if (!mounted) return;
    if (result.success && result.hasData) {
      final weightSpots = _convertToFlSpots(result.dataPoints!, 'weight');
      final feedSpots = _convertToFlSpots(result.dataPoints!, 'feed_rate');
      setState(() {
        _hopperWeightData[_selectedHopperIndex] = weightSpots;
        _feedSpeedData[_selectedHopperIndex] = feedSpots;
      });
    } else {
      debugPrint('❌ 加载称重数据失败: ${result.error}');
    }
  }

  /// 加载回转窑能耗历史数据
  Future<void> _loadHopperEnergyData() async {
    final deviceId =
        HistoryDataService.hopperDeviceIds[_selectedHopperIndex + 1]!;

    final result = await _historyService.queryHopperEnergyHistory(
      deviceId: deviceId,
      start: _hopperChartStartTime,
      end: _hopperChartEndTime,
    );

    if (!mounted) return;
    if (result.success && result.hasData) {
      final spots = _convertToFlSpots(result.dataPoints!, 'ImpEp');
      setState(() => _hopperEnergyData[_selectedHopperIndex] = spots);
    } else {
      debugPrint('❌ 加载能耗数据失败: ${result.error}');
    }
  }

  // 🔧 [REMOVED] 前端去重逻辑已删除，改为使用后端直接计算的投料记录

  /// 🔧 [REFACTORED] 加载回转窑投料记录数据
  /// 逻辑：直接从后端查询投料记录 -> 显示在图表中（散点图）
  /// 不再进行前端计算、去重、累加等操作
  Future<void> _loadHopperFeedingData() async {
    final deviceId =
        HistoryDataService.hopperDeviceIds[_selectedHopperIndex + 1]!;

    // 1. 从后端查询投料记录（不设置聚合度，直接查询原始记录）
    final records = await _historyService.queryHopperFeedingHistory(
      deviceId: deviceId,
      start: _hopperChartStartTime,
      end: _hopperChartEndTime,
    );

    if (!mounted) return;

    // 2. 排序（确保正序）
    records.sort((a, b) => a.time.compareTo(b.time));

    debugPrint('📊 [Feeding] 后端返回投料记录: ${records.length} 条');

    // 3. 直接将投料记录转换为散点数据（每条记录显示为一个点）
    List<FlSpot> spots = [];

    if (records.isEmpty) {
      // 如果没有投料记录，检查是否有称重数据（验证是否为有效料仓）
      final weightRes = await _historyService.queryHopperWeightHistory(
        deviceId: deviceId,
        start: _hopperChartStartTime,
        end: _hopperChartEndTime,
      );

      // 只有在该设备有称重数据（说明是有效料仓）时，才显示 0 线
      if (weightRes.success &&
          weightRes.hasData &&
          weightRes.dataPoints != null &&
          weightRes.dataPoints!.isNotEmpty) {
        spots.add(
            FlSpot(_hopperChartStartTime.millisecondsSinceEpoch.toDouble(), 0));
        spots.add(
            FlSpot(_hopperChartEndTime.millisecondsSinceEpoch.toDouble(), 0));
      }
    } else {
      // 将每条投料记录转换为一个数据点
      // X轴：投料时间，Y轴：投料重量
      for (var record in records) {
        spots.add(FlSpot(
          record.time.millisecondsSinceEpoch.toDouble(),
          record.addedWeight,
        ));
      }
    }

    // 保留两位小数
    spots = spots
        .map((e) => FlSpot(e.x, double.parse(e.y.toStringAsFixed(2))))
        .toList();

    setState(() => _hopperFeedingData[_selectedHopperIndex] = spots);
  }

  // 🔧 [REMOVED] 所有前端验证、回填、删除逻辑已删除
  // 投料记录完全由后端 feeding_analysis_service_v3.py 负责生成和管理

  /// 加载辊道窑历史数据
  /// 🔧 [优化] 使用并行请求替代串行循环，大幅提升加载速度
  Future<void> _loadRollerData() async {
    // 收集所有选中温区的请求任务
    final List<Future<void>> tasks = [];

    for (int i = 0; i < 6; i++) {
      if (!_selectedRollerZones[i]) continue;
      // 每个温区的数据加载作为独立任务
      tasks.add(_loadSingleRollerZoneData(i));
    }

    // 并行执行所有温区的数据加载
    if (tasks.isNotEmpty) {
      await Future.wait(tasks);
    }
  }

  /// 加载单个辊道窑温区数据（供并行调用）
  Future<void> _loadSingleRollerZoneData(int zoneIndex) async {
    final zoneId = HistoryDataService.rollerZoneIds[zoneIndex + 1]!;

    // 并行请求温度和功率数据
    final results = await Future.wait([
      _historyService.queryRollerTemperatureHistory(
        start: _rollerChartStartTime,
        end: _rollerChartEndTime,
        zone: zoneId,
      ),
      _historyService.queryRollerPowerHistory(
        start: _rollerChartStartTime,
        end: _rollerChartEndTime,
        zone: zoneId,
      ),
    ]);

    final tempResult = results[0];
    final powerResult = results[1];

    if (!mounted) return;

    // 温度数据
    if (tempResult.success && tempResult.hasData) {
      final spots = _convertToFlSpots(tempResult.dataPoints!, 'temperature');
      setState(() => _rollerTemperatureData[zoneIndex] = spots);
    }

    // 功率和能耗数据
    if (powerResult.success && powerResult.hasData) {
      final powerSpots = _convertToFlSpots(powerResult.dataPoints!, 'Pt');
      final energySpots = _convertToFlSpots(powerResult.dataPoints!, 'ImpEp');
      setState(() {
        _rollerPowerData[zoneIndex] = powerSpots;
        _rollerEnergyData[zoneIndex] = energySpots;
      });
    }
  }

  /// 加载SCR和风机历史数据
  Future<void> _loadScrFanData() async {
    await Future.wait([
      _loadSCRData(),
      _loadFanData(),
    ]);
  }

  /// 加载当前选中的SCR设备数据 (包含水泵功率和燃气流量)
  Future<void> _loadSCRData() async {
    final index = _selectedPumpIndex;
    final deviceId = HistoryDataService.scrDeviceIds[index + 1]!;

    // 并行请求功率和燃气数据
    final results = await Future.wait([
      // 1. 功率数据
      _historyService.queryScrPowerHistory(
        deviceId: deviceId,
        start: _scrChartStartTime,
        end: _scrChartEndTime,
      ),
      // 2. 燃气数据
      _historyService.queryScrGasHistory(
        deviceId: deviceId,
        start: _scrChartStartTime,
        end: _scrChartEndTime,
      ),
    ]);

    if (!mounted) return;

    final powerResult = results[0];
    final gasResult = results[1];

    if (powerResult.success && powerResult.hasData) {
      final spots = _convertToFlSpots(powerResult.dataPoints!, 'Pt');
      setState(() => _scrPowerData[index] = spots);
    }

    if (gasResult.success && gasResult.hasData) {
      final flowSpots = _convertToFlSpots(gasResult.dataPoints!, 'flow_rate');
      final totalSpots = _convertToFlSpots(gasResult.dataPoints!, 'total_flow');
      setState(() {
        _scrGasFlowData[index] = flowSpots;
        _scrGasTotalData[index] = totalSpots;
      });
    }
  }

  /// 加载当前选中的风机设备数据 (支持多选)
  Future<void> _loadFanData() async {
    final List<Future<void>> tasks = [];

    for (int i = 0; i < _selectedFanIndexes.length; i++) {
      if (!_selectedFanIndexes[i]) continue;

      final deviceId = HistoryDataService.fanDeviceIds[i + 1]!;
      tasks.add(_historyService
          .queryFanPowerHistory(
        deviceId: deviceId,
        start: _fanChartStartTime,
        end: _fanChartEndTime,
      )
          .then((result) {
        if (!mounted) return;
        if (result.success && result.hasData) {
          final spots = _convertToFlSpots(result.dataPoints!, 'Pt');
          setState(() => _fanPowerData[i] = spots);
        }
      }));
    }

    if (tasks.isNotEmpty) {
      await Future.wait(tasks);
    }
  }

  /// 兼容旧方法名 (用于并行调用)
  Future<void> _loadSingleScrData(int index) => _loadSCRData();
  Future<void> _loadSingleFanData(int index) => _loadFanData();

  /// 将历史数据点转换为FlSpot列表
  /// 所有数值保留两位小数
  List<FlSpot> _convertToFlSpots(
      List<HistoryDataPoint> dataPoints, String field) {
    if (dataPoints.isEmpty) return [];

    // 🔧 [CRITICAL] 确保数据按时间正序排列，防止图表出现回环/多条线
    dataPoints.sort((a, b) => a.time.compareTo(b.time));

    return dataPoints.map((point) {
      // X轴：时间戳（毫秒）
      final x = point.time.millisecondsSinceEpoch.toDouble();

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

  /// 格式化时间戳为 HH:mm
  String _formatBottomTitle(double value) {
    final date = DateTime.fromMillisecondsSinceEpoch(value.toInt());
    return '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
  }

  /// 根据时间范围计算合适的X轴间隔
  double _calculateXInterval(DateTime start, DateTime end) {
    final duration = end.difference(start);
    // 目标是在X轴上显示约 6-8 个标签
    final totalMilliseconds = duration.inMilliseconds;
    final targetLabels = 6;
    final roughInterval = totalMilliseconds / targetLabels;

    // 转换为合适的时间单位（向下取整到整分/整时）
    if (roughInterval < 60000) {
      // < 1分钟
      return 10000; // 10秒
    } else if (roughInterval < 3600000) {
      // < 1小时
      // 取整到分钟 (1, 5, 10, 15, 30)
      final minutes = roughInterval / 60000;
      if (minutes <= 2) return 60000; // 1分钟
      if (minutes <= 5) return 300000; // 5分钟
      if (minutes <= 10) return 600000; // 10分钟
      if (minutes <= 15) return 900000; // 15分钟
      return 1800000; // 30分钟
    } else {
      // 取整到小时 (1, 2, 4, 6, 12)
      final hours = roughInterval / 3600000;
      if (hours <= 1) return 3600000; // 1小时
      if (hours <= 2) return 7200000; // 2小时
      if (hours <= 4) return 14400000; // 4小时
      if (hours <= 6) return 21600000; // 6小时
      return 43200000; // 12小时
    }
  }

  /// 获取回转窑设备显示名称
  /// 与实时数据页面的窑编号保持一致
  String _getHopperLabel(int index) {
    final deviceId = HistoryDataService.hopperDeviceIds[index + 1];
    if (deviceId == null) return '窑${index + 1}';

    // 映射 device_id 到实时大屏中的窑编号
    // 短窑: 7,6,5,4, 无料仓: 2,1, 长窑: 8,3,9
    const deviceToKilnNumber = {
      'short_hopper_1': 7,
      'short_hopper_2': 6,
      'short_hopper_3': 5,
      'short_hopper_4': 4,
      'no_hopper_1': 2,
      'no_hopper_2': 1,
      'long_hopper_1': 8,
      'long_hopper_2': 3,
      'long_hopper_3': 9,
    };

    final kilnNumber = deviceToKilnNumber[deviceId];
    return kilnNumber != null ? '窑$kilnNumber' : deviceId;
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
              headerActions: [
                // 1. 回转窑选择器
                SingleSelectDropdown(
                  label: '选择回转窑',
                  itemCount: 9,
                  selectedIndex: _selectedHopperIndex,
                  itemColors: _hopperColors,
                  getItemLabel: _getHopperLabel,
                  accentColor: TechColors.glowOrange,
                  compact: true,
                  onItemSelect: (index) {
                    setState(() {
                      _selectedHopperIndex = index;
                    });
                    // 切换料仓时，同时刷新所有图表的数据
                    _loadHopperTemperatureData();
                    _loadHopperWeightData();
                    _loadHopperEnergyData();
                    _loadHopperFeedingData();
                  },
                ),
                const SizedBox(width: 8),
                // 2. 快捷时间选择
                QuickTimeRangeSelector(
                  accentColor: TechColors.glowOrange,
                  onDurationSelected: (duration) =>
                      _handleQuickTimeSelect('hopper', duration),
                ),
                // 3. 时间范围选择
                TimeRangeSelector(
                  startTime: _hopperChartStartTime,
                  endTime: _hopperChartEndTime,
                  onStartTimeTap: () => _selectChartStartTime('hopper'),
                  onEndTimeTap: () => _selectChartEndTime('hopper'),
                  onCancel: () => _refreshChartData('hopper'),
                  accentColor: TechColors.glowOrange,
                  compact: true,
                ),
                // 4. 数据导出（新版）
                const SizedBox(width: 8),
                TextButton.icon(
                  icon: const Icon(Icons.file_download,
                      color: TechColors.glowOrange, size: 20),
                  label: const Text(
                    '数据导出',
                    style: TextStyle(
                      color: TechColors.glowOrange,
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  onPressed: _showDataExportDialog,
                  style: TextButton.styleFrom(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(4),
                      side: BorderSide(
                          color: TechColors.glowOrange.withOpacity(0.5)),
                    ),
                  ),
                ),
              ],
              child: Column(
                children: [
                  // 历史温度曲线（包含选择器，高度稍大）
                  Expanded(
                    flex: 4,
                    child: _buildTemperatureChart(),
                  ),
                  const SizedBox(height: 8),
                  // 🔧 能耗曲线（新增）
                  Expanded(
                    flex: 3,
                    child: _buildHopperEnergyChart(),
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
                  const SizedBox(height: 8),
                  // 🔧 投料总量曲线（新增）
                  Expanded(
                    flex: 3,
                    child: _buildHopperFeedingChart(),
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
                    headerActions: [
                      // 1. 温区多选
                      MultiSelectDropdown(
                        label: '温区',
                        itemCount: 6,
                        selectedItems: _selectedRollerZones,
                        itemColors: _rollerZoneColors,
                        getItemLabel: _getRollerZoneLabel,
                        accentColor: TechColors.glowCyan,
                        compact: true,
                        onItemToggle: (index) {
                          setState(() {
                            _selectedRollerZones[index] =
                                !_selectedRollerZones[index];
                          });
                          _loadRollerData();
                        },
                      ),
                      const SizedBox(width: 8),
                      // 2. 快捷时间
                      QuickTimeRangeSelector(
                        accentColor: TechColors.glowCyan,
                        onDurationSelected: (duration) =>
                            _handleQuickTimeSelect('roller', duration),
                      ),
                      // 3. 时间范围
                      TimeRangeSelector(
                        startTime: _rollerChartStartTime,
                        endTime: _rollerChartEndTime,
                        onStartTimeTap: () => _selectChartStartTime('roller'),
                        onEndTimeTap: () => _selectChartEndTime('roller'),
                        onCancel: () => _refreshChartData('roller'),
                        accentColor: TechColors.glowCyan,
                        compact: true,
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
                const SizedBox(height: 12),
                // 下部：SCR设备容器（2/5高度） - 拆分为两个独立的面板
                Expanded(
                  flex: 2,
                  child: Row(
                    children: [
                      // 1. SCR水泵面板
                      Expanded(
                        child: TechPanel(
                          title: 'SCR',
                          accentColor: TechColors.glowGreen,
                          headerActions: [
                            // 切换数据显示类型 (功率/燃气)
                            SingleSelectDropdown(
                              label: '指标',
                              itemCount: 2,
                              selectedIndex: _showScrGas ? 1 : 0,
                              itemColors: const [
                                TechColors.glowGreen,
                                TechColors.glowOrange
                              ],
                              getItemLabel: (i) => i == 0 ? '电表' : '燃气表',
                              accentColor: _showScrGas
                                  ? TechColors.glowOrange
                                  : TechColors.glowGreen,
                              compact: true,
                              onItemSelect: (index) {
                                setState(() => _showScrGas = index == 1);
                                _loadSCRData();
                              },
                            ),
                            const SizedBox(width: 8),
                            SingleSelectDropdown(
                              label: '设备',
                              itemCount: 2,
                              selectedIndex: _selectedPumpIndex,
                              itemColors: const [
                                TechColors.glowGreen,
                                TechColors.glowGreen
                              ],
                              getItemLabel: (i) => '设备#${i + 1}',
                              accentColor: TechColors.glowGreen,
                              compact: true,
                              onItemSelect: (index) {
                                setState(() => _selectedPumpIndex = index);
                                _loadSCRData();
                              },
                            ),
                            const SizedBox(width: 8),
                            QuickTimeRangeSelector(
                              accentColor: TechColors.glowGreen,
                              onDurationSelected: (duration) =>
                                  _handleQuickTimeSelect('scr', duration),
                            ),
                            TimeRangeSelector(
                              startTime: _scrChartStartTime,
                              endTime: _scrChartEndTime,
                              onStartTimeTap: () =>
                                  _selectChartStartTime('scr'),
                              onEndTimeTap: () => _selectChartEndTime('scr'),
                              onCancel: () => _refreshChartData('scr'),
                              accentColor: TechColors.glowGreen,
                              compact: true,
                            ),
                          ],
                          child: _showScrGas
                              ? _buildScrGasChart()
                              : _buildPumpEnergyChart(),
                        ),
                      ),
                      const SizedBox(width: 8),
                      // 2. 风机面板
                      Expanded(
                        child: TechPanel(
                          title: '风机',
                          accentColor: TechColors.glowOrange,
                          headerActions: [
                            MultiSelectDropdown(
                              label: '风机',
                              itemCount: 2,
                              selectedItems: _selectedFanIndexes,
                              itemColors: const [
                                TechColors.glowOrange,
                                TechColors.glowOrange
                              ],
                              getItemLabel: (i) => '风机#${i + 1}',
                              accentColor: TechColors.glowOrange,
                              compact: true,
                              onItemToggle: (index) {
                                setState(() => _selectedFanIndexes[index] =
                                    !_selectedFanIndexes[index]);
                                _loadFanData();
                              },
                            ),
                            const SizedBox(width: 8),
                            QuickTimeRangeSelector(
                              accentColor: TechColors.glowOrange,
                              onDurationSelected: (duration) =>
                                  _handleQuickTimeSelect('fan', duration),
                            ),
                            TimeRangeSelector(
                              startTime: _fanChartStartTime,
                              endTime: _fanChartEndTime,
                              onStartTimeTap: () =>
                                  _selectChartStartTime('fan'),
                              onEndTimeTap: () => _selectChartEndTime('fan'),
                              onCancel: () => _refreshChartData('fan'),
                              accentColor: TechColors.glowOrange,
                              compact: true,
                            ),
                          ],
                          child: _buildFanEnergyChart(),
                        ),
                      ),
                    ],
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
    // 检查是否为长料仓（索引 6, 7, 8）
    final isLongHopper = _selectedHopperIndex >= 6;

    if (isLongHopper) {
      // 长料仓：显示双曲线 (Temp1/Temp2)
      // 使用 MultiSelect 模式来渲染两条线
      return TechLineChart(
        title: '料仓温度曲线 (双区对比)',
        accentColor: TechColors.glowOrange,
        yAxisLabel: '温度(°C)',
        xAxisLabel: '',
        xInterval:
            _calculateXInterval(_hopperChartStartTime, _hopperChartEndTime),
        getBottomTitle: _formatBottomTitle,
        // 构造临时数据映射: 0->Temp1, 1->Temp2
        dataMap: {
          0: _temperatureData[_selectedHopperIndex] ?? [],
          1: _temperatureData2[_selectedHopperIndex] ?? []
        },
        isSingleSelect: false,
        // 默认全选
        selectedItems: const [true, true],
        // 即使点击切换也不改变状态（始终显示两条）
        onItemToggle: (index) {},
        itemColors: const [TechColors.glowOrange, TechColors.glowCyan],
        itemCount: 2,
        getItemLabel: (index) => index == 0 ? '温度1' : '温度2',
        selectorLabel: '温度探头',
        showSelector: true, // 显示图例
        compact: true,
      );
    }

    return TechLineChart(
      title: '料仓温度曲线',
      accentColor: TechColors.glowOrange,
      yAxisLabel: '温度(°C)',
      xAxisLabel: '',
      xInterval:
          _calculateXInterval(_hopperChartStartTime, _hopperChartEndTime),
      getBottomTitle: _formatBottomTitle,
      dataMap: _temperatureData,
      isSingleSelect: true,
      selectedIndex: _selectedHopperIndex,
      itemColors: _hopperColors,
      itemCount: 9,
      getItemLabel: _getHopperLabel,
      selectorLabel: '选择回转窑',
      showSelector: false,
      onItemSelect: (index) {},
    );
  }

  /// 下料速度曲线图（不显示选择器，与温度图共用选择器）
  Widget _buildFeedSpeedChart() {
    return TechLineChart(
      title: '下料速度曲线',
      accentColor: TechColors.glowCyan,
      yAxisLabel: '速度(kg/s)',
      xAxisLabel: '',
      xInterval:
          _calculateXInterval(_hopperChartStartTime, _hopperChartEndTime),
      getBottomTitle: _formatBottomTitle,
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
      xAxisLabel: '',
      xInterval:
          _calculateXInterval(_hopperChartStartTime, _hopperChartEndTime),
      getBottomTitle: _formatBottomTitle,
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

  /// 🔧 料仓能耗曲线图（不显示选择器，与温度图共用选择器）
  Widget _buildHopperEnergyChart() {
    return TechLineChart(
      title: '能耗历史 (kWh)',
      accentColor: TechColors.glowOrange,
      yAxisLabel: '能耗(kWh)',
      xAxisLabel: '',
      xInterval:
          _calculateXInterval(_hopperChartStartTime, _hopperChartEndTime),
      getBottomTitle: _formatBottomTitle,
      dataMap: _hopperEnergyData,
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

  /// 🔧 [REFACTORED] 投料记录散点图（显示每次投料事件）
  /// 改为散点图模式，每个点代表一次投料事件
  Widget _buildHopperFeedingChart() {
    return TechLineChart(
      title: '投料记录 (kg)',
      accentColor: TechColors.glowGreen,
      yAxisLabel: '投料重量(kg)',
      xAxisLabel: '',
      xInterval:
          _calculateXInterval(_hopperChartStartTime, _hopperChartEndTime),
      getBottomTitle: _formatBottomTitle,
      dataMap: _hopperFeedingData,
      isSingleSelect: true,
      selectedIndex: _selectedHopperIndex,
      itemColors: _hopperColors,
      itemCount: 9,
      getItemLabel: _getHopperLabel,
      selectorLabel: '选择回转窑',
      showSelector: false,
      isCurved: false, // 直线连接
      onItemSelect: (index) {},
    );
  }

  /// 辊道窑温度曲线图（不显示选择器，与功率图共用选择器）
  Widget _buildRollerTemperatureChart() {
    return TechLineChart(
      title: '辊道窑温度曲线',
      accentColor: TechColors.glowCyan,
      yAxisLabel: '温度(°C)',
      xAxisLabel: '',
      xInterval:
          _calculateXInterval(_rollerChartStartTime, _rollerChartEndTime),
      getBottomTitle: _formatBottomTitle,
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
      xAxisLabel: '',
      xInterval:
          _calculateXInterval(_rollerChartStartTime, _rollerChartEndTime),
      getBottomTitle: _formatBottomTitle,
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
      xAxisLabel: '',
      xInterval:
          _calculateXInterval(_rollerChartStartTime, _rollerChartEndTime),
      getBottomTitle: _formatBottomTitle,
      dataMap: _rollerPowerData,
      selectedItems: _selectedRollerZones,
      itemColors: _rollerZoneColors,
      itemCount: 6,
      getItemLabel: _getRollerZoneLabel,
      selectorLabel: '选择分区',
      showSelector: false,
      onItemToggle: (index) {},
    );
  }

  /// SCR功率曲线图
  Widget _buildPumpEnergyChart() {
    // 将单选索引转换为 List<bool> 供 TechBarChart 使用
    final selectedItems = List.generate(2, (i) => i == _selectedPumpIndex);

    return TechBarChart(
      title: 'SCR功率曲线',
      accentColor: TechColors.glowGreen,
      yAxisLabel: '功率(kW)',
      xAxisLabel: '',
      xInterval: _calculateXInterval(_scrChartStartTime, _scrChartEndTime),
      getBottomTitle: _formatBottomTitle,
      dataMap: _scrPowerData,
      selectedItems: selectedItems,
      itemColors: _deviceColors,
      itemCount: 2,
      getItemLabel: (index) => 'SCR ${index + 1}',
      selectorLabel: '选择SCR',
      showSelector: false,
      onItemToggle: (index) {},
    );
  }

  /// SCR燃气流量曲线图
  Widget _buildScrGasChart() {
    // 燃气图只显示当前选中的SCR设备
    // 我们可以显示两条线：流量(flow_rate) 和 累计(total_flow，但累计值通常很大，和流量放一起不好看)
    // 既然用户说是"流量和流速"，也许只是flow_rate。
    // 如果要同时显示，可能需要双Y轴（fl_chart支持不好）
    // 或者仅仅显示flow_rate。
    // 这里我们先显示流量曲线。

    // 构造临时Map显示当前设备的流量
    final Map<int, List<FlSpot>> dataMap = {
      0: _scrGasFlowData[_selectedPumpIndex] ?? [],
    };

    return TechLineChart(
      title: 'SCR燃气流量 (m³/h)',
      accentColor: TechColors.glowOrange,
      yAxisLabel: '流量(m³/h)',
      xAxisLabel: '',
      xInterval: _calculateXInterval(_scrChartStartTime, _scrChartEndTime),
      getBottomTitle: _formatBottomTitle,
      dataMap: dataMap,
      selectedItems: const [true],
      itemColors: const [TechColors.glowOrange],
      itemCount: 1,
      getItemLabel: (index) => '流量',
      selectorLabel: '指标',
      showSelector: false,
      onItemToggle: (index) {},
    );
  }

  /// 风机功率曲线图 (多选)
  Widget _buildFanEnergyChart() {
    return TechLineChart(
      // 改为 LineChart 以支持多曲线对比
      title: '风机功率曲线',
      accentColor: TechColors.glowGreen,
      yAxisLabel: '功率(kW)',
      xAxisLabel: '',
      xInterval: _calculateXInterval(_fanChartStartTime, _fanChartEndTime),
      getBottomTitle: _formatBottomTitle,
      dataMap: _fanPowerData,
      selectedItems: _selectedFanIndexes,
      itemColors: _deviceColors,
      itemCount: 2,
      getItemLabel: (index) => '风机${index + 1}:表${index == 0 ? 64 : 65}',
      selectorLabel: '选择风机',
      showSelector: false, // 外部控制，这里不显示内部选择器
      onItemToggle: (index) {},
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
      case 'scr':
        return TechColors.glowOrange;
      case 'fan':
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
      case 'scr':
        return _scrChartStartTime;
      case 'fan':
        return _fanChartStartTime;
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
      case 'scr':
        _scrChartStartTime = time;
        break;
      case 'fan':
        _fanChartStartTime = time;
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
      case 'scr':
        return _scrChartEndTime;
      case 'fan':
        return _fanChartEndTime;
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
      case 'scr':
        _scrChartEndTime = time;
        break;
      case 'fan':
        _fanChartEndTime = time;
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
      // 回转窑：同时刷新温度、称重、能耗和投料数据
      _loadHopperTemperatureData();
      _loadHopperWeightData();
      _loadHopperEnergyData(); // 🔧 新增能耗数据加载
      _loadHopperFeedingData(); // 🔧 新增投料数据加载
    } else if (chartType == 'roller') {
      // 辊道窑：刷新所有温区数据
      _loadRollerData();
    } else if (chartType == 'scr') {
      _loadSCRData();
    } else if (chartType == 'fan') {
      _loadFanData();
    }
  }
}

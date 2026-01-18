import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'dart:io';
import 'package:excel/excel.dart' hide Border;
import 'package:intl/intl.dart';
import 'package:path/path.dart' as p;
import '../widgets/data_display/data_tech_line_widgets.dart';
import '../widgets/data_display/data_time_range_selector.dart';
import '../widgets/data_display/data_tech_line_chart.dart';
import '../widgets/data_display/data_tech_bar_chart.dart';
import '../widgets/data_display/quick_time_range_selector.dart';
import '../widgets/data_display/data_single_select_dropdown.dart';
import '../widgets/data_display/data_multi_select_dropdown.dart';
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

  /// 导出回转窑报表
  Future<void> _exportHopperReport() async {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('正在生成回转窑报表...')),
    );

    try {
      final rows = <List<dynamic>>[];
      // 表头
      rows.add([
        '窑编号',
        '起始时间',
        '终止时间',
        '最初能耗(kWh)',
        '最后能耗(kWh)',
        '能耗消耗(kWh)',
        '投料总量(kg)'
      ]);

      final start = _hopperChartStartTime;
      final end = _hopperChartEndTime;
      final dateFormat = DateFormat('yyyy-MM-dd HH:mm:ss');

      // 遍历 1-9 号窑
      for (int i = 1; i <= 9; i++) {
        final deviceId = HistoryDataService.hopperDeviceIds[i]!;
        final kilnName = _getHopperLabel(i - 1);

        // 1. 获取能耗数据
        final energyRes = await _historyService.queryHopperEnergyHistory(
          deviceId: deviceId,
          start: start,
          end: end,
        );

        double firstEnergy = 0.0;
        double lastEnergy = 0.0;
        double consumption = 0.0;

        if (energyRes.success &&
            energyRes.hasData &&
            energyRes.dataPoints != null &&
            energyRes.dataPoints!.isNotEmpty) {
          final points = energyRes.dataPoints!;
          // 假设点按时间排序
          firstEnergy =
              (points.first.fields['ImpEp'] as num?)?.toDouble() ?? 0.0;
          lastEnergy = (points.last.fields['ImpEp'] as num?)?.toDouble() ?? 0.0;
          consumption = lastEnergy - firstEnergy;
          if (consumption < 0) consumption = 0.0;
        }

        // 2. 获取投料数据
        final feedingRecs = await _historyService.queryHopperFeedingHistory(
          deviceId: deviceId,
          start: start,
          end: end,
        );

        double totalFeeding = 0.0;
        for (var rec in feedingRecs) {
          totalFeeding += rec.addedWeight;
        }

        rows.add([
          kilnName,
          dateFormat.format(start),
          dateFormat.format(end),
          firstEnergy.toStringAsFixed(2),
          lastEnergy.toStringAsFixed(2),
          consumption.toStringAsFixed(2),
          totalFeeding.toStringAsFixed(2),
        ]);
      }

      // 3. 生成 Excel
      var excelObj = Excel.createExcel();
      Sheet sheet = excelObj['Sheet1'];

      // 添加行
      for (var row in rows) {
        List<CellValue> cellValues =
            row.map((e) => TextCellValue(e.toString())).toList();
        sheet.appendRow(cellValues);
      }

      // 设置列宽
      for (int i = 0; i < 7; i++) {
        sheet.setColumnWidth(i, 20.0);
      }

      // 4. 保存文件
      String desktopPath;
      // 优先尝试获取 USERPROFILE (Windows通常有效)
      final userProfile = Platform.environment['USERPROFILE'];
      if (Platform.isWindows && userProfile != null) {
        desktopPath = p.join(userProfile, 'Desktop');
      } else {
        // 后备路径
        desktopPath = Directory.current.path;
      }

      // 确保目录存在
      if (!Directory(desktopPath).existsSync()) {
        // 如果 USERPROFILE\Desktop 不存在，尝试硬编码路径 (仅作最后的尝试)
        if (Platform.isWindows) {
          final hardcoded = r'C:\Users\Admin\Desktop';
          if (Directory(hardcoded).existsSync()) {
            desktopPath = hardcoded;
          }
        }
      }

      final timestamp = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
      final filename = '回转窑报表_$timestamp.xlsx';
      final savePath = p.join(desktopPath, filename);

      final bytes = excelObj.encode();
      if (bytes != null) {
        File(savePath)
          ..createSync(recursive: true)
          ..writeAsBytesSync(bytes);

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('已导出到: $savePath'),
              duration: const Duration(seconds: 5),
            ),
          );
        }
      }
    } catch (e) {
      debugPrint('Export failed: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('导出失败: $e')),
        );
      }
    }
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

  /// 🔧 [FIX] 投料记录去重过滤器
  /// 同一投料周期内（120分钟）的多条记录只保留第一条
  /// 解决后端产生重复记录导致累计值虚高的问题
  List<FeedingRecord> _deduplicateFeedingRecords(List<FeedingRecord> records) {
    if (records.isEmpty) return records;

    // 🔧 [CRITICAL] 去重窗口改为 120 分钟
    // 原因：投料过程可能持续 30-60 分钟，后端在这期间可能产生多条记录
    // 60分钟的窗口不够，比如 23:30 和 00:30 相差正好 60 分钟，会被误判为两次投料
    const int dedupeWindowMins = 120;
    List<FeedingRecord> result = [];
    DateTime? lastAcceptedTime;

    for (var record in records) {
      if (lastAcceptedTime == null) {
        // 第一条记录直接接受
        result.add(record);
        lastAcceptedTime = record.time;
      } else {
        // 检查与上一条接受记录的时间差
        final diffMins =
            record.time.difference(lastAcceptedTime).inMinutes.abs();
        if (diffMins >= dedupeWindowMins) {
          // 超过窗口，视为新的投料事件
          result.add(record);
          lastAcceptedTime = record.time;
        } else {
          // 在窗口内，视为重复，跳过
          debugPrint('🔄 [Dedupe] 跳过重复记录: ${record.time} (距上一条 ${diffMins}分钟)');
        }
      }
    }

    return result;
  }

  /// 加载回转窑投料累计数据
  /// 逻辑：获取投料事件 -> 去重过滤 -> 按时间累加 -> 生成阶梯图数据
  Future<void> _loadHopperFeedingData() async {
    final deviceId =
        HistoryDataService.hopperDeviceIds[_selectedHopperIndex + 1]!;

    // 1. 获取原始记录
    final records = await _historyService.queryHopperFeedingHistory(
      deviceId: deviceId,
      start: _hopperChartStartTime,
      end: _hopperChartEndTime,
    );

    if (!mounted) return;

    // 2. 排序（确保正序）
    records.sort((a, b) => a.time.compareTo(b.time));

    // 🔧 [FIX] 前端去重过滤：同一小时内的多条记录只保留第一条
    // 解决后端产生重复记录导致累计值虚高的问题
    final deduplicatedRecords = _deduplicateFeedingRecords(records);
    debugPrint(
        '📊 [Feeding] 原始记录: ${records.length}, 去重后: ${deduplicatedRecords.length}');

    List<FlSpot> spots = [];
    double cumulativeWeight = 0;

    // 起点：时间范围开始时，累计量默认为 0
    // spots.add(FlSpot(_hopperChartStartTime.millisecondsSinceEpoch.toDouble(), 0));

    // 如果数据点很少，为了画出漂亮的阶梯线，可以在每个点之前插一个点（维持上一个值）
    // 或者直接画折线图（TechLineChart 默认是直线连接）。
    // 用户需求是 "投料总量的变化"，所以直接连接点即可。

    // 如果没有数据，显示一条 0 线 (前提是该设备必须有称重数据，即确实是"有料仓"的)
    if (records.isEmpty) {
      // 检查是否有称重数据（验证是否为有效料仓）
      final weightRes = await _historyService.queryHopperWeightHistory(
        deviceId: deviceId,
        start: _hopperChartStartTime,
        end: _hopperChartEndTime,
      );

      // 只有在该设备有称重数据（说明是有效料仓）时，才显示 0 线
      // 否则保持 spots 为空（即不显示曲线）
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
      // 遍历事件进行累加（使用去重后的记录）
      // 为了让图表从左到右连贯，我们假设起点是0
      // 如果第一个事件发生在中间，那么前面都是0
      if (deduplicatedRecords.first.time.isAfter(_hopperChartStartTime)) {
        spots.add(
            FlSpot(_hopperChartStartTime.millisecondsSinceEpoch.toDouble(), 0));
      }

      for (var record in deduplicatedRecords) {
        // 累加（使用去重后的记录）
        cumulativeWeight += record.addedWeight;
        spots.add(FlSpot(
            record.time.millisecondsSinceEpoch.toDouble(), cumulativeWeight));
      }

      // 延伸到结束时间（保持最后一个累计值）
      if (deduplicatedRecords.last.time.isBefore(_hopperChartEndTime)) {
        spots.add(FlSpot(_hopperChartEndTime.millisecondsSinceEpoch.toDouble(),
            cumulativeWeight));
      }
    }

    // 保留两位小数
    spots = spots
        .map((e) => FlSpot(e.x, double.parse(e.y.toStringAsFixed(2))))
        .toList();

    setState(() => _hopperFeedingData[_selectedHopperIndex] = spots);

    // 🔧 [Fail-Safe] 前端双重验证：回填遗漏 + 删除多余
    // 仅在查看范围接近 24 小时（即"最近1天"）时触发
    final duration = _hopperChartEndTime.difference(_hopperChartStartTime);
    if (duration.inHours >= 23 && duration.inHours <= 25) {
      // 异步执行，不阻塞 UI
      _verifySyncFeedingData(deviceId, records);
    }
  }

  /// [Fail-Safe] 验证并同步投料记录（双向同步：回填 + 删除）
  Future<void> _verifySyncFeedingData(
      String deviceId, List<FeedingRecord> backendRecords) async {
    try {
      // 1. 获取原始称重数据
      final points = await _fetchRawWeightData(deviceId);
      if (points == null || points.isEmpty) return;

      // 2. 本地重新计算理想的投料事件
      final localEvents = _detectLocalFeedingEvents(points);

      // 3. 执行删除逻辑 (Backend有但Local无)
      await _cleanupExtraFeedings(deviceId, backendRecords, localEvents);

      // 4. 执行回填逻辑 (Local有但Backend无)
      // 注意：传入最新的 backendRecords (如果刚才删除了应该排除，但简化起见用原列表也行，
      // 因为已删除的在_cleanupExtraFeedings里处理了，这里主要看Backend缺少的)
      await _backfillMissingFeedings(deviceId, localEvents, backendRecords);
    } catch (e) {
      debugPrint('⚠️ [Fail-Safe] 验证逻辑异常: $e');
    }
  }

  /// 本地检测投料事件 (纯前端算法)
  List<Map<String, dynamic>> _detectLocalFeedingEvents(
      List<HistoryDataPoint> points) {
    const double threshold = 10.0;
    // 🔧 [FIX] 增大防抖时间到 60分钟 (解决 interval=30m 时连续两个点被识别为两次投料的问题)
    const int debounceMins = 60;

    List<Map<String, dynamic>> events = [];
    DateTime? lastTriggerTime;

    // 从索引1开始，如果索引0就是高值(400)，因为没有prev，自然不会触发 diff > 10
    // 除非 points[0]=0, points[1]=400。
    // 如果 points[0]=400，points[1]=399 -> diff = -1，不会触发。
    // 所以只要确保不把"缺少前值"的情况当做0处理即可。
    // _fetchRawWeightData 返回的是真实数据点，不包含补0点。

    for (int i = 1; i < points.length; i++) {
      // [关键] 忽略开头的前几个点，避免因为图表截断导致的"假上升"
      // 比如数据是从昨天23:59开始的，如果刚巧在投料中，可能会被截断。
      // 但通常我们不希望处理图表边缘的不完整事件。
      if (i < 3) continue;

      final prev = (points[i - 1].fields['weight'] as num?)?.toDouble() ?? 0.0;
      final curr = (points[i].fields['weight'] as num?)?.toDouble() ?? 0.0;

      // 过滤无效数据 (0值通常是采集错误)
      if (prev < 1.0 || curr < 1.0) continue;

      final diff = curr - prev;

      if (diff > threshold) {
        final eventTime = points[i].time;

        // 防抖
        // 🔧 [FIX] 这里使用 < debounceMins，如果 interval是30m，30 < 30是false，防抖失效
        // 现在 debounceMins 改为 60 了，30 < 60 是true，防抖生效。
        final actualEventTime =
            points[i - 1].time; // [FIX] 使用 i-1 (上升开始点) 作为事件时间
        if (lastTriggerTime != null &&
            actualEventTime.difference(lastTriggerTime).inMinutes <
                debounceMins) {
          // 如果在防抖期内，忽略这次触发，但更新 lastTriggerTime 吗？
          // 不，不更新 lastTriggerTime，因为我们要以"第一次触发"的时间为准
          continue;
        }

        events.add({
          'time': actualEventTime,
          'weight': diff, // 粗略估算，主要用于时间匹配
        });
        lastTriggerTime = actualEventTime;

        debugPrint(
            '🔍 [Local Detect] 发现投料事件: Time=$actualEventTime, Diff=${diff.toStringAsFixed(1)}');
      }
    }

    debugPrint(
        '📊 [Local Detect] 本地共检测到 ${events.length} 个投料事件: ${events.map((e) => e['time']).toList()}');
    return events;
  }

  /// 清理多余的投料记录 (Backend 有，但 Local 没检测到)
  Future<void> _cleanupExtraFeedings(
    String deviceId,
    List<FeedingRecord> backendRecords,
    List<Map<String, dynamic>> localEvents,
  ) async {
    const int matchWindowMins = 30; // [FIX] 匹配窗口扩大到 +/- 30分钟
    debugPrint(
        '🧹 [Cleanup Task] 开始比对: LocalEvents=${localEvents.length}, BackendRecords=${backendRecords.length}');

    for (var record in backendRecords) {
      // 检查这个 record 是否能匹配上任意一个 local event
      bool isMatched = localEvents.any((local) {
        final timeDiff =
            record.time.difference(local['time'] as DateTime).inMinutes.abs();
        return timeDiff <= matchWindowMins;
      });

      if (!isMatched) {
        // [关键] 未匹配上，认为是多余/错误的记录
        // 但是要做一个保护：如果 backend record 的 added_weight 很小（比如 < 10），
        // 或者它发生在图表边缘（Local检测不到），则谨慎删除。
        // 这里我们假设 Local 算法足够鲁棒。

        // 保护：不要删除最近 1 小时内的记录（可能还在生成中）
        if (DateTime.now().difference(record.time).inMinutes < 60) continue;

        debugPrint(
            '🗑️ [Fail-Safe] 发现多余投料记录，删除: ID=$deviceId, Time=${record.time}');
        final success =
            await _historyService.deleteFeedingRecord(deviceId, record.time);

        // 🔧 [Fail-Safe] 电路熔断：如果删除失败（可能是后端不支持或网络问题），
        // 立即停止后续删除操作，防止死循环刷日志
        if (!success) {
          debugPrint('⚠️ [Fail-Safe] 删除操作失败，触发熔断，停止本次清理任务');
          break;
        }
      }
    }
  }

  /// 回填缺失的投料记录 (Local 有，但 Backend 无)
  Future<void> _backfillMissingFeedings(
    String deviceId,
    List<Map<String, dynamic>> localEvents,
    List<FeedingRecord> backendRecords,
  ) async {
    const int matchWindowMins = 30; // [FIX] 回填逻辑也同步使用 +/- 30分钟窗口

    for (var local in localEvents) {
      final localTime = local['time'] as DateTime;

      bool isRecorded = backendRecords.any((backend) {
        final timeDiff = backend.time.difference(localTime).inMinutes.abs();
        return timeDiff <= matchWindowMins;
      });

      if (!isRecorded) {
        final weight = local['weight'] as double;
        debugPrint(
            '🛡️ [Fail-Safe] 发现遗漏投料记录，回填: ID=$deviceId, Time=$localTime');

        await _historyService.backfillFeedingRecord(
          deviceId,
          {
            'time': localTime.toUtc().toIso8601String(),
            'added_weight': weight,
          },
        );
      }
    }
  }

  /// 获取原始称重数据（已排序）
  Future<List<HistoryDataPoint>?> _fetchRawWeightData(String deviceId) async {
    final result = await _historyService.queryHopperWeightHistory(
      deviceId: deviceId,
      start: _hopperChartStartTime,
      end: _hopperChartEndTime,
    );

    if (!result.success || !result.hasData || result.dataPoints == null) {
      return null;
    }

    final points = result.dataPoints!;
    points.sort((a, b) => a.time.compareTo(b.time));
    return points;
  }

  /// 检测投料事件并回填遗漏记录 (已废弃，由 _verifySyncFeedingData 替代)
  // Future<void> _detectAndBackfillMissingFeedings ... (Deleted)

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
                // 4. 导出报表
                const SizedBox(width: 8),
                IconButton(
                  icon:
                      const Icon(Icons.download, color: TechColors.glowOrange),
                  tooltip: '导出报表',
                  onPressed: _exportHopperReport,
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
                          title: 'SCR设备',
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

  /// 🔧 投料累计曲线图
  Widget _buildHopperFeedingChart() {
    return TechLineChart(
      title: '投料累计 (kg)',
      accentColor: TechColors.glowGreen,
      yAxisLabel: '投料总量(kg)',
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

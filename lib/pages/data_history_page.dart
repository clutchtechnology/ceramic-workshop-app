import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:fl_chart/fl_chart.dart';
import 'dart:io';
import 'package:excel/excel.dart' hide Border;
import '../utils/app_logger.dart';
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
import '../services/data_export_service.dart';
import '../utils/device_name_mapper.dart';

/// 历史数据页面（回转窑、辊道窑、SCR + 风机）
class HistoryDataPage extends StatefulWidget {
  const HistoryDataPage({super.key});

  @override
  HistoryDataPageState createState() => HistoryDataPageState();
}

/// 公开 State 类以便通过 GlobalKey 访问
class HistoryDataPageState extends State<HistoryDataPage>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  final HistoryDataService _historyService = HistoryDataService();
  bool _isLoading = true;

  static const Duration _refreshDebounceInterval = Duration(seconds: 10);

  DateTime? _lastRefreshTime;

  // [CRITICAL] 代际计数器 - 防止页面切换后旧请求的 setState 覆盖新数据
  int _loadGeneration = 0;
  // [CRITICAL] 加载互斥锁 - 防止多次加载重叠执行
  bool _isLoadingInProgress = false;

  // 各设备图表时间范围
  late DateTime _hopperChartStartTime;
  late DateTime _hopperChartEndTime;
  late DateTime _rollerChartStartTime;
  late DateTime _rollerChartEndTime;
  late DateTime _scrChartStartTime;
  late DateTime _scrChartEndTime;
  late DateTime _fanChartStartTime;
  late DateTime _fanChartEndTime;

  // 设备选择状态
  int _selectedHopperIndex = 0;
  List<bool> _selectedRollerZones = List.generate(6, (_) => true);
  int _selectedPumpIndex = 0;
  List<bool> _selectedFanIndexes = [true, false];

  // 图表数据
  final Map<int, List<FlSpot>> _temperatureData = {};
  final Map<int, List<FlSpot>> _temperatureData2 = {}; // 长料仓双温区
  final Map<int, List<FlSpot>> _feedSpeedData = {};
  final Map<int, List<FlSpot>> _hopperWeightData = {};
  final Map<int, List<FlSpot>> _hopperEnergyData = {};
  final Map<int, List<FlSpot>> _hopperFeedingData = {};
  final Map<int, List<FlSpot>> _rollerTemperatureData = {};
  final Map<int, List<FlSpot>> _rollerEnergyData = {};
  final Map<int, List<FlSpot>> _rollerPowerData = {};
  final Map<int, List<FlSpot>> _scrPowerData = {};
  final Map<int, List<FlSpot>> _scrGasFlowData = {};
  final Map<int, List<FlSpot>> _scrGasTotalData = {};
  final Map<int, List<FlSpot>> _fanPowerData = {};

  bool _showScrGas = false;

  // 设备颜色
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
    _refreshHistoryDataWithDebounce(forceRefresh: true);
  }

  @override
  void dispose() {
    super.dispose();
  }

  /// 页面进入时调用（由父组件调用），防抖10秒
  void onPageEnter() {
    _refreshHistoryDataWithDebounce();
  }

  /// 防抖刷新，[forceRefresh] 忽略防抖间隔
  void _refreshHistoryDataWithDebounce({bool forceRefresh = false}) {
    final now = DateTime.now();
    final shouldRefresh = forceRefresh ||
        _lastRefreshTime == null ||
        now.difference(_lastRefreshTime!) > _refreshDebounceInterval;

    if (shouldRefresh) {
      _lastRefreshTime = now;
      _initializeTimeRangesAndLoadData();
    }
  }

  /// 初始化所有图表时间范围：当前本地时间往前24h
  void _initializeTimeRanges() {
    final DateTime end = DateTime.now();
    final DateTime start = end.subtract(const Duration(hours: 24));

    _hopperChartStartTime =
        _rollerChartStartTime = _scrChartStartTime = _fanChartStartTime = start;
    _hopperChartEndTime =
        _rollerChartEndTime = _scrChartEndTime = _fanChartEndTime = end;
  }

  Future<void> _initializeTimeRangesAndLoadData() async {
    _initializeTimeRanges();
    await _loadAllHistoryData();
  }

  /// 加载所有历史数据
  Future<void> _loadAllHistoryData() async {
    if (!mounted) return;

    // [CRITICAL] 如果上一批请求还在执行，递增 generation 使其丢弃结果，但不重复发起
    if (_isLoadingInProgress) {
      _loadGeneration++;
      return;
    }

    _isLoadingInProgress = true;
    _loadGeneration++;
    final currentGen = _loadGeneration;

    setState(() => _isLoading = true);

    try {
      // 分 2 批加载，每批 3 个任务，避免同时发起 ~21 个 HTTP 请求
      // 第 1 批：回转窑数据
      await Future.wait([
        _loadHopperTemperatureData(),
        _loadHopperWeightData(),
        _loadHopperEnergyData(),
      ]).timeout(const Duration(seconds: 15));

      // [CRITICAL] 检查代际 - 如果已经有新的加载请求，丢弃本次结果
      if (!mounted || currentGen != _loadGeneration) return;

      // 第 2 批：投料 + 辊道窑 + SCR/风机
      await Future.wait([
        _loadHopperFeedingData(),
        _loadRollerData(),
        _loadScrFanData(),
      ]).timeout(const Duration(seconds: 15));
    } catch (e) {
      logger.error('加载历史数据超时或失败', e);
    } finally {
      _isLoadingInProgress = false;
    }

    if (mounted && currentGen == _loadGeneration) {
      setState(() => _isLoading = false);
    }
  }

  void _handleQuickTimeSelect(String chartType, Duration duration) {
    setState(() {
      final end = DateTime.now();
      _setChartStartTime(chartType, end.subtract(duration));
      _setChartEndTime(chartType, end);
      _refreshChartData(chartType);
    });
  }

  /// 显示数据导出弹窗
  Future<void> _showExportDatePicker() async {
    // 默认选择最近7天
    DateTime startDate = DateTime.now().subtract(const Duration(days: 7));
    DateTime endDate = DateTime.now();
    int selectedQuickDays = 7; // 快捷选择天数
    String selectedExportType = 'runtime'; // 导出类型

    // 导出类型定义
    final exportTypes = [
      {
        'value': 'runtime',
        'label': '设备运行时长',
        'desc': '导出所有设备(回转窑、辊道窑、SCR、风机)的设备运行时长',
      },
      {
        'value': 'gas',
        'label': '燃气用量',
        'desc': '导出SCR燃气表的燃气用量统计',
      },
      {
        'value': 'feeding',
        'label': '投料量统计',
        'desc': '导出带料仓回转窑(窑7,6,5,4,8,3,9)的投料量统计',
      },
      {
        'value': 'electricity',
        'label': '用电量',
        'desc': '导出所有设备(回转窑、辊道窑、SCR、风机)的电量消耗统计',
      },
      {
        'value': 'comprehensive',
        'label': '全部数据',
        'desc': '导出所有设备的全部数据(电量+运行时长+燃气+投料)',
      },
    ];

    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      barrierDismissible: true,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            final dateFormat = DateFormat('yyyy-MM-dd HH:mm');

            // 快捷天数按钮
            Widget quickDayButton(int days, String label) {
              final isSelected = selectedQuickDays == days;
              return GestureDetector(
                onTap: () {
                  setDialogState(() {
                    selectedQuickDays = days;
                    endDate = DateTime.now();
                    startDate = endDate.subtract(Duration(days: days));
                  });
                },
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? TechColors.glowCyan.withValues(alpha: 0.15)
                        : Colors.transparent,
                    border: Border.all(
                      color: isSelected
                          ? TechColors.glowCyan
                          : TechColors.borderDark,
                      width: isSelected ? 1.5 : 1.0,
                    ),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    label,
                    style: TextStyle(
                      color: isSelected
                          ? TechColors.glowCyan
                          : TechColors.textSecondary,
                      fontSize: 13,
                      fontWeight:
                          isSelected ? FontWeight.w600 : FontWeight.normal,
                    ),
                  ),
                ),
              );
            }

            // 时间显示卡片
            Widget timeCard(String title, DateTime time, bool isStart) {
              return Expanded(
                child: GestureDetector(
                  onTap: () async {
                    final pickedDate = await showDatePicker(
                      context: context,
                      initialDate: time,
                      firstDate: DateTime(2024),
                      lastDate: DateTime.now(),
                      builder: (context, child) {
                        return Theme(
                          data: ThemeData.dark().copyWith(
                            colorScheme: const ColorScheme.dark(
                              primary: TechColors.glowCyan,
                              surface: TechColors.bgDark,
                            ),
                          ),
                          child: child!,
                        );
                      },
                    );
                    if (pickedDate != null) {
                      // 选择时间
                      final pickedTime = await showTimePicker(
                        context: context,
                        initialTime: TimeOfDay.fromDateTime(time),
                        builder: (context, child) {
                          return Theme(
                            data: ThemeData.dark().copyWith(
                              colorScheme: const ColorScheme.dark(
                                primary: TechColors.glowCyan,
                                surface: TechColors.bgDark,
                              ),
                            ),
                            child: child!,
                          );
                        },
                      );
                      setDialogState(() {
                        final newTime = DateTime(
                          pickedDate.year,
                          pickedDate.month,
                          pickedDate.day,
                          pickedTime?.hour ?? time.hour,
                          pickedTime?.minute ?? time.minute,
                        );
                        if (isStart) {
                          startDate = newTime;
                        } else {
                          endDate = newTime;
                        }
                        selectedQuickDays = -1; // 取消快捷选择
                      });
                    }
                  },
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: TechColors.bgMedium,
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: TechColors.borderDark),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: const TextStyle(
                            color: TechColors.textSecondary,
                            fontSize: 12,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            const Icon(Icons.calendar_today,
                                color: TechColors.glowCyan, size: 14),
                            const SizedBox(width: 6),
                            Text(
                              dateFormat.format(time),
                              style: const TextStyle(
                                color: TechColors.glowCyan,
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }

            return Dialog(
              backgroundColor: TechColors.bgDark,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
                side: const BorderSide(color: TechColors.borderDark),
              ),
              child: Container(
                width: 520,
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 标题栏
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Container(
                              width: 3,
                              height: 20,
                              color: TechColors.glowCyan,
                            ),
                            const SizedBox(width: 8),
                            const Text(
                              '数据导出',
                              style: TextStyle(
                                color: TechColors.textPrimary,
                                fontSize: 18,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                        GestureDetector(
                          onTap: () => Navigator.pop(context),
                          child: const Icon(Icons.close,
                              color: TechColors.textSecondary, size: 20),
                        ),
                      ],
                    ),

                    const SizedBox(height: 20),

                    // 时间范围标题
                    Row(
                      children: [
                        Container(
                          width: 3,
                          height: 14,
                          color: TechColors.glowCyan,
                        ),
                        const SizedBox(width: 6),
                        const Text(
                          '时间范围',
                          style: TextStyle(
                            color: TechColors.textPrimary,
                            fontSize: 15,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 12),

                    // 快捷时间选择按钮
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        quickDayButton(1, '最近 1 天'),
                        quickDayButton(3, '最近 3 天'),
                        quickDayButton(5, '最近 5 天'),
                        quickDayButton(7, '最近 7 天'),
                        quickDayButton(30, '最近 30 天'),
                      ],
                    ),

                    const SizedBox(height: 16),

                    // 开始时间 -> 结束时间
                    Row(
                      children: [
                        timeCard('开始时间', startDate, true),
                        const Padding(
                          padding: EdgeInsets.symmetric(horizontal: 8),
                          child: Icon(Icons.arrow_forward,
                              color: TechColors.textSecondary, size: 16),
                        ),
                        timeCard('结束时间', endDate, false),
                      ],
                    ),

                    const SizedBox(height: 20),

                    // 导出类型标题
                    Row(
                      children: [
                        Container(
                          width: 3,
                          height: 14,
                          color: TechColors.glowCyan,
                        ),
                        const SizedBox(width: 6),
                        const Text(
                          '导出类型',
                          style: TextStyle(
                            color: TechColors.textPrimary,
                            fontSize: 15,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 12),

                    // 导出类型下拉选择
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      decoration: BoxDecoration(
                        color: TechColors.bgMedium,
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: TechColors.borderDark),
                      ),
                      child: DropdownButton<String>(
                        value: selectedExportType,
                        isExpanded: true,
                        dropdownColor: TechColors.bgDark,
                        underline: const SizedBox(),
                        icon: const Icon(Icons.keyboard_arrow_down,
                            color: TechColors.glowCyan),
                        style: const TextStyle(
                          color: TechColors.textPrimary,
                          fontSize: 14,
                        ),
                        items: exportTypes.map((type) {
                          return DropdownMenuItem<String>(
                            value: type['value'] as String,
                            child: Text(type['label'] as String),
                          );
                        }).toList(),
                        onChanged: (value) {
                          if (value != null) {
                            setDialogState(() {
                              selectedExportType = value;
                            });
                          }
                        },
                      ),
                    ),

                    const SizedBox(height: 8),

                    // 导出类型描述
                    Text(
                      exportTypes.firstWhere(
                              (t) => t['value'] == selectedExportType)['desc']
                          as String,
                      style: const TextStyle(
                        color: TechColors.textMuted,
                        fontSize: 12,
                      ),
                    ),

                    const SizedBox(height: 24),

                    // 底部按钮
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        // 取消按钮
                        TextButton(
                          onPressed: () => Navigator.pop(context),
                          style: TextButton.styleFrom(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 24, vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(4),
                              side: const BorderSide(
                                  color: TechColors.borderDark),
                            ),
                          ),
                          child: const Text(
                            '取消',
                            style: TextStyle(
                              color: TechColors.textSecondary,
                              fontSize: 14,
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        // 导出按钮
                        ElevatedButton(
                          onPressed: () {
                            if (endDate.isBefore(startDate)) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('结束时间不能早于开始时间')),
                              );
                              return;
                            }
                            Navigator.pop(context, {
                              'start': startDate,
                              'end': endDate,
                              'type': selectedExportType,
                            });
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: TechColors.glowOrange,
                            padding: const EdgeInsets.symmetric(
                                horizontal: 32, vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(4),
                            ),
                          ),
                          child: const Text(
                            '导出',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );

    if (result != null) {
      final start = result['start'] as DateTime;
      final end = result['end'] as DateTime;
      final type = result['type'] as String;

      switch (type) {
        case 'runtime':
          await _exportDeviceRuntime(start, end);
          break;
        case 'electricity':
          await _exportElectricity(start, end);
          break;
        case 'gas':
          await _exportGasConsumption(start, end);
          break;
        case 'feeding':
          await _exportFeedingAmount(start, end);
          break;
        case 'comprehensive':
          await _exportComprehensive(start, end);
          break;
      }
    }
  }

  // ============================================================
  // 导出逻辑: 调用后端 API + 生成 Excel
  // ============================================================

  final DataExportService _exportService = DataExportService();

  /// 获取桌面路径
  String _getDesktopPath() {
    final userProfile = Platform.environment['USERPROFILE'];
    if (Platform.isWindows && userProfile != null) {
      final desktop = p.join(userProfile, 'Desktop');
      if (Directory(desktop).existsSync()) return desktop;
    }
    // 备用路径
    if (Platform.isWindows) {
      const hardcoded = r'C:\Users\Admin\Desktop';
      if (Directory(hardcoded).existsSync()) return hardcoded;
    }
    return Directory.current.path;
  }

  /// 保存 Excel 文件到桌面
  Future<void> _saveExcelToDesktop(Excel excelObj, String filename) async {
    final desktopPath = _getDesktopPath();
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
  }

  /// 将设备列表的 daily_records 写入 Excel sheet
  void _writeDeviceRuntimeToSheet(
    Sheet sheet,
    List<dynamic> devices,
    String deviceIdKey,
  ) {
    for (final device in devices) {
      final deviceId = device[deviceIdKey] as String? ?? '';
      final deviceName = DeviceNameMapper.getDeviceName(deviceId);
      final records = device['daily_records'] as List<dynamic>? ?? [];

      for (final record in records) {
        final date = record['date'] ?? '';
        final startTime = record['start_time'] ?? '';
        final endTime = record['end_time'] ?? '';
        final runtimeHours = record['runtime_hours'] ?? 0.0;

        sheet.appendRow([
          TextCellValue(date.toString()),
          TextCellValue(deviceName),
          TextCellValue(DeviceNameMapper.getDeviceType(deviceId)),
          TextCellValue(startTime.toString()),
          TextCellValue(endTime.toString()),
          TextCellValue(runtimeHours.toStringAsFixed(2)),
        ]);
      }
    }
  }

  /// 导出: 设备运行时长
  Future<void> _exportDeviceRuntime(
      DateTime startDate, DateTime endDate) async {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('正在获取设备运行时长数据，请稍候...')),
    );

    try {
      final data = await _exportService.getAllDevicesRuntime(
        startTime: startDate,
        endTime: endDate,
      );

      // 生成 Excel
      var excelObj = Excel.createExcel();
      Sheet sheet = excelObj['设备运行时长'];

      // 表头
      sheet.appendRow([
        TextCellValue('日期'),
        TextCellValue('设备名称'),
        TextCellValue('设备类型'),
        TextCellValue('起始时间'),
        TextCellValue('终止时间'),
        TextCellValue('运行时长(小时)'),
      ]);

      // 回转窑
      final hoppers = data['hoppers'] as List<dynamic>? ?? [];
      _writeDeviceRuntimeToSheet(sheet, hoppers, 'device_id');

      // 辊道窑分区
      final rollerZones = data['roller_kiln_zones'] as List<dynamic>? ?? [];
      _writeDeviceRuntimeToSheet(sheet, rollerZones, 'device_id');

      // 辊道窑合计
      final rollerTotal = data['roller_kiln_total'];
      if (rollerTotal != null) {
        _writeDeviceRuntimeToSheet(sheet, [rollerTotal], 'device_id');
      }

      // SCR氨水泵
      final scrDevices = data['scr_devices'] as List<dynamic>? ?? [];
      _writeDeviceRuntimeToSheet(sheet, scrDevices, 'device_id');

      // 风机
      final fanDevices = data['fan_devices'] as List<dynamic>? ?? [];
      _writeDeviceRuntimeToSheet(sheet, fanDevices, 'device_id');

      // 设置列宽
      for (int i = 0; i < 6; i++) {
        sheet.setColumnWidth(i, 20.0);
      }

      // 删除默认Sheet1
      if (excelObj.sheets.containsKey('Sheet1')) {
        excelObj.delete('Sheet1');
      }

      final dayFormat = DateFormat('yyyy-MM-dd');
      final filename =
          '设备运行时长_${dayFormat.format(startDate)}_至_${dayFormat.format(endDate)}.xlsx';
      await _saveExcelToDesktop(excelObj, filename);
    } catch (e) {
      logger.error('[Export] runtime export failed', e);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('导出失败: $e')),
        );
      }
    }
  }

  /// 导出: 用电量
  Future<void> _exportElectricity(DateTime startDate, DateTime endDate) async {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('正在获取用电量数据，请稍候...')),
    );

    try {
      final data = await _exportService.getAllElectricity(
        startTime: startDate,
        endTime: endDate,
      );

      var excelObj = Excel.createExcel();
      Sheet sheet = excelObj['用电量'];

      // 表头
      sheet.appendRow([
        TextCellValue('日期'),
        TextCellValue('设备名称'),
        TextCellValue('设备类型'),
        TextCellValue('起始时间'),
        TextCellValue('终止时间'),
        TextCellValue('起始读数(kWh)'),
        TextCellValue('终止读数(kWh)'),
        TextCellValue('电量消耗(kWh)'),
        TextCellValue('运行时长(小时)'),
      ]);

      // 写入各类设备
      void writeElecDevices(List<dynamic> devices) {
        for (final device in devices) {
          final deviceId = device['device_id'] as String? ?? '';
          final deviceName = DeviceNameMapper.getDeviceName(deviceId);
          final records = device['daily_records'] as List<dynamic>? ?? [];

          for (final record in records) {
            sheet.appendRow([
              TextCellValue((record['date'] ?? '').toString()),
              TextCellValue(deviceName),
              TextCellValue(DeviceNameMapper.getDeviceType(deviceId)),
              TextCellValue((record['start_time'] ?? '').toString()),
              TextCellValue((record['end_time'] ?? '').toString()),
              TextCellValue(
                  (record['start_reading'] ?? 0.0).toStringAsFixed(2)),
              TextCellValue((record['end_reading'] ?? 0.0).toStringAsFixed(2)),
              TextCellValue((record['consumption'] ?? 0.0).toStringAsFixed(2)),
              TextCellValue(
                  (record['runtime_hours'] ?? 0.0).toStringAsFixed(2)),
            ]);
          }
        }
      }

      writeElecDevices(data['hoppers'] as List<dynamic>? ?? []);
      writeElecDevices(data['roller_kiln_zones'] as List<dynamic>? ?? []);
      if (data['roller_kiln_total'] != null) {
        writeElecDevices([data['roller_kiln_total']]);
      }
      writeElecDevices(data['scr_devices'] as List<dynamic>? ?? []);
      writeElecDevices(data['fan_devices'] as List<dynamic>? ?? []);

      for (int i = 0; i < 9; i++) {
        sheet.setColumnWidth(i, 18.0);
      }

      if (excelObj.sheets.containsKey('Sheet1')) {
        excelObj.delete('Sheet1');
      }

      final dayFormat = DateFormat('yyyy-MM-dd');
      final filename =
          '用电量_${dayFormat.format(startDate)}_至_${dayFormat.format(endDate)}.xlsx';
      await _saveExcelToDesktop(excelObj, filename);
    } catch (e) {
      logger.error('[Export] electricity export failed', e);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('导出失败: $e')),
        );
      }
    }
  }

  /// 导出: 燃气用量
  Future<void> _exportGasConsumption(
      DateTime startDate, DateTime endDate) async {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('正在获取燃气用量数据，请稍候...')),
    );

    try {
      final data = await _exportService.getGasConsumption(
        deviceIds: ['scr_1', 'scr_2'],
        startTime: startDate,
        endTime: endDate,
      );

      var excelObj = Excel.createExcel();
      Sheet sheet = excelObj['燃气用量'];

      // 表头
      sheet.appendRow([
        TextCellValue('日期'),
        TextCellValue('设备名称'),
        TextCellValue('起始时间'),
        TextCellValue('终止时间'),
        TextCellValue('起始读数(m3)'),
        TextCellValue('终止读数(m3)'),
        TextCellValue('燃气用量(m3)'),
      ]);

      for (final deviceId in ['scr_1', 'scr_2']) {
        final deviceData = data[deviceId] as Map<String, dynamic>?;
        if (deviceData == null) continue;

        final deviceName = DeviceNameMapper.getDeviceName(deviceId);
        final records = deviceData['daily_records'] as List<dynamic>? ?? [];

        for (final record in records) {
          sheet.appendRow([
            TextCellValue((record['date'] ?? '').toString()),
            TextCellValue(deviceName),
            TextCellValue((record['start_time'] ?? '').toString()),
            TextCellValue((record['end_time'] ?? '').toString()),
            TextCellValue((record['start_reading'] ?? 0.0).toStringAsFixed(2)),
            TextCellValue((record['end_reading'] ?? 0.0).toStringAsFixed(2)),
            TextCellValue((record['consumption'] ?? 0.0).toStringAsFixed(2)),
          ]);
        }
      }

      for (int i = 0; i < 7; i++) {
        sheet.setColumnWidth(i, 18.0);
      }

      if (excelObj.sheets.containsKey('Sheet1')) {
        excelObj.delete('Sheet1');
      }

      final dayFormat = DateFormat('yyyy-MM-dd');
      final filename =
          '燃气用量_${dayFormat.format(startDate)}_至_${dayFormat.format(endDate)}.xlsx';
      await _saveExcelToDesktop(excelObj, filename);
    } catch (e) {
      logger.error('[Export] gas export failed', e);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('导出失败: $e')),
        );
      }
    }
  }

  /// 导出: 投料量统计
  Future<void> _exportFeedingAmount(
      DateTime startDate, DateTime endDate) async {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('正在获取投料量数据，请稍候...')),
    );

    try {
      final data = await _exportService.getFeedingAmount(
        startTime: startDate,
        endTime: endDate,
      );

      var excelObj = Excel.createExcel();
      Sheet sheet = excelObj['投料量统计'];

      // 表头
      sheet.appendRow([
        TextCellValue('日期'),
        TextCellValue('设备名称'),
        TextCellValue('起始时间'),
        TextCellValue('终止时间'),
        TextCellValue('投料总量(kg)'),
      ]);

      final hoppers = data['hoppers'] as List<dynamic>? ?? [];
      for (final device in hoppers) {
        final deviceId = device['device_id'] as String? ?? '';
        final deviceName = DeviceNameMapper.getDeviceName(deviceId);
        final records = device['daily_records'] as List<dynamic>? ?? [];

        for (final record in records) {
          sheet.appendRow([
            TextCellValue((record['date'] ?? '').toString()),
            TextCellValue(deviceName),
            TextCellValue((record['start_time'] ?? '').toString()),
            TextCellValue((record['end_time'] ?? '').toString()),
            TextCellValue((record['feeding_amount'] ?? 0.0).toStringAsFixed(2)),
          ]);
        }
      }

      for (int i = 0; i < 5; i++) {
        sheet.setColumnWidth(i, 18.0);
      }

      if (excelObj.sheets.containsKey('Sheet1')) {
        excelObj.delete('Sheet1');
      }

      final dayFormat = DateFormat('yyyy-MM-dd');
      final filename =
          '投料量统计_${dayFormat.format(startDate)}_至_${dayFormat.format(endDate)}.xlsx';
      await _saveExcelToDesktop(excelObj, filename);
    } catch (e) {
      logger.error('[Export] feeding export failed', e);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('导出失败: $e')),
        );
      }
    }
  }

  /// 导出: 全部数据
  Future<void> _exportComprehensive(
      DateTime startDate, DateTime endDate) async {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('正在获取全部数据，请稍候...')),
    );

    try {
      final data = await _exportService.getComprehensiveData(
        startTime: startDate,
        endTime: endDate,
      );

      var excelObj = Excel.createExcel();
      Sheet sheet = excelObj['全部数据'];

      // 表头
      sheet.appendRow([
        TextCellValue('日期'),
        TextCellValue('设备名称'),
        TextCellValue('设备类型'),
        TextCellValue('起始时间'),
        TextCellValue('终止时间'),
        TextCellValue('电量消耗(kWh)'),
        TextCellValue('运行时长(小时)'),
        TextCellValue('燃气用量(m3)'),
        TextCellValue('投料量(kg)'),
      ]);

      final devices = data['devices'] as List<dynamic>? ?? [];
      // 按排序权重排序
      devices.sort((a, b) {
        final aId = a['device_id'] as String? ?? '';
        final bId = b['device_id'] as String? ?? '';
        return DeviceNameMapper.getDeviceSortOrder(aId)
            .compareTo(DeviceNameMapper.getDeviceSortOrder(bId));
      });

      for (final device in devices) {
        final deviceId = device['device_id'] as String? ?? '';
        final deviceName = DeviceNameMapper.getDeviceName(deviceId);
        final deviceType = DeviceNameMapper.getDeviceType(deviceId);
        final records = device['daily_records'] as List<dynamic>? ?? [];

        for (final record in records) {
          sheet.appendRow([
            TextCellValue((record['date'] ?? '').toString()),
            TextCellValue(deviceName),
            TextCellValue(deviceType),
            TextCellValue((record['start_time'] ?? '').toString()),
            TextCellValue((record['end_time'] ?? '').toString()),
            TextCellValue(
                (record['electricity_consumption'] ?? 0.0).toStringAsFixed(2)),
            TextCellValue((record['runtime_hours'] ?? 0.0).toStringAsFixed(2)),
            TextCellValue(
                (record['gas_consumption'] ?? 0.0).toStringAsFixed(2)),
            TextCellValue((record['feeding_amount'] ?? 0.0).toStringAsFixed(2)),
          ]);
        }
      }

      for (int i = 0; i < 9; i++) {
        sheet.setColumnWidth(i, 18.0);
      }

      if (excelObj.sheets.containsKey('Sheet1')) {
        excelObj.delete('Sheet1');
      }

      final dayFormat = DateFormat('yyyy-MM-dd');
      final filename =
          '全部数据_${dayFormat.format(startDate)}_至_${dayFormat.format(endDate)}.xlsx';
      await _saveExcelToDesktop(excelObj, filename);
    } catch (e) {
      logger.error('[Export] comprehensive export failed', e);
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
    }
  }

  /// 加载回转窑称重历史数据（重量）和下料速度
  Future<void> _loadHopperWeightData() async {
    final deviceId =
        HistoryDataService.hopperDeviceIds[_selectedHopperIndex + 1]!;

    // 1. 查询重量数据 (sensor_data)
    final weightResult = await _historyService.queryHopperWeightHistory(
      deviceId: deviceId,
      start: _hopperChartStartTime,
      end: _hopperChartEndTime,
    );

    // 2. 查询下料速度数据 (feeding_cumulative)
    final feedRateResult = await _historyService.queryHopperFeedRateHistory(
      deviceId: deviceId,
      start: _hopperChartStartTime,
      end: _hopperChartEndTime,
    );

    if (!mounted) return;

    // 更新重量数据
    if (weightResult.success && weightResult.hasData) {
      setState(() => _hopperWeightData[_selectedHopperIndex] =
          _convertToFlSpots(weightResult.dataPoints!, 'weight'));
    }
    if (feedRateResult.success && feedRateResult.hasData) {
      setState(() => _feedSpeedData[_selectedHopperIndex] =
          _convertToFlSpots(feedRateResult.dataPoints!, 'display_feed_rate'));
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
      setState(() => _hopperEnergyData[_selectedHopperIndex] =
          _convertToFlSpots(result.dataPoints!, 'ImpEp'));
    }
  }

  /// 加载回转窑投料累计数据（feeding_cumulative 表的 feeding_total 字段）
  Future<void> _loadHopperFeedingData() async {
    final deviceId =
        HistoryDataService.hopperDeviceIds[_selectedHopperIndex + 1]!;
    final result = await _historyService.queryHopperFeedingTotalHistory(
      deviceId: deviceId,
      start: _hopperChartStartTime,
      end: _hopperChartEndTime,
    );

    if (!mounted) return;

    final spots = <FlSpot>[];
    if (result.success && result.hasData && result.dataPoints != null) {
      for (var point in result.dataPoints!) {
        final total = (point.fields['feeding_total'] as num?)?.toDouble();
        if (total != null) {
          spots.add(FlSpot(
            point.time.millisecondsSinceEpoch.toDouble(),
            double.parse(total.toStringAsFixed(2)),
          ));
        }
      }
    }
    setState(() => _hopperFeedingData[_selectedHopperIndex] = spots);
  }

  Future<void> _loadRollerData() async {
    final tasks = [
      for (int i = 0; i < 6; i++)
        if (_selectedRollerZones[i]) _loadSingleRollerZoneData(i)
    ];
    if (tasks.isNotEmpty) await Future.wait(tasks);
  }

  /// 加载单个辊道窑温区数据
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

  Future<void> _loadScrFanData() async {
    await Future.wait([_loadSCRData(), _loadFanData()]);
  }

  Future<void> _loadSCRData() async {
    final index = _selectedPumpIndex;
    final deviceId = HistoryDataService.scrDeviceIds[index + 1]!;

    final results = await Future.wait([
      _historyService.queryScrPowerHistory(
          deviceId: deviceId, start: _scrChartStartTime, end: _scrChartEndTime),
      _historyService.queryScrGasHistory(
          deviceId: deviceId, start: _scrChartStartTime, end: _scrChartEndTime),
    ]);

    if (!mounted) return;
    final powerResult = results[0];
    final gasResult = results[1];

    if (powerResult.success && powerResult.hasData) {
      setState(() => _scrPowerData[index] =
          _convertToFlSpots(powerResult.dataPoints!, 'Pt'));
    }
    if (gasResult.success && gasResult.hasData) {
      setState(() {
        _scrGasFlowData[index] =
            _convertToFlSpots(gasResult.dataPoints!, 'flow_rate');
        _scrGasTotalData[index] =
            _convertToFlSpots(gasResult.dataPoints!, 'total_flow');
      });
    }
  }

  Future<void> _loadFanData() async {
    final tasks = <Future<void>>[];
    for (int i = 0; i < _selectedFanIndexes.length; i++) {
      if (!_selectedFanIndexes[i]) continue;
      final deviceId = HistoryDataService.fanDeviceIds[i + 1]!;
      tasks.add(_historyService
          .queryFanPowerHistory(
              deviceId: deviceId,
              start: _fanChartStartTime,
              end: _fanChartEndTime)
          .then((result) {
        if (!mounted) return;
        if (result.success && result.hasData) {
          setState(() =>
              _fanPowerData[i] = _convertToFlSpots(result.dataPoints!, 'Pt'));
        }
      }));
    }
    if (tasks.isNotEmpty) await Future.wait(tasks);
  }

  /// 将历史数据点转换为 FlSpot 列表，数值保留两位小数
  List<FlSpot> _convertToFlSpots(
      List<HistoryDataPoint> dataPoints, String field) {
    if (dataPoints.isEmpty) return [];
    dataPoints.sort((a, b) => a.time.compareTo(b.time));
    return dataPoints.map((point) {
      final x = point.time.millisecondsSinceEpoch.toDouble();
      double y;
      switch (field) {
        case 'temperature':
          y = point.temperature ?? 0;
          break;
        case 'weight':
          y = point.weight ?? 0;
          break;
        case 'display_feed_rate':
          // feeding_cumulative measurement 下料速度字段
          y = point.fields['display_feed_rate']?.toDouble() ?? 0;
          break;
        case 'feeding_total':
          // feeding_cumulative measurement 投料总量字段
          y = point.fields['feeding_total']?.toDouble() ?? 0;
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
        case 'total_flow':
          y = point.fields['total_flow']?.toDouble() ?? 0;
          break;
        default:
          y = point.fields[field]?.toDouble() ?? 0;
      }
      return FlSpot(x, double.parse(y.toStringAsFixed(2)));
    }).toList();
  }

  String _formatBottomTitle(double value) {
    final date = DateTime.fromMillisecondsSinceEpoch(value.toInt());
    return '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
  }

  /// X轴间隔，目标显示6个标签
  double _calculateXInterval(DateTime start, DateTime end) {
    final totalMilliseconds = end.difference(start).inMilliseconds;
    const targetLabels = 6;
    final roughInterval = totalMilliseconds / targetLabels;

    if (roughInterval < 60000) return 10000;
    if (roughInterval < 3600000) {
      final minutes = roughInterval / 60000;
      if (minutes <= 2) return 60000;
      if (minutes <= 5) return 300000;
      if (minutes <= 10) return 600000;
      if (minutes <= 15) return 900000;
      return 1800000;
    } else {
      final hours = roughInterval / 3600000;
      if (hours <= 1) return 3600000;
      if (hours <= 2) return 7200000;
      if (hours <= 4) return 14400000;
      if (hours <= 6) return 21600000;
      return 43200000;
    }
  }

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
                TextButton.icon(
                  icon: const Icon(Icons.download,
                      color: TechColors.glowOrange, size: 20),
                  label: const Text(
                    '导出数据',
                    style: TextStyle(
                      color: TechColors.glowOrange,
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  onPressed: _showExportDatePicker,
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
                  //  能耗曲线（新增）
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
                  //  投料总量曲线（新增）
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
                          accentColor: TechColors.glowGreen,
                          headerActions: [
                            MultiSelectDropdown(
                              label: '风机',
                              itemCount: 2,
                              selectedItems: _selectedFanIndexes,
                              itemColors: const [
                                TechColors.glowGreen,
                                TechColors.glowGreen
                              ],
                              getItemLabel: (i) => '风机#${i + 1}',
                              accentColor: TechColors.glowGreen,
                              compact: true,
                              onItemToggle: (index) {
                                setState(() => _selectedFanIndexes[index] =
                                    !_selectedFanIndexes[index]);
                                _loadFanData();
                              },
                            ),
                            const SizedBox(width: 8),
                            QuickTimeRangeSelector(
                              accentColor: TechColors.glowGreen,
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
                              accentColor: TechColors.glowGreen,
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

  Widget _buildTemperatureChart() {
    // 检查是否为长料仓（索引 6, 7, 8）
    final isLongHopper = _selectedHopperIndex >= 6;

    if (isLongHopper) {
      return TechLineChart(
        title: '料仓温度曲线 (双区对比)',
        accentColor: TechColors.glowOrange,
        yAxisLabel: '温度(°C)',
        xAxisLabel: '',
        xInterval:
            _calculateXInterval(_hopperChartStartTime, _hopperChartEndTime),
        getBottomTitle: _formatBottomTitle,
        dataMap: {
          0: _temperatureData[_selectedHopperIndex] ?? [],
          1: _temperatureData2[_selectedHopperIndex] ?? [],
        },
        isSingleSelect: false,
        selectedItems: const [true, true],
        onItemToggle: (index) {},
        itemColors: const [TechColors.glowOrange, TechColors.glowCyan],
        itemCount: 2,
        getItemLabel: (index) => index == 0 ? '温度1' : '温度2',
        selectorLabel: '温度探头',
        showSelector: true,
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

  Widget _buildHopperFeedingChart() {
    // 判断当前选中窑是否为无料仓设备（no_hopper_1/no_hopper_2，索引4,5）
    final deviceId =
        HistoryDataService.hopperDeviceIds[_selectedHopperIndex + 1];
    final isNoHopper = deviceId?.startsWith('no_hopper') ?? false;

    return Stack(
      children: [
        TechLineChart(
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
          isCurved: false,
          onItemSelect: (index) {},
        ),
        // 仅非无料仓设备显示「查看投料记录」按钮
        if (!isNoHopper)
          Positioned(
            top: 6,
            right: 8,
            child: TextButton.icon(
              onPressed: () => _showFeedingRecordsDialog(context),
              icon: const Icon(
                Icons.list_alt,
                size: 14,
                color: TechColors.glowOrange,
              ),
              label: const Text(
                '查看投料记录',
                style: TextStyle(
                  color: TechColors.glowOrange,
                  fontSize: 12,
                ),
              ),
              style: TextButton.styleFrom(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                backgroundColor: TechColors.glowOrange.withOpacity(0.08),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(4),
                  side: BorderSide(
                    color: TechColors.glowOrange.withOpacity(0.4),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }

  // ============================================================
  // 投料记录弹窗
  // ============================================================

  /// 直接打开投料记录弹窗
  Future<void> _showFeedingRecordsDialog(BuildContext context) async {
    final deviceId =
        HistoryDataService.hopperDeviceIds[_selectedHopperIndex + 1]!;
    final kilnLabel = _getHopperLabel(_selectedHopperIndex);

    showDialog(
      context: context,
      builder: (_) => _FeedingRecordsDialog(
        deviceId: deviceId,
        kilnLabel: kilnLabel,
        start: _hopperChartStartTime,
        end: _hopperChartEndTime,
        historyService: _historyService,
      ),
    );
  }

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

  Widget _buildPumpEnergyChart() {
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

  Widget _buildScrGasChart() {
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

  Widget _buildFanEnergyChart() {
    return TechLineChart(
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
      getItemLabel: (index) => '风机${index + 1}:表${index == 0 ? 65 : 66}',
      selectorLabel: '选择风机',
      showSelector: false,
      onItemToggle: (index) {},
    );
  }

  Color _getChartAccentColor(String chartType) {
    switch (chartType) {
      case 'hopper':
        return TechColors.glowOrange;
      case 'roller':
        return TechColors.glowCyan;
      case 'scr':
        return TechColors.glowOrange;
      case 'fan':
        return TechColors.glowGreen;
      default:
        return TechColors.glowCyan;
    }
  }

  DateTime _getChartStartTime(String chartType) {
    switch (chartType) {
      case 'hopper':
        return _hopperChartStartTime;
      case 'roller':
        return _rollerChartStartTime;
      case 'scr':
        return _scrChartStartTime;
      case 'fan':
        return _fanChartStartTime;
      default:
        return DateTime.now().subtract(const Duration(hours: 24));
    }
  }

  void _setChartStartTime(String chartType, DateTime time) {
    switch (chartType) {
      case 'hopper':
        _hopperChartStartTime = time;
        break;
      case 'roller':
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

  DateTime _getChartEndTime(String chartType) {
    switch (chartType) {
      case 'hopper':
        return _hopperChartEndTime;
      case 'roller':
        return _rollerChartEndTime;
      case 'scr':
        return _scrChartEndTime;
      case 'fan':
        return _fanChartEndTime;
      default:
        return DateTime.now();
    }
  }

  void _setChartEndTime(String chartType, DateTime time) {
    switch (chartType) {
      case 'hopper':
        _hopperChartEndTime = time;
        break;
      case 'roller':
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

  ThemeData _darkPickerTheme(Color accent) => ThemeData.dark().copyWith(
        colorScheme:
            ColorScheme.dark(primary: accent, surface: TechColors.bgMedium),
      );

  Future<void> _selectChartStartTime(String chartType) async {
    final accent = _getChartAccentColor(chartType);
    final current = _getChartStartTime(chartType);
    final pickedDate = await showDatePicker(
      context: context,
      initialDate: current,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      builder: (ctx, child) =>
          Theme(data: _darkPickerTheme(accent), child: child!),
    );
    if (pickedDate == null || !mounted) return;
    final pickedTime = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(current),
      builder: (ctx, child) =>
          Theme(data: _darkPickerTheme(accent), child: child!),
    );
    if (pickedTime != null) {
      setState(() {
        _setChartStartTime(
            chartType,
            DateTime(
              pickedDate.year,
              pickedDate.month,
              pickedDate.day,
              pickedTime.hour,
              pickedTime.minute,
            ));
        _refreshChartData(chartType);
      });
    }
  }

  Future<void> _selectChartEndTime(String chartType) async {
    final accent = _getChartAccentColor(chartType);
    final current = _getChartEndTime(chartType);
    final pickedDate = await showDatePicker(
      context: context,
      initialDate: current,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      builder: (ctx, child) =>
          Theme(data: _darkPickerTheme(accent), child: child!),
    );
    if (pickedDate == null || !mounted) return;
    final pickedTime = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(current),
      builder: (ctx, child) =>
          Theme(data: _darkPickerTheme(accent), child: child!),
    );
    if (pickedTime != null) {
      setState(() {
        _setChartEndTime(
            chartType,
            DateTime(
              pickedDate.year,
              pickedDate.month,
              pickedDate.day,
              pickedTime.hour,
              pickedTime.minute,
            ));
        _refreshChartData(chartType);
      });
    }
  }

  void _refreshChartData(String chartType) {
    switch (chartType) {
      case 'hopper':
        _loadHopperTemperatureData();
        _loadHopperWeightData();
        _loadHopperEnergyData();
        _loadHopperFeedingData();
        break;
      case 'roller':
        _loadRollerData();
        break;
      case 'scr':
        _loadSCRData();
        break;
      case 'fan':
        _loadFanData();
        break;
    }
  }
}

// ============================================================
// 投料记录弹窗组件
// ============================================================

class _FeedingRecordsDialog extends StatefulWidget {
  final String deviceId;
  final String kilnLabel;
  final DateTime start;
  final DateTime end;
  final HistoryDataService historyService;

  const _FeedingRecordsDialog({
    required this.deviceId,
    required this.kilnLabel,
    required this.start,
    required this.end,
    required this.historyService,
  });

  @override
  State<_FeedingRecordsDialog> createState() => _FeedingRecordsDialogState();
}

class _FeedingRecordsDialogState extends State<_FeedingRecordsDialog> {
  bool _isLoading = true;
  List<FeedingRecord> _records = [];
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadRecords();
  }

  Future<void> _loadRecords() async {
    try {
      final records = await widget.historyService.queryHopperFeedingHistory(
        deviceId: widget.deviceId,
        start: widget.start,
        end: widget.end,
      );
      if (mounted) {
        setState(() {
          _records = records;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = '加载失败: $e';
          _isLoading = false;
        });
      }
    }
  }

  String _formatDateTime(DateTime dt) {
    return DateFormat('MM-dd HH:mm:ss').format(dt);
  }

  String _formatDateRange() {
    final fmt = DateFormat('MM-dd HH:mm');
    return '${fmt.format(widget.start)} ~ ${fmt.format(widget.end)}';
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: TechColors.bgDark,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(color: TechColors.glowOrange.withOpacity(0.5)),
      ),
      child: Container(
        width: 620,
        height: 520,
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 标题行：标题左侧，时间范围右侧
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Text(
                  '投料记录 - ${widget.kilnLabel}',
                  style: const TextStyle(
                    color: TechColors.textPrimary,
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(width: 16),
                Text(
                  _formatDateRange(),
                  style: const TextStyle(
                    color: TechColors.textSecondary,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Container(height: 1, color: TechColors.borderDark),
            const SizedBox(height: 8),
            // 表内容区域
            Expanded(child: _buildContent()),
            Container(height: 1, color: TechColors.borderDark),
            const SizedBox(height: 10),
            // 底部：统计 + 关闭
            Row(
              children: [
                Text(
                  _isLoading ? '' : '共 ${_records.length} 条记录',
                  style: const TextStyle(
                    color: TechColors.textSecondary,
                    fontSize: 12,
                  ),
                ),
                const Spacer(),
                SizedBox(
                  height: 32,
                  child: ElevatedButton(
                    onPressed: () => Navigator.of(context).pop(),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: TechColors.bgMedium,
                      foregroundColor: TechColors.textPrimary,
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(4),
                        side: const BorderSide(color: TechColors.borderDark),
                      ),
                      elevation: 0,
                    ),
                    child: const Text('关闭', style: TextStyle(fontSize: 13)),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContent() {
    if (_isLoading) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(TechColors.glowOrange),
            ),
            SizedBox(height: 12),
            Text(
              '加载投料记录...',
              style: TextStyle(color: TechColors.textSecondary, fontSize: 13),
            ),
          ],
        ),
      );
    }

    if (_error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline,
                color: TechColors.statusAlarm, size: 32),
            const SizedBox(height: 10),
            Text(_error!,
                style: const TextStyle(
                    color: TechColors.statusAlarm, fontSize: 13)),
          ],
        ),
      );
    }

    if (_records.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.inbox_outlined,
                color: TechColors.textSecondary, size: 32),
            SizedBox(height: 10),
            Text('该时段无投料记录',
                style:
                    TextStyle(color: TechColors.textSecondary, fontSize: 13)),
          ],
        ),
      );
    }

    const double rowHeight = 42.0; // 增加行高

    return Column(
      children: [
        // 表头
        Container(
          height: rowHeight,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: TechColors.glowOrange.withOpacity(0.08),
            border: Border(
              bottom: BorderSide(
                  color: TechColors.glowOrange.withOpacity(0.4), width: 1),
            ),
          ),
          child: const Row(
            children: [
              SizedBox(
                width: 48,
                child: Text('#',
                    style: TextStyle(
                        color: TechColors.glowOrange,
                        fontSize: 15, // 字号加大
                        fontWeight: FontWeight.w600)),
              ),
              Expanded(
                child: Text('投料时间',
                    style: TextStyle(
                        color: TechColors.glowOrange,
                        fontSize: 15, // 字号加大
                        fontWeight: FontWeight.w600)),
              ),
              SizedBox(
                width: 130,
                child: Text('投料量 (kg)',
                    textAlign: TextAlign.right,
                    style: TextStyle(
                        color: TechColors.glowOrange,
                        fontSize: 15, // 字号加大
                        fontWeight: FontWeight.w600)),
              ),
            ],
          ),
        ),
        // 数据行（支持长按拖动滚动）
        Expanded(
          child: ScrollConfiguration(
            behavior: ScrollConfiguration.of(context).copyWith(
              dragDevices: {
                PointerDeviceKind.touch,
                PointerDeviceKind.mouse,
              },
            ),
            child: ListView.builder(
              itemCount: _records.length,
              itemExtent: rowHeight,
              itemBuilder: (context, index) {
                final record = _records[index];
                final isEven = index % 2 == 0;
                return Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  color: isEven
                      ? TechColors.bgMedium.withOpacity(0.2)
                      : Colors.transparent,
                  child: Row(
                    children: [
                      SizedBox(
                        width: 48,
                        child: Text(
                          '${index + 1}',
                          style: const TextStyle(
                              color: TechColors.textSecondary,
                              fontSize: 15), // 字号加大
                        ),
                      ),
                      Expanded(
                        child: Text(
                          _formatDateTime(record.time),
                          style: const TextStyle(
                              color: TechColors.textPrimary,
                              fontSize: 16), // 字号加大
                        ),
                      ),
                      SizedBox(
                        width: 130,
                        child: Text(
                          record.amount.toStringAsFixed(2),
                          textAlign: TextAlign.right,
                          style: const TextStyle(
                              color: TechColors.glowGreen,
                              fontSize: 16, // 字号加大
                              fontWeight: FontWeight.w500),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ),
      ],
    );
  }
}

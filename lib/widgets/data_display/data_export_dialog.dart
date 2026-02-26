import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'data_tech_line_widgets.dart';
import '../../services/data_export_service.dart';
import 'package:excel/excel.dart' hide Border;
import 'dart:io';
import 'package:path/path.dart' as p;
import 'package:file_picker/file_picker.dart';

/// ============================================================================
/// 数据导出弹窗 (Data Export Dialog)
/// ============================================================================
/// 功能:
/// 1. 选择时间范围（快速选择或自定义）
/// 2. 选择导出类型（设备运行时长/燃气用量/累计投料量/用电量/全部数据）
/// 3. 导出为Excel文件（使用文件选择器保存）
///
/// ============================================================================
/// 导出类型及表头说明
/// ============================================================================
///
/// 【1】设备运行时长 (ExportType.runtime)
/// 文件名: 设备运行时长_YYYYMMDD_HHMMSS.xlsx
/// 表头: 设备名称 | 日期 | 起始时间 | 终止时间 | 当日运行时长(h)
/// 设备: 窑1-9, 辊道窑分区1-6, 辊道窑合计, SCR北/南_氨水泵, SCR北/南_风机
/// 日期格式: yyyyMMdd
/// 示例数据:
///   窑7           | 20260126 | 2026-01-26T00:00:00Z | 2026-01-26T23:59:59Z | 48.00
///   辊道窑分区1   | 20260126 | 2026-01-26T00:00:00Z | 2026-01-26T23:59:59Z | 7.03
///   辊道窑分区2   | 20260126 | 2026-01-26T00:00:00Z | 2026-01-26T23:59:59Z | 7.03
///   辊道窑分区3   | 20260126 | 2026-01-26T00:00:00Z | 2026-01-26T23:59:59Z | 7.03
///   辊道窑分区4   | 20260126 | 2026-01-26T00:00:00Z | 2026-01-26T23:59:59Z | 7.03
///   辊道窑分区5   | 20260126 | 2026-01-26T00:00:00Z | 2026-01-26T23:59:59Z | 7.03
///   辊道窑分区6   | 20260126 | 2026-01-26T00:00:00Z | 2026-01-26T23:59:59Z | 0.17
///   辊道窑合计    | 20260126 | 2026-01-26T00:00:00Z | 2026-01-26T23:59:59Z | 7.03 (平均值)
///   SCR北_氨水泵  | 20260126 | 2026-01-26T00:00:00Z | 2026-01-26T23:59:59Z | 14.90
///   SCR北_风机    | 20260126 | 2026-01-26T00:00:00Z | 2026-01-26T23:59:59Z | 14.90
///
/// 【2】燃气用量统计 (ExportType.gasConsumption)
/// 文件名: 燃气用量_YYYYMMDD_HHMMSS.xlsx
/// 表头: 设备名称 | 日期 | 起始时间 | 终止时间 | 起始读数(m³) | 截止读数(m³) | 当日消耗(m³)
/// 设备: SCR北_燃气表, SCR南_燃气表
/// 日期格式: yyyyMMdd
/// 示例数据:
///   SCR北_燃气表 | 20260126 | 2026-01-26T00:00:00Z | 2026-01-26T23:59:59Z | 5000.50 | 5150.30 | 149.80
///
/// 【3】投料量统计 (ExportType.feedingAmount)
/// 文件名: 投料量统计_YYYYMMDD_HHMMSS.xlsx
/// 表头: 设备名称 | 日期 | 起始时间 | 终止时间 | 当日投料量(kg)
/// 设备: 窑7,6,5,4,2,1,8,3,9（7个有料仓的窑）
/// 日期格式: yyyyMMdd
/// 示例数据:
///   窑7 | 20260126 | 2026-01-26T00:00:00Z | 2026-01-26T23:59:59Z | 1250.50
///   窑7 | 20260127 | 2026-01-27T00:00:00Z | 2026-01-27T23:59:59Z | 1180.30
///
/// 【4】用电量 (ExportType.electricityAll)
/// 文件名: 用电量_YYYYMMDD_HHMMSS.xlsx
/// 表头: 设备名称 | 日期 | 起始时间 | 终止时间 | 起始读数(kWh) | 截止读数(kWh) | 当日消耗(kWh) | 运行时长(h)
/// 设备: 窑1-9, 辊道窑分区1-6, 辊道窑合计, SCR北/南_氨水泵, SCR北/南_风机
/// 日期格式: yyyyMMdd
/// 示例数据:
///   窑7           | 20260126 | 2026-01-26T00:00:00Z | 2026-01-26T23:59:59Z | 20005.71 | 20170.35 | 164.64 | 48.00
///   辊道窑分区1   | 20260126 | 2026-01-26T00:00:00Z | 2026-01-26T23:59:59Z | 1710043.95 | 1715011.45 | 4967.50 | 7.03
///   辊道窑分区2   | 20260126 | 2026-01-26T00:00:00Z | 2026-01-26T23:59:59Z | 2208061.41 | 2213028.91 | 4967.50 | 7.03
///   辊道窑分区3   | 20260126 | 2026-01-26T00:00:00Z | 2026-01-26T23:59:59Z | 3072086.95 | 3077054.45 | 4967.50 | 7.03
///   辊道窑分区4   | 20260126 | 2026-01-26T00:00:00Z | 2026-01-26T23:59:59Z | 3588094.45 | 3593061.95 | 4967.50 | 7.03
///   辊道窑分区5   | 20260126 | 2026-01-26T00:00:00Z | 2026-01-26T23:59:59Z | 3270090.70 | 3275058.20 | 4967.50 | 7.03
///   辊道窑分区6   | 20260126 | 2026-01-26T00:00:00Z | 2026-01-26T23:59:59Z | 3314062.73 | 3314890.23 | 827.50 | 0.17
///   辊道窑合计    | 20260126 | 2026-01-26T00:00:00Z | 2026-01-26T23:59:59Z | 16464952.38 | 16494757.88 | 29805.50 | 7.03
///   SCR北_氨水泵  | 20260126 | 2026-01-26T00:00:00Z | 2026-01-26T23:59:59Z | 48515.60 | 48680.25 | 164.65 | 14.90
///
/// 【5】全部数据 (ExportType.comprehensive)
/// 文件名: 全部数据_YYYYMMDD_HHMMSS.xlsx
/// Sheet1 - 全部数据（按天）:
///   表头: 设备名称 | 日期 | 起始时间 | 终止时间 | 燃气当日消耗(m³) | 当日投料(kg) | 电能当日消耗(kWh) | 当日运行时间(h)
/// Sheet2 - 用量总计:
///   表头: 设备名称 | 日期 | 起始时间 | 终止时间 | 能耗用量总计(kWh) | 投料总计(kg) | 燃气用量总计(m³) | 运行时长总计(h)
/// 设备: 窑1-9, 辊道窑分区1-6, 辊道窑合计, SCR北/南_燃气表, SCR北/南_氨水泵, SCR北/南_风机
/// 日期格式: yyyyMMdd (Sheet1), yyyyMMdd-yyyyMMdd (Sheet2)
///
/// ============================================================================
/// 设备名称映射
/// ============================================================================
/// - short_hopper_1~4 → 窑7,6,5,4
/// - no_hopper_1~2 → 窑2,1
/// - long_hopper_1~3 → 窑8,3,9
/// - zone1~6 → 辊道窑分区1-6
/// - roller_kiln_total → 辊道窑合计
/// - scr_1/2 → SCR北/南_燃气表, SCR北/南_氨水泵
/// - fan_1/2 → SCR北/南_风机
/// ============================================================================

class DataExportDialog extends StatefulWidget {
  const DataExportDialog({super.key});

  @override
  State<DataExportDialog> createState() => _DataExportDialogState();
}

class _DataExportDialogState extends State<DataExportDialog> {
  // ==================== 时间选择 ====================
  DateTime? _startTime;
  DateTime? _endTime;
  int _selectedQuickDays = 7; // 默认最近7天

  // ==================== 导出类型 ====================
  ExportType _selectedExportType = ExportType.runtime;

  // ==================== 加载状态 ====================
  bool _isExporting = false;

  // ==================== 服务 ====================
  final DataExportService _exportService = DataExportService();

  @override
  void initState() {
    super.initState();
    _updateTimeRange(_selectedQuickDays);
  }

  /// 更新时间范围
  void _updateTimeRange(int days) {
    setState(() {
      _selectedQuickDays = days;
      _endTime = DateTime.now();
      _startTime = _endTime!.subtract(Duration(days: days));
    });
  }

  /// 选择开始时间
  Future<void> _selectStartTime() async {
    final DateTime? pickedDate = await showDatePicker(
      context: context,
      initialDate: _startTime ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      builder: (context, child) {
        return Theme(
          data: ThemeData.dark().copyWith(
            colorScheme: const ColorScheme.dark(
              primary: TechColors.glowCyan,
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
        initialTime: TimeOfDay.fromDateTime(_startTime ?? DateTime.now()),
        builder: (context, child) {
          return Theme(
            data: ThemeData.dark().copyWith(
              colorScheme: const ColorScheme.dark(
                primary: TechColors.glowCyan,
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
          _selectedQuickDays = 0; // 清除快速选择
        });
      }
    }
  }

  /// 选择结束时间
  Future<void> _selectEndTime() async {
    final DateTime? pickedDate = await showDatePicker(
      context: context,
      initialDate: _endTime ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      builder: (context, child) {
        return Theme(
          data: ThemeData.dark().copyWith(
            colorScheme: const ColorScheme.dark(
              primary: TechColors.glowCyan,
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
        initialTime: TimeOfDay.fromDateTime(_endTime ?? DateTime.now()),
        builder: (context, child) {
          return Theme(
            data: ThemeData.dark().copyWith(
              colorScheme: const ColorScheme.dark(
                primary: TechColors.glowCyan,
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
          _selectedQuickDays = 0; // 清除快速选择
        });
      }
    }
  }

  /// 执行导出
  Future<void> _performExport() async {
    if (_startTime == null || _endTime == null) {
      _showMessage('请选择时间范围', isError: true);
      return;
    }

    if (_endTime!.isBefore(_startTime!)) {
      _showMessage('结束时间不能早于开始时间', isError: true);
      return;
    }

    setState(() {
      _isExporting = true;
    });

    try {
      switch (_selectedExportType) {
        case ExportType.runtime:
          await _exportRuntime();
          break;
        case ExportType.gasConsumption:
          await _exportGasConsumption();
          break;
        case ExportType.feedingAmount:
          await _exportFeedingAmount();
          break;
        case ExportType.electricityAll:
          await _exportElectricityAll();
          break;
        case ExportType.comprehensive:
          await _exportComprehensive();
          break;
      }

      if (mounted) {
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) {
        _showMessage('导出失败: $e', isError: true);
      }
    } finally {
      if (mounted) {
        setState(() {
          _isExporting = false;
        });
      }
    }
  }

  /// 设备名称映射
  String _getDeviceName(String deviceId) {
    const deviceMap = {
      'short_hopper_1': '窑7',
      'short_hopper_2': '窑6',
      'short_hopper_3': '窑5',
      'short_hopper_4': '窑4',
      'no_hopper_1': '窑2',
      'no_hopper_2': '窑1',
      'long_hopper_1': '窑8',
      'long_hopper_2': '窑3',
      'long_hopper_3': '窑9',
      'zone1': '辊道窑分区1',
      'zone2': '辊道窑分区2',
      'zone3': '辊道窑分区3',
      'zone4': '辊道窑分区4',
      'zone5': '辊道窑分区5',
      'zone6': '辊道窑分区6',
      'roller_kiln_total': '辊道窑合计',
      'scr_1': 'SCR北_燃气表',
      'scr_2': 'SCR南_燃气表',
      'scr_1_pump': 'SCR北_氨水泵',
      'scr_2_pump': 'SCR南_氨水泵',
      'fan_1': 'SCR北_风机',
      'fan_2': 'SCR南_风机',
    };
    return deviceMap[deviceId] ?? deviceId;
  }

  /// 设置列宽（统一设置，避免重复代码）
  void _setColumnWidths(Sheet sheet, List<double> widths) {
    for (int i = 0; i < widths.length; i++) {
      sheet.setColumnWidth(i, widths[i]);
    }
  }

  /// 导出运行时长
  Future<void> _exportRuntime() async {
    final data = await _exportService.getAllDevicesRuntime(
      startTime: _startTime!,
      endTime: _endTime!,
    );

    final excel = Excel.createExcel();
    final sheet = excel['设备运行时长'];

    // 表头：设备名称、日期、起始时间、终止时间、当日运行时长(h)
    sheet.appendRow([
      TextCellValue('设备名称'),
      TextCellValue('日期'),
      TextCellValue('起始时间'),
      TextCellValue('终止时间'),
      TextCellValue('当日运行时长(h)'),
    ]);

    // 设置列宽（设备名称、日期、起始时间、终止时间、运行时长）
    _setColumnWidths(sheet, [18, 15, 28, 28, 20]);

    // 删除默认的Sheet1（必须在创建新sheet之后）
    if (excel.sheets.containsKey('Sheet1')) {
      excel.delete('Sheet1');
    }

    // 回转窑（每个设备的每日记录）
    for (var hopper in data['hoppers'] ?? []) {
      final deviceName = _getDeviceName(hopper['device_id'].toString());
      for (var record in hopper['daily_records'] ?? []) {
        // 格式化日期为 yyyyMMdd
        final dateStr = record['date']?.toString() ?? '';
        final formattedDate = dateStr.replaceAll('-', '');

        sheet.appendRow([
          TextCellValue(deviceName),
          TextCellValue(formattedDate),
          TextCellValue(record['start_time']?.toString() ?? ''),
          TextCellValue(record['end_time']?.toString() ?? ''),
          DoubleCellValue(record['runtime_hours']?.toDouble() ?? 0.0),
        ]);
      }
    }

    // 辊道窑6个分区（每个分区的每日记录）
    for (var zone in data['roller_kiln_zones'] ?? []) {
      final deviceName = _getDeviceName(zone['device_id'].toString());
      for (var record in zone['daily_records'] ?? []) {
        final dateStr = record['date']?.toString() ?? '';
        final formattedDate = dateStr.replaceAll('-', '');

        sheet.appendRow([
          TextCellValue(deviceName),
          TextCellValue(formattedDate),
          TextCellValue(record['start_time']?.toString() ?? ''),
          TextCellValue(record['end_time']?.toString() ?? ''),
          DoubleCellValue(record['runtime_hours']?.toDouble() ?? 0.0),
        ]);
      }
    }

    // 辊道窑合计（每日记录）
    final rollerTotal = data['roller_kiln_total'];
    if (rollerTotal != null) {
      final deviceName = _getDeviceName(rollerTotal['device_id'].toString());
      for (var record in rollerTotal['daily_records'] ?? []) {
        final dateStr = record['date']?.toString() ?? '';
        final formattedDate = dateStr.replaceAll('-', '');

        sheet.appendRow([
          TextCellValue(deviceName),
          TextCellValue(formattedDate),
          TextCellValue(record['start_time']?.toString() ?? ''),
          TextCellValue(record['end_time']?.toString() ?? ''),
          DoubleCellValue(record['runtime_hours']?.toDouble() ?? 0.0),
        ]);
      }
    }

    // SCR（每个设备的每日记录）
    for (var scr in data['scr_devices'] ?? []) {
      final deviceName = _getDeviceName(scr['device_id'].toString());
      for (var record in scr['daily_records'] ?? []) {
        final dateStr = record['date']?.toString() ?? '';
        final formattedDate = dateStr.replaceAll('-', '');

        sheet.appendRow([
          TextCellValue(deviceName),
          TextCellValue(formattedDate),
          TextCellValue(record['start_time']?.toString() ?? ''),
          TextCellValue(record['end_time']?.toString() ?? ''),
          DoubleCellValue(record['runtime_hours']?.toDouble() ?? 0.0),
        ]);
      }
    }

    // 风机（每个设备的每日记录）
    for (var fan in data['fan_devices'] ?? []) {
      final deviceName = _getDeviceName(fan['device_id'].toString());
      for (var record in fan['daily_records'] ?? []) {
        final dateStr = record['date']?.toString() ?? '';
        final formattedDate = dateStr.replaceAll('-', '');

        sheet.appendRow([
          TextCellValue(deviceName),
          TextCellValue(formattedDate),
          TextCellValue(record['start_time']?.toString() ?? ''),
          TextCellValue(record['end_time']?.toString() ?? ''),
          DoubleCellValue(record['runtime_hours']?.toDouble() ?? 0.0),
        ]);
      }
    }

    await _saveExcel(excel, '设备运行时长');
  }

  /// 导出燃气用量统计
  Future<void> _exportGasConsumption() async {
    final data = await _exportService.getGasConsumption(
      deviceIds: ['scr_1', 'scr_2'],
      startTime: _startTime!,
      endTime: _endTime!,
    );

    final excel = Excel.createExcel();
    final sheet = excel['燃气用量'];

    // 表头：设备名称、日期、起始时间、终止时间、起始读数(m³)、截止读数(m³)、当日消耗(m³)
    sheet.appendRow([
      TextCellValue('设备名称'),
      TextCellValue('日期'),
      TextCellValue('起始时间'),
      TextCellValue('终止时间'),
      TextCellValue('起始读数(m³)'),
      TextCellValue('截止读数(m³)'),
      TextCellValue('当日消耗(m³)'),
    ]);

    // 设置列宽（设备名称、日期、起始时间、终止时间、起始读数、截止读数、当日消耗）
    _setColumnWidths(sheet, [18, 15, 28, 28, 18, 18, 18]);

    // 删除默认的Sheet1（必须在创建新sheet之后）
    if (excel.sheets.containsKey('Sheet1')) {
      excel.delete('Sheet1');
    }

    // 遍历设备
    for (var entry in data.entries) {
      final deviceId = entry.key;
      final deviceData = entry.value;
      final dailyRecords = deviceData['daily_records'] as List? ?? [];

      for (var record in dailyRecords) {
        // 格式化日期为 yyyyMMdd
        final dateStr = record['date']?.toString() ?? '';
        final formattedDate = dateStr.replaceAll('-', '');

        sheet.appendRow([
          TextCellValue(_getDeviceName(deviceId)),
          TextCellValue(formattedDate),
          TextCellValue(record['start_time']?.toString() ?? ''),
          TextCellValue(record['end_time']?.toString() ?? ''),
          DoubleCellValue(record['start_reading']?.toDouble() ?? 0.0),
          DoubleCellValue(record['end_reading']?.toDouble() ?? 0.0),
          DoubleCellValue(record['consumption']?.toDouble() ?? 0.0),
        ]);
      }
    }

    await _saveExcel(excel, '燃气用量');
  }

  /// 导出投料量统计
  Future<void> _exportFeedingAmount() async {
    final data = await _exportService.getFeedingAmount(
      startTime: _startTime!,
      endTime: _endTime!,
    );

    final excel = Excel.createExcel();
    final sheet = excel['投料量统计'];

    // 表头：设备名称、日期、起始时间、终止时间、当日投料量(kg)
    sheet.appendRow([
      TextCellValue('设备名称'),
      TextCellValue('日期'),
      TextCellValue('起始时间'),
      TextCellValue('终止时间'),
      TextCellValue('当日投料量(kg)'),
    ]);

    // 设置列宽（设备名称、日期、起始时间、终止时间、当日投料量）
    _setColumnWidths(sheet, [18, 15, 28, 28, 20]);

    // 删除默认的Sheet1（必须在创建新sheet之后）
    if (excel.sheets.containsKey('Sheet1')) {
      excel.delete('Sheet1');
    }

    // 遍历所有料仓
    for (var hopper in data['hoppers'] ?? []) {
      final deviceName = _getDeviceName(hopper['device_id'].toString());

      for (var record in hopper['daily_records'] ?? []) {
        final dailyAmount = record['feeding_amount']?.toDouble() ?? 0.0;

        // 格式化日期为 yyyyMMdd
        final dateStr = record['date']?.toString() ?? '';
        final formattedDate = dateStr.replaceAll('-', '');

        sheet.appendRow([
          TextCellValue(deviceName),
          TextCellValue(formattedDate),
          TextCellValue(record['start_time']?.toString() ?? ''),
          TextCellValue(record['end_time']?.toString() ?? ''),
          DoubleCellValue(dailyAmount),
        ]);
      }
    }

    await _saveExcel(excel, '投料量统计');
  }

  /// 导出所有用电量
  Future<void> _exportElectricityAll() async {
    final data = await _exportService.getAllElectricity(
      startTime: _startTime!,
      endTime: _endTime!,
    );

    final excel = Excel.createExcel();
    final sheet = excel['用电量'];

    // 表头：设备名称、日期、起始时间、终止时间、起始读数(kWh)、截止读数(kWh)、当日消耗(kWh)、运行时长(h)
    sheet.appendRow([
      TextCellValue('设备名称'),
      TextCellValue('日期'),
      TextCellValue('起始时间'),
      TextCellValue('终止时间'),
      TextCellValue('起始读数(kWh)'),
      TextCellValue('截止读数(kWh)'),
      TextCellValue('当日消耗(kWh)'),
      TextCellValue('运行时长(h)'),
    ]);

    // 设置列宽（设备名称、日期、起始时间、终止时间、起始读数、截止读数、当日消耗、运行时长）
    _setColumnWidths(sheet, [18, 15, 28, 28, 18, 18, 18, 18]);

    // 删除默认的Sheet1（必须在创建新sheet之后）
    if (excel.sheets.containsKey('Sheet1')) {
      excel.delete('Sheet1');
    }

    // 回转窑
    for (var hopper in data['hoppers'] ?? []) {
      final dailyRecords = hopper['daily_records'] as List? ?? [];
      for (var record in dailyRecords) {
        // 格式化日期为 yyyyMMdd
        final dateStr = record['date']?.toString() ?? '';
        final formattedDate = dateStr.replaceAll('-', '');

        sheet.appendRow([
          TextCellValue(_getDeviceName(hopper['device_id']?.toString() ?? '')),
          TextCellValue(formattedDate),
          TextCellValue(record['start_time']?.toString() ?? ''),
          TextCellValue(record['end_time']?.toString() ?? ''),
          DoubleCellValue(record['start_reading']?.toDouble() ?? 0.0),
          DoubleCellValue(record['end_reading']?.toDouble() ?? 0.0),
          DoubleCellValue(record['consumption']?.toDouble() ?? 0.0),
          DoubleCellValue(record['runtime_hours']?.toDouble() ?? 0.0),
        ]);
      }
    }

    // 辊道窑6个分区
    for (var zone in data['roller_kiln_zones'] ?? []) {
      final dailyRecords = zone['daily_records'] as List? ?? [];
      for (var record in dailyRecords) {
        final dateStr = record['date']?.toString() ?? '';
        final formattedDate = dateStr.replaceAll('-', '');

        sheet.appendRow([
          TextCellValue(_getDeviceName(zone['device_id']?.toString() ?? '')),
          TextCellValue(formattedDate),
          TextCellValue(record['start_time']?.toString() ?? ''),
          TextCellValue(record['end_time']?.toString() ?? ''),
          DoubleCellValue(record['start_reading']?.toDouble() ?? 0.0),
          DoubleCellValue(record['end_reading']?.toDouble() ?? 0.0),
          DoubleCellValue(record['consumption']?.toDouble() ?? 0.0),
          DoubleCellValue(record['runtime_hours']?.toDouble() ?? 0.0),
        ]);
      }
    }

    // 辊道窑合计
    final rollerTotal = data['roller_kiln_total'];
    if (rollerTotal != null) {
      final dailyRecords = rollerTotal['daily_records'] as List? ?? [];
      for (var record in dailyRecords) {
        final dateStr = record['date']?.toString() ?? '';
        final formattedDate = dateStr.replaceAll('-', '');

        sheet.appendRow([
          TextCellValue(
              _getDeviceName(rollerTotal['device_id']?.toString() ?? '')),
          TextCellValue(formattedDate),
          TextCellValue(record['start_time']?.toString() ?? ''),
          TextCellValue(record['end_time']?.toString() ?? ''),
          DoubleCellValue(record['start_reading']?.toDouble() ?? 0.0),
          DoubleCellValue(record['end_reading']?.toDouble() ?? 0.0),
          DoubleCellValue(record['consumption']?.toDouble() ?? 0.0),
          DoubleCellValue(record['runtime_hours']?.toDouble() ?? 0.0),
        ]);
      }
    }

    // SCR
    for (var scr in data['scr_devices'] ?? []) {
      final dailyRecords = scr['daily_records'] as List? ?? [];
      for (var record in dailyRecords) {
        final dateStr = record['date']?.toString() ?? '';
        final formattedDate = dateStr.replaceAll('-', '');

        sheet.appendRow([
          TextCellValue(_getDeviceName(scr['device_id']?.toString() ?? '')),
          TextCellValue(formattedDate),
          TextCellValue(record['start_time']?.toString() ?? ''),
          TextCellValue(record['end_time']?.toString() ?? ''),
          DoubleCellValue(record['start_reading']?.toDouble() ?? 0.0),
          DoubleCellValue(record['end_reading']?.toDouble() ?? 0.0),
          DoubleCellValue(record['consumption']?.toDouble() ?? 0.0),
          DoubleCellValue(record['runtime_hours']?.toDouble() ?? 0.0),
        ]);
      }
    }

    // 风机
    for (var fan in data['fan_devices'] ?? []) {
      final dailyRecords = fan['daily_records'] as List? ?? [];
      for (var record in dailyRecords) {
        final dateStr = record['date']?.toString() ?? '';
        final formattedDate = dateStr.replaceAll('-', '');

        sheet.appendRow([
          TextCellValue(_getDeviceName(fan['device_id']?.toString() ?? '')),
          TextCellValue(formattedDate),
          TextCellValue(record['start_time']?.toString() ?? ''),
          TextCellValue(record['end_time']?.toString() ?? ''),
          DoubleCellValue(record['start_reading']?.toDouble() ?? 0.0),
          DoubleCellValue(record['end_reading']?.toDouble() ?? 0.0),
          DoubleCellValue(record['consumption']?.toDouble() ?? 0.0),
          DoubleCellValue(record['runtime_hours']?.toDouble() ?? 0.0),
        ]);
      }
    }

    await _saveExcel(excel, '用电量');
  }

  /// 导出综合数据（全部数据）
  Future<void> _exportComprehensive() async {
    final data = await _exportService.getComprehensiveData(
      startTime: _startTime!,
      endTime: _endTime!,
    );

    final excel = Excel.createExcel();

    // ========== Sheet 1: 全部数据（按天） ==========
    final sheet = excel['全部数据'];

    // 表头：设备名称、日期、起始时间、终止时间、燃气当日消耗(m³)、当日投料(kg)、电能当日消耗(kWh)、当日运行时间(h)
    sheet.appendRow([
      TextCellValue('设备名称'),
      TextCellValue('日期'),
      TextCellValue('起始时间'),
      TextCellValue('终止时间'),
      TextCellValue('燃气当日消耗(m³)'),
      TextCellValue('当日投料(kg)'),
      TextCellValue('电能当日消耗(kWh)'),
      TextCellValue('当日运行时间(h)'),
    ]);

    // 设置列宽
    _setColumnWidths(sheet, [18, 15, 28, 28, 20, 18, 20, 20]);

    // 用于计算总计的Map
    Map<String, Map<String, double>> deviceTotals = {};

    // 遍历所有设备
    for (var device in data['devices'] ?? []) {
      final deviceId = device['device_id'].toString();
      final deviceName = _getDeviceName(deviceId);
      final deviceType = device['device_type'].toString();

      // 初始化设备总计
      if (!deviceTotals.containsKey(deviceId)) {
        deviceTotals[deviceId] = {
          'gas': 0.0,
          'feeding': 0.0,
          'electricity': 0.0,
          'runtime': 0.0,
        };
      }

      for (var record in device['daily_records'] ?? []) {
        // 格式化日期为 yyyyMMdd
        final dateStr = record['date']?.toString() ?? '';
        final formattedDate = dateStr.replaceAll('-', '');

        final gasConsumption = record['gas_consumption']?.toDouble() ?? 0.0;
        final feedingAmount = record['feeding_amount']?.toDouble() ?? 0.0;
        final electricityConsumption =
            record['electricity_consumption']?.toDouble() ?? 0.0;
        final runtimeHours = record['runtime_hours']?.toDouble() ?? 0.0;

        // 累加到总计
        deviceTotals[deviceId]!['gas'] =
            deviceTotals[deviceId]!['gas']! + gasConsumption;
        deviceTotals[deviceId]!['feeding'] =
            deviceTotals[deviceId]!['feeding']! + feedingAmount;
        deviceTotals[deviceId]!['electricity'] =
            deviceTotals[deviceId]!['electricity']! + electricityConsumption;
        deviceTotals[deviceId]!['runtime'] =
            deviceTotals[deviceId]!['runtime']! + runtimeHours;

        // 根据设备类型决定显示哪些数据
        CellValue? gasCell;
        CellValue? feedingCell;
        CellValue? electricityCell;
        CellValue? runtimeCell;

        if (deviceType == 'hopper') {
          // 回转窑：投料、电能、运行时长（燃气为空）
          gasCell = TextCellValue('');
          feedingCell = DoubleCellValue(feedingAmount);
          electricityCell = DoubleCellValue(electricityConsumption);
          runtimeCell = DoubleCellValue(runtimeHours);
        } else if (deviceType == 'roller_kiln_zone' ||
            deviceType == 'roller_kiln_total') {
          // 辊道窑：电能、运行时长（燃气、投料为空）
          gasCell = TextCellValue('');
          feedingCell = TextCellValue('');
          electricityCell = DoubleCellValue(electricityConsumption);
          runtimeCell = DoubleCellValue(runtimeHours);
        } else if (deviceType == 'scr') {
          // SCR燃气表：燃气、运行时长（电能、投料为空）
          gasCell = DoubleCellValue(gasConsumption);
          feedingCell = TextCellValue('');
          electricityCell = TextCellValue('');
          runtimeCell = DoubleCellValue(runtimeHours);
        } else if (deviceType == 'scr_pump' || deviceType == 'fan') {
          // SCR氨水泵、风机：电能、运行时长（燃气、投料为空）
          gasCell = TextCellValue('');
          feedingCell = TextCellValue('');
          electricityCell = DoubleCellValue(electricityConsumption);
          runtimeCell = DoubleCellValue(runtimeHours);
        } else {
          // 默认：全部显示
          gasCell = DoubleCellValue(gasConsumption);
          feedingCell = DoubleCellValue(feedingAmount);
          electricityCell = DoubleCellValue(electricityConsumption);
          runtimeCell = DoubleCellValue(runtimeHours);
        }

        sheet.appendRow([
          TextCellValue(deviceName),
          TextCellValue(formattedDate),
          TextCellValue(record['start_time']?.toString() ?? ''),
          TextCellValue(record['end_time']?.toString() ?? ''),
          gasCell,
          feedingCell,
          electricityCell,
          runtimeCell,
        ]);
      }
    }

    // ========== Sheet 2: 用量总计 ==========
    final summarySheet = excel['用量总计'];

    // 表头：设备名称、日期、起始时间、终止时间、能耗用量总计(kWh)、投料总计(kg)、燃气用量总计(m³)、运行时长总计(h)
    summarySheet.appendRow([
      TextCellValue('设备名称'),
      TextCellValue('日期'),
      TextCellValue('起始时间'),
      TextCellValue('终止时间'),
      TextCellValue('能耗用量总计(kWh)'),
      TextCellValue('投料总计(kg)'),
      TextCellValue('燃气用量总计(m³)'),
      TextCellValue('运行时长总计(h)'),
    ]);

    // 设置列宽
    _setColumnWidths(summarySheet, [18, 20, 28, 28, 20, 18, 20, 20]);

    // 遍历所有设备，输出总计
    for (var device in data['devices'] ?? []) {
      final deviceId = device['device_id'].toString();
      final deviceName = _getDeviceName(deviceId);
      final deviceType = device['device_type'].toString();
      final totals = deviceTotals[deviceId]!;

      // 获取该设备的第一条和最后一条记录的时间
      final dailyRecords = device['daily_records'] as List? ?? [];
      String dateRange = '';
      String startTime = '';
      String endTime = '';

      if (dailyRecords.isNotEmpty) {
        final firstRecord = dailyRecords.first;
        final lastRecord = dailyRecords.last;

        // 格式化日期范围：20260120-20260126
        final firstDate = firstRecord['date']?.toString() ?? '';
        final lastDate = lastRecord['date']?.toString() ?? '';
        dateRange =
            '${firstDate.replaceAll('-', '')}-${lastDate.replaceAll('-', '')}';

        // 起始时间和终止时间
        startTime = firstRecord['start_time']?.toString() ?? '';
        endTime = lastRecord['end_time']?.toString() ?? '';
      }

      // 根据设备类型决定显示哪些总计
      CellValue? electricityCell;
      CellValue? feedingCell;
      CellValue? gasCell;
      CellValue? runtimeCell;

      if (deviceType == 'hopper') {
        // 回转窑：电能、投料、运行时长（燃气为空）
        electricityCell = DoubleCellValue(totals['electricity']!);
        feedingCell = DoubleCellValue(totals['feeding']!);
        gasCell = TextCellValue('');
        runtimeCell = DoubleCellValue(totals['runtime']!);
      } else if (deviceType == 'roller_kiln_zone' ||
          deviceType == 'roller_kiln_total') {
        // 辊道窑：电能、运行时长（燃气、投料为空）
        electricityCell = DoubleCellValue(totals['electricity']!);
        feedingCell = TextCellValue('');
        gasCell = TextCellValue('');
        runtimeCell = DoubleCellValue(totals['runtime']!);
      } else if (deviceType == 'scr') {
        // SCR燃气表：燃气、运行时长（电能、投料为空）
        electricityCell = TextCellValue('');
        feedingCell = TextCellValue('');
        gasCell = DoubleCellValue(totals['gas']!);
        runtimeCell = DoubleCellValue(totals['runtime']!);
      } else if (deviceType == 'scr_pump' || deviceType == 'fan') {
        // SCR氨水泵、风机：电能、运行时长（燃气、投料为空）
        electricityCell = DoubleCellValue(totals['electricity']!);
        feedingCell = TextCellValue('');
        gasCell = TextCellValue('');
        runtimeCell = DoubleCellValue(totals['runtime']!);
      } else {
        // 默认：全部显示
        electricityCell = DoubleCellValue(totals['electricity']!);
        feedingCell = DoubleCellValue(totals['feeding']!);
        gasCell = DoubleCellValue(totals['gas']!);
        runtimeCell = DoubleCellValue(totals['runtime']!);
      }

      summarySheet.appendRow([
        TextCellValue(deviceName),
        TextCellValue(dateRange),
        TextCellValue(startTime),
        TextCellValue(endTime),
        electricityCell,
        feedingCell,
        gasCell,
        runtimeCell,
      ]);
    }

    // 删除默认的Sheet1
    if (excel.sheets.containsKey('Sheet1')) {
      excel.delete('Sheet1');
    }

    await _saveExcel(excel, '全部数据');
  }

  /// 保存Excel文件
  Future<void> _saveExcel(Excel excel, String baseName) async {
    try {
      final timestamp = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
      final fileName = '${baseName}_$timestamp.xlsx';

      // 使用文件选择器让用户选择保存位置
      String? outputPath = await FilePicker.platform.saveFile(
        dialogTitle: '保存Excel文件',
        fileName: fileName,
        type: FileType.custom,
        allowedExtensions: ['xlsx'],
      );

      if (outputPath == null) {
        // 用户取消了保存
        throw Exception('用户取消了保存操作');
      }

      // 确保文件扩展名为 .xlsx
      if (!outputPath.toLowerCase().endsWith('.xlsx')) {
        outputPath = '$outputPath.xlsx';
      }

      // 编码Excel数据
      final bytes = excel.encode();
      if (bytes == null) {
        throw Exception('Excel数据编码失败');
      }

      // 保存文件
      final file = File(outputPath);
      await file.writeAsBytes(bytes);

      print(' 文件已保存: $outputPath');

      // 更新成功消息，显示保存路径
      if (mounted) {
        _showMessage('导出成功！文件已保存到: $outputPath', isError: false);
      }
    } catch (e) {
      print(' 保存文件失败: $e');
      rethrow;
    }
  }

  /// 显示消息
  void _showMessage(String message, {required bool isError}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor:
            isError ? TechColors.statusAlarm : TechColors.statusNormal,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      child: GlowBorderContainer(
        width: 600,
        glowColor: TechColors.glowCyan,
        glowIntensity: 0.3,
        padding: EdgeInsets.zero,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // 标题栏
            _buildHeader(),
            // 内容区
            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // 时间选择区域
                  _buildTimeSelection(),
                  const SizedBox(height: 20),
                  // 导出类型选择
                  _buildExportTypeSelection(),
                  const SizedBox(height: 24),
                  // 操作按钮
                  _buildActionButtons(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 构建标题栏
  Widget _buildHeader() {
    return Container(
      height: 50,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: TechColors.bgMedium.withOpacity(0.5),
        border: Border(
          bottom: BorderSide(
            color: TechColors.glowCyan.withOpacity(0.3),
          ),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 3,
            height: 20,
            decoration: BoxDecoration(
              color: TechColors.glowCyan,
              borderRadius: BorderRadius.circular(1),
            ),
          ),
          const SizedBox(width: 12),
          Text(
            '数据导出',
            style: TextStyle(
              color: TechColors.textPrimary,
              fontSize: 32,
              fontWeight: FontWeight.w600,
              letterSpacing: 1,
              shadows: [
                Shadow(
                  color: TechColors.glowCyan.withOpacity(0.5),
                  blurRadius: 8,
                ),
              ],
            ),
          ),
          const Spacer(),
          IconButton(
            icon: const Icon(Icons.close, color: TechColors.textSecondary),
            onPressed: () => Navigator.of(context).pop(),
            iconSize: 20,
          ),
        ],
      ),
    );
  }

  /// 构建时间选择区域
  Widget _buildTimeSelection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 标题
        Row(
          children: [
            Container(
              width: 2,
              height: 14,
              color: TechColors.glowCyan,
            ),
            const SizedBox(width: 8),
            const Text(
              '时间范围',
              style: TextStyle(
                color: TechColors.textPrimary,
                fontSize: 28,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        // 快速选择按钮
        Row(
          children: [
            Expanded(child: _buildQuickTimeButton('最近 1 天', 1)),
            const SizedBox(width: 8),
            Expanded(child: _buildQuickTimeButton('最近 3 天', 3)),
            const SizedBox(width: 8),
            Expanded(child: _buildQuickTimeButton('最近 5 天', 5)),
            const SizedBox(width: 8),
            Expanded(child: _buildQuickTimeButton('最近 7 天', 7)),
            const SizedBox(width: 8),
            Expanded(child: _buildQuickTimeButton('最近 30 天', 30)),
          ],
        ),
        const SizedBox(height: 16),
        // 自定义时间选择
        Row(
          children: [
            Expanded(
                child:
                    _buildTimeSelector('开始时间', _startTime, _selectStartTime)),
            const SizedBox(width: 12),
            const Icon(Icons.arrow_forward,
                color: TechColors.textSecondary, size: 16),
            const SizedBox(width: 12),
            Expanded(
                child: _buildTimeSelector('结束时间', _endTime, _selectEndTime)),
          ],
        ),
      ],
    );
  }

  /// 构建快速时间按钮
  Widget _buildQuickTimeButton(String label, int days) {
    final isSelected = _selectedQuickDays == days;

    return GestureDetector(
      onTap: () => _updateTimeRange(days),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected
              ? TechColors.glowCyan.withOpacity(0.2)
              : TechColors.bgLight.withOpacity(0.3),
          border: Border.all(
            color: isSelected ? TechColors.glowCyan : TechColors.borderDark,
          ),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Container(
          alignment: Alignment.center,
          child: Text(
            label,
            maxLines: 1,
            softWrap: false,
            overflow: TextOverflow.visible,
            textAlign: TextAlign.center,
            style: TextStyle(
              color:
                  isSelected ? TechColors.glowCyan : TechColors.textSecondary,
              fontSize: 18,
              fontWeight: isSelected ? FontWeight.w500 : FontWeight.normal,
            ),
          ),
        ),
      ),
    );
  }

  /// 构建时间选择器
  Widget _buildTimeSelector(String label, DateTime? time, VoidCallback onTap) {
    final dateFormat = DateFormat('yyyy-MM-dd HH:mm');

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: TechColors.bgLight.withOpacity(0.3),
          border: Border.all(color: TechColors.borderDark),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: const TextStyle(
                color: TechColors.textSecondary,
                fontSize: 22,
              ),
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                const Icon(Icons.calendar_today,
                    color: TechColors.glowCyan, size: 14),
                const SizedBox(width: 8),
                Text(
                  time != null ? dateFormat.format(time) : '选择时间',
                  style: const TextStyle(
                    color: TechColors.textPrimary,
                    fontSize: 26,
                    fontFamily: 'Roboto Mono',
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  /// 构建导出类型选择
  Widget _buildExportTypeSelection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 标题
        Row(
          children: [
            Container(
              width: 2,
              height: 14,
              color: TechColors.glowCyan,
            ),
            const SizedBox(width: 8),
            const Text(
              '导出类型',
              style: TextStyle(
                color: TechColors.textPrimary,
                fontSize: 28,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        // 导出类型下拉框
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: TechColors.bgLight.withOpacity(0.3),
            border: Border.all(color: TechColors.glowCyan.withOpacity(0.3)),
            borderRadius: BorderRadius.circular(4),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<ExportType>(
              value: _selectedExportType,
              isExpanded: true,
              icon:
                  const Icon(Icons.arrow_drop_down, color: TechColors.glowCyan),
              dropdownColor: TechColors.bgMedium,
              style: const TextStyle(
                color: TechColors.textPrimary,
                fontSize: 26,
              ),
              onChanged: (ExportType? value) {
                if (value != null) {
                  setState(() {
                    _selectedExportType = value;
                  });
                }
              },
              items: const [
                DropdownMenuItem(
                  value: ExportType.runtime,
                  child: Text('设备运行时长'),
                ),
                DropdownMenuItem(
                  value: ExportType.gasConsumption,
                  child: Text('燃气用量'),
                ),
                DropdownMenuItem(
                  value: ExportType.feedingAmount,
                  child: Text('投料量统计'),
                ),
                DropdownMenuItem(
                  value: ExportType.electricityAll,
                  child: Text('用电量'),
                ),
                DropdownMenuItem(
                  value: ExportType.comprehensive,
                  child: Text('全部数据'),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 8),
        // 说明文字
        Text(
          _getExportTypeDescription(),
          style: const TextStyle(
            color: TechColors.textMuted,
            fontSize: 22,
          ),
        ),
      ],
    );
  }

  /// 获取导出类型说明
  String _getExportTypeDescription() {
    switch (_selectedExportType) {
      case ExportType.runtime:
        return '导出所有设备（回转窑、辊道窑、SCR、风机）的设备运行时长';
      case ExportType.gasConsumption:
        return '导出SCR设备的燃气用量统计（按天）';
      case ExportType.feedingAmount:
        return '导出所有料仓的投料量统计（按天）';
      case ExportType.electricityAll:
        return '导出所有设备的用电量统计（按天，含运行时长）';
      case ExportType.comprehensive:
        return '导出所有设备的全部数据（燃气、投料、电量、运行时长），建议最多查询30天';
    }
  }

  /// 构建操作按钮
  Widget _buildActionButtons() {
    return Row(
      children: [
        Expanded(
          child: _buildButton(
            label: '取消',
            onPressed: () => Navigator.of(context).pop(),
            isPrimary: false,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildButton(
            label: _isExporting ? '导出中...' : '导出',
            onPressed: _isExporting ? null : _performExport,
            isPrimary: true,
          ),
        ),
      ],
    );
  }

  /// 构建按钮
  Widget _buildButton({
    required String label,
    required VoidCallback? onPressed,
    required bool isPrimary,
  }) {
    return GestureDetector(
      onTap: onPressed,
      child: Container(
        height: 40,
        decoration: BoxDecoration(
          color: isPrimary
              ? TechColors.glowOrange
                  .withOpacity(onPressed == null ? 0.1 : 0.05)
              : TechColors.bgLight.withOpacity(0.3),
          border: Border.all(
            color: isPrimary
                ? TechColors.glowOrange
                    .withOpacity(onPressed == null ? 0.3 : 0.5)
                : TechColors.borderDark,
          ),
          borderRadius: BorderRadius.circular(4),
          boxShadow: isPrimary && onPressed != null
              ? [
                  BoxShadow(
                    color: TechColors.glowOrange.withOpacity(0.3),
                    blurRadius: 8,
                  ),
                ]
              : null,
        ),
        child: Center(
          child: Text(
            label,
            style: TextStyle(
              color: isPrimary
                  ? (onPressed == null
                      ? TechColors.textMuted
                      : TechColors.glowOrange)
                  : TechColors.textSecondary,
              fontSize: 28,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ),
    );
  }
}

/// 导出类型枚举
enum ExportType {
  runtime, // 运行时长
  gasConsumption, // 燃气流量
  feedingAmount, // 投料量
  electricityAll, // 用电量
  comprehensive, // 综合导出全部数据
}

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/alarm_model.dart';
import '../services/alarm_service.dart';
import '../widgets/data_display/data_tech_line_widgets.dart';

// ============================================================
// 报警记录页面 - 六宫格布局
// ============================================================
// 6个分类: 回转窑温度/回转窑功率/辊道窑温度/SCR功率/SCR燃气/风机功率
// 顶部: 时间范围选择 + 查询全部 + 重置
// 每格: 标题 + 设备下拉框 + 查询按钮 + 数据表格
// ============================================================

// -- 宫格配置 --
class _GridConfig {
  final String title;
  final String paramPrefix;
  final Map<String, String> devices; // 显示名 -> suffix

  const _GridConfig({
    required this.title,
    required this.paramPrefix,
    required this.devices,
  });
}

// -- 设备 ID -> 显示名 映射 --
const _deviceNameMap = <String, String>{
  'short_hopper_1': '窑7',
  'short_hopper_2': '窑6',
  'short_hopper_3': '窑5',
  'short_hopper_4': '窑4',
  'no_hopper_1': '窑2',
  'no_hopper_2': '窑1',
  'long_hopper_1': '窑8',
  'long_hopper_2': '窑3',
  'long_hopper_3': '窑9',
  'roller_kiln_1': '辊道窑',
  'fan_1': '风机1',
  'fan_2': '风机2',
  'scr_1': 'SCR1',
  'scr_2': 'SCR2',
};

// -- 回转窑设备下拉选项 --
const _kilnDevices = <String, String>{
  '全部': '',
  '窑7': '_short_hopper_1',
  '窑6': '_short_hopper_2',
  '窑5': '_short_hopper_3',
  '窑4': '_short_hopper_4',
  '窑2': '_no_hopper_1',
  '窑1': '_no_hopper_2',
  '窑8': '_long_hopper_1',
  '窑3': '_long_hopper_2',
  '窑9': '_long_hopper_3',
};

// -- 6个宫格定义 --
const _gridConfigs = <_GridConfig>[
  _GridConfig(
    title: '回转窑温度',
    paramPrefix: 'rotary_temp',
    devices: _kilnDevices,
  ),
  _GridConfig(
    title: '回转窑功率',
    paramPrefix: 'rotary_power',
    devices: _kilnDevices,
  ),
  _GridConfig(
    title: '辊道窑温度',
    paramPrefix: 'roller_temp',
    devices: <String, String>{
      '全部': '',
      '温区1': '_zone1',
      '温区2': '_zone2',
      '温区3': '_zone3',
      '温区4': '_zone4',
      '温区5': '_zone5',
      '温区6': '_zone6',
    },
  ),
  _GridConfig(
    title: 'SCR功率',
    paramPrefix: 'scr_power',
    devices: <String, String>{'全部': '', 'SCR1': '_1', 'SCR2': '_2'},
  ),
  _GridConfig(
    title: 'SCR燃气',
    paramPrefix: 'scr_gas',
    devices: <String, String>{'全部': '', 'SCR1': '_1', 'SCR2': '_2'},
  ),
  _GridConfig(
    title: '风机功率',
    paramPrefix: 'fan_power',
    devices: <String, String>{'全部': '', '风机1': '_1', '风机2': '_2'},
  ),
];

class AlarmRecordsPage extends StatefulWidget {
  const AlarmRecordsPage({super.key});

  @override
  State<AlarmRecordsPage> createState() => AlarmRecordsPageState();
}

class AlarmRecordsPageState extends State<AlarmRecordsPage> {
  final AlarmService _alarmService = AlarmService();
  final DateFormat _dtFmt = DateFormat('MM-dd HH:mm:ss');
  final DateFormat _dateFmt = DateFormat('yyyy-MM-dd');

  // 共享时间范围 (默认最近24小时)
  DateTime _startTime = DateTime.now().subtract(const Duration(hours: 24));
  DateTime _endTime = DateTime.now();

  // 每个宫格的状态
  final List<String> _selectedDeviceKeys = List.filled(6, '全部');
  final List<List<AlarmRecord>> _gridRecords = List.generate(6, (_) => []);
  final List<bool> _gridLoading = List.filled(6, false);

  // -- 供 top_bar 调用 --
  void resumePolling() {}
  void pausePolling() {}

  // ============================================================
  // 时间选择
  // ============================================================

  Future<void> _pickStartDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _startTime,
      firstDate: DateTime.now().subtract(const Duration(days: 90)),
      lastDate: _endTime,
      builder: _darkThemeBuilder,
    );
    if (picked != null && mounted) {
      setState(() {
        _startTime = DateTime(picked.year, picked.month, picked.day);
      });
    }
  }

  Future<void> _pickEndDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _endTime,
      firstDate: _startTime,
      lastDate: DateTime.now().add(const Duration(days: 1)),
      builder: _darkThemeBuilder,
    );
    if (picked != null && mounted) {
      setState(() {
        _endTime =
            DateTime(picked.year, picked.month, picked.day, 23, 59, 59);
      });
    }
  }

  Widget Function(BuildContext, Widget?) get _darkThemeBuilder =>
      (context, child) => Theme(
            data: ThemeData.dark().copyWith(
              colorScheme: const ColorScheme.dark(
                primary: TechColors.glowCyan,
                onPrimary: TechColors.bgDeep,
                surface: TechColors.bgMedium,
                onSurface: TechColors.textPrimary,
              ),
            ),
            child: child!,
          );

  // ============================================================
  // 数据查询
  // ============================================================

  // 查询全部6个宫格
  Future<void> _queryAll() async {
    for (int i = 0; i < 6; i++) {
      _queryGrid(i);
    }
  }

  // 查询单个宫格
  Future<void> _queryGrid(int index) async {
    if (_gridLoading[index]) return;
    setState(() => _gridLoading[index] = true);

    final config = _gridConfigs[index];
    final deviceKey = _selectedDeviceKeys[index];
    final suffix = config.devices[deviceKey] ?? '';
    final paramPrefix = '${config.paramPrefix}$suffix';

    try {
      final records = await _alarmService.queryAlarms(
        start: _startTime,
        end: _endTime,
        paramPrefix: paramPrefix,
        limit: 100,
      );
      if (mounted) {
        setState(() {
          _gridRecords[index] = records;
          _gridLoading[index] = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _gridLoading[index] = false);
      }
      debugPrint('[AlarmRecordsPage] grid $index query error: $e');
    }
  }

  // 重置为最近24小时
  void _resetTimeRange() {
    setState(() {
      _startTime = DateTime.now().subtract(const Duration(hours: 24));
      _endTime = DateTime.now();
    });
  }

  // ============================================================
  // 设备名称辅助
  // ============================================================

  String _getDeviceLabel(AlarmRecord record) {
    if (record.deviceId == 'roller_kiln_1') {
      final match = RegExp(r'zone(\d+)').firstMatch(record.paramName);
      if (match != null) return '温区${match.group(1)}';
      return '辊道窑';
    }
    return _deviceNameMap[record.deviceId] ?? record.deviceId;
  }

  // ============================================================
  // UI
  // ============================================================

  @override
  Widget build(BuildContext context) {
    return Container(
      color: TechColors.bgDeep,
      padding: const EdgeInsets.all(12),
      child: Column(
        children: [
          // 顶部筛选栏
          _buildTopFilterBar(),
          const SizedBox(height: 10),
          // 六宫格 (3列 x 2行)
          Expanded(
            child: Column(
              children: [
                Expanded(
                  child: Row(
                    children: [
                      Expanded(child: _buildGridCard(0)),
                      const SizedBox(width: 8),
                      Expanded(child: _buildGridCard(1)),
                      const SizedBox(width: 8),
                      Expanded(child: _buildGridCard(2)),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                Expanded(
                  child: Row(
                    children: [
                      Expanded(child: _buildGridCard(3)),
                      const SizedBox(width: 8),
                      Expanded(child: _buildGridCard(4)),
                      const SizedBox(width: 8),
                      Expanded(child: _buildGridCard(5)),
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

  // -- 顶部筛选栏 --
  Widget _buildTopFilterBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: TechColors.bgDark,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: TechColors.glowCyan.withOpacity(0.2)),
      ),
      child: Row(
        children: [
          _buildDateButton(
            label: '开始',
            value: _dateFmt.format(_startTime),
            onTap: _pickStartDate,
          ),
          const SizedBox(width: 10),
          const Text('至',
              style: TextStyle(color: TechColors.textSecondary, fontSize: 13)),
          const SizedBox(width: 10),
          _buildDateButton(
            label: '结束',
            value: _dateFmt.format(_endTime),
            onTap: _pickEndDate,
          ),
          const SizedBox(width: 20),
          _buildActionButton(
            label: '查询',
            color: TechColors.glowCyan,
            onTap: _queryAll,
          ),
          const SizedBox(width: 8),
          _buildActionButton(
            label: '重置',
            color: TechColors.textSecondary,
            onTap: _resetTimeRange,
          ),
          const Spacer(),
        ],
      ),
    );
  }

  Widget _buildDateButton({
    required String label,
    required String value,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: TechColors.bgMedium,
          borderRadius: BorderRadius.circular(4),
          border: Border.all(color: TechColors.borderDark),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.calendar_today,
                size: 14, color: TechColors.glowCyan),
            const SizedBox(width: 6),
            Text(
              '$label: $value',
              style: const TextStyle(
                  color: TechColors.textPrimary, fontSize: 13),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionButton({
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 7),
        decoration: BoxDecoration(
          color: color.withOpacity(0.12),
          borderRadius: BorderRadius.circular(4),
          border: Border.all(color: color.withOpacity(0.5)),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: color,
            fontSize: 13,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    );
  }

  // ============================================================
  // 单个宫格卡片
  // ============================================================

  Widget _buildGridCard(int index) {
    final config = _gridConfigs[index];
    final records = _gridRecords[index];
    final isLoading = _gridLoading[index];

    return Container(
      decoration: BoxDecoration(
        color: TechColors.bgDark,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: TechColors.glowCyan.withOpacity(0.2)),
      ),
      child: Column(
        children: [
          _buildGridHeader(index, config),
          Expanded(child: _buildGridTable(index, records, isLoading, config)),
        ],
      ),
    );
  }

  // -- 宫格头部 --
  Widget _buildGridHeader(int index, _GridConfig config) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: TechColors.bgMedium,
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(5),
          topRight: Radius.circular(5),
        ),
        border: Border(
          bottom: BorderSide(color: TechColors.glowCyan.withOpacity(0.2)),
        ),
      ),
      child: Row(
        children: [
          Text(
            config.title,
            style: const TextStyle(
              color: TechColors.glowCyan,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(width: 10),
          _buildDeviceDropdown(index, config),
          const Spacer(),
          _buildSmallButton(
            label: '查询',
            onTap: () => _queryGrid(index),
          ),
        ],
      ),
    );
  }

  Widget _buildDeviceDropdown(int index, _GridConfig config) {
    final keys = config.devices.keys.toList();

    return Container(
      height: 26,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      decoration: BoxDecoration(
        color: TechColors.bgDeep,
        borderRadius: BorderRadius.circular(3),
        border: Border.all(color: TechColors.borderDark),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: _selectedDeviceKeys[index],
          dropdownColor: TechColors.bgMedium,
          isDense: true,
          style: const TextStyle(
            color: TechColors.textPrimary,
            fontSize: 12,
          ),
          icon: const Icon(Icons.arrow_drop_down,
              color: TechColors.textSecondary, size: 16),
          items: keys.map((k) {
            return DropdownMenuItem(value: k, child: Text(k));
          }).toList(),
          onChanged: (v) {
            if (v != null) {
              setState(() => _selectedDeviceKeys[index] = v);
            }
          },
        ),
      ),
    );
  }

  Widget _buildSmallButton({
    required String label,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
        decoration: BoxDecoration(
          color: TechColors.glowCyan.withOpacity(0.12),
          borderRadius: BorderRadius.circular(3),
          border: Border.all(color: TechColors.glowCyan.withOpacity(0.4)),
        ),
        child: Text(
          label,
          style: const TextStyle(
            color: TechColors.glowCyan,
            fontSize: 11,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    );
  }

  // ============================================================
  // 宫格内表格
  // ============================================================

  Widget _buildGridTable(
      int index, List<AlarmRecord> records, bool isLoading, _GridConfig config) {
    // 多设备 + 选择"全部"时才显示设备列
    final showDeviceCol =
        config.devices.length > 2 && _selectedDeviceKeys[index] == '全部';

    return Column(
      children: [
        _buildTableHeaderRow(showDeviceCol),
        Expanded(
          child: isLoading
              ? const Center(
                  child: SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 1.5,
                      color: TechColors.glowCyan,
                    ),
                  ),
                )
              : records.isEmpty
                  ? Center(
                      child: Text(
                        '暂无报警记录',
                        style: TextStyle(
                          color: TechColors.textMuted,
                          fontSize: 12,
                        ),
                      ),
                    )
                  : ListView.builder(
                      itemCount: records.length,
                      padding: EdgeInsets.zero,
                      itemBuilder: (context, i) {
                        return _buildRecordRow(records[i], i, showDeviceCol);
                      },
                    ),
        ),
      ],
    );
  }

  Widget _buildTableHeaderRow(bool showDeviceCol) {
    const style = TextStyle(
      color: TechColors.textSecondary,
      fontSize: 11,
      fontWeight: FontWeight.w500,
    );
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: TechColors.bgMedium.withOpacity(0.5),
        border: Border(
          bottom: BorderSide(color: TechColors.borderDark.withOpacity(0.5)),
        ),
      ),
      child: Row(
        children: [
          const Expanded(flex: 4, child: Text('时间', style: style)),
          if (showDeviceCol)
            const Expanded(flex: 2, child: Text('设备', style: style)),
          const Expanded(flex: 2, child: Text('实测值', style: style)),
          const Expanded(flex: 2, child: Text('阈值', style: style)),
        ],
      ),
    );
  }

  Widget _buildRecordRow(AlarmRecord record, int index, bool showDeviceCol) {
    final isEven = index % 2 == 0;
    final timeStr = DateTime.tryParse(record.time) != null
        ? _dtFmt.format(DateTime.parse(record.time).toLocal())
        : record.time;
    final valueStr =
        record.value != null ? record.value!.toStringAsFixed(1) : '-';
    final threshStr =
        record.threshold != null ? record.threshold!.toStringAsFixed(1) : '-';

    const rowTextStyle = TextStyle(
      color: TechColors.textPrimary,
      fontSize: 11,
      fontFamily: 'Roboto Mono',
    );

    return Container(
      color:
          isEven ? Colors.transparent : TechColors.bgMedium.withOpacity(0.2),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: Row(
        children: [
          Expanded(
            flex: 4,
            child: Text(
              timeStr,
              style: const TextStyle(
                color: TechColors.textSecondary,
                fontSize: 11,
                fontFamily: 'Roboto Mono',
              ),
            ),
          ),
          if (showDeviceCol)
            Expanded(
              flex: 2,
              child: Text(_getDeviceLabel(record), style: rowTextStyle),
            ),
          Expanded(
            flex: 2,
            child: Text(
              valueStr,
              style: const TextStyle(
                color: TechColors.glowRed,
                fontSize: 11,
                fontFamily: 'Roboto Mono',
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(threshStr, style: rowTextStyle),
          ),
        ],
      ),
    );
  }
}

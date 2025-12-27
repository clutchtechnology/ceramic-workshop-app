import 'package:flutter/material.dart';
import 'dart:async';
import '../models/sensor_health_model.dart';
import '../services/sensor_health_service.dart';
import '../widgets/data_display/data_tech_line_widgets.dart';
import '../utils/app_logger.dart';

/// 传感器健康监控页面
/// 检查每个传感器在最近N分钟内是否有数据写入
class SensorHealthPage extends StatefulWidget {
  const SensorHealthPage({super.key});

  @override
  State<SensorHealthPage> createState() => _SensorHealthPageState();
}

class _SensorHealthPageState extends State<SensorHealthPage> {
  final SensorHealthService _healthService = SensorHealthService();

  Timer? _timer;
  SensorHealthResponse? _healthData;
  bool _isLoading = true;
  String? _errorMessage;

  // 检查时间范围（分钟）
  int _checkMinutes = 30;

  // 可选的时间范围
  final List<int> _minuteOptions = [10, 30, 60, 120, 360, 720, 1440];

  @override
  void initState() {
    super.initState();
    _fetchData();
    // 每60秒自动刷新一次
    _timer = Timer.periodic(const Duration(seconds: 60), (_) => _fetchData());
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _fetchData() async {
    if (!mounted) return;

    setState(() {
      _isLoading = _healthData == null; // 首次加载显示loading
      _errorMessage = null;
    });

    try {
      final response =
          await _healthService.getSensorHealth(minutes: _checkMinutes);

      if (mounted) {
        setState(() {
          _isLoading = false;
          if (response.success && response.data != null) {
            _healthData = response.data;
          } else {
            _errorMessage = response.error ?? '获取数据失败';
          }
        });
      }
    } catch (e, stack) {
      logger.error('获取传感器健康数据失败', e, stack);
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = '网络错误: $e';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: TechColors.bgDeep,
      body: Column(
        children: [
          _buildHeader(),
          Expanded(
            child: _isLoading
                ? _buildLoadingWidget()
                : _errorMessage != null
                    ? _buildErrorWidget()
                    : _buildContent(),
          ),
        ],
      ),
    );
  }

  /// 顶部状态栏
  Widget _buildHeader() {
    final summary = _healthData?.summary;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: TechColors.bgDark,
        border: Border(
          bottom: BorderSide(
            color: TechColors.borderDark.withOpacity(0.5),
            width: 1,
          ),
        ),
      ),
      child: Row(
        children: [
          // 标题
          const Icon(
            Icons.monitor_heart,
            color: TechColors.glowCyan,
            size: 24,
          ),
          const SizedBox(width: 8),
          const Text(
            '传感器健康监控',
            style: TextStyle(
              color: TechColors.textPrimary,
              fontSize: 20,
              fontWeight: FontWeight.bold,
              fontFamily: 'Roboto Mono',
            ),
          ),
          const SizedBox(width: 24),
          // 时间范围选择
          _buildTimeRangeSelector(),
          const Spacer(),
          // 统计信息
          if (summary != null) ...[
            _buildStatChip('总计', summary.total, TechColors.glowCyan),
            const SizedBox(width: 12),
            _buildStatChip('正常', summary.healthy, TechColors.glowGreen),
            const SizedBox(width: 12),
            _buildStatChip('异常', summary.unhealthy, TechColors.glowRed),
          ],
          const SizedBox(width: 16),
          // 刷新按钮
          IconButton(
            onPressed: _isLoading ? null : _fetchData,
            icon: _isLoading
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: TechColors.glowCyan,
                    ),
                  )
                : const Icon(Icons.refresh, color: TechColors.glowCyan),
            tooltip: '刷新',
          ),
        ],
      ),
    );
  }

  /// 时间范围选择器
  Widget _buildTimeRangeSelector() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: TechColors.bgMedium,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: TechColors.borderDark),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<int>(
          value: _checkMinutes,
          dropdownColor: TechColors.bgDark,
          style: const TextStyle(
            color: TechColors.textPrimary,
            fontSize: 14,
            fontFamily: 'Roboto Mono',
          ),
          items: _minuteOptions.map((minutes) {
            String label;
            if (minutes < 60) {
              label = '$minutes 分钟';
            } else if (minutes < 1440) {
              label = '${minutes ~/ 60} 小时';
            } else {
              label = '${minutes ~/ 1440} 天';
            }
            return DropdownMenuItem(
              value: minutes,
              child: Text('检查范围: $label'),
            );
          }).toList(),
          onChanged: (value) {
            if (value != null) {
              setState(() => _checkMinutes = value);
              _fetchData();
            }
          },
        ),
      ),
    );
  }

  /// 统计标签
  Widget _buildStatChip(String label, int count, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(label, style: TextStyle(color: color, fontSize: 12)),
          const SizedBox(width: 6),
          Text(
            '$count',
            style: TextStyle(
              color: color,
              fontSize: 14,
              fontWeight: FontWeight.bold,
              fontFamily: 'Roboto Mono',
            ),
          ),
        ],
      ),
    );
  }

  /// 加载中
  Widget _buildLoadingWidget() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(color: TechColors.glowCyan),
          SizedBox(height: 16),
          Text(
            '正在检查传感器状态...',
            style: TextStyle(color: TechColors.textSecondary),
          ),
        ],
      ),
    );
  }

  /// 错误提示
  Widget _buildErrorWidget() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.error_outline, color: TechColors.glowRed, size: 48),
          const SizedBox(height: 16),
          Text(
            _errorMessage ?? '未知错误',
            style: const TextStyle(color: TechColors.textSecondary),
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: _fetchData,
            style: ElevatedButton.styleFrom(
              backgroundColor: TechColors.glowCyan.withOpacity(0.2),
            ),
            child: const Text('重试'),
          ),
        ],
      ),
    );
  }

  /// 主内容区
  Widget _buildContent() {
    if (_healthData == null) return const SizedBox();

    final devicesByType = _healthData!.devicesByType;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 检查时间提示
          _buildCheckTimeInfo(),
          const SizedBox(height: 16),
          // 按设备类型显示表格
          ...devicesByType.entries.map((entry) {
            if (entry.value.isEmpty) return const SizedBox();
            return _buildDeviceTypeSection(entry.key, entry.value);
          }),
        ],
      ),
    );
  }

  /// 检查时间信息
  Widget _buildCheckTimeInfo() {
    final checkTime = _healthData?.checkTime;
    final timeStr = checkTime != null
        ? '${checkTime.hour.toString().padLeft(2, '0')}:${checkTime.minute.toString().padLeft(2, '0')}:${checkTime.second.toString().padLeft(2, '0')}'
        : '--:--:--';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: TechColors.bgDark.withOpacity(0.5),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          const Icon(Icons.access_time,
              color: TechColors.textSecondary, size: 16),
          const SizedBox(width: 8),
          Text(
            '检查时间: $timeStr  |  检查范围: 最近 $_checkMinutes 分钟内是否有数据',
            style: const TextStyle(
              color: TechColors.textSecondary,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  /// 设备类型区块
  Widget _buildDeviceTypeSection(String typeName, List<DeviceHealth> devices) {
    return Container(
      margin: const EdgeInsets.only(bottom: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 标题
          Row(
            children: [
              Container(
                width: 4,
                height: 20,
                decoration: BoxDecoration(
                  color: TechColors.glowCyan,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                typeName,
                style: const TextStyle(
                  color: TechColors.textPrimary,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(width: 12),
              // 统计
              Text(
                '(${devices.where((d) => d.healthy).length}/${devices.length} 正常)',
                style: const TextStyle(
                  color: TechColors.textSecondary,
                  fontSize: 14,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // 表格
          _buildDeviceTable(devices),
        ],
      ),
    );
  }

  /// 设备表格
  Widget _buildDeviceTable(List<DeviceHealth> devices) {
    if (devices.isEmpty) return const SizedBox();

    // 获取所有可能的模块类型
    final allModules = <String>{};
    for (final device in devices) {
      allModules.addAll(device.modules.keys);
    }
    final moduleList = allModules.toList()..sort();

    return Container(
      decoration: BoxDecoration(
        color: TechColors.bgDark,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: TechColors.borderDark.withOpacity(0.5)),
      ),
      child: Table(
        columnWidths: {
          0: const FlexColumnWidth(2), // 设备名
          for (int i = 0; i < moduleList.length; i++)
            i + 1: const FlexColumnWidth(1), // 模块列
          moduleList.length + 1: const FlexColumnWidth(2), // 最后更新时间
        },
        border: TableBorder(
          horizontalInside: BorderSide(
            color: TechColors.borderDark.withOpacity(0.3),
          ),
        ),
        children: [
          // 表头
          _buildTableHeader(moduleList),
          // 数据行
          ...devices.map((device) => _buildTableRow(device, moduleList)),
        ],
      ),
    );
  }

  /// 表头
  TableRow _buildTableHeader(List<String> modules) {
    final moduleNames = {
      'ElectricityMeter': '电表',
      'TemperatureSensor': '温度',
      'WeighSensor': '称重',
      'GasMeter': '燃气',
    };

    return TableRow(
      decoration: BoxDecoration(
        color: TechColors.bgMedium.withOpacity(0.5),
      ),
      children: [
        _buildHeaderCell('设备名称'),
        ...modules.map((m) => _buildHeaderCell(moduleNames[m] ?? m)),
        _buildHeaderCell('最后数据时间'),
      ],
    );
  }

  Widget _buildHeaderCell(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: Text(
        text,
        style: const TextStyle(
          color: TechColors.textSecondary,
          fontSize: 13,
          fontWeight: FontWeight.bold,
        ),
        textAlign: TextAlign.center,
      ),
    );
  }

  /// 数据行
  TableRow _buildTableRow(DeviceHealth device, List<String> modules) {
    return TableRow(
      children: [
        // 设备名称
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(
            children: [
              // 状态指示灯
              Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: device.healthy
                      ? TechColors.glowGreen
                      : TechColors.glowRed,
                  boxShadow: [
                    BoxShadow(
                      color: (device.healthy
                              ? TechColors.glowGreen
                              : TechColors.glowRed)
                          .withOpacity(0.5),
                      blurRadius: 4,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  device.name,
                  style: const TextStyle(
                    color: TechColors.textPrimary,
                    fontSize: 13,
                    fontFamily: 'Roboto Mono',
                  ),
                ),
              ),
            ],
          ),
        ),
        // 模块状态
        ...modules.map((m) => _buildModuleCell(device.modules[m])),
        // 最后数据时间
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Text(
            device.lastSeen != null ? _formatTime(device.lastSeen!) : '无数据',
            style: TextStyle(
              color: device.lastSeen != null
                  ? TechColors.textSecondary
                  : TechColors.glowRed,
              fontSize: 12,
              fontFamily: 'Roboto Mono',
            ),
            textAlign: TextAlign.center,
          ),
        ),
      ],
    );
  }

  /// 模块状态单元格
  Widget _buildModuleCell(ModuleHealth? module) {
    if (module == null) {
      // 设备没有这个模块
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: const Text(
          '-',
          style: TextStyle(color: TechColors.textSecondary),
          textAlign: TextAlign.center,
        ),
      );
    }

    final isHealthy = module.healthy;
    final color = isHealthy ? TechColors.glowGreen : TechColors.glowRed;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: color.withOpacity(0.15),
          borderRadius: BorderRadius.circular(4),
          border: Border.all(color: color.withOpacity(0.3)),
        ),
        child: Text(
          isHealthy ? '正常' : '异常',
          style: TextStyle(
            color: color,
            fontSize: 12,
            fontWeight: FontWeight.bold,
          ),
          textAlign: TextAlign.center,
        ),
      ),
    );
  }

  /// 格式化时间
  String _formatTime(DateTime time) {
    final now = DateTime.now();
    final diff = now.difference(time);

    if (diff.inMinutes < 1) {
      return '刚刚';
    } else if (diff.inMinutes < 60) {
      return '${diff.inMinutes}分钟前';
    } else if (diff.inHours < 24) {
      return '${diff.inHours}小时前';
    } else {
      return '${time.month}/${time.day} ${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
    }
  }
}

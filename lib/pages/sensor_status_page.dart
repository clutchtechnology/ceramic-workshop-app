import 'package:flutter/material.dart';
import 'dart:async';
import '../models/sensor_status_model.dart';
import '../services/sensor_status_service.dart';
import '../widgets/data_display/data_tech_line_widgets.dart';
import '../utils/app_logger.dart';

/// 传感器状态位显示页面
/// 简洁列表布局，显示所有设备的原始状态值（done, busy, error, status）
class SensorStatusPage extends StatefulWidget {
  const SensorStatusPage({super.key});

  @override
  State<SensorStatusPage> createState() => _SensorStatusPageState();
}

class _SensorStatusPageState extends State<SensorStatusPage> {
  final SensorStatusService _statusService = SensorStatusService();

  Timer? _timer;
  List<SensorStatus> _statusList = [];
  bool _isRefreshing = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _initData();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _timer = null;
    super.dispose();
  }

  Future<void> _initData() async {
    await _fetchData();
    _timer = Timer.periodic(const Duration(seconds: 5), (timer) async {
      try {
        await _fetchData();
      } catch (e, stack) {
        logger.error('状态位定时器回调异常', e, stack);
      }
    });
  }

  Future<void> _fetchData() async {
    if (_isRefreshing || !mounted) return;

    setState(() {
      _isRefreshing = true;
      _errorMessage = null;
    });

    try {
      final response = await _statusService.getAllStatus();

      if (mounted) {
        setState(() {
          if (response.success && response.data != null) {
            // 将Map转换为List，并按device_id排序
            _statusList = response.data!.values.toList();
            _statusList.sort((a, b) => a.deviceId.compareTo(b.deviceId));
          } else {
            _errorMessage = response.error ?? '获取状态失败';
          }
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = '网络错误: $e';
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _isRefreshing = false;
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
          // 顶部状态栏
          _buildHeader(),
          // 列表内容
          Expanded(
            child: _errorMessage != null
                ? _buildErrorWidget()
                : _buildStatusList(),
          ),
        ],
      ),
    );
  }

  /// 顶部状态栏
  Widget _buildHeader() {
    final totalCount = _statusList.length;
    final errorCount = _statusList.where((s) => s.error).length;
    final normalCount = totalCount - errorCount;

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
          const Text(
            'DB1 设备状态位',
            style: TextStyle(
              color: TechColors.textPrimary,
              fontSize: 20,
              fontWeight: FontWeight.bold,
              fontFamily: 'Roboto Mono',
            ),
          ),
          const Spacer(),
          // 统计信息
          _buildStatChip('总计', totalCount, TechColors.glowCyan),
          const SizedBox(width: 12),
          _buildStatChip('正常', normalCount, TechColors.glowGreen),
          const SizedBox(width: 12),
          _buildStatChip('错误', errorCount, TechColors.glowRed),
          const SizedBox(width: 16),
          // 刷新按钮
          IconButton(
            onPressed: _isRefreshing ? null : _fetchData,
            icon: _isRefreshing
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: TechColors.glowCyan,
                    ),
                  )
                : const Icon(
                    Icons.refresh,
                    color: TechColors.glowCyan,
                  ),
          ),
        ],
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
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 12,
            ),
          ),
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

  /// 错误提示
  Widget _buildErrorWidget() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(
            Icons.error_outline,
            color: TechColors.glowRed,
            size: 48,
          ),
          const SizedBox(height: 16),
          Text(
            _errorMessage ?? '未知错误',
            style: const TextStyle(
              color: TechColors.textSecondary,
              fontSize: 14,
            ),
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

  /// 状态列表（3列布局，每列垂直排列）
  Widget _buildStatusList() {
    if (_statusList.isEmpty) {
      return const Center(
        child: Text(
          '暂无数据',
          style: TextStyle(
            color: TechColors.textSecondary,
            fontSize: 14,
          ),
        ),
      );
    }

    // 计算每列的行数
    final itemsPerColumn = (_statusList.length / 3).ceil();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 第1列
          Expanded(
            child: _buildColumn(0, itemsPerColumn),
          ),
          const SizedBox(width: 8),
          // 第2列
          Expanded(
            child: _buildColumn(itemsPerColumn, itemsPerColumn * 2),
          ),
          const SizedBox(width: 8),
          // 第3列
          Expanded(
            child: _buildColumn(itemsPerColumn * 2, _statusList.length),
          ),
        ],
      ),
    );
  }

  /// 构建单列
  Widget _buildColumn(int startIndex, int endIndex) {
    final items = <Widget>[];
    for (int i = startIndex; i < endIndex && i < _statusList.length; i++) {
      items.add(_buildStatusCard(_statusList[i], i));
    }
    return Column(
      children: items,
    );
  }

  /// 单个状态卡片（3列布局）
  Widget _buildStatusCard(SensorStatus status, int index) {
    final hasError = status.error;
    final accentColor = hasError ? TechColors.glowRed : TechColors.glowGreen;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: TechColors.bgDark.withOpacity(0.6),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: hasError
              ? TechColors.glowRed.withOpacity(0.3)
              : TechColors.borderDark.withOpacity(0.3),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          // 序号 + 状态灯 + 设备名（占1/2）
          Expanded(
            flex: 4,
            child: Row(
              children: [
                Text(
                  '${index + 1}',
                  style: const TextStyle(
                    color: TechColors.textSecondary,
                    fontSize: 12,
                    fontFamily: 'Roboto Mono',
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: accentColor,
                    boxShadow: [
                      BoxShadow(
                        color: accentColor.withOpacity(0.5),
                        blurRadius: 4,
                        spreadRadius: 1,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    status.deviceId,
                    style: const TextStyle(
                      color: TechColors.textPrimary,
                      fontSize: 13,
                      fontFamily: 'Roboto Mono',
                      fontWeight: FontWeight.w500,
                    ),
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          // D值（占1/8）
          Expanded(
            flex: 1,
            child:
                _buildCompactValueCell('D', status.done, TechColors.glowGreen),
          ),
          const SizedBox(width: 4),
          // B值（占1/8）
          Expanded(
            flex: 1,
            child:
                _buildCompactValueCell('B', status.busy, TechColors.glowOrange),
          ),
          const SizedBox(width: 4),
          // E值（占1/8）
          Expanded(
            flex: 1,
            child:
                _buildCompactValueCell('E', status.error, TechColors.glowRed),
          ),
          const SizedBox(width: 4),
          // S值（占1/8）
          Expanded(
            flex: 1,
            child: _buildCompactStatusCell(status.statusCode),
          ),
        ],
      ),
    );
  }

  Widget _buildCompactValueCell(String label, bool value, Color activeColor) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          '$label:',
          style: const TextStyle(
            color: TechColors.textSecondary,
            fontSize: 11,
          ),
        ),
        const SizedBox(width: 4),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          decoration: BoxDecoration(
            color: value
                ? activeColor.withOpacity(0.2)
                : TechColors.bgMedium.withOpacity(0.5),
            borderRadius: BorderRadius.circular(3),
            border: Border.all(
              color: value
                  ? activeColor.withOpacity(0.5)
                  : TechColors.borderDark.withOpacity(0.3),
            ),
          ),
          child: Text(
            value ? '1' : '0',
            style: TextStyle(
              color: value ? activeColor : TechColors.textSecondary,
              fontSize: 14,
              fontWeight: FontWeight.bold,
              fontFamily: 'Roboto Mono',
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildCompactStatusCell(int statusCode) {
    final hasError = statusCode != 0;
    final color = hasError ? TechColors.glowRed : TechColors.textSecondary;
    // 将状态码转换为4位十六进制（大写），例如：0 -> 0000, 33280 -> 8200
    final hexStatus =
        statusCode.toRadixString(16).toUpperCase().padLeft(4, '0');

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Text(
          'S:',
          style: TextStyle(
            color: TechColors.textSecondary,
            fontSize: 11,
          ),
        ),
        const SizedBox(width: 4),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          decoration: BoxDecoration(
            color: hasError
                ? TechColors.glowRed.withOpacity(0.2)
                : TechColors.bgMedium.withOpacity(0.5),
            borderRadius: BorderRadius.circular(3),
            border: Border.all(
              color: hasError
                  ? TechColors.glowRed.withOpacity(0.5)
                  : TechColors.borderDark.withOpacity(0.3),
            ),
          ),
          child: Text(
            hexStatus,
            style: TextStyle(
              color: color,
              fontSize: 14,
              fontWeight: FontWeight.bold,
              fontFamily: 'Roboto Mono',
            ),
          ),
        ),
      ],
    );
  }
}

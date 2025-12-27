import 'dart:async';
import 'package:flutter/material.dart';
import '../../api/index.dart';
import '../../api/api.dart';
import '../../utils/app_logger.dart';
import '../data_display/data_tech_line_widgets.dart';

class HealthStatusWidget extends StatefulWidget {
  const HealthStatusWidget({super.key});

  @override
  State<HealthStatusWidget> createState() => _HealthStatusWidgetState();
}

class _HealthStatusWidgetState extends State<HealthStatusWidget> {
  bool _isSystemHealthy = false;
  bool _isPlcHealthy = false;
  bool _isDbHealthy = false;
  Timer? _timer;

  // 记录上次状态，用于检测状态变化
  bool? _lastSystemHealthy;
  bool? _lastPlcHealthy;
  bool? _lastDbHealthy;

  @override
  void initState() {
    super.initState();
    _checkHealth();
    _timer = Timer.periodic(const Duration(minutes: 1), (timer) {
      try {
        _checkHealth();
      } catch (e) {
        // 忽略异常，保持定时器运行
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _checkHealth() async {
    final client = ApiClient();

    // Check System Health
    try {
      await client.get(Api.health);
      if (mounted) {
        // 状态变化：从不健康变为健康
        if (_lastSystemHealthy == false) {
          logger.info('系统服务恢复正常');
        }
        _lastSystemHealthy = true;
        setState(() => _isSystemHealthy = true);
      }
    } catch (e) {
      if (mounted) {
        // 状态变化：从健康变为不健康，记录ERROR
        if (_lastSystemHealthy != false) {
          logger.error('系统服务不可达', e);
        }
        _lastSystemHealthy = false;
        setState(() => _isSystemHealthy = false);
      }
    }

    // Check PLC Health - 需要检查返回的 connected 字段
    try {
      final response = await client.get(Api.healthPlc);
      // 解析响应，检查 data.connected 字段
      bool plcConnected = false;
      if (response is Map<String, dynamic>) {
        final data = response['data'];
        if (data is Map<String, dynamic>) {
          plcConnected = data['connected'] == true;
        }
      }
      if (mounted) {
        // 状态变化日志
        if (plcConnected && _lastPlcHealthy == false) {
          logger.info('PLC连接恢复正常');
        } else if (!plcConnected && _lastPlcHealthy != false) {
          logger.error('PLC连接断开 - connected: $plcConnected');
        }
        _lastPlcHealthy = plcConnected;
        setState(() => _isPlcHealthy = plcConnected);
      }
    } catch (e) {
      if (mounted) {
        if (_lastPlcHealthy != false) {
          logger.error('PLC健康检查失败', e);
        }
        _lastPlcHealthy = false;
        setState(() => _isPlcHealthy = false);
      }
    }

    // Check DB Health - 需要检查返回的 status 字段
    try {
      final response = await client.get(Api.healthDb);
      // 解析响应，检查 data.status 或 data.databases.influxdb.connected 字段
      bool dbConnected = false;
      if (response is Map<String, dynamic>) {
        final data = response['data'];
        if (data is Map<String, dynamic>) {
          // 检查 status 是否为 "healthy"
          if (data['status'] == 'healthy') {
            dbConnected = true;
          } else {
            // 或者检查 databases.influxdb.connected
            final databases = data['databases'];
            if (databases is Map<String, dynamic>) {
              final influxdb = databases['influxdb'];
              if (influxdb is Map<String, dynamic>) {
                dbConnected = influxdb['connected'] == true;
              }
            }
          }
        }
      }
      if (mounted) {
        // 状态变化日志
        if (dbConnected && _lastDbHealthy == false) {
          logger.info('数据库连接恢复正常');
        } else if (!dbConnected && _lastDbHealthy != false) {
          logger.error('数据库连接断开 - status: ${response}');
        }
        _lastDbHealthy = dbConnected;
        setState(() => _isDbHealthy = dbConnected);
      }
    } catch (e) {
      if (mounted) {
        if (_lastDbHealthy != false) {
          logger.error('数据库健康检查失败', e);
        }
        _lastDbHealthy = false;
        setState(() => _isDbHealthy = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _buildStatusIndicator('服务', _isSystemHealthy),
        const SizedBox(width: 8),
        _buildStatusIndicator('PLC', _isPlcHealthy),
        const SizedBox(width: 8),
        _buildStatusIndicator('数据库', _isDbHealthy),
      ],
    );
  }

  Widget _buildStatusIndicator(String label, bool isHealthy) {
    final color = isHealthy ? TechColors.glowGreen : TechColors.glowRed;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: TechColors.bgMedium,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(
          color: color.withOpacity(0.5),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: color.withOpacity(0.5),
                  blurRadius: 4,
                ),
              ],
            ),
          ),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 12,
              fontWeight: FontWeight.w600,
              fontFamily: 'Roboto Mono',
            ),
          ),
        ],
      ),
    );
  }
}

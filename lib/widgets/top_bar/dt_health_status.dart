import 'dart:async';
import 'package:flutter/material.dart';
import '../../api/index.dart';
import '../../api/api.dart';
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

  @override
  void initState() {
    super.initState();
    _checkHealth();
    _timer = Timer.periodic(const Duration(minutes: 1), (timer) {
      _checkHealth();
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
      if (mounted) setState(() => _isSystemHealthy = true);
    } catch (e) {
      if (mounted) setState(() => _isSystemHealthy = false);
    }

    // Check PLC Health
    try {
      await client.get(Api.healthPlc);
      if (mounted) setState(() => _isPlcHealthy = true);
    } catch (e) {
      if (mounted) setState(() => _isPlcHealthy = false);
    }

    // Check DB Health
    try {
      await client.get(Api.healthDb);
      if (mounted) setState(() => _isDbHealthy = true);
    } catch (e) {
      if (mounted) setState(() => _isDbHealthy = false);
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

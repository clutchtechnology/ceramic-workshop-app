import 'package:flutter/material.dart';
import 'tech_line_widgets.dart';

/// 时间范围选择器组件
/// 可自定义主题色，用于不同设备类型的时间选择
class TimeRangeSelector extends StatelessWidget {
  final DateTime startTime;
  final DateTime endTime;
  final VoidCallback onStartTimeTap;
  final VoidCallback onEndTimeTap;
  final Color accentColor;

  const TimeRangeSelector({
    super.key,
    required this.startTime,
    required this.endTime,
    required this.onStartTimeTap,
    required this.onEndTimeTap,
    this.accentColor = TechColors.glowOrange,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: TechColors.bgMedium.withOpacity(0.5),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(
          color: accentColor.withOpacity(0.3),
        ),
      ),
      child: Row(
        children: [
          Icon(
            Icons.date_range,
            size: 16,
            color: accentColor,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: GestureDetector(
              onTap: onStartTimeTap,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: TechColors.bgDark,
                  borderRadius: BorderRadius.circular(3),
                ),
                child: Text(
                  _formatDateTime(startTime),
                  style: const TextStyle(
                    color: TechColors.textPrimary,
                    fontSize: 11,
                    fontFamily: 'Roboto Mono',
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          const Text(
            '~',
            style: TextStyle(
              color: TechColors.textSecondary,
              fontSize: 12,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: GestureDetector(
              onTap: onEndTimeTap,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: TechColors.bgDark,
                  borderRadius: BorderRadius.circular(3),
                ),
                child: Text(
                  _formatDateTime(endTime),
                  style: const TextStyle(
                    color: TechColors.textPrimary,
                    fontSize: 11,
                    fontFamily: 'Roboto Mono',
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// 格式化时间显示
  String _formatDateTime(DateTime dateTime) {
    return '${dateTime.month.toString().padLeft(2, '0')}-${dateTime.day.toString().padLeft(2, '0')} ${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}';
  }
}

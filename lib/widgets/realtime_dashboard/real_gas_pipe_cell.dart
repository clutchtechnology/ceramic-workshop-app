import 'package:flutter/material.dart';
import '../data_display/data_tech_line_widgets.dart';
import '../icons/icons.dart';

/// 燃气管单元组件
/// 用于显示SCR设备中的燃气管道
class GasPipeCell extends StatelessWidget {
  /// 燃气管编号
  final int index;

  /// 运行状态 (true=运行, false=停止)
  final bool isRunning;

  /// 流速 (L/min)
  final double flowRate;

  /// 累计流量 (m³)
  final double energyConsumption;

  const GasPipeCell({
    super.key,
    required this.index,
    this.isRunning = true,
    this.flowRate = 0.0,
    this.energyConsumption = 0.0,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: TechColors.bgMedium.withOpacity(0.3),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(
          color: TechColors.glowCyan.withOpacity(0.3),
          width: 1,
        ),
      ),
      child: Stack(
        children: [
          // 燃气管图片作为背景
          Positioned(
            top: 0,
            left: 0,
            bottom: 50,
            width: 60,
            child: Image.asset(
              'assets/images/gas.png',
              fit: BoxFit.contain,
              alignment: Alignment.centerLeft,
              errorBuilder: (context, error, stackTrace) {
                return Icon(
                  Icons.image_not_supported,
                  color: TechColors.textSecondary.withOpacity(0.5),
                  size: 25,
                );
              },
            ),
          ),
          // 数据显示区域 - 绝对定位在底部
          Positioned(
            left: 4,
            right: 4,
            bottom: 8,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
              decoration: BoxDecoration(
                color: TechColors.bgDeep.withOpacity(0.85),
                borderRadius: BorderRadius.circular(4),
                border: Border.all(
                  color: TechColors.glowCyan.withOpacity(0.4),
                  width: 1,
                ),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const FlowRateIcon(size: 18, color: TechColors.glowCyan),
                      const SizedBox(width: 2),
                      Flexible(
                        child: Text(
                          '${flowRate.toStringAsFixed(1)}L/min',
                          style: const TextStyle(
                            color: TechColors.glowCyan,
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                            fontFamily: 'Roboto Mono',
                          ),
                          overflow: TextOverflow.ellipsis,
                          softWrap: false,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const TotalFlowIcon(
                          size: 18, color: TechColors.glowGreen),
                      const SizedBox(width: 2),
                      Flexible(
                        child: Text(
                          '${energyConsumption.toStringAsFixed(1)}m³',
                          style: const TextStyle(
                            color: TechColors.glowGreen,
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                            fontFamily: 'Roboto Mono',
                          ),
                          overflow: TextOverflow.ellipsis,
                          softWrap: false,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          // 左上角启停状态指示灯
          Positioned(
            top: 8,
            left: 8,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 12,
                  height: 12,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: isRunning
                        ? TechColors.statusNormal
                        : TechColors.statusOffline,
                    boxShadow: [
                      BoxShadow(
                        color: (isRunning
                                ? TechColors.statusNormal
                                : TechColors.statusOffline)
                            .withOpacity(0.6),
                        blurRadius: 6,
                        spreadRadius: 2,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  isRunning ? '运行' : '停止',
                  style: TextStyle(
                    color: isRunning
                        ? TechColors.statusNormal
                        : TechColors.statusOffline,
                    fontSize: 16.5,
                    fontWeight: FontWeight.w600,
                    fontFamily: 'Roboto Mono',
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

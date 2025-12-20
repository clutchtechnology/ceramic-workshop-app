import 'package:flutter/material.dart';
import '../data_display/data_tech_line_widgets.dart';
import '../icons/icons.dart';

/// 水泵单元组件
/// 用于显示SCR设备中的水泵（氨泵）
class WaterPumpCell extends StatelessWidget {
  /// 水泵编号
  final int index;

  /// 运行状态 (true=运行, false=停止)
  final bool isRunning;

  /// 功率 (kW)
  final double power;

  /// 累计电量 (kW·h)
  final double cumulativeEnergy;

  /// 能耗 (kW)
  final double energyConsumption;

  const WaterPumpCell({
    super.key,
    required this.index,
    this.isRunning = true,
    this.power = 0.0,
    this.cumulativeEnergy = 0.0,
    this.energyConsumption = 0.0,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: TechColors.bgMedium.withOpacity(0.3),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(
          color: TechColors.borderDark,
          width: 1,
        ),
      ),
      child: Stack(
        children: [
          // 水泵图片作为背景
          Positioned(
            top: 0,
            left: 20,
            right: 20,
            bottom: 70,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12.0),
              child: Image.asset(
                'assets/images/water_pump.png',
                fit: BoxFit.contain,
                errorBuilder: (context, error, stackTrace) {
                  return Icon(
                    Icons.image_not_supported,
                    color: TechColors.textSecondary.withOpacity(0.5),
                    size: 32,
                  );
                },
              ),
            ),
          ),
          // 数据显示区域 - 绝对定位在底部
          Positioned(
            left: 8,
            right: 8,
            bottom: 8,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 15),
              decoration: BoxDecoration(
                color: TechColors.bgDeep.withOpacity(0.92),
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
                    children: [
                      const PowerIcon(size: 24, color: TechColors.glowCyan),
                      const SizedBox(width: 4),
                      Text(
                        '${power.toStringAsFixed(1)} kW',
                        style: const TextStyle(
                          color: TechColors.glowCyan,
                          fontSize: 19.5,
                          fontWeight: FontWeight.w500,
                          fontFamily: 'Roboto Mono',
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      const EnergyIcon(size: 24, color: TechColors.glowOrange),
                      const SizedBox(width: 4),
                      Text(
                        '${energyConsumption.toStringAsFixed(1)} kWh',
                        style: const TextStyle(
                          color: TechColors.glowOrange,
                          fontSize: 19.5,
                          fontWeight: FontWeight.w500,
                          fontFamily: 'Roboto Mono',
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

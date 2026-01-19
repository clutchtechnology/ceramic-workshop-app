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

  /// 三相电流 (A)
  final double currentA;
  final double currentB;
  final double currentC;

  const WaterPumpCell({
    super.key,
    required this.index,
    this.isRunning = true,
    this.power = 0.0,
    this.cumulativeEnergy = 0.0,
    this.energyConsumption = 0.0,
    this.currentA = 0.0,
    this.currentB = 0.0,
    this.currentC = 0.0,
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
          // 水泵图片作为背景（变小）
          Positioned(
            top: 8,
            left: 35,
            right: 35,
            bottom: 55,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8.0),
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
            left: 4,
            right: 4,
            bottom: 4,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 3),
              decoration: BoxDecoration(
                color: TechColors.bgDeep.withOpacity(0.85),
                borderRadius: BorderRadius.circular(4),
                border: Border.all(
                  color: TechColors.glowCyan.withOpacity(0.4),
                  width: 1,
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // 左侧列：功率和能耗
                  Flexible(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const PowerIcon(
                                size: 16, color: TechColors.glowCyan),
                            const SizedBox(width: 2),
                            Flexible(
                              child: Text(
                                '${power.toStringAsFixed(1)}kW',
                                style: const TextStyle(
                                  color: TechColors.glowCyan,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w500,
                                  fontFamily: 'Roboto Mono',
                                ),
                                overflow: TextOverflow.ellipsis,
                                softWrap: false,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 1),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const EnergyIcon(
                                size: 16, color: TechColors.glowOrange),
                            const SizedBox(width: 2),
                            Flexible(
                              child: Text(
                                '${energyConsumption.toStringAsFixed(0)}kWh',
                                style: const TextStyle(
                                  color: TechColors.glowOrange,
                                  fontSize: 14,
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
                  // 右侧列：三相电流（紧凑显示）
                  Flexible(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            CurrentIcon(color: TechColors.glowCyan, size: 16),
                            Flexible(
                              child: Text(
                                'A:${currentA.toStringAsFixed(1)}A',
                                style: const TextStyle(
                                  color: TechColors.glowCyan,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w500,
                                  fontFamily: 'Roboto Mono',
                                ),
                                overflow: TextOverflow.ellipsis,
                                softWrap: false,
                              ),
                            ),
                          ],
                        ),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            CurrentIcon(color: TechColors.glowCyan, size: 16),
                            Flexible(
                              child: Text(
                                'B:${currentB.toStringAsFixed(1)}A',
                                style: const TextStyle(
                                  color: TechColors.glowCyan,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w500,
                                  fontFamily: 'Roboto Mono',
                                ),
                                overflow: TextOverflow.ellipsis,
                                softWrap: false,
                              ),
                            ),
                          ],
                        ),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            CurrentIcon(color: TechColors.glowCyan, size: 16),
                            Flexible(
                              child: Text(
                                'C:${currentC.toStringAsFixed(1)}A',
                                style: const TextStyle(
                                  color: TechColors.glowCyan,
                                  fontSize: 14,
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
          // 右上角电表编号标签
          Positioned(
            top: 8,
            right: 8,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
              decoration: BoxDecoration(
                color: TechColors.bgDeep.withOpacity(0.85),
                borderRadius: BorderRadius.circular(4),
                border: Border.all(
                  color: TechColors.glowCyan.withOpacity(0.5),
                  width: 1,
                ),
              ),
              child: Text(
                'SCR${index == 1 ? "北" : "南"} 氨水泵:表${index == 1 ? 63 : 64}',
                style: const TextStyle(
                  color: TechColors.glowCyan,
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  fontFamily: 'Roboto Mono',
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

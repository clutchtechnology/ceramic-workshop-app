import 'package:flutter/material.dart';
import '../data_display/data_tech_line_widgets.dart';
import '../icons/icons.dart';

/// 风机单元组件
/// 用于显示单个风机设备
class FanCell extends StatelessWidget {
  /// 风机编号
  final int index;

  /// 是否运行中
  final bool isRunning;

  /// 功率 (kW)
  final double power;

  /// 累计能耗 (kWh)
  final double cumulativeEnergy;

  /// 三相电流 (A)
  final double currentA;
  final double currentB;
  final double currentC;

  const FanCell({
    super.key,
    required this.index,
    this.isRunning = false,
    this.power = 0.0,
    this.cumulativeEnergy = 0.0,
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
          color: TechColors.borderDark,
          width: 1,
        ),
      ),
      child: Stack(
        children: [
          Column(
            children: [
              // 上方 - 风机图片
              Expanded(
                flex: 1,
                child: Padding(
                  padding: const EdgeInsets.only(
                      top: 28.0, left: 4.0, right: 4.0, bottom: 4.0),
                  child: Image.asset(
                    'assets/images/fan.png',
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
              // 下方 - 数据显示区域（两列显示：左列功率+能耗，右列三相电流）
              Padding(
                padding:
                    const EdgeInsets.only(left: 4.0, right: 4.0, bottom: 8.0),
                child: Container(
                  width: double.infinity,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
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
                                    size: 18, color: TechColors.glowCyan),
                                const SizedBox(width: 2),
                                Text(
                                  '${power.toStringAsFixed(1)}kW',
                                  style: const TextStyle(
                                    color: TechColors.glowCyan,
                                    fontSize: 16,
                                    fontWeight: FontWeight.w500,
                                    fontFamily: 'Roboto Mono',
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                  softWrap: false,
                                ),
                              ],
                            ),
                            const SizedBox(height: 2),
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const EnergyIcon(
                                    size: 18, color: TechColors.glowOrange),
                                const SizedBox(width: 2),
                                Text(
                                  '${cumulativeEnergy.toStringAsFixed(1)}kWh',
                                  style: const TextStyle(
                                    color: TechColors.glowOrange,
                                    fontSize: 16,
                                    fontWeight: FontWeight.w500,
                                    fontFamily: 'Roboto Mono',
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                  softWrap: false,
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      // 右侧列：三相电流
                      Flexible(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                CurrentIcon(
                                    color: TechColors.glowCyan, size: 18),
                                Text(
                                  'A:${currentA.toStringAsFixed(1)}A',
                                  style: const TextStyle(
                                    color: TechColors.glowCyan,
                                    fontSize: 16,
                                    fontWeight: FontWeight.w500,
                                    fontFamily: 'Roboto Mono',
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                  softWrap: false,
                                ),
                              ],
                            ),
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                CurrentIcon(
                                    color: TechColors.glowCyan, size: 18),
                                Text(
                                  'B:${currentB.toStringAsFixed(1)}A',
                                  style: const TextStyle(
                                    color: TechColors.glowCyan,
                                    fontSize: 16,
                                    fontWeight: FontWeight.w500,
                                    fontFamily: 'Roboto Mono',
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                  softWrap: false,
                                ),
                              ],
                            ),
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                CurrentIcon(
                                    color: TechColors.glowCyan, size: 18),
                                Text(
                                  'C:${currentC.toStringAsFixed(1)}A',
                                  style: const TextStyle(
                                    color: TechColors.glowCyan,
                                    fontSize: 16,
                                    fontWeight: FontWeight.w500,
                                    fontFamily: 'Roboto Mono',
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                  softWrap: false,
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
            ],
          ),
          // 左上角状态指示灯
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
                        color: isRunning
                            ? TechColors.statusNormal.withOpacity(0.6)
                            : TechColors.statusOffline.withOpacity(0.3),
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

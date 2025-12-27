import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/hopper_model.dart';
import '../../providers/realtime_config_provider.dart';
import '../data_display/data_tech_line_widgets.dart';
import '../icons/icons.dart';

/// 长回转窑单元组件
/// 用于显示单个长回转窑设备
class RotaryKilnLongCell extends StatelessWidget {
  /// 窑编号
  final int index;
  final HopperData? data;

  /// 设备ID，用于获取阈值配置
  final String? deviceId;

  const RotaryKilnLongCell({
    super.key,
    required this.index,
    this.data,
    this.deviceId,
  });

  @override
  Widget build(BuildContext context) {
    final weight = data?.weighSensor?.weight ?? 0.0;
    final feedRate = data?.weighSensor?.feedRate ?? 0.0;
    final energy = data?.electricityMeter?.impEp ?? 0.0;
    // ✅ 长料仓显示两个温度
    final temperature1 = data?.temperatureSensor1?.temperature ?? 0.0;
    final temperature2 = data?.temperatureSensor2?.temperature ?? 0.0;
    // ✅ 三相电流
    final currentA = data?.electricityMeter?.currentA ?? 0.0;
    final currentB = data?.electricityMeter?.currentB ?? 0.0;
    final currentC = data?.electricityMeter?.currentC ?? 0.0;

    // 获取温度颜色配置 (长窑有两个温度点，使用同一个设备配置)
    final configProvider = context.watch<RealtimeConfigProvider>();
    final tempColor1 = deviceId != null
        ? configProvider.getRotaryKilnTempColor(deviceId!, temperature1)
        : ThresholdColors.normal;
    final tempColor2 = deviceId != null
        ? configProvider.getRotaryKilnTempColor(deviceId!, temperature2)
        : ThresholdColors.normal;

    // 使用配置的料斗容量计算百分比 (getHopperPercentage 返回 0.0-1.0)
    final double capacityPercentage = deviceId != null
        ? configProvider.getHopperPercentage(deviceId!, weight)
        : (weight / 800.0).clamp(0.0, 1.0);
    final int percentageInt = (capacityPercentage * 100).toInt();

    // 料仓颜色（固定青色，不需要报警变化）
    const hopperColor = TechColors.glowCyan;

    return Container(
      decoration: BoxDecoration(
        color: TechColors.bgMedium.withOpacity(0.3),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(
          color: TechColors.borderDark,
          width: 1,
        ),
      ),
      child: Center(
        child: Padding(
          padding: const EdgeInsets.only(
              left: 4.0, right: 4.0, top: 4.0, bottom: 0.0),
          child: Stack(
            children: [
              // 主图片 - 底部对齐，让图片空白在顶部被数据标签遮挡
              Align(
                alignment: Alignment.bottomCenter,
                child: Image.asset(
                  'assets/images/rotary_kiln3.png',
                  fit: BoxFit.contain,
                  width: double.infinity,
                  errorBuilder: (context, error, stackTrace) {
                    // 图片加载失败时的占位符
                    return Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.image_not_supported,
                          color: TechColors.textSecondary.withOpacity(0.5),
                          size: 32,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '回转窑 $index',
                          style: TextStyle(
                            color: TechColors.textSecondary,
                            fontSize: 10,
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),
              // 左侧垂直进度条
              Positioned(
                left: 0,
                top: 0,
                bottom: 0,
                child: Center(
                  child: Container(
                    width: 20,
                    height: 120,
                    decoration: BoxDecoration(
                      color: TechColors.bgDeep.withOpacity(0.8),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: hopperColor.withOpacity(0.5),
                        width: 1.5,
                      ),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(8.5),
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          // 进度填充
                          Align(
                            alignment: Alignment.bottomCenter,
                            child: FractionallySizedBox(
                              alignment: Alignment.bottomCenter,
                              heightFactor: capacityPercentage,
                              child: Container(
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    begin: Alignment.bottomCenter,
                                    end: Alignment.topCenter,
                                    colors: [
                                      hopperColor,
                                      hopperColor.withOpacity(0.6),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),
                          // 百分比文字（横向显示在进度条内）
                          Text(
                            '$percentageInt',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 13.5,
                              fontWeight: FontWeight.w700,
                              fontFamily: 'Roboto Mono',
                              shadows: [
                                Shadow(
                                  color: Colors.black,
                                  offset: Offset(0, 0),
                                  blurRadius: 3,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              // 数据标签
              Positioned(
                left: 0,
                right: 0,
                top: 0,
                bottom: 0,
                child: Align(
                  alignment: const Alignment(0.4, -1.1),
                  child: Transform.translate(
                    offset: const Offset(18, 40), // 右移18px，下移40px
                    child: Container(
                      padding: const EdgeInsets.only(
                        left: 4,
                        right: 10, // 右边加长6px
                        top: 6,
                        bottom: 6,
                      ),
                      decoration: BoxDecoration(
                        color: TechColors.bgDeep.withOpacity(0.85),
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(
                          color: hopperColor.withOpacity(0.4),
                          width: 1,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // 左侧列：重量、进料速率、电能
                          Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  WeightIcon(color: hopperColor, size: 18),
                                  const SizedBox(width: 2),
                                  Text(
                                    '${weight.toStringAsFixed(0)}kg',
                                    style: TextStyle(
                                      color: hopperColor,
                                      fontSize: 16,
                                      fontWeight: FontWeight.w500,
                                      fontFamily: 'Roboto Mono',
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 2),
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  FeedRateIcon(
                                      color: TechColors.glowGreen, size: 18),
                                  const SizedBox(width: 2),
                                  Text(
                                    '${feedRate.toStringAsFixed(1)}kg/h',
                                    style: const TextStyle(
                                      color: TechColors.glowGreen,
                                      fontSize: 16,
                                      fontWeight: FontWeight.w500,
                                      fontFamily: 'Roboto Mono',
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 2),
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  EnergyIcon(
                                      color: TechColors.glowOrange, size: 18),
                                  const SizedBox(width: 2),
                                  Text(
                                    '${energy.toStringAsFixed(1)}kWh',
                                    style: const TextStyle(
                                      color: TechColors.glowOrange,
                                      fontSize: 16,
                                      fontWeight: FontWeight.w500,
                                      fontFamily: 'Roboto Mono',
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                          const SizedBox(width: 4),
                          // 右侧列：三相电流
                          Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  CurrentIcon(color: hopperColor, size: 18),
                                  Text(
                                    'A:${currentA.toStringAsFixed(1)}A',
                                    style: TextStyle(
                                      color: hopperColor,
                                      fontSize: 16,
                                      fontWeight: FontWeight.w500,
                                      fontFamily: 'Roboto Mono',
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 2),
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  CurrentIcon(color: hopperColor, size: 18),
                                  Text(
                                    'B:${currentB.toStringAsFixed(1)}A',
                                    style: TextStyle(
                                      color: hopperColor,
                                      fontSize: 16,
                                      fontWeight: FontWeight.w500,
                                      fontFamily: 'Roboto Mono',
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 2),
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  CurrentIcon(color: hopperColor, size: 18),
                                  Text(
                                    'C:${currentC.toStringAsFixed(1)}A',
                                    style: TextStyle(
                                      color: hopperColor,
                                      fontSize: 16,
                                      fontWeight: FontWeight.w500,
                                      fontFamily: 'Roboto Mono',
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              // 中间温度显示 - 左右两边显示两个温度
              Positioned(
                left: 0,
                right: 0,
                top: 90,
                bottom: 0,
                child: Center(
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // 温度1 - 左侧
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: TechColors.bgDeep.withOpacity(0.7),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            ThermometerIcon(
                              color: tempColor1,
                              size: 18,
                            ),
                            const SizedBox(width: 2),
                            Text(
                              '${temperature1.toStringAsFixed(1)}°C',
                              style: TextStyle(
                                color: tempColor1,
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                                fontFamily: 'Roboto Mono',
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      // 温度2 - 右侧
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: TechColors.bgDeep.withOpacity(0.7),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            ThermometerIcon(
                              color: tempColor2,
                              size: 18,
                            ),
                            const SizedBox(width: 2),
                            Text(
                              '${temperature2.toStringAsFixed(1)}°C',
                              style: TextStyle(
                                color: tempColor2,
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                                fontFamily: 'Roboto Mono',
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              // 右下角窑编号标签
              Positioned(
                right: 4,
                bottom: 4,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: TechColors.bgDeep.withOpacity(0.85),
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(
                      color: TechColors.glowOrange.withOpacity(0.6),
                      width: 1,
                    ),
                  ),
                  child: Text(
                    '窑 $index',
                    style: const TextStyle(
                      color: TechColors.glowOrange,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      fontFamily: 'Roboto Mono',
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/hopper_model.dart';
import '../../providers/realtime_config_provider.dart';
import '../data_display/data_tech_line_widgets.dart';

/// 回转窑单元组件
/// 用于显示单个回转窑设备
class RotaryKilnCell extends StatelessWidget {
  /// 窑编号（1-7）
  final int index;
  final HopperData? data;

  /// 设备ID，用于获取阈值配置
  final String? deviceId;

  const RotaryKilnCell({
    super.key,
    required this.index,
    this.data,
    this.deviceId,
  });

  @override
  Widget build(BuildContext context) {
    final weight = data?.weighSensor?.weight ?? 0.0;
    final feedRate = data?.weighSensor?.feedRate ?? 0.0;
    final power = data?.electricityMeter?.pt ?? 0.0;
    final energy = data?.electricityMeter?.impEp ?? 0.0;
    final temperature = data?.temperatureSensor?.temperature ?? 0.0;

    // 获取温度颜色配置
    final configProvider = context.watch<RealtimeConfigProvider>();
    final tempColor = deviceId != null
        ? configProvider.getRotaryKilnTempColor(deviceId!, temperature)
        : ThresholdColors.normal;

    // 假设最大重量为 500kg 用于显示进度条 (需根据实际情况调整)
    final maxWeight = 500.0;
    final weightPercentage = (weight / maxWeight).clamp(0.0, 1.0);
    final weightPercentageInt = (weightPercentage * 100).toInt();

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
          padding: const EdgeInsets.all(8.0),
          child: Stack(
            children: [
              // 主图片
              Image.asset(
                'assets/images/rotary_kiln1.png',
                fit: BoxFit.contain,
                width: double.infinity,
                height: double.infinity,
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
                        color: TechColors.glowCyan.withOpacity(0.5),
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
                              heightFactor: weightPercentage, // 实时进度
                              child: Container(
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    begin: Alignment.bottomCenter,
                                    end: Alignment.topCenter,
                                    colors: [
                                      TechColors.glowCyan,
                                      TechColors.glowCyan.withOpacity(0.6),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),
                          // 百分比文字（横向显示在进度条内）
                          Text(
                            '$weightPercentageInt',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 9,
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
              // 数据标签（）
              Positioned(
                left: 0,
                right: 0,
                top: 0,
                bottom: 0,
                child: Align(
                  alignment: const Alignment(0.3, -1.1), //
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 6,
                    ),
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
                        Text(
                          '重量: ${weight.toStringAsFixed(1)}kg',
                          style: const TextStyle(
                            color: TechColors.glowCyan,
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                            fontFamily: 'Roboto Mono',
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '下料速度: ${feedRate.toStringAsFixed(1)}kg/h',
                          style: const TextStyle(
                            color: TechColors.glowGreen,
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                            fontFamily: 'Roboto Mono',
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '能耗: ${energy.toStringAsFixed(1)}kWh',
                          style: const TextStyle(
                            color: TechColors.glowOrange,
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                            fontFamily: 'Roboto Mono',
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              // 中间温度显示
              Positioned(
                left: 10,
                right: 0,
                top: 20,
                bottom: 0,
                child: Center(
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    child: Text(
                      '温度: ${temperature.toStringAsFixed(1)}°C',
                      style: TextStyle(
                        color: tempColor,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        fontFamily: 'Roboto Mono',
                      ),
                    ),
                  ),
                ),
              ),
              // 窑编号标签（左下角）
              Positioned(
                bottom: 4,
                left: 4,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: TechColors.bgDeep.withOpacity(0.8),
                    borderRadius: BorderRadius.circular(2),
                    border: Border.all(
                      color: TechColors.glowOrange.withOpacity(0.3),
                      width: 1,
                    ),
                  ),
                  child: Text(
                    '窑 $index',
                    style: const TextStyle(
                      color: TechColors.glowOrange,
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
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

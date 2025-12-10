import 'package:flutter/material.dart';
import 'tech_line_widgets.dart';

/// 无料仓回转窑单元组件
/// 用于显示单个无料仓回转窑设备
class RotaryKilnNoHopperCell extends StatelessWidget {
  /// 窑编号
  final int index;

  const RotaryKilnNoHopperCell({
    super.key,
    required this.index,
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
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(8.0),
          child: Stack(
            children: [
              // 主图片
              Image.asset(
                'assets/images/rotary_kiln2.png',
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
              // 数据标签（左侧30%位置，垂直居中）
              Positioned(
                left: 0,
                right: 0,
                top: 0,
                bottom: 0,
                child: Align(
                  alignment: const Alignment(0.1, -1), // 左侧30%位置，垂直居中
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
                          '重量: 300kg',
                          style: const TextStyle(
                            color: TechColors.glowCyan,
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                            fontFamily: 'Roboto Mono',
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '下料速度: 10kg/h',
                          style: const TextStyle(
                            color: TechColors.glowGreen,
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                            fontFamily: 'Roboto Mono',
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '能耗: 45kW',
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
                left: -35,
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
                      '温度: 850°C',
                      style: const TextStyle(
                        color: TechColors.glowRed,
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

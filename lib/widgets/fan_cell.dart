import 'package:flutter/material.dart';
import 'tech_line_widgets.dart';

/// 风机单元组件
/// 用于显示单个风机设备
class FanCell extends StatelessWidget {
  /// 风机编号
  final int index;

  const FanCell({
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
      child: Stack(
        children: [
          Column(
            children: [
              // 上方 - 风机图片（缩小尺寸）
              Expanded(
                flex: 2,
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: FractionallySizedBox(
                    widthFactor: 0.9, // 图片宽度为容器的90%
                    heightFactor: 0.9, // 图片高度为容器的90%
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
              ),
              // 下方 - 数据显示区域
              Expanded(
                flex: 1,
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 8.0, vertical: 4.0),
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                    decoration: BoxDecoration(
                      color: TechColors.bgDeep.withOpacity(0.85),
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(
                        color: TechColors.glowCyan.withOpacity(0.4),
                        width: 1,
                      ),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '功率: 15kW',
                          style: const TextStyle(
                            color: TechColors.glowCyan,
                            fontSize: 10,
                            fontWeight: FontWeight.w500,
                            fontFamily: 'Roboto Mono',
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '累计电量: 1250kW·h',
                          style: const TextStyle(
                            color: TechColors.glowGreen,
                            fontSize: 10,
                            fontWeight: FontWeight.w500,
                            fontFamily: 'Roboto Mono',
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '能耗: 12kW',
                          style: const TextStyle(
                            color: TechColors.glowOrange,
                            fontSize: 10,
                            fontWeight: FontWeight.w500,
                            fontFamily: 'Roboto Mono',
                          ),
                        ),
                      ],
                    ),
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
                    color: TechColors.statusNormal, // 绿色表示运行
                    boxShadow: [
                      BoxShadow(
                        color: TechColors.statusNormal.withOpacity(0.6),
                        blurRadius: 6,
                        spreadRadius: 2,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 6),
                const Text(
                  '运行',
                  style: TextStyle(
                    color: TechColors.statusNormal,
                    fontSize: 11,
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

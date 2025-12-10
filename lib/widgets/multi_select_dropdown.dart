import 'package:flutter/material.dart';
import 'tech_line_widgets.dart';

/// 多选下拉框组件
/// 用于选择多个设备/项目，支持复选框和颜色指示器
class MultiSelectDropdown extends StatelessWidget {
  final String label;
  final int itemCount;
  final List<bool> selectedItems;
  final List<Color> itemColors;
  final String Function(int index) getItemLabel;
  final Color accentColor;
  final ValueChanged<int> onItemToggle;

  const MultiSelectDropdown({
    super.key,
    required this.label,
    required this.itemCount,
    required this.selectedItems,
    required this.itemColors,
    required this.getItemLabel,
    required this.accentColor,
    required this.onItemToggle,
  });

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<int>(
      color: TechColors.bgMedium,
      icon: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: TechColors.bgDark,
          borderRadius: BorderRadius.circular(3),
          border: Border.all(
            color: accentColor.withOpacity(0.3),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: const TextStyle(
                color: TechColors.textPrimary,
                fontSize: 10,
              ),
            ),
            const SizedBox(width: 4),
            const Icon(
              Icons.arrow_drop_down,
              size: 16,
              color: TechColors.textSecondary,
            ),
          ],
        ),
      ),
      itemBuilder: (context) {
        return List.generate(itemCount, (index) {
          return PopupMenuItem<int>(
            value: index,
            enabled: false,
            child: StatefulBuilder(
              builder: (context, setState) {
                return InkWell(
                  onTap: () {
                    setState(() {
                      onItemToggle(index);
                    });
                  },
                  child: Row(
                    children: [
                      // 复选框
                      Container(
                        width: 16,
                        height: 16,
                        decoration: BoxDecoration(
                          color: selectedItems[index]
                              ? itemColors[index]
                              : Colors.transparent,
                          border: Border.all(
                            color: itemColors[index],
                            width: 2,
                          ),
                          borderRadius: BorderRadius.circular(3),
                        ),
                        child: selectedItems[index]
                            ? const Icon(
                                Icons.check,
                                size: 12,
                                color: TechColors.bgDeep,
                              )
                            : null,
                      ),
                      const SizedBox(width: 8),
                      // 颜色指示器
                      Container(
                        width: 12,
                        height: 12,
                        decoration: BoxDecoration(
                          color: itemColors[index],
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 8),
                      // 标签文字
                      Text(
                        getItemLabel(index),
                        style: const TextStyle(
                          color: TechColors.textPrimary,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          );
        });
      },
    );
  }
}

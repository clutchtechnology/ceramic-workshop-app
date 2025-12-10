import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'tech_line_widgets.dart';
import 'multi_select_dropdown.dart';
import 'single_select_dropdown.dart';

/// 可复用的技术风格折线图组件
/// 支持单选和多选两种模式
class TechLineChart extends StatelessWidget {
  /// 图表标题
  final String title;

  /// 标题左侧装饰条颜色
  final Color accentColor;

  /// Y轴单位标签
  final String yAxisLabel;

  /// X轴单位标签
  final String xAxisLabel;

  /// Y轴最小值
  final double minY;

  /// Y轴最大值
  final double maxY;

  /// Y轴间隔
  final double yInterval;

  /// X轴间隔
  final double xInterval;

  /// 数据源映射 (设备索引 -> 数据点列表)
  final Map<int, List<FlSpot>> dataMap;

  /// 是否为单选模式（默认false为多选模式）
  final bool isSingleSelect;

  /// 单选模式：当前选中的索引
  final int? selectedIndex;

  /// 多选模式：设备选择状态列表
  final List<bool>? selectedItems;

  /// 设备颜色列表
  final List<Color> itemColors;

  /// 设备数量
  final int itemCount;

  /// 获取设备标签的函数
  final String Function(int index) getItemLabel;

  /// 下拉框标签
  final String selectorLabel;

  /// 单选模式：设备选择回调
  final void Function(int index)? onItemSelect;

  /// 多选模式：设备切换回调
  final void Function(int index)? onItemToggle;

  const TechLineChart({
    super.key,
    required this.title,
    required this.accentColor,
    required this.yAxisLabel,
    required this.xAxisLabel,
    required this.minY,
    required this.maxY,
    required this.yInterval,
    required this.xInterval,
    required this.dataMap,
    required this.itemColors,
    required this.itemCount,
    required this.getItemLabel,
    required this.selectorLabel,
    this.isSingleSelect = false,
    this.selectedIndex,
    this.selectedItems,
    this.onItemSelect,
    this.onItemToggle,
  }) : assert(
          isSingleSelect
              ? (selectedIndex != null && onItemSelect != null)
              : (selectedItems != null && onItemToggle != null),
          '单选模式需要 selectedIndex 和 onItemSelect，多选模式需要 selectedItems 和 onItemToggle',
        );

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: TechColors.bgMedium.withOpacity(0.3),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: TechColors.borderDark),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeader(),
          const SizedBox(height: 12),
          Expanded(
            child: _buildChart(),
          ),
        ],
      ),
    );
  }

  /// 构建图表头部
  Widget _buildHeader() {
    return Row(
      children: [
        Container(
          width: 3,
          height: 12,
          decoration: BoxDecoration(
            color: accentColor,
            borderRadius: BorderRadius.circular(1),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          title,
          style: const TextStyle(
            color: TechColors.textPrimary,
            fontSize: 12,
            fontWeight: FontWeight.w500,
          ),
        ),
        const Spacer(),
        _buildSelector(),
      ],
    );
  }

  /// 构建设备选择器
  Widget _buildSelector() {
    if (isSingleSelect) {
      return SingleSelectDropdown(
        label: selectorLabel,
        itemCount: itemCount,
        selectedIndex: selectedIndex!,
        itemColors: itemColors,
        getItemLabel: getItemLabel,
        accentColor: accentColor,
        onItemSelect: onItemSelect!,
      );
    } else {
      return MultiSelectDropdown(
        label: selectorLabel,
        itemCount: itemCount,
        selectedItems: selectedItems!,
        itemColors: itemColors,
        getItemLabel: getItemLabel,
        accentColor: accentColor,
        onItemToggle: onItemToggle!,
      );
    }
  }

  /// 构建折线图
  Widget _buildChart() {
    return LineChart(
      LineChartData(
        gridData: FlGridData(
          show: true,
          drawVerticalLine: true,
          horizontalInterval: yInterval,
          verticalInterval: xInterval,
          getDrawingHorizontalLine: (value) {
            return FlLine(
              color: TechColors.borderDark.withOpacity(0.3),
              strokeWidth: 1,
            );
          },
          getDrawingVerticalLine: (value) {
            return FlLine(
              color: TechColors.borderDark.withOpacity(0.3),
              strokeWidth: 1,
            );
          },
        ),
        titlesData: FlTitlesData(
          leftTitles: AxisTitles(
            axisNameWidget: Text(
              yAxisLabel,
              style: const TextStyle(
                color: TechColors.textSecondary,
                fontSize: 10,
              ),
            ),
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 40,
              getTitlesWidget: (value, meta) {
                return Text(
                  value.toInt().toString(),
                  style: const TextStyle(
                    color: TechColors.textSecondary,
                    fontSize: 9,
                  ),
                );
              },
            ),
          ),
          bottomTitles: AxisTitles(
            axisNameWidget: Text(
              xAxisLabel,
              style: const TextStyle(
                color: TechColors.textSecondary,
                fontSize: 10,
              ),
            ),
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 24,
              interval: xInterval,
              getTitlesWidget: (value, meta) {
                return Text(
                  value.toInt().toString(),
                  style: const TextStyle(
                    color: TechColors.textSecondary,
                    fontSize: 9,
                  ),
                );
              },
            ),
          ),
          rightTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          topTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
        ),
        borderData: FlBorderData(
          show: true,
          border: Border.all(
            color: TechColors.borderDark.withOpacity(0.5),
          ),
        ),
        lineBarsData: _getSelectedData(),
        minY: minY,
        maxY: maxY,
      ),
    );
  }

  /// 获取选中设备的数据
  List<LineChartBarData> _getSelectedData() {
    List<LineChartBarData> result = [];

    if (isSingleSelect) {
      // 单选模式：只显示选中项的数据
      if (dataMap.containsKey(selectedIndex)) {
        result.add(
          LineChartBarData(
            spots: dataMap[selectedIndex]!,
            isCurved: true,
            color: itemColors[selectedIndex!],
            barWidth: 2,
            dotData: const FlDotData(show: false),
          ),
        );
      }
    } else {
      // 多选模式：显示所有选中项的数据
      for (int i = 0; i < itemCount; i++) {
        if (selectedItems![i] && dataMap.containsKey(i)) {
          result.add(
            LineChartBarData(
              spots: dataMap[i]!,
              isCurved: true,
              color: itemColors[i],
              barWidth: 2,
              dotData: const FlDotData(show: false),
            ),
          );
        }
      }
    }

    return result;
  }
}

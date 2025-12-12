import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'data_tech_line_widgets.dart';
import 'data_multi_select_dropdown.dart';
import 'data_single_select_dropdown.dart';

/// 可复用的技术风格柱状折线图组件
/// 显示真正的折线图效果：带数据点、直线连接
/// 支持单选和多选两种模式
class TechBarChart extends StatelessWidget {
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

  /// 标题栏右侧自定义组件（如时间选择器）
  final List<Widget>? headerActions;

  /// 单选模式：设备选择回调
  final void Function(int index)? onItemSelect;

  /// 多选模式：设备切换回调
  final void Function(int index)? onItemToggle;

  /// 是否使用紧凑模式（更小的字体和间距）
  final bool compact;

  const TechBarChart({
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
    this.headerActions,
    this.isSingleSelect = false,
    this.selectedIndex,
    this.selectedItems,
    this.onItemSelect,
    this.onItemToggle,
    this.compact = false,
  }) : assert(
          isSingleSelect
              ? (selectedIndex != null && onItemSelect != null)
              : (selectedItems != null && onItemToggle != null),
          '单选模式需要 selectedIndex 和 onItemSelect，多选模式需要 selectedItems 和 onItemToggle',
        );

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(compact ? 8 : 12),
      decoration: BoxDecoration(
        color: TechColors.bgMedium.withOpacity(0.3),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: TechColors.borderDark),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeader(),
          SizedBox(height: compact ? 6 : 12),
          Expanded(
            child: _buildChart(),
          ),
        ],
      ),
    );
  }

  /// 构建图表头部 - 选择器和时间选择器靠右上角
  Widget _buildHeader() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        // 设备选择器
        _buildSelector(),
        // 间距
        if (headerActions != null) SizedBox(width: compact ? 4 : 10),
        // 时间选择器（headerActions）
        if (headerActions != null) ...headerActions!,
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
        compact: compact,
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
        compact: compact,
      );
    }
  }

  /// 构建折线图（真正的折线图：点到点直线连接）
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
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 16,
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

  /// 获取选中设备的数据（折线图模式：显示点，直线连接）
  List<LineChartBarData> _getSelectedData() {
    List<LineChartBarData> result = [];

    if (isSingleSelect) {
      // 单选模式：只显示选中项的数据
      if (dataMap.containsKey(selectedIndex)) {
        result.add(
          LineChartBarData(
            spots: dataMap[selectedIndex]!,
            isCurved: false, // [关键] 不使用曲线，使用直线连接
            color: itemColors[selectedIndex!],
            barWidth: 2,
            dotData: FlDotData(
              show: true, // [关键] 显示数据点
              getDotPainter: (spot, percent, barData, index) {
                return FlDotCirclePainter(
                  radius: 3, // 数据点半径
                  color: itemColors[selectedIndex!], // 数据点颜色
                  strokeWidth: 1.5,
                  strokeColor: TechColors.bgDeep, // 数据点边框颜色
                );
              },
            ),
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
              isCurved: false, // [关键] 不使用曲线，使用直线连接
              color: itemColors[i],
              barWidth: 2,
              dotData: FlDotData(
                show: true, // [关键] 显示数据点
                getDotPainter: (spot, percent, barData, index) {
                  return FlDotCirclePainter(
                    radius: 3, // 数据点半径
                    color: itemColors[i], // 数据点颜色
                    strokeWidth: 1.5,
                    strokeColor: TechColors.bgDeep, // 数据点边框颜色
                  );
                },
              ),
            ),
          );
        }
      }
    }

    return result;
  }
}

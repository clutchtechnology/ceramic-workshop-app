import 'package:flutter/material.dart';
import '../widgets/tech_line_widgets.dart';
import '../widgets/rotary_kiln_cell.dart';
import '../widgets/rotary_kiln_no_hopper_cell.dart';
import '../widgets/rotary_kiln_long_cell.dart';
import '../widgets/fan_cell.dart';
import '../widgets/water_pump_cell.dart';
import '../widgets/gas_pipe_cell.dart';

/// 实时大屏页面
/// 用于展示实时生产数据和监控信息
class RealtimeDashboardPage extends StatefulWidget {
  const RealtimeDashboardPage({super.key});

  @override
  State<RealtimeDashboardPage> createState() => _RealtimeDashboardPageState();
}

class _RealtimeDashboardPageState extends State<RealtimeDashboardPage> {
  @override
  void initState() {
    super.initState();
    // TODO: 接入PLC数据后，在此处初始化数据连接
  }

  @override
  void dispose() {
    // TODO: 接入PLC数据后，在此处释放数据连接
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // 获取屏幕尺寸
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;

    // 回转窑容器尺寸
    final rotaryKilnWidth = screenWidth * 0.77;
    final rotaryKilnHeight = screenHeight * 0.5;

    // SCR容器尺寸
    final scrWidth = screenWidth * 0.2;
    final scrHeight = screenHeight * 0.5;

    // 辊道窑容器尺寸
    final rollerKilnWidth = screenWidth * 0.72;
    final rollerKilnHeight = screenHeight * 0.39;

    // 风机容器尺寸
    final fanWidth = screenWidth * 0.25;
    final fanHeight = screenHeight * 0.39;

    return Scaffold(
      backgroundColor: TechColors.bgDeep,
      body: AnimatedGridBackground(
        gridColor: TechColors.borderDark.withOpacity(0.3),
        gridSize: 40,
        child: Padding(
          padding: const EdgeInsets.all(12.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 顶部区域 - 回转窑 + SCR
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 左侧 - 回转窑区域
                  _buildRotaryKilnSection(rotaryKilnWidth, rotaryKilnHeight),
                  const SizedBox(width: 12),
                  // 右侧 - SCR区域
                  _buildScrSection(scrWidth, scrHeight),
                ],
              ),
              const SizedBox(height: 12),
              // 底部区域 - 辊道窑 + 风机
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 左侧 - 辊道窑
                  _buildRollerKilnSection(rollerKilnWidth, rollerKilnHeight),
                  const SizedBox(width: 12),
                  // 右侧 - 风机
                  _buildFanSection(fanWidth, fanHeight),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// 回转窑区域 - 5x2网格布局（9个容器）
  Widget _buildRotaryKilnSection(double width, double height) {
    return SizedBox(
      width: width,
      height: height,
      child: TechPanel(
        title: '回转窑监控',
        accentColor: TechColors.glowOrange,
        child: Padding(
          padding: const EdgeInsets.all(8.0),
          child: Column(
            children: [
              // 第一行 - 5个小容器
              Expanded(
                child: Row(
                  children: [
                    Expanded(child: _buildRotaryKilnCell(1)),
                    const SizedBox(width: 8),
                    Expanded(child: _buildRotaryKilnCell(2)),
                    const SizedBox(width: 8),
                    Expanded(child: _buildRotaryKilnNoHopperCell(3)),
                    const SizedBox(width: 8),
                    Expanded(child: _buildRotaryKilnLongCell(4)),
                    const SizedBox(width: 8),
                    Expanded(child: _buildRotaryKilnLongCell(5)),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              // 第二行 - 4个容器 + 1个空白
              Expanded(
                child: Row(
                  children: [
                    Expanded(child: _buildRotaryKilnCell(6)),
                    const SizedBox(width: 8),
                    Expanded(child: _buildRotaryKilnCell(7)),
                    const SizedBox(width: 8),
                    Expanded(child: _buildRotaryKilnNoHopperCell(8)),
                    const SizedBox(width: 8),
                    Expanded(child: _buildRotaryKilnLongCell(9)),
                    const SizedBox(width: 8),
                    const Expanded(child: SizedBox.shrink()),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// 单个回转窑数据小容器 - 显示设备图片
  Widget _buildRotaryKilnCell(int index) {
    return RotaryKilnCell(index: index);
  }

  /// 单个无料仓回转窑数据小容器
  Widget _buildRotaryKilnNoHopperCell(int index) {
    return RotaryKilnNoHopperCell(index: index);
  }

  /// 单个长回转窑数据小容器
  Widget _buildRotaryKilnLongCell(int index) {
    return RotaryKilnLongCell(index: index);
  }

  /// SCR设备区域 - 包含2个小容器
  Widget _buildScrSection(double width, double height) {
    return SizedBox(
      width: width,
      height: height,
      child: TechPanel(
        title: 'SCR 设备',
        accentColor: TechColors.glowBlue,
        child: Padding(
          padding: const EdgeInsets.all(8.0),
          child: Column(
            children: [
              // SCR-1 容器
              Expanded(
                child: _buildScrCell(1),
              ),
              const SizedBox(height: 12),
              // SCR-2 容器
              Expanded(
                child: _buildScrCell(2),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// 单个SCR设备小容器 - 包含氨泵（水泵）组件 + 燃气管
  Widget _buildScrCell(int index) {
    return Row(
      children: [
        // 左侧 - 水泵组件
        Expanded(
          child: WaterPumpCell(
            index: index,
            isRunning: index == 1 ? true : false,
            power: index == 1 ? 12.5 : 0.0,
            cumulativeEnergy: index == 1 ? 850.0 : 620.0,
            energyConsumption: index == 1 ? 10.2 : 0.0,
          ),
        ),
        // 右侧 - 燃气管组件（紧贴水泵）
        Expanded(
          child: GasPipeCell(
            index: index,
            isRunning: index == 1 ? true : false,
            flowRate: index == 1 ? 85.5 : 0.0,
            energyConsumption: index == 1 ? 15.8 : 0.0,
          ),
        ),
      ],
    );
  }

  /// 辊道窑区域 - 显示设备图片
  Widget _buildRollerKilnSection(double width, double height) {
    return SizedBox(
      width: width,
      height: height,
      child: TechPanel(
        title: '辊道窑监控',
        accentColor: TechColors.glowGreen,
        child: Padding(
          padding: const EdgeInsets.all(8.0),
          child: Stack(
            children: [
              // 背景图片 - 占满整个空间
              Center(
                child: Image.asset(
                  'assets/images/roller_kiln.png',
                  fit: BoxFit.contain,
                  width: double.infinity,
                  height: double.infinity,
                  errorBuilder: (context, error, stackTrace) {
                    // 图片加载失败时的占位符
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.image_not_supported,
                            color: TechColors.textSecondary.withOpacity(0.5),
                            size: 48,
                          ),
                          const SizedBox(height: 12),
                          Text(
                            '辊道窑设备图',
                            style: TextStyle(
                              color: TechColors.textSecondary,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
              // 上方数据标签 - 覆盖在图片上
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: SizedBox(
                  height: 70,
                  child: Row(
                    children: [
                      Expanded(
                          child: _buildRollerKilnDataCard(
                              '区域 1', '820°C', '38kW')),
                      const SizedBox(width: 8),
                      Expanded(
                          child: _buildRollerKilnDataCard(
                              '区域 2', '850°C', '42kW')),
                      const SizedBox(width: 8),
                      Expanded(
                          child: _buildRollerKilnDataCard(
                              '区域 3', '880°C', '45kW')),
                      const SizedBox(width: 8),
                      Expanded(
                          child: _buildRollerKilnDataCard(
                              '区域 4', '860°C', '40kW')),
                      const SizedBox(width: 8),
                      Expanded(
                          child: _buildRollerKilnDataCard(
                              '区域 5', '840°C', '39kW')),
                      const SizedBox(width: 8),
                      Expanded(
                          child: _buildRollerKilnDataCard(
                              '区域 6', '810°C', '36kW')),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// 辊道窑数据卡片
  Widget _buildRollerKilnDataCard(
      String zone, String temperature, String power) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: TechColors.bgDeep.withOpacity(0.85),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(
          color: TechColors.glowGreen.withOpacity(0.4),
          width: 1,
        ),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            zone,
            style: const TextStyle(
              color: TechColors.glowGreen,
              fontSize: 11,
              fontWeight: FontWeight.w600,
              fontFamily: 'Roboto Mono',
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '温度: $temperature',
            style: const TextStyle(
              color: TechColors.glowRed,
              fontSize: 11,
              fontWeight: FontWeight.w500,
              fontFamily: 'Roboto Mono',
            ),
          ),
          const SizedBox(height: 2),
          Text(
            '能耗: $power',
            style: const TextStyle(
              color: TechColors.glowOrange,
              fontSize: 11,
              fontWeight: FontWeight.w500,
              fontFamily: 'Roboto Mono',
            ),
          ),
        ],
      ),
    );
  }

  /// 风机区域 - 包含2个横向排列的小容器
  Widget _buildFanSection(double width, double height) {
    return SizedBox(
      width: width,
      height: height,
      child: TechPanel(
        title: '风机监控',
        accentColor: TechColors.glowCyan,
        child: Padding(
          padding: const EdgeInsets.all(8.0),
          child: Row(
            children: [
              // 风机-1 容器
              Expanded(
                child: FanCell(index: 1),
              ),
              const SizedBox(width: 12),
              // 风机-2 容器
              Expanded(
                child: FanCell(index: 2),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

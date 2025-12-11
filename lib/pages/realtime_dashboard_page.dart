import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'dart:async';
import '../models/hopper_model.dart';
import '../models/roller_kiln_model.dart';
import '../models/scr_fan_model.dart';
import '../providers/realtime_config_provider.dart';
import '../services/hopper_service.dart';
import '../services/roller_kiln_service.dart';
import '../services/scr_fan_service.dart';
import '../widgets/data_display/data_tech_line_widgets.dart';
import '../widgets/realtime_dashboard/real_rotary_kiln_cell.dart';
import '../widgets/realtime_dashboard/real_rotary_kiln_no_hopper_cell.dart';
import '../widgets/realtime_dashboard/real_rotary_kiln_long_cell.dart';
import '../widgets/realtime_dashboard/real_fan_cell.dart';
import '../widgets/realtime_dashboard/real_water_pump_cell.dart';
import '../widgets/realtime_dashboard/real_gas_pipe_cell.dart';

/// 实时大屏页面
/// 用于展示实时生产数据和监控信息
class RealtimeDashboardPage extends StatefulWidget {
  const RealtimeDashboardPage({super.key});

  @override
  State<RealtimeDashboardPage> createState() => _RealtimeDashboardPageState();
}

class _RealtimeDashboardPageState extends State<RealtimeDashboardPage> {
  final HopperService _hopperService = HopperService();
  final RollerKilnService _rollerKilnService = RollerKilnService();
  final ScrFanService _scrFanService = ScrFanService();

  Timer? _timer;
  Map<String, HopperData> _hopperData = {};
  RollerKilnData? _rollerKilnData;
  ScrFanBatchData? _scrFanData;
  bool _isRefreshing = false;

  // 映射 UI 索引到设备 ID
  // 短窑: 1-4, 无料仓: 5-6, 长窑: 7-9
  final Map<int, String> _deviceMapping = {
    1: 'short_hopper_1',
    2: 'short_hopper_2',
    3: 'short_hopper_3',
    4: 'short_hopper_4',
    5: 'no_hopper_1',
    6: 'no_hopper_2',
    7: 'long_hopper_1',
    8: 'long_hopper_2',
    9: 'long_hopper_3',
  };

  @override
  void initState() {
    super.initState();
    _initData();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _initData() async {
    await _fetchData();
    // 每5秒轮询一次数据
    _timer = Timer.periodic(const Duration(seconds: 5), (timer) {
      _fetchData();
    });
  }

  Future<void> _fetchData() async {
    if (_isRefreshing) return;

    setState(() {
      _isRefreshing = true;
    });

    try {
      debugPrint('=== 开始批量获取实时数据 ===');

      // 方案1: 按设备类型分别调用批量接口
      final results = await Future.wait([
        // 1. 获取9个料仓数据
        _hopperService.getHopperBatchData(),
        // 2. 获取辊道窑数据
        _rollerKilnService.getRollerKilnRealtimeFormatted(),
        // 3. 获取SCR+风机数据
        _scrFanService.getScrFanBatchData(),
      ]);

      final hopperData = results[0] as Map<String, HopperData>;
      final rollerData = results[1] as RollerKilnData?;
      final scrFanData = results[2] as ScrFanBatchData?;

      debugPrint('✓ 料仓数据: ${hopperData.length} 个');
      debugPrint(
          '✓ 辊道窑数据: ${rollerData != null ? rollerData.zones.length : 0} 个温区');
      debugPrint('✓ SCR设备: ${scrFanData?.scr.total ?? 0} 个');
      debugPrint('✓ 风机设备: ${scrFanData?.fan.total ?? 0} 个');
      debugPrint('=== 数据获取完成 ===');

      if (mounted) {
        setState(() {
          _hopperData = hopperData;
          _rollerKilnData = rollerData;
          _scrFanData = scrFanData;
        });
      }
    } catch (e) {
      debugPrint('Error fetching batch data: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isRefreshing = false;
        });
      }
    }
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
        // 添加刷新按钮到标题栏
        titleAction: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '已获取: ${_hopperData.length}/9',
              style: TextStyle(
                color: TechColors.textSecondary,
                fontSize: 12,
                fontFamily: 'Roboto Mono',
              ),
            ),
            const SizedBox(width: 12),
            InkWell(
              onTap: _isRefreshing ? null : _fetchData,
              borderRadius: BorderRadius.circular(4),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: _isRefreshing
                      ? TechColors.bgMedium
                      : TechColors.glowOrange.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(
                    color: _isRefreshing
                        ? TechColors.borderDark
                        : TechColors.glowOrange,
                    width: 1,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (_isRefreshing)
                      SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(
                            TechColors.glowOrange,
                          ),
                        ),
                      )
                    else
                      Icon(
                        Icons.refresh,
                        size: 16,
                        color: TechColors.glowOrange,
                      ),
                    const SizedBox(width: 6),
                    Text(
                      _isRefreshing ? '刷新中...' : '刷新数据',
                      style: TextStyle(
                        color: _isRefreshing
                            ? TechColors.textSecondary
                            : TechColors.glowOrange,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        fontFamily: 'Roboto Mono',
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(8.0),
          child: Column(
            children: [
              // 第一行 - 短窑1-2 + 无料仓5 + 长窑7-8
              Expanded(
                child: Row(
                  children: [
                    Expanded(child: _buildRotaryKilnCell(1)),
                    const SizedBox(width: 8),
                    Expanded(child: _buildRotaryKilnCell(2)),
                    const SizedBox(width: 8),
                    Expanded(child: _buildRotaryKilnNoHopperCell(5)),
                    const SizedBox(width: 8),
                    Expanded(child: _buildRotaryKilnLongCell(7)),
                    const SizedBox(width: 8),
                    Expanded(child: _buildRotaryKilnLongCell(8)),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              // 第二行 - 短窑3-4 + 无料仓6 + 长窑9 + 空白
              Expanded(
                child: Row(
                  children: [
                    Expanded(child: _buildRotaryKilnCell(3)),
                    const SizedBox(width: 8),
                    Expanded(child: _buildRotaryKilnCell(4)),
                    const SizedBox(width: 8),
                    Expanded(child: _buildRotaryKilnNoHopperCell(6)),
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
    final deviceId = _deviceMapping[index];
    final data = deviceId != null ? _hopperData[deviceId] : null;
    return RotaryKilnCell(index: index, data: data, deviceId: deviceId);
  }

  /// 单个无料仓回转窑数据小容器
  Widget _buildRotaryKilnNoHopperCell(int index) {
    final deviceId = _deviceMapping[index];
    final data = deviceId != null ? _hopperData[deviceId] : null;
    return RotaryKilnNoHopperCell(index: index, data: data, deviceId: deviceId);
  }

  /// 单个长回转窑数据小容器
  Widget _buildRotaryKilnLongCell(int index) {
    final deviceId = _deviceMapping[index];
    final data = deviceId != null ? _hopperData[deviceId] : null;
    return RotaryKilnLongCell(index: index, data: data, deviceId: deviceId);
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
    // 从批量数据中获取对应的SCR设备 (index从1开始，数组从0开始)
    final scrDevice = (_scrFanData?.scr.devices.length ?? 0) >= index
        ? _scrFanData!.scr.devices[index - 1]
        : null;

    final power = scrDevice?.elec?.pt ?? 0.0;
    final energy = scrDevice?.elec?.impEp ?? 0.0;
    final flowRate = scrDevice?.gas?.flowRate ?? 0.0;

    // 使用配置的阈值判断运行状态
    final configProvider = context.read<RealtimeConfigProvider>();
    final isPumpRunning = configProvider.isScrPumpRunning(index, power);
    final isGasRunning = configProvider.isScrGasRunning(index, flowRate);

    return Row(
      children: [
        // 左侧 - 水泵组件
        Expanded(
          child: WaterPumpCell(
            index: index,
            isRunning: isPumpRunning,
            power: power,
            cumulativeEnergy: energy,
            energyConsumption: energy,
          ),
        ),
        // 右侧 - 燃气管组件（紧贴水泵）
        Expanded(
          child: GasPipeCell(
            index: index,
            isRunning: isGasRunning,
            flowRate: flowRate,
            energyConsumption: scrDevice?.gas?.totalFlow ?? 0.0,
          ),
        ),
      ],
    );
  }

  /// 辊道窑区域 - 显示设备图片
  Widget _buildRollerKilnSection(double width, double height) {
    // 计算总能耗（6个温区电表能耗的总和）
    final totalPower = _rollerKilnData?.zones.fold<double>(
          0.0,
          (sum, zone) => sum + zone.energy,
        ) ??
        0.0;

    return SizedBox(
      width: width,
      height: height,
      child: TechPanel(
        title: '辊道窑监控',
        accentColor: TechColors.glowGreen,
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
                        const Text(
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
                  children: _rollerKilnData?.zones.asMap().entries.map((entry) {
                        final index = entry.key;
                        final zone = entry.value;
                        return Expanded(
                          child: Padding(
                            padding: EdgeInsets.only(
                              left: index == 0 ? 0 : 4,
                              right:
                                  index == (_rollerKilnData!.zones.length - 1)
                                      ? 0
                                      : 4,
                            ),
                            child: _buildRollerKilnDataCard(
                              zone.zoneName,
                              '${zone.temperature.toStringAsFixed(0)}°C',
                              '${zone.energy.toStringAsFixed(0)}kWh',
                              zoneIndex: index + 1, // 温区索引 1-6
                              temperatureValue: zone.temperature,
                            ),
                          ),
                        );
                      }).toList() ??
                      List.generate(
                        6,
                        (index) => Expanded(
                          child: Padding(
                            padding: EdgeInsets.only(
                              left: index == 0 ? 0 : 4,
                              right: index == 5 ? 0 : 4,
                            ),
                            child: _buildRollerKilnDataCard(
                              '区域 ${index + 1}',
                              '--°C',
                              '--kW',
                              zoneIndex: index + 1,
                            ),
                          ),
                        ),
                      ),
                ),
              ),
            ),
            // 左下角功率总和标签
            Positioned(
              left: 0,
              bottom: 0,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: TechColors.bgDeep.withOpacity(0.92),
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(
                    color: TechColors.glowOrange.withOpacity(0.5),
                    width: 1,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      '总能耗: ',
                      style: TextStyle(
                        color: TechColors.textSecondary,
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    Text(
                      totalPower > 0
                          ? '${totalPower.toStringAsFixed(1)}kWh'
                          : '--kWh',
                      style: TextStyle(
                        color: TechColors.glowOrange,
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        fontFamily: 'Roboto Mono',
                        shadows: [
                          Shadow(
                            color: TechColors.glowOrange.withOpacity(0.5),
                            blurRadius: 6,
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
      ),
    );
  }

  /// 辊道窑数据卡片
  /// [zoneIndex] 温区索引 (1-6)
  /// [temperatureValue] 温度数值，用于计算颜色
  Widget _buildRollerKilnDataCard(String zone, String temperature, String power,
      {int? zoneIndex, double? temperatureValue}) {
    // 获取温度颜色配置
    final configProvider = context.read<RealtimeConfigProvider>();
    final tempColor = (zoneIndex != null && temperatureValue != null)
        ? configProvider.getRollerKilnTempColorByIndex(
            zoneIndex, temperatureValue)
        : TechColors.glowRed;

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
            style: TextStyle(
              color: tempColor,
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
    // 从批量数据中获取风机设备
    final fan1 = (_scrFanData?.fan.devices.isNotEmpty ?? false)
        ? _scrFanData!.fan.devices[0]
        : null;
    final fan2 = (_scrFanData?.fan.devices.length ?? 0) >= 2
        ? _scrFanData!.fan.devices[1]
        : null;

    // 使用配置的阈值判断运行状态
    final configProvider = context.read<RealtimeConfigProvider>();
    final fan1Power = fan1?.elec?.pt ?? 0.0;
    final fan2Power = fan2?.elec?.pt ?? 0.0;
    final isFan1Running = configProvider.isFanRunning(1, fan1Power);
    final isFan2Running = configProvider.isFanRunning(2, fan2Power);

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
                child: FanCell(
                  index: 1,
                  isRunning: isFan1Running,
                  power: fan1Power,
                  cumulativeEnergy: fan1?.elec?.impEp ?? 0.0,
                ),
              ),
              const SizedBox(width: 12),
              // 风机-2 容器
              Expanded(
                child: FanCell(
                  index: 2,
                  isRunning: isFan2Running,
                  power: fan2Power,
                  cumulativeEnergy: fan2?.elec?.impEp ?? 0.0,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

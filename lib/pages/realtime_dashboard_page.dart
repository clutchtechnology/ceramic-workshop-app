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
import '../widgets/icons/icons.dart';
import '../widgets/realtime_dashboard/real_rotary_kiln_cell.dart';
import '../widgets/realtime_dashboard/real_rotary_kiln_no_hopper_cell.dart';
import '../widgets/realtime_dashboard/real_rotary_kiln_long_cell.dart';
import '../widgets/realtime_dashboard/real_fan_cell.dart';
import '../widgets/realtime_dashboard/real_water_pump_cell.dart';
import '../widgets/realtime_dashboard/real_gas_pipe_cell.dart';
import '../utils/app_logger.dart';

/// 实时大屏页面
/// 用于展示实时生产数据和监控信息
class RealtimeDashboardPage extends StatefulWidget {
  const RealtimeDashboardPage({super.key});

  @override
  State<RealtimeDashboardPage> createState() => RealtimeDashboardPageState();
}

class RealtimeDashboardPageState extends State<RealtimeDashboardPage> {
  final HopperService _hopperService = HopperService();
  final RollerKilnService _rollerKilnService = RollerKilnService();
  final ScrFanService _scrFanService = ScrFanService();

  Timer? _timer;
  Map<String, HopperData> _hopperData = {};
  RollerKilnData? _rollerKilnData;
  ScrFanBatchData? _scrFanData;
  bool _isRefreshing = false;

  // 🔧 新增: 请求统计
  int _successCount = 0;
  int _failCount = 0;
  DateTime? _lastSuccessTime;
  DateTime? _lastUIRefreshTime; // 🔧 UI刷新时间追踪
  int _consecutiveSkips = 0; // 🔧 连续跳过刷新次数

  // 🔧 公开方法供顶部bar调用
  bool get isRefreshing => _isRefreshing;

  /// 手动刷新数据
  Future<void> refreshData() async {
    await _fetchData();
  }

  // 映射 UI 索引到设备 ID
  // 短窑: 7,6,5,4, 无料仓: 2,1, 长窑: 8,3,9
  final Map<int, String> _deviceMapping = {
    7: 'short_hopper_1',
    6: 'short_hopper_2',
    5: 'short_hopper_3',
    4: 'short_hopper_4',
    2: 'no_hopper_1',
    1: 'no_hopper_2',
    8: 'long_hopper_1',
    3: 'long_hopper_2',
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
    _timer = null;
    logger.info('RealtimeDashboardPage disposed, timer cancelled');
    super.dispose();
  }

  Future<void> _initData() async {
    await _fetchData();
    // 🔧 修复: Timer 回调添加异常保护
    _timer = Timer.periodic(const Duration(seconds: 5), (timer) async {
      try {
        // 🔧 检测UI长时间未刷新
        if (_lastUIRefreshTime != null) {
          final sinceLastRefresh =
              DateTime.now().difference(_lastUIRefreshTime!);
          if (sinceLastRefresh.inSeconds > 60) {
            logger.warning(
                'UI超过60秒未刷新！上次刷新: $_lastUIRefreshTime, isRefreshing=$_isRefreshing, mounted=$mounted');
          }
        }
        await _fetchData();
      } catch (e, stack) {
        logger.error('定时器回调异常', e, stack);
        // 异常不会导致定时器停止
      }
    });
    logger.lifecycle('数据轮询定时器已启动 (间隔: 5秒)');
  }

  Future<void> _fetchData() async {
    // 🔧 检测是否被跳过
    if (_isRefreshing) {
      _consecutiveSkips++;
      if (_consecutiveSkips >= 10) {
        logger.warning('UI刷新被跳过 $_consecutiveSkips 次（_isRefreshing持续为true）');
      }
      return;
    }
    if (!mounted) {
      logger.warning('组件未挂载，跳过刷新');
      return;
    }

    _consecutiveSkips = 0; // 重置跳过计数

    setState(() {
      _isRefreshing = true;
    });

    try {
      // 🔧 修复: Future.wait 添加超时控制
      final results = await Future.wait([
        _hopperService.getHopperBatchData(),
        _rollerKilnService.getRollerKilnRealtimeFormatted(),
        _scrFanService.getScrFanBatchData(),
      ]).timeout(
        const Duration(seconds: 15),
        onTimeout: () {
          logger.warning('批量数据请求超时 (15秒)');
          throw TimeoutException('批量数据请求超时');
        },
      );

      final hopperData = results[0] as Map<String, HopperData>;
      final rollerData = results[1] as RollerKilnData?;
      final scrFanData = results[2] as ScrFanBatchData?;

      // 🔧 更新统计
      _successCount++;
      _lastSuccessTime = DateTime.now();

      // 每500次成功记录一次日志（约 42 分钟），减少日志噪音
      if (_successCount % 500 == 0) {
        logger.info(
            '数据轮询统计: 成功=$_successCount, 失败=$_failCount, 最后成功时间=$_lastSuccessTime');
      }

      if (mounted) {
        setState(() {
          _hopperData = hopperData;
          _rollerKilnData = rollerData;
          _scrFanData = scrFanData;
        });
        _lastUIRefreshTime = DateTime.now(); // 🔧 记录UI刷新时间
      } else {
        logger.warning('数据获取成功但组件已卸载，无法刷新UI');
      }
    } catch (e, stack) {
      _failCount++;

      // 🔧 失败时记录日志（每10次失败记录一次，避免日志过多）
      if (_failCount <= 3 || _failCount % 10 == 0) {
        logger.error('数据获取失败 (第$_failCount次)', e, stack);
      }
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
    final rotaryKilnHeight = screenHeight * 0.54; // 增加高度 (0.5 -> 0.54)

    // SCR容器尺寸
    final scrWidth = screenWidth * 0.2;
    final scrHeight = screenHeight * 0.54; // 增加高度 (0.5 -> 0.54)

    // 辊道窑容器尺寸
    final rollerKilnWidth = screenWidth * 0.72;
    final rollerKilnHeight = screenHeight * 0.35; // 减小高度 (0.39 -> 0.35)

    // 风机容器尺寸
    final fanWidth = screenWidth * 0.25;
    final fanHeight = screenHeight * 0.35; // 减小高度 (0.39 -> 0.35)

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
        accentColor: TechColors.glowOrange,
        child: Padding(
          padding: const EdgeInsets.all(4.0),
          child: Column(
            children: [
              // 第一行 - 短窑7-6 + 无料仓2 + 长窑8-3
              Expanded(
                child: Row(
                  children: [
                    Expanded(flex: 6, child: _buildRotaryKilnCell(7)), // 1.5
                    const SizedBox(width: 4),
                    Expanded(flex: 6, child: _buildRotaryKilnCell(6)), // 1.5
                    const SizedBox(width: 4),
                    Expanded(
                        flex: 5,
                        child: _buildRotaryKilnNoHopperCell(2)), // 1.25
                    const SizedBox(width: 4),
                    Expanded(
                        flex: 6, child: _buildRotaryKilnLongCell(8)), // 1.5
                    const SizedBox(width: 4),
                    Expanded(
                        flex: 6, child: _buildRotaryKilnLongCell(3)), // 1.5
                  ],
                ),
              ),
              const SizedBox(height: 4),
              // 第二行 - 短窑5-4 + 无料仓1 + 长窑9 + 空白
              Expanded(
                child: Row(
                  children: [
                    Expanded(flex: 6, child: _buildRotaryKilnCell(5)), // 1.5
                    const SizedBox(width: 4),
                    Expanded(flex: 6, child: _buildRotaryKilnCell(4)), // 1.5
                    const SizedBox(width: 4),
                    Expanded(
                        flex: 5,
                        child: _buildRotaryKilnNoHopperCell(1)), // 1.25
                    const SizedBox(width: 4),
                    Expanded(
                        flex: 6, child: _buildRotaryKilnLongCell(9)), // 1.5
                    const SizedBox(width: 4),
                    const Expanded(flex: 6, child: SizedBox.shrink()), // 1.5
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
    final currentA = scrDevice?.elec?.currentA ?? 0.0;
    final currentB = scrDevice?.elec?.currentB ?? 0.0;
    final currentC = scrDevice?.elec?.currentC ?? 0.0;

    // 使用配置的阈值判断运行状态
    final configProvider = context.read<RealtimeConfigProvider>();
    final isPumpRunning = configProvider.isScrPumpRunning(index, power);
    final isGasRunning = configProvider.isScrGasRunning(index, flowRate);

    return Row(
      children: [
        // 左侧 - 水泵组件 (占5份)
        Expanded(
          flex: 5,
          child: WaterPumpCell(
            index: index,
            isRunning: isPumpRunning,
            power: power,
            cumulativeEnergy: energy,
            energyConsumption: energy,
            currentA: currentA,
            currentB: currentB,
            currentC: currentC,
          ),
        ),
        // 右侧 - 燃气管组件 (占3份)
        Expanded(
          flex: 3,
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
    final totalEnergy = _rollerKilnData?.zones.fold<double>(
          0.0,
          (sum, zone) => sum + zone.energy,
        ) ??
        0.0;

    // 计算总电流（6个温区电流的总和）
    final totalCurrentA = _rollerKilnData?.zones.fold<double>(
          0.0,
          (sum, zone) => sum + zone.currentA,
        ) ??
        0.0;
    final totalCurrentB = _rollerKilnData?.zones.fold<double>(
          0.0,
          (sum, zone) => sum + zone.currentB,
        ) ??
        0.0;
    final totalCurrentC = _rollerKilnData?.zones.fold<double>(
          0.0,
          (sum, zone) => sum + zone.currentC,
        ) ??
        0.0;

    return SizedBox(
      width: width,
      height: height,
      child: TechPanel(
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
                height: 120,
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
                              currentA: zone.currentA,
                              currentB: zone.currentB,
                              currentC: zone.currentC,
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
                              '0°C',
                              '0kWh',
                              zoneIndex: index + 1,
                              temperatureValue: 0.0,
                              currentA: 0.0,
                              currentB: 0.0,
                              currentC: 0.0,
                            ),
                          ),
                        ),
                      ),
                ),
              ),
            ),
            // 左下角功率总和标签 + 三相电流（单列4行显示）
            Positioned(
              left: 0,
              bottom: 0,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
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
                    // 第一行：总能耗
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        EnergyIcon(color: TechColors.glowOrange, size: 18),
                        const SizedBox(width: 2),
                        Text(
                          _rollerKilnData != null
                              ? '${totalEnergy.toStringAsFixed(1)}kWh'
                              : '0.0kWh',
                          style: const TextStyle(
                            color: TechColors.glowOrange,
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                            fontFamily: 'Roboto Mono',
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    // 第二行：A相电流
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        CurrentIcon(color: TechColors.glowCyan, size: 18),
                        Text(
                          'A:${totalCurrentA.toStringAsFixed(1)}A',
                          style: const TextStyle(
                            color: TechColors.glowCyan,
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                            fontFamily: 'Roboto Mono',
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    // 第三行：B相电流
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        CurrentIcon(color: TechColors.glowCyan, size: 18),
                        Text(
                          'B:${totalCurrentB.toStringAsFixed(1)}A',
                          style: const TextStyle(
                            color: TechColors.glowCyan,
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                            fontFamily: 'Roboto Mono',
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    // 第四行：C相电流
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        CurrentIcon(color: TechColors.glowCyan, size: 18),
                        Text(
                          'C:${totalCurrentC.toStringAsFixed(1)}A',
                          style: const TextStyle(
                            color: TechColors.glowCyan,
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                            fontFamily: 'Roboto Mono',
                          ),
                        ),
                      ],
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
  /// [currentA], [currentB], [currentC] 三相电流值
  Widget _buildRollerKilnDataCard(String zone, String temperature, String power,
      {int? zoneIndex,
      double? temperatureValue,
      double? currentA,
      double? currentB,
      double? currentC}) {
    // 获取温度颜色配置
    final configProvider = context.read<RealtimeConfigProvider>();
    final tempColor = (zoneIndex != null && temperatureValue != null)
        ? configProvider.getRollerKilnTempColorByIndex(
            zoneIndex, temperatureValue)
        : TechColors.glowRed;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
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
          // 左侧列: 温区名称 + 温度 + 能耗
          Flexible(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.only(left: 2),
                  child: Text(
                    zone,
                    style: const TextStyle(
                      color: TechColors.glowGreen,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      fontFamily: 'Roboto Mono',
                    ),
                    overflow: TextOverflow.ellipsis,
                    softWrap: false,
                  ),
                ),
                const SizedBox(height: 2),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    ThermometerIcon(color: tempColor, size: 18),
                    const SizedBox(width: 2),
                    Text(
                      temperature,
                      style: TextStyle(
                        color: tempColor,
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
                    EnergyIcon(color: TechColors.glowOrange, size: 18),
                    const SizedBox(width: 2),
                    Text(
                      power,
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
          // 右侧列: 三相电流
          if (currentA != null && currentB != null && currentC != null)
            Flexible(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      CurrentIcon(color: TechColors.glowCyan, size: 18),
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
                      CurrentIcon(color: TechColors.glowCyan, size: 18),
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
                      CurrentIcon(color: TechColors.glowCyan, size: 18),
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
                  currentA: fan1?.elec?.currentA ?? 0.0,
                  currentB: fan1?.elec?.currentB ?? 0.0,
                  currentC: fan1?.elec?.currentC ?? 0.0,
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
                  currentA: fan2?.elec?.currentA ?? 0.0,
                  currentB: fan2?.elec?.currentB ?? 0.0,
                  currentC: fan2?.elec?.currentC ?? 0.0,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

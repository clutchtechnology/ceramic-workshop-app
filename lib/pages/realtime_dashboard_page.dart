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
import '../services/realtime_data_cache_service.dart';
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
  final RealtimeDataCacheService _cacheService = RealtimeDataCacheService();

  // ═══════════════════════════════════════════════════════════════════════════
  // 核心业务数据 (序号关联注释法)
  // ═══════════════════════════════════════════════════════════════════════════

  Timer? _timer;

  // 1, 料仓数据 - 9台回转窑 (短窑4台 + 无料仓2台 + 长窑3台)
  Map<String, HopperData> _hopperData = {};

  // 2, 辊道窑数据 - 1台辊道窑 (6个温区)
  RollerKilnData? _rollerKilnData;

  // 3, SCR+风机数据 - 2台SCR + 2台风机
  ScrFanBatchData? _scrFanData;

  // 4, 刷新状态标志 - 防止重复请求
  bool _isRefreshing = false;

  // 5, 请求统计 - 用于7x24监控诊断
  int _successCount = 0;
  int _failCount = 0;
  DateTime? _lastSuccessTime;
  DateTime? _lastUIRefreshTime;
  int _consecutiveSkips = 0;

  // 🔧 [CRITICAL] 防止 _isRefreshing 卡死的保护机制
  DateTime? _refreshStartTime; // 记录请求开始时间
  static const int _maxRefreshDurationSeconds = 20; // 最大允许刷新时长

  // 🔧 [CRITICAL] 网络异常时的退避策略
  int _consecutiveFailures = 0; // 连续失败次数
  static const int _maxBackoffSeconds = 60; // 最大退避间隔
  static const int _normalIntervalSeconds = 5; // 正常轮询间隔

  // 6, UI索引到设备ID的映射 (硬件布局决定)
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

  // 4, 公开刷新状态供顶部bar调用
  bool get isRefreshing => _isRefreshing;

  /// 手动刷新数据
  Future<void> refreshData() async {
    await _fetchData();
  }

  /// 🔧 暂停定时器（页面不可见时调用）
  void pausePolling() {
    if (_timer != null && _timer!.isActive) {
      _timer?.cancel();
      _timer = null;
      logger.info('RealtimeDashboardPage: 轮询已暂停');
    }
  }

  /// 🔧 恢复定时器（页面可见时调用）
  void resumePolling() {
    if (_timer == null) {
      _startPolling();
      logger.info('RealtimeDashboardPage: 轮询已恢复');
      // 立即刷新一次数据
      _fetchData();
    }
  }

  /// 🔧 [核心] 启动轮询定时器（提取公共逻辑，消除重复）
  /// 支持动态间隔：网络异常时自动延长轮询间隔，恢复后自动缩短
  void _startPolling() {
    _timer?.cancel(); // 防止重复创建

    // 🔧 计算当前轮询间隔（指数退避）
    int intervalSeconds = _normalIntervalSeconds;
    if (_consecutiveFailures > 0) {
      // 每失败一次，间隔翻倍，最大60秒
      intervalSeconds = (_normalIntervalSeconds * (1 << _consecutiveFailures))
          .clamp(_normalIntervalSeconds, _maxBackoffSeconds);
    }

    _timer = Timer.periodic(Duration(seconds: intervalSeconds), (timer) async {
      // 🔧 [CRITICAL] 必须检查 mounted，防止 Widget 销毁后继续执行
      if (!mounted) {
        timer.cancel();
        return;
      }

      try {
        // 🔧 检测UI长时间未刷新（使用局部变量避免竞态）
        final lastRefresh = _lastUIRefreshTime;
        if (lastRefresh != null) {
          final sinceLastRefresh = DateTime.now().difference(lastRefresh);
          if (sinceLastRefresh.inSeconds > 60) {
            logger.warning(
                'UI超过60秒未刷新！上次刷新: $lastRefresh, isRefreshing=$_isRefreshing');
          }
        }
        await _fetchData();
      } catch (e, stack) {
        logger.error('定时器回调异常', e, stack);
        // 异常不会导致定时器停止
      }
    });
  }

  /// 🔧 重启轮询（用于失败后调整间隔）
  void _restartPollingIfNeeded(bool wasSuccess) {
    if (!mounted) return;

    final previousFailures = _consecutiveFailures;

    if (wasSuccess) {
      // 成功时，如果之前有失败记录，需要恢复正常间隔
      if (_consecutiveFailures > 0) {
        _consecutiveFailures = 0;
        logger.info('网络恢复，轮询间隔恢复为 ${_normalIntervalSeconds}s');
        _startPolling(); // 重启以应用新间隔
      }
    } else {
      // 失败时，增加失败计数，但不超过4次（最大退避60秒）
      _consecutiveFailures = (_consecutiveFailures + 1).clamp(0, 4);

      // 只有失败次数变化时才重启定时器
      if (_consecutiveFailures != previousFailures &&
          _consecutiveFailures > 0) {
        final newInterval =
            (_normalIntervalSeconds * (1 << _consecutiveFailures))
                .clamp(_normalIntervalSeconds, _maxBackoffSeconds);
        logger.warning(
            '网络异常，轮询间隔延长至 ${newInterval}s (连续失败 $_consecutiveFailures 次)');
        _startPolling(); // 重启以应用新间隔
      }
    }
  }

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
    // 🔧 先加载本地缓存数据（App 重启后恢复上次数据）
    await _loadCachedData();

    // 然后尝试获取最新数据
    await _fetchData();

    // 🔧 启动轮询定时器（复用公共方法）
    _startPolling();
    logger.lifecycle('数据轮询定时器已启动 (间隔: 5秒)');
  }

  /// 加载本地缓存数据
  Future<void> _loadCachedData() async {
    try {
      final cachedData = await _cacheService.loadCache();
      if (cachedData != null && cachedData.hasData && mounted) {
        setState(() {
          _hopperData = cachedData.hopperData;
          _rollerKilnData = cachedData.rollerKilnData;
          _scrFanData = cachedData.scrFanData;
        });
        logger.info('已从缓存恢复数据显示');
      }
    } catch (e, stack) {
      logger.error('加载缓存数据失败', e, stack);
    }
  }

  Future<void> _fetchData() async {
    // 🔧 [CRITICAL] 检测 _isRefreshing 是否卡死
    if (_isRefreshing) {
      _consecutiveSkips++;

      // 检查是否超过最大允许刷新时长
      if (_refreshStartTime != null) {
        final duration =
            DateTime.now().difference(_refreshStartTime!).inSeconds;
        if (duration > _maxRefreshDurationSeconds) {
          // 🔧 强制重置 _isRefreshing，防止永久卡死
          logger.error('⚠️ _isRefreshing 卡死超过 ${duration}s，强制重置！');
          _isRefreshing = false;
          _refreshStartTime = null;
          // 不 return，继续执行本次请求
        } else {
          // 5, 连续跳过10次则记录警告
          if (_consecutiveSkips >= 10) {
            logger.warning(
                'UI刷新被跳过 $_consecutiveSkips 次（_isRefreshing持续为true, 已等待${duration}s）');
          }
          return;
        }
      } else {
        // _refreshStartTime 为空但 _isRefreshing 为 true，异常状态，强制重置
        logger.warning('异常状态：_isRefreshing=true 但 _refreshStartTime=null，强制重置');
        _isRefreshing = false;
      }
    }
    if (!mounted) {
      logger.warning('组件未挂载，跳过刷新');
      return;
    }

    _consecutiveSkips = 0; // 5, 重置跳过计数
    _refreshStartTime = DateTime.now(); // 🔧 记录请求开始时间

    setState(() {
      _isRefreshing = true; // 4, 标记开始刷新
    });

    try {
      // 1,2,3, 并行请求三类设备数据，添加15秒超时控制
      final results = await Future.wait([
        _hopperService.getHopperBatchData(), // 1, 料仓数据
        _rollerKilnService.getRollerKilnRealtimeFormatted(), // 2, 辊道窑数据
        _scrFanService.getScrFanBatchData(), // 3, SCR+风机数据
      ]).timeout(
        const Duration(seconds: 15),
        onTimeout: () {
          logger.warning('批量数据请求超时 (15秒)');
          throw TimeoutException('批量数据请求超时');
        },
      );

      // 1,2,3, 解析响应数据
      final hopperData = results[0] as Map<String, HopperData>;
      final rollerData = results[1] as RollerKilnData?;
      final scrFanData = results[2] as ScrFanBatchData?;

      // 🔧 [CRITICAL] 数据有效性检查 - 防止空数据覆盖正常数据
      final hasValidHopperData = hopperData.isNotEmpty;
      final hasValidRollerData = rollerData != null;
      final hasValidScrFanData = scrFanData != null;

      // 如果所有数据都为空，则视为失败（保持原有数据）
      if (!hasValidHopperData && !hasValidRollerData && !hasValidScrFanData) {
        throw Exception('API 返回空数据，可能后端正在处理中');
      }

      // 5, 更新请求统计
      _successCount++;
      _lastSuccessTime = DateTime.now();

      // 🔧 网络恢复，重置退避
      _restartPollingIfNeeded(true);

      // 5, 每500次成功记录一次日志（约42分钟），减少日志噪音
      if (_successCount % 500 == 0) {
        logger.info(
            '数据轮询统计: 成功=$_successCount, 失败=$_failCount, 最后成功时间=$_lastSuccessTime');
      }

      if (mounted) {
        setState(() {
          // 🔧 [CRITICAL] 只有当新数据非空时才更新（防止空数据覆盖导致显示为0）
          if (hasValidHopperData) {
            _hopperData = hopperData; // 1, 更新料仓数据
          }
          if (hasValidRollerData) {
            _rollerKilnData = rollerData; // 2, 更新辊道窑数据
          }
          if (hasValidScrFanData) {
            _scrFanData = scrFanData; // 3, 更新SCR+风机数据
          }
        });
        _lastUIRefreshTime = DateTime.now(); // 5, 记录UI刷新时间

        // 异步保存到本地缓存（只保存非空数据）
        _cacheService.saveCache(
          hopperData: hasValidHopperData ? hopperData : _hopperData,
          rollerKilnData: hasValidRollerData ? rollerData : _rollerKilnData,
          scrFanData: hasValidScrFanData ? scrFanData : _scrFanData,
        );
      } else {
        logger.warning('数据获取成功但组件已卸载，无法刷新UI');
      }
    } catch (e, stack) {
      _failCount++; // 5, 记录失败次数

      // 🔧 网络异常，启动退避策略
      _restartPollingIfNeeded(false);

      // 请求失败时保持上一次成功的数据，不清空也不更新
      // 这样即使后端服务未启动或网络异常，UI也能显示最后一次成功获取的数据
      if (_failCount <= 3 || _failCount % 10 == 0) {
        final hasValidData = _hopperData.isNotEmpty ||
            _rollerKilnData != null ||
            _scrFanData != null;
        logger.error(
            '数据获取失败 (第$_failCount次), 保持上一次数据显示 (hasValidData=$hasValidData)',
            e,
            stack);
      }
    } finally {
      // 🔧 [CRITICAL] 无论成功失败，都必须重置状态
      _refreshStartTime = null;
      if (mounted) {
        setState(() {
          _isRefreshing = false; // 4, 标记刷新结束
        });
      } else {
        // 即使 unmounted，也要重置标志（虽然此时已无意义）
        _isRefreshing = false;
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
    // 6, 通过UI索引查找设备ID，获取对应料仓数据
    final deviceId = _deviceMapping[index];
    // 1, 获取该设备的料仓实时数据
    final data = deviceId != null ? _hopperData[deviceId] : null;
    return RotaryKilnCell(index: index, data: data, deviceId: deviceId);
  }

  /// 单个无料仓回转窑数据小容器
  Widget _buildRotaryKilnNoHopperCell(int index) {
    // 6, 通过UI索引查找设备ID
    final deviceId = _deviceMapping[index];
    // 1, 获取该设备的料仓实时数据
    final data = deviceId != null ? _hopperData[deviceId] : null;
    return RotaryKilnNoHopperCell(index: index, data: data, deviceId: deviceId);
  }

  /// 单个长回转窑数据小容器
  Widget _buildRotaryKilnLongCell(int index) {
    // 6, 通过UI索引查找设备ID
    final deviceId = _deviceMapping[index];
    // 1, 获取该设备的料仓实时数据
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
    // 3, 从SCR批量数据中安全获取对应设备 (index从1开始，数组从0开始)
    final scrDevices = _scrFanData?.scr.devices;
    final scrDevice = (scrDevices != null && scrDevices.length >= index)
        ? scrDevices[index - 1]
        : null;

    final power = scrDevice?.elec?.pt ?? 0.0;
    final energy = scrDevice?.elec?.impEp ?? 0.0;
    final flowRate = scrDevice?.gas?.flowRate ?? 0.0;
    final currentA = scrDevice?.elec?.currentA ?? 0.0;
    final currentB = scrDevice?.elec?.currentB ?? 0.0;
    final currentC = scrDevice?.elec?.currentC ?? 0.0;

    // 3, 使用配置的阈值判断SCR氨泵和燃气运行状态
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
    // 2, 计算辊道窑6个温区的总能耗 (kWh)
    final totalEnergy = _rollerKilnData?.zones.fold<double>(
          0.0,
          (sum, zone) => sum + zone.energy,
        ) ??
        0.0;

    // 2, 计算辊道窑6个温区的三相总电流 (A)
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

    // 2, 安全获取温区列表，避免强制解包
    final zones = _rollerKilnData?.zones;

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
                // 2, 根据辊道窑温区数据渲染温度卡片
                child: Row(
                  children: zones?.asMap().entries.map((entry) {
                        final index = entry.key;
                        final zone = entry.value;
                        return Expanded(
                          child: Padding(
                            padding: EdgeInsets.only(
                              left: index == 0 ? 0 : 4,
                              right: index == (zones.length - 1) ? 0 : 4,
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
    // 3, 从风机批量数据中安全获取设备
    final fanDevices = _scrFanData?.fan.devices;
    final fan1 = (fanDevices?.isNotEmpty ?? false) ? fanDevices![0] : null;
    final fan2 =
        (fanDevices != null && fanDevices.length >= 2) ? fanDevices[1] : null;

    // 3, 使用配置的阈值判断风机运行状态
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

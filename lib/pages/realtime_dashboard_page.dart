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
import '../utils/timer_manager.dart';

/// 实时大屏页面
/// 用于展示实时生产数据和监控信息
class RealtimeDashboardPage extends StatefulWidget {
  const RealtimeDashboardPage({super.key});

  @override
  State<RealtimeDashboardPage> createState() => RealtimeDashboardPageState();
}

class RealtimeDashboardPageState extends State<RealtimeDashboardPage>
    with WidgetsBindingObserver {
  final HopperService _hopperService = HopperService();
  final RollerKilnService _rollerKilnService = RollerKilnService();
  final ScrFanService _scrFanService = ScrFanService();
  final RealtimeDataCacheService _cacheService = RealtimeDataCacheService();

  // ═══════════════════════════════════════════════════════════════════════════
  // 核心业务数据 (序号关联注释法)
  // ═══════════════════════════════════════════════════════════════════════════

  // 🔧 [CRITICAL] Timer ID 常量
  static const String _timerIdRealtime = 'realtime_dashboard_polling';

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

  // 🔧 [CRITICAL] 防止 _isRefreshing 卡死的保护机制
  DateTime? _refreshStartTime; // 记录请求开始时间
  static const int _maxRefreshDurationSeconds = 10; // 🔧 缩短到 10 秒（5秒超时 + 5秒缓冲）

  // 🔧 [CRITICAL] 网络异常时的退避策略
  int _consecutiveFailures = 0; // 连续失败次数
  static const int _maxBackoffSeconds = 60; // 最大退避间隔
  static const int _normalIntervalSeconds = 5; // 正常轮询间隔

  // 🔧 [NEW] 后端服务状态标志
  bool _isBackendAvailable = true; // 后端是否可用
  String? _lastErrorMessage; // 最后一次错误信息

  // 🔧 [CRITICAL] 缓存 Provider 引用（防止 build() 中频繁查找导致卡死）
  late RealtimeConfigProvider _configProvider;

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
    TimerManager().pause(_timerIdRealtime);
    logger.info('RealtimeDashboardPage: 轮询已暂停');
  }

  /// 🔧 恢复定时器（页面可见时调用）
  void resumePolling() {
    // 🔧 重置连续失败计数
    _consecutiveFailures = 0;

    if (!TimerManager().exists(_timerIdRealtime)) {
      _startPolling();
    } else {
      TimerManager().resume(_timerIdRealtime);
    }
    logger.info('RealtimeDashboardPage: 轮询已恢复');
    // 立即刷新一次数据
    _fetchData();
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // 应用生命周期监听 (处理窗口最小化/恢复)
  // ═══════════════════════════════════════════════════════════════════════════

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);

    switch (state) {
      case AppLifecycleState.resumed:
        // 🔧 窗口恢复/激活 → 恢复轮询
        logger.lifecycle('RealtimeDashboardPage: 应用恢复 (resumed) - 恢复轮询');
        resumePolling();
        break;
      case AppLifecycleState.inactive:
        // 🔧 窗口失去焦点（如切换到其他应用）→ 暂停轮询
        logger.lifecycle('RealtimeDashboardPage: 应用失去焦点 (inactive) - 暂停轮询');
        pausePolling();
        break;
      case AppLifecycleState.paused:
        // 🔧 窗口最小化 → 暂停轮询
        logger.lifecycle('RealtimeDashboardPage: 应用暂停 (paused) - 暂停轮询');
        pausePolling();
        break;
      case AppLifecycleState.detached:
        // 🔧 应用即将退出 → 清理资源
        logger.lifecycle('RealtimeDashboardPage: 应用即将退出 (detached)');
        pausePolling();
        break;
      case AppLifecycleState.hidden:
        // 🔧 窗口被隐藏 → 暂停轮询
        logger.lifecycle('RealtimeDashboardPage: 应用被隐藏 (hidden) - 暂停轮询');
        pausePolling();
        break;
    }
  }

  /// 🔧 [核心] 启动轮询定时器（使用 TimerManager 统一管理）
  /// 支持动态间隔：网络异常时自动延长轮询间隔，恢复后自动缩短
  void _startPolling() {
    // 🔧 计算当前轮询间隔（指数退避）
    int intervalSeconds = _normalIntervalSeconds;
    if (_consecutiveFailures > 0) {
      intervalSeconds = (_normalIntervalSeconds * (1 << _consecutiveFailures))
          .clamp(_normalIntervalSeconds, _maxBackoffSeconds);
    }

    // 🔧 使用 TimerManager 注册 Timer
    TimerManager().register(
      _timerIdRealtime,
      Duration(seconds: intervalSeconds),
      () async {
        if (!mounted) return;

        try {
          // 🔧 检测UI长时间未刷新
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
        }
      },
      description: '实时大屏数据轮询',
      immediate: false,
    );
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
        TimerManager().cancel(_timerIdRealtime);
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
        TimerManager().cancel(_timerIdRealtime);
        _startPolling(); // 重启以应用新间隔
      }
    }
  }

  /// 🔧 [NEW] 解析错误信息，返回用户友好的提示
  String _getErrorMessage(dynamic error) {
    final errorStr = error.toString();

    if (errorStr.contains('SocketException') ||
        errorStr.contains('远程计算机拒绝网络连接')) {
      return '无法连接到后端服务 (端口 8080)';
    } else if (errorStr.contains('TimeoutException')) {
      return '请求超时，后端响应过慢';
    } else if (errorStr.contains('Connection refused')) {
      return '后端服务未启动';
    } else if (errorStr.contains('API 返回空数据')) {
      return '后端返回空数据';
    } else {
      return '网络异常';
    }
  }

  @override
  void initState() {
    super.initState();
    // 🔧 [CRITICAL] 注册生命周期监听
    WidgetsBinding.instance.addObserver(this);
    // 🔧 [CRITICAL] 缓存 Provider 引用（防止 build() 中频繁查找）
    _configProvider = context.read<RealtimeConfigProvider>();
    _initData();
  }

  @override
  void dispose() {
    // 🔧 [CRITICAL] 移除生命周期监听
    WidgetsBinding.instance.removeObserver(this);
    // 🔧 使用 TimerManager 取消 Timer
    TimerManager().cancel(_timerIdRealtime);
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
          // 正常跳过（请求进行中）
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

    _refreshStartTime = DateTime.now(); // 🔧 记录请求开始时间

    setState(() {
      _isRefreshing = true; // 4, 标记开始刷新
    });

    try {
      // 1,2,3, 并行请求三类设备数据，添加8秒超时控制
      // 🔧 [CRITICAL] 缩短批量超时时间（单个请求5秒 + 3秒缓冲）
      final results = await Future.wait([
        _hopperService.getHopperBatchData(), // 1, 料仓数据
        _rollerKilnService.getRollerKilnRealtimeFormatted(), // 2, 辊道窑数据
        _scrFanService.getScrFanBatchData(), // 3, SCR+风机数据
      ]).timeout(
        const Duration(seconds: 8), // 从 15 秒缩短到 8 秒
        onTimeout: () {
          logger.warning('批量数据请求超时 (8秒)，后端服务可能不可用');
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

      // 🔧 网络恢复，重置退避和错误状态
      _restartPollingIfNeeded(true);

      // 🔧 [NEW] 恢复后端可用状态
      if (!_isBackendAvailable && mounted) {
        setState(() {
          _isBackendAvailable = true;
          _lastErrorMessage = null;
        });
        logger.info('✅ 后端服务已恢复');
      }

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

      // 🔧 [NEW] 更新后端状态（连续失败3次后标记为不可用）
      if (_consecutiveFailures >= 3 && _isBackendAvailable && mounted) {
        setState(() {
          _isBackendAvailable = false;
          _lastErrorMessage = _getErrorMessage(e);
        });
        logger.warning('⚠️ 后端服务不可用（连续失败 $_consecutiveFailures 次）');
      }

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

    // ═══════════════════════════════════════════════════════════════════════
    // 新布局设计 (3区块):
    // ┌─────────────────────────────────────────────────────────────────────┐
    // │  回转窑第一行: 窑7, 6, 2, 8, 3, 9 (height 0.27, 全宽)
    // ├───┬───────────────────────────────────┤
    // │  回转窑第二行: 窑5, 4, 1        │  SCR上层: 氨泵1+燃气+风机2(表66)
    // │  (height 0.27, width 0.50)      │  (height 0.365, width 0.40)       │
    // ├─────────────────────────────────┤───────────────────────────────────┤
    // │  辊道窑                          │  SCR下层: 氨泵2+燃气+风机1(表65)   │
    // │  (height 0.46, width 0.60)      │  (height 0.365, width 0.40)       │
    // └─────────────────────────────────┴───────────────────────────────────┘
    // ═══════════════════════════════════════════════════════════════════════

    // 回转窑第一行 (全宽，6个设备)
    final rotaryRow1Width = screenWidth - 24; // 减去padding
    final rotaryRow1Height = screenHeight * 0.27;

    // 辊道窑区域 (左边0.64宽度)
    final rollerKilnWidth = (screenWidth - 24) * 0.64;

    // 回转窑第二行 (与辊道窑同宽)
    final rotaryRow2Width = rollerKilnWidth;
    final rotaryRow2Height = screenHeight * 0.27;

    // SCR+风机区域 (右边0.36宽度，从第二行开始)
    final scrWidth = (screenWidth - 24) * 0.36 - 12; // 减去间距
    final scrRowHeight = (screenHeight * 0.73 - 8) / 2; // 两行平分高度

    return Scaffold(
      backgroundColor: TechColors.bgDeep,
      body: Stack(
        children: [
          // 主内容
          AnimatedGridBackground(
            gridColor: TechColors.borderDark.withOpacity(0.3),
            gridSize: 40,
            child: Padding(
              padding: const EdgeInsets.all(12.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ═══════════════════════════════════════════════════════════════
                  // 第一行: 回转窑 (窑7, 6, 2, 8, 3, 9) - 全宽
                  // ═══════════════════════════════════════════════════════════════
                  _buildRotaryKilnRow1(rotaryRow1Width, rotaryRow1Height),
                  const SizedBox(height: 8),

                  // ═══════════════════════════════════════════════════════════════
                  // 第二行 + 第三行: 左边回转窑+辊道窑，右边SCR区域
                  // ═══════════════════════════════════════════════════════════════
                  Expanded(
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // 左侧区域: 回转窑第二行 + 辊道窑
                        SizedBox(
                          width: rollerKilnWidth,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // 回转窑第二行 (窑5, 4, 1)
                              _buildRotaryKilnRow2(
                                  rotaryRow2Width, rotaryRow2Height),
                              const SizedBox(height: 8),
                              // 辊道窑 - 使用 Expanded 填充剩余高度
                              Expanded(
                                child: _buildRollerKilnSectionExpanded(
                                    rollerKilnWidth),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 12),
                        // 右侧区域: SCR (上下两层，包含氨泵+燃气+风机)
                        Expanded(
                          child:
                              _buildScrWithFanSection(scrWidth, scrRowHeight),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          // 🔧 [NEW] 后端不可用时的浮动提示
          if (!_isBackendAvailable)
            Positioned(
              top: 16,
              left: 0,
              right: 0,
              child: Center(
                child: Material(
                  color: Colors.transparent,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 24, vertical: 12),
                    decoration: BoxDecoration(
                      color: Colors.red.shade900.withOpacity(0.95),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.red.shade400, width: 2),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.red.withOpacity(0.3),
                          blurRadius: 12,
                          spreadRadius: 2,
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.warning_amber_rounded,
                          color: Colors.red.shade200,
                          size: 24,
                        ),
                        const SizedBox(width: 12),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              '⚠️ 后端服务不可用',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            if (_lastErrorMessage != null)
                              Text(
                                _lastErrorMessage!,
                                style: TextStyle(
                                  color: Colors.red.shade200,
                                  fontSize: 12,
                                ),
                              ),
                            Text(
                              '显示最后一次成功获取的数据',
                              style: TextStyle(
                                color: Colors.red.shade200,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(width: 12),
                        IconButton(
                          icon: Icon(Icons.refresh, color: Colors.white),
                          onPressed: () async {
                            await refreshData();
                          },
                          tooltip: '手动重试',
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  /// 回转窑第一行 - 6个设备: 窑7, 6, 5, 4, 2, 1 (全宽)
  Widget _buildRotaryKilnRow1(double width, double height) {
    return SizedBox(
      width: width,
      height: height,
      child: TechPanel(
        accentColor: TechColors.glowOrange,
        child: Padding(
          padding: const EdgeInsets.all(4.0),
          child: Row(
            children: [
              Expanded(flex: 6, child: _buildRotaryKilnCell(7)), // 短窑7
              const SizedBox(width: 4),
              Expanded(flex: 6, child: _buildRotaryKilnCell(6)), // 短窑6
              const SizedBox(width: 4),
              Expanded(flex: 6, child: _buildRotaryKilnCell(5)), // 短窑5
              const SizedBox(width: 4),
              Expanded(flex: 6, child: _buildRotaryKilnCell(4)), // 短窑4
              const SizedBox(width: 4),
              Expanded(flex: 5, child: _buildRotaryKilnNoHopperCell(2)), // 无料仓2
              const SizedBox(width: 4),
              Expanded(flex: 5, child: _buildRotaryKilnNoHopperCell(1)), // 无料仓1
            ],
          ),
        ),
      ),
    );
  }

  /// 回转窑第二行 - 3个设备: 窑8, 3, 9 (左边区域，长窑)
  Widget _buildRotaryKilnRow2(double width, double height) {
    return SizedBox(
      width: width,
      height: height,
      child: TechPanel(
        accentColor: TechColors.glowOrange,
        child: Padding(
          padding: const EdgeInsets.all(4.0),
          child: Row(
            children: [
              Expanded(flex: 6, child: _buildRotaryKilnLongCell(8)), // 长窑8
              const SizedBox(width: 4),
              Expanded(flex: 6, child: _buildRotaryKilnLongCell(3)), // 长窑3
              const SizedBox(width: 4),
              Expanded(flex: 6, child: _buildRotaryKilnLongCell(9)), // 长窑9
            ],
          ),
        ),
      ),
    );
  }

  /// 原回转窑区域方法 - 保留但不再使用（兼容性）
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

    // 3, 使用缓存的配置判断SCR氨泵和燃气运行状态
    final isPumpRunning = _configProvider.isScrPumpRunning(index, power);
    final isGasRunning = _configProvider.isScrGasRunning(index, flowRate);

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

  /// ═══════════════════════════════════════════════════════════════════════
  /// SCR+风机组合区域 (新布局)
  /// 上层: 氨泵1(表63) + 燃气 + 风机2(表66)
  /// 下层: 氨泵2(表64) + 燃气 + 风机1(表65)
  /// ═══════════════════════════════════════════════════════════════════════
  Widget _buildScrWithFanSection(double width, double rowHeight) {
    // 3, 安全获取SCR数据
    final scrDevices = _scrFanData?.scr.devices;
    final scrDevice1 =
        (scrDevices != null && scrDevices.isNotEmpty) ? scrDevices[0] : null;
    final scrDevice2 =
        (scrDevices != null && scrDevices.length > 1) ? scrDevices[1] : null;

    // 3, 安全获取风机数据
    final fanDevices = _scrFanData?.fan.devices;
    final fan1 =
        (fanDevices != null && fanDevices.isNotEmpty) ? fanDevices[0] : null;
    final fan2 =
        (fanDevices != null && fanDevices.length > 1) ? fanDevices[1] : null;

    return Column(
      children: [
        // 上层: 氨泵1(表63) + 燃气 + 风机2(表66)
        Expanded(
          child: _buildScrWithFanRow(
            scrDevice: scrDevice1,
            scrIndex: 1,
            fanDevice: fan2,
            fanIndex: 2,
          ),
        ),
        const SizedBox(height: 8),
        // 下层: 氨泵2(表64) + 燃气 + 风机1(表65)
        Expanded(
          child: _buildScrWithFanRow(
            scrDevice: scrDevice2,
            scrIndex: 2,
            fanDevice: fan1,
            fanIndex: 1,
          ),
        ),
      ],
    );
  }

  /// 单行SCR+风机组合: 氨泵 + 燃气 + 风机
  Widget _buildScrWithFanRow({
    required dynamic scrDevice,
    required int scrIndex,
    required dynamic fanDevice,
    required int fanIndex,
  }) {
    // SCR数据
    final scrPower = scrDevice?.elec?.pt ?? 0.0;
    final scrEnergy = scrDevice?.elec?.impEp ?? 0.0;
    final flowRate = scrDevice?.gas?.flowRate ?? 0.0;
    final scrCurrentA = scrDevice?.elec?.currentA ?? 0.0;
    final scrCurrentB = scrDevice?.elec?.currentB ?? 0.0;
    final scrCurrentC = scrDevice?.elec?.currentC ?? 0.0;

    final isPumpRunning = _configProvider.isScrPumpRunning(scrIndex, scrPower);
    final isGasRunning = _configProvider.isScrGasRunning(scrIndex, flowRate);

    // 风机数据
    final fanPower = fanDevice?.elec?.pt ?? 0.0;
    final fanEnergy = fanDevice?.elec?.impEp ?? 0.0;
    final fanCurrentA = fanDevice?.elec?.currentA ?? 0.0;
    final fanCurrentB = fanDevice?.elec?.currentB ?? 0.0;
    final fanCurrentC = fanDevice?.elec?.currentC ?? 0.0;
    final isFanRunning = _configProvider.isFanRunning(fanIndex, fanPower);

    return TechPanel(
      accentColor: TechColors.glowBlue,
      child: Padding(
        padding: const EdgeInsets.all(6.0),
        child: Row(
          children: [
            // 左侧 - 氨泵(水泵)组件 (占4份)
            Expanded(
              flex: 4,
              child: WaterPumpCell(
                index: scrIndex,
                isRunning: isPumpRunning,
                power: scrPower,
                cumulativeEnergy: scrEnergy,
                energyConsumption: scrEnergy,
                currentA: scrCurrentA,
                currentB: scrCurrentB,
                currentC: scrCurrentC,
              ),
            ),
            const SizedBox(width: 6),
            // 中间 - 燃气管组件 (占2份)
            Expanded(
              flex: 2,
              child: GasPipeCell(
                index: scrIndex,
                isRunning: isGasRunning,
                flowRate: flowRate,
                energyConsumption: scrDevice?.gas?.totalFlow ?? 0.0,
              ),
            ),
            const SizedBox(width: 6),
            // 右侧 - 风机组件 (占4份)
            Expanded(
              flex: 4,
              child: FanCell(
                index: fanIndex,
                isRunning: isFanRunning,
                power: fanPower,
                cumulativeEnergy: fanEnergy,
                currentA: fanCurrentA,
                currentB: fanCurrentB,
                currentC: fanCurrentC,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 辊道窑区域 (自适应高度版本) - 用于新布局
  /// 布局：上方1-6号温区卡片，左下角总电表，背景图居中偏右
  Widget _buildRollerKilnSectionExpanded(double width) {
    // 2, 从后端获取总表数据（不再前端累加）
    final totalPower = _rollerKilnData?.total.power ?? 0.0;
    final totalEnergy = _rollerKilnData?.total.energy ?? 0.0;
    final totalCurrentA = _rollerKilnData?.total.currentA ?? 0.0;
    final totalCurrentB = _rollerKilnData?.total.currentB ?? 0.0;
    final totalCurrentC = _rollerKilnData?.total.currentC ?? 0.0;

    // 2, 安全获取温区列表，避免强制解包
    final zones = _rollerKilnData?.zones;

    return SizedBox(
      width: width,
      child: TechPanel(
        accentColor: TechColors.glowGreen,
        child: Stack(
          children: [
            // 背景图片 - 居中偏右60px显示
            Positioned.fill(
              child: Padding(
                padding: const EdgeInsets.only(left: 60), // 右移60px
                child: Center(
                  child: Image.asset(
                    'assets/images/roller_kiln.png',
                    fit: BoxFit.contain,
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
              ),
            ),
            // 叠加数据层 - 上方温区卡片 + 左下角总电表
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 上方：1-6号温区数据卡片 (水平排列)
                  SizedBox(
                    height: 95,
                    child: Row(
                      children: List.generate(
                        6,
                        (i) {
                          final zoneIndex = i + 1;
                          final zone = (zones != null && zones.length > i)
                              ? zones[i]
                              : null;
                          return Expanded(
                            child: Padding(
                              padding: EdgeInsets.only(left: i == 0 ? 0 : 4),
                              child: _buildRollerKilnDataCard(
                                '${zoneIndex}号温区',
                                zone != null
                                    ? '${zone.temperature.toStringAsFixed(0)}°C'
                                    : '0°C',
                                zone != null
                                    ? '${zone.energy.toStringAsFixed(0)}kWh'
                                    : '0kWh',
                                zoneIndex: zoneIndex,
                                temperatureValue: zone?.temperature,
                                currentA: zone?.currentA,
                                currentB: zone?.currentB,
                                currentC: zone?.currentC,
                                powerValue: zone?.power,
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                  // 中间留空，让背景图显示
                  const Spacer(),
                  // 左下角：总电表卡片（样式与温区卡片一致，字体+2）
                  Container(
                    padding:
                        const EdgeInsets.symmetric(vertical: 6, horizontal: 8),
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
                        // 功率
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const PowerIcon(
                                size: 18, color: TechColors.glowCyan),
                            const SizedBox(width: 2),
                            Text(
                              '${totalPower.toStringAsFixed(1)}kW',
                              style: const TextStyle(
                                color: TechColors.glowCyan,
                                fontSize: 17,
                                fontWeight: FontWeight.w500,
                                fontFamily: 'Roboto Mono',
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 2),
                        // 能耗
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            EnergyIcon(size: 18, color: TechColors.glowOrange),
                            const SizedBox(width: 2),
                            Text(
                              '${totalEnergy.toStringAsFixed(1)}kWh',
                              style: const TextStyle(
                                color: TechColors.glowOrange,
                                fontSize: 17,
                                fontWeight: FontWeight.w500,
                                fontFamily: 'Roboto Mono',
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 2),
                        // A相电流
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            CurrentIcon(color: TechColors.glowCyan, size: 18),
                            Text(
                              'A:${totalCurrentA.toStringAsFixed(1)}A',
                              style: const TextStyle(
                                color: TechColors.glowCyan,
                                fontSize: 17,
                                fontWeight: FontWeight.w500,
                                fontFamily: 'Roboto Mono',
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 2),
                        // B相电流
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            CurrentIcon(color: TechColors.glowCyan, size: 18),
                            Text(
                              'B:${totalCurrentB.toStringAsFixed(1)}A',
                              style: const TextStyle(
                                color: TechColors.glowCyan,
                                fontSize: 17,
                                fontWeight: FontWeight.w500,
                                fontFamily: 'Roboto Mono',
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 2),
                        // C相电流
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            CurrentIcon(color: TechColors.glowCyan, size: 18),
                            Text(
                              'C:${totalCurrentC.toStringAsFixed(1)}A',
                              style: const TextStyle(
                                color: TechColors.glowCyan,
                                fontSize: 17,
                                fontWeight: FontWeight.w500,
                                fontFamily: 'Roboto Mono',
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 辊道窑区域 - 显示设备图片
  Widget _buildRollerKilnSection(double width, double height) {
    // 2, 从后端获取总表数据（不再前端累加）
    final totalPower = _rollerKilnData?.total.power ?? 0.0;
    final totalEnergy = _rollerKilnData?.total.energy ?? 0.0;
    final totalCurrentA = _rollerKilnData?.total.currentA ?? 0.0;
    final totalCurrentB = _rollerKilnData?.total.currentB ?? 0.0;
    final totalCurrentC = _rollerKilnData?.total.currentC ?? 0.0;

    // 2, 安全获取温区列表，避免强制解包
    final zones = _rollerKilnData?.zones;

    return SizedBox(
      width: width,
      height: height,
      child: TechPanel(
        accentColor: TechColors.glowGreen,
        child: Stack(
          children: [
            // 背景图片 - 右移40px显示
            Positioned(
              right: -40,
              top: 0,
              bottom: 0,
              left: 40,
              child: Image.asset(
                'assets/images/roller_kiln.png',
                fit: BoxFit.contain,
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
                height: 150,
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
                              powerValue: zone.power, // 传入功率数值
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
                              powerValue: 0.0,
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
                    // 第一行：总分区 (已移除)
                    // 第二行：总功率
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const PowerIcon(size: 18, color: TechColors.glowCyan),
                        const SizedBox(width: 2),
                        Text(
                          _rollerKilnData != null
                              ? '${totalPower.toStringAsFixed(1)}kW'
                              : '0.0kW',
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
                    // 第三行：总能耗
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
  /// [powerValue] 功率数值 (kW)
  Widget _buildRollerKilnDataCard(
      String zone, String temperature, String energyString,
      {int? zoneIndex,
      double? temperatureValue,
      double? currentA,
      double? currentB,
      double? currentC,
      double? powerValue}) {
    // 使用缓存的配置获取温度颜色
    final tempColor = (zoneIndex != null && temperatureValue != null)
        ? _configProvider.getRollerKilnTempColorByIndex(
            zoneIndex, temperatureValue)
        : TechColors.glowRed;

    // 格式化功率
    final powerString =
        powerValue != null ? '${powerValue.toStringAsFixed(1)}kW' : '0.0kW';

    return Container(
      decoration: BoxDecoration(
        color: TechColors.bgDeep.withOpacity(0.85),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(
          color: TechColors.glowCyan.withOpacity(0.4),
          width: 1,
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 顶部标签 (衍生出的 Height)
          Container(
            height: 22,
            alignment: Alignment.centerLeft, // 左对齐
            padding: const EdgeInsets.only(left: 4), // 加一点左边距，防止紧贴边缘
            color: TechColors.bgDeep.withOpacity(0.95),
            child: Text(
              zone,
              style: const TextStyle(
                color: TechColors.glowGreen,
                fontSize: 14,
                fontWeight: FontWeight.w600,
                fontFamily: 'Roboto Mono',
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          // 主数据盒子
          Container(
            padding: const EdgeInsets.fromLTRB(4, 2, 4, 2),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // 左侧列: 温度 + 功率 + 能耗
                Flexible(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.start,
                    children: [
                      // 温度
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          ThermometerIcon(color: tempColor, size: 16),
                          const SizedBox(width: 2),
                          Flexible(
                            child: Text(
                              temperature,
                              style: TextStyle(
                                color: tempColor,
                                fontSize: 15,
                                fontWeight: FontWeight.w500,
                                fontFamily: 'Roboto Mono',
                              ),
                              overflow: TextOverflow.ellipsis,
                              softWrap: false,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      // 功率
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const PowerIcon(size: 16, color: TechColors.glowCyan),
                          const SizedBox(width: 2),
                          Flexible(
                            child: Text(
                              powerString,
                              style: const TextStyle(
                                color: TechColors.glowCyan,
                                fontSize: 15,
                                fontWeight: FontWeight.w500,
                                fontFamily: 'Roboto Mono',
                              ),
                              overflow: TextOverflow.ellipsis,
                              softWrap: false,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      // 能耗
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          EnergyIcon(color: TechColors.glowOrange, size: 16),
                          const SizedBox(width: 2),
                          Flexible(
                            child: Text(
                              energyString,
                              style: const TextStyle(
                                color: TechColors.glowOrange,
                                fontSize: 15,
                                fontWeight: FontWeight.w500,
                                fontFamily: 'Roboto Mono',
                              ),
                              overflow: TextOverflow.ellipsis,
                              softWrap: false,
                            ),
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
                      mainAxisAlignment: MainAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            CurrentIcon(color: TechColors.glowCyan, size: 16),
                            Flexible(
                              child: Text(
                                'A:${currentA.toStringAsFixed(1)}A',
                                style: const TextStyle(
                                  color: TechColors.glowCyan,
                                  fontSize: 15,
                                  fontWeight: FontWeight.w500,
                                  fontFamily: 'Roboto Mono',
                                ),
                                overflow: TextOverflow.ellipsis,
                                softWrap: false,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 2),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            CurrentIcon(color: TechColors.glowCyan, size: 16),
                            Flexible(
                              child: Text(
                                'B:${currentB.toStringAsFixed(1)}A',
                                style: const TextStyle(
                                  color: TechColors.glowCyan,
                                  fontSize: 15,
                                  fontWeight: FontWeight.w500,
                                  fontFamily: 'Roboto Mono',
                                ),
                                overflow: TextOverflow.ellipsis,
                                softWrap: false,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 2),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            CurrentIcon(color: TechColors.glowCyan, size: 16),
                            Flexible(
                              child: Text(
                                'C:${currentC.toStringAsFixed(1)}A',
                                style: const TextStyle(
                                  color: TechColors.glowCyan,
                                  fontSize: 15,
                                  fontWeight: FontWeight.w500,
                                  fontFamily: 'Roboto Mono',
                                ),
                                overflow: TextOverflow.ellipsis,
                                softWrap: false,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// 风机区域 - 包含2个容器
  Widget _buildFanSection(double width, double height) {
    // 3, 安全获取风机数据
    final fanDevices = _scrFanData?.fan.devices;
    // index=1对应数组下标0, index=2对应数组下标1
    final fan1 =
        (fanDevices != null && fanDevices.isNotEmpty) ? fanDevices[0] : null;
    final fan2 =
        (fanDevices != null && fanDevices.length > 1) ? fanDevices[1] : null;

    final fan1Power = fan1?.elec?.pt ?? 0.0;
    final fan2Power = fan2?.elec?.pt ?? 0.0;
    final isFan1Running = _configProvider.isFanRunning(1, fan1Power);
    final isFan2Running = _configProvider.isFanRunning(2, fan2Power);

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

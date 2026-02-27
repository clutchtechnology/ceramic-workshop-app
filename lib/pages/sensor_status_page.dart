import 'package:flutter/material.dart';
import 'dart:async';
import '../models/sensor_status_model.dart';
import '../services/sensor_status_service.dart';
import '../services/websocket_service.dart';
import '../widgets/data_display/data_tech_line_widgets.dart';
import '../utils/app_logger.dart';
import '../utils/timer_manager.dart';

/// 设备状态位显示页面 (单页面垂直布局)
/// 同时显示 DB3(回转窑) / DB7(辊道窑) / DB11(SCR/风机) 的模块状态
/// 高度按各DB设备数量比例分配
class SensorStatusPage extends StatefulWidget {
  const SensorStatusPage({super.key});

  @override
  State<SensorStatusPage> createState() => SensorStatusPageState();
}

///  公开 State 类以便通过 GlobalKey 访问 (用于页面切换时暂停/恢复轮询)
class SensorStatusPageState extends State<SensorStatusPage>
    with WidgetsBindingObserver {
  // ============================================================
  // 常量定义
  // ============================================================

  //  [CRITICAL] Timer ID 常量
  static const String _timerIdSensor = 'sensor_status_polling';

  // 6, 每个DB区块内的列数
  static const int _columnCount = 3;
  // 7, 轮询间隔 (秒)
  static const int _pollIntervalSeconds = 5;
  //  网络异常退避配置
  static const int _maxBackoffSeconds = 60;

  // ============================================================
  // 状态变量
  // ============================================================

  // 1, 状态位查询服务 (单例，内部管理HTTP Client)
  final SensorStatusService _statusService = SensorStatusService();
  final WebSocketService _wsService = WebSocketService();
  StreamSubscription<AllStatusResponse>? _wsSubscription;

  //  [优化] 使用 ValueNotifier 替代普通变量，减少不必要的 Widget 重建
  // 3, API响应数据 (包含db3/db7/db11三个状态列表 + summary统计)
  final ValueNotifier<AllStatusResponse?> _responseNotifier =
      ValueNotifier(null);
  // 4, 防抖标志: 防止重复请求
  final ValueNotifier<bool> _isRefreshingNotifier = ValueNotifier(false);
  // 5, 错误信息 (用于UI显示网络/API错误)
  final ValueNotifier<String?> _errorMessageNotifier = ValueNotifier(null);

  //  网络异常退避计数
  int _consecutiveFailures = 0;

  //  [CRITICAL] 防止 _isRefreshing 卡死
  DateTime? _refreshStartTime;
  static const int _maxRefreshDurationSeconds = 15;

  // ============================================================
  // 生命周期
  // ============================================================

  @override
  void initState() {
    super.initState();
    //  [CRITICAL] 注册生命周期监听
    WidgetsBinding.instance.addObserver(this);
    _wsSubscription = _wsService.deviceStatusStream.listen(_handleStatusWsData);
    // [CRITICAL] 在 initState 中订阅 WebSocket，生命周期内始终保持
    // 即使页面在 Offstage 中，Stream 数据仍会更新 ValueNotifier
    _wsService.subscribeDeviceStatus().catchError((e) {
      // 订阅失败不影响页面初始化，WebSocket 断线重连后自动重新订阅
      logger.warning('SensorStatusPage: WebSocket订阅失败: $e');
    });
  }

  @override
  void dispose() {
    //  [CRITICAL] 移除生命周期监听
    WidgetsBinding.instance.removeObserver(this);
    //  使用 TimerManager 取消 Timer
    TimerManager().cancel(_timerIdSensor);
    _wsService.unsubscribeDeviceStatus();
    _wsSubscription?.cancel();
    _wsSubscription = null;
    //  [CRITICAL] 释放 ValueNotifier 防止内存泄漏
    _responseNotifier.dispose();
    _isRefreshingNotifier.dispose();
    _errorMessageNotifier.dispose();
    super.dispose();
  }

  // ============================================================
  // 应用生命周期监听 (处理窗口最小化/恢复)
  // ============================================================

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    // [工业监控] 7x24h运行，WebSocket订阅始终保持活跃
    // 不因窗口状态变化影响数据接收，资源释放统一由 dispose() 负责
    logger.lifecycle('SensorStatusPage: 生命周期变化 ($state)');
  }

  // ============================================================
  // 轮询控制 (供外部通过GlobalKey调用)
  // ============================================================

  // 暂停HTTP备用定时器（页面不可见时调用）
  // [CRITICAL] WebSocket订阅始终保持活跃，仅暂停HTTP备用定时器
  void pausePolling() {
    TimerManager().pause(_timerIdSensor);
    logger.info('SensorStatusPage: HTTP备用定时器已暂停（WebSocket订阅保持活跃）');
  }

  /// 恢复定时器（页面可见时调用）
  /// [CRITICAL] WebSocket订阅始终保持活跃，仅恢复HTTP备用定时器
  void resumePolling() {
    // 重置退避计数
    _consecutiveFailures = 0;

    // 立即获取一次数据（首次切换到此页面时的冷启动）
    _fetchData();

    // 启动或恢复 HTTP 备用 Timer
    if (!TimerManager().exists(_timerIdSensor)) {
      _startPollingWithInterval(_pollIntervalSeconds);
    } else {
      TimerManager().resume(_timerIdSensor);
    }
    logger.info('SensorStatusPage: HTTP备用定时器已恢复（WebSocket订阅保持活跃）');
  }

  ///  启动轮询定时器（支持动态间隔）
  void _startPollingWithInterval(int intervalSeconds) {
    TimerManager().cancel(_timerIdSensor); // 先取消旧的

    TimerManager().register(
      _timerIdSensor,
      Duration(seconds: intervalSeconds),
      () async {
        if (!mounted) return;
        if (_wsService.isConnected) return;
        try {
          await _fetchData();
        } catch (e, stack) {
          logger.error('状态位定时器回调异常', e, stack);
        }
      },
      description: '设备状态位轮询',
      immediate: false,
    );
  }

  ///  调整轮询间隔（网络异常时退避）
  void _adjustPollingInterval(bool wasSuccess) {
    if (!mounted) return;

    if (wasSuccess) {
      if (_consecutiveFailures > 0) {
        _consecutiveFailures = 0;
        _startPollingWithInterval(_pollIntervalSeconds);
      }
    } else {
      _consecutiveFailures = (_consecutiveFailures + 1).clamp(0, 4);
      final newInterval = (_pollIntervalSeconds * (1 << _consecutiveFailures))
          .clamp(_pollIntervalSeconds, _maxBackoffSeconds);
      if (_consecutiveFailures == 1) {
        logger.warning('SensorStatusPage: 网络异常，轮询间隔延长至 ${newInterval}s');
      }
      _startPollingWithInterval(newInterval);
    }
  }

  // ============================================================
  // 数据获取
  // ============================================================

  /// 获取状态数据
  ///  [优化] 使用 ValueNotifier 更新数据，不触发整页重建
  Future<void> _fetchData() async {
    //  [CRITICAL] 检测 _isRefreshing 是否卡死
    if (_isRefreshingNotifier.value) {
      if (_refreshStartTime != null) {
        final duration =
            DateTime.now().difference(_refreshStartTime!).inSeconds;
        if (duration > _maxRefreshDurationSeconds) {
          logger
              .error('SensorStatusPage: _isRefreshing 卡死超过 ${duration}s，强制重置！');
          _isRefreshingNotifier.value = false;
          _refreshStartTime = null;
        } else {
          return;
        }
      } else {
        _isRefreshingNotifier.value = false;
      }
    }
    if (!mounted) return;

    _refreshStartTime = DateTime.now();

    //  [优化] 使用 ValueNotifier 更新状态，不触发整页重建
    _isRefreshingNotifier.value = true;
    _errorMessageNotifier.value = null;

    try {
      // 3, 调用API获取所有DB状态
      final response = await _statusService.getAllStatus();

      if (!mounted) return;

      //  [优化] 只更新 ValueNotifier，不调用 setState
      if (response.success) {
        // 3, 更新响应数据
        _responseNotifier.value = response;
        //  成功时重置退避
        _adjustPollingInterval(true);
      } else {
        // 5, 记录错误信息
        _errorMessageNotifier.value = response.error ?? '获取状态失败';
        //  失败时启动退避
        _adjustPollingInterval(false);
      }
    } catch (e) {
      if (!mounted) return;
      // 5, 记录网络错误
      _errorMessageNotifier.value = '网络错误: $e';
      //  网络异常时启动退避
      _adjustPollingInterval(false);
    } finally {
      //  [CRITICAL] 无论成功失败，都必须重置状态
      _refreshStartTime = null;
      if (mounted) {
        _isRefreshingNotifier.value = false;
      } else {
        _isRefreshingNotifier.value = false;
      }
    }
  }

  void _handleStatusWsData(AllStatusResponse response) {
    if (!mounted) return;
    if (!response.success) {
      logger.warning('SensorStatusPage: WS数据接收失败: success=false');
      return;
    }

    _responseNotifier.value = response;
    _errorMessageNotifier.value = null;
    _adjustPollingInterval(true);
  }

  /// 根据 DB 号获取状态列表
  List<ModuleStatus> _getStatusByDb(int dbNumber) {
    // 3, 从响应数据中提取对应DB的状态列表
    return _responseNotifier.value?.data?['db$dbNumber'] ?? [];
  }

  // ============================================================
  // UI 构建
  // ============================================================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: TechColors.bgDeep,
      body: Column(
        children: [
          _buildHeader(),
          Expanded(
            //  [优化] 使用 ValueListenableBuilder 监听错误状态，只在错误变化时重建
            child: ValueListenableBuilder<String?>(
              valueListenable: _errorMessageNotifier,
              builder: (context, errorMessage, child) {
                return errorMessage != null
                    ? _buildErrorWidget(errorMessage)
                    : _buildVerticalLayout();
              },
            ),
          ),
        ],
      ),
    );
  }

  /// 垂直布局: 回转窑 → 辊道窑 → SCR/风机 (固定高度比例 2:1:1)
  ///  [优化] 使用 ValueListenableBuilder 监听数据变化，只在数据变化时重建
  Widget _buildVerticalLayout() {
    return ValueListenableBuilder<AllStatusResponse?>(
      valueListenable: _responseNotifier,
      builder: (context, response, child) {
        // 3, 获取各DB的状态列表
        final db3List = response?.data?['db3'] ?? <ModuleStatus>[];
        final db7List = response?.data?['db7'] ?? <ModuleStatus>[];
        final db11List = response?.data?['db11'] ?? <ModuleStatus>[];

        // 固定高度比例: 料仓(DB3) 1/2, 辊道窑(DB7) 1/4, SCR/风机(DB11) 1/4
        const int db3Flex = 2; // 1/2
        const int db7Flex = 1; // 1/4
        const int db11Flex = 1; // 1/4

        return Padding(
          padding: const EdgeInsets.all(8),
          child: Column(
            children: [
              Expanded(
                flex: db3Flex,
                child:
                    _buildDbSection('DB3 回转窑', db3List, TechColors.glowOrange),
              ),
              const SizedBox(height: 6),
              Expanded(
                flex: db7Flex,
                child: _buildDbSection('DB7 辊道窑', db7List, TechColors.glowCyan),
              ),
              const SizedBox(height: 6),
              Expanded(
                flex: db11Flex,
                child: _buildDbSection(
                    'DB11 SCR/风机', db11List, TechColors.glowGreen),
              ),
            ],
          ),
        );
      },
    );
  }

  /// 单个DB区块
  Widget _buildDbSection(
    String title,
    List<ModuleStatus> statusList,
    Color accentColor,
  ) {
    final normalCount = statusList.where((s) => s.isNormal).length;

    return Container(
      decoration: BoxDecoration(
        color: TechColors.bgDark.withOpacity(0.5),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: accentColor.withOpacity(0.3)),
      ),
      child: Column(
        children: [
          // 区块标题栏
          _buildSectionHeader(
              title, normalCount, statusList.length, accentColor),
          // 状态列表 (6, 水平多列布局)
          Expanded(
            child: statusList.isEmpty
                ? _buildEmptyHint()
                : _buildStatusGrid(statusList),
          ),
        ],
      ),
    );
  }

  /// 区块标题栏
  Widget _buildSectionHeader(
    String title,
    int normalCount,
    int totalCount,
    Color accentColor,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: accentColor.withOpacity(0.1),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(5)),
        border: Border(bottom: BorderSide(color: accentColor.withOpacity(0.3))),
      ),
      child: Row(
        children: [
          Container(
            width: 3,
            height: 14,
            decoration: BoxDecoration(
              color: accentColor,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            title,
            style: TextStyle(
              color: accentColor,
              fontSize: 13,
              fontWeight: FontWeight.bold,
              fontFamily: 'Roboto Mono',
            ),
          ),
          const Spacer(),
          Text(
            '正常: $normalCount/$totalCount',
            style: TextStyle(
              color: accentColor.withOpacity(0.8),
              fontSize: 11,
              fontFamily: 'Roboto Mono',
            ),
          ),
        ],
      ),
    );
  }

  /// 空数据提示
  Widget _buildEmptyHint() {
    return Center(
      child: Text(
        '暂无数据',
        style: TextStyle(
          color: TechColors.textSecondary.withOpacity(0.5),
          fontSize: 11,
        ),
      ),
    );
  }

  /// 状态网格 (6, 分列显示)
  Widget _buildStatusGrid(List<ModuleStatus> statusList) {
    final itemsPerColumn = (statusList.length / _columnCount).ceil();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: List.generate(_columnCount, (colIndex) {
          final startIndex = colIndex * itemsPerColumn;
          final endIndex =
              (startIndex + itemsPerColumn).clamp(0, statusList.length);

          return Expanded(
            child: Column(
              children: [
                for (int i = startIndex; i < endIndex; i++)
                  _buildStatusCard(statusList[i], i),
              ],
            ),
          );
        }),
      ),
    );
  }

  /// 顶部状态栏
  ///  [优化] 使用 ValueListenableBuilder 监听数据和刷新状态
  Widget _buildHeader() {
    return ValueListenableBuilder<AllStatusResponse?>(
      valueListenable: _responseNotifier,
      builder: (context, response, child) {
        // 3, 从响应数据中获取统计摘要
        final summary = response?.summary;

        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            color: TechColors.bgDark,
            border: Border(
              bottom: BorderSide(color: TechColors.borderDark.withOpacity(0.5)),
            ),
          ),
          child: Row(
            children: [
              const Text(
                '设备状态位监控',
                style: TextStyle(
                  color: TechColors.textPrimary,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  fontFamily: 'Roboto Mono',
                ),
              ),
              const Spacer(),
              // 3, 统计信息显示
              _buildStatChip('总计', summary?.total ?? 0, TechColors.glowCyan),
              const SizedBox(width: 10),
              _buildStatChip('正常', summary?.normal ?? 0, TechColors.glowGreen),
              const SizedBox(width: 10),
              _buildStatChip('异常', summary?.error ?? 0, TechColors.glowRed),
              const SizedBox(width: 12),
              //  [优化] 刷新按钮也使用 ValueListenableBuilder
              ValueListenableBuilder<bool>(
                valueListenable: _isRefreshingNotifier,
                builder: (context, isRefreshing, child) {
                  return IconButton(
                    onPressed: isRefreshing ? null : _fetchData,
                    icon: isRefreshing
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: TechColors.glowCyan,
                            ),
                          )
                        : const Icon(Icons.refresh,
                            color: TechColors.glowCyan, size: 20),
                  );
                },
              ),
            ],
          ),
        );
      },
    );
  }

  /// 统计标签
  Widget _buildStatChip(String label, int count, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(3),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(label, style: TextStyle(color: color, fontSize: 11)),
          const SizedBox(width: 4),
          Text(
            '$count',
            style: TextStyle(
              color: color,
              fontSize: 13,
              fontWeight: FontWeight.bold,
              fontFamily: 'Roboto Mono',
            ),
          ),
        ],
      ),
    );
  }

  /// 错误提示
  Widget _buildErrorWidget(String errorMessage) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.error_outline, color: TechColors.glowRed, size: 48),
          const SizedBox(height: 16),
          // 5, 显示错误信息
          Text(
            errorMessage,
            style:
                const TextStyle(color: TechColors.textSecondary, fontSize: 14),
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: _fetchData,
            style: ElevatedButton.styleFrom(
              backgroundColor: TechColors.glowCyan.withOpacity(0.2),
            ),
            child: const Text('重试'),
          ),
        ],
      ),
    );
  }

  /// 单个状态卡片
  Widget _buildStatusCard(ModuleStatus status, int index) {
    final hasError = !status.isNormal;
    final accentColor = hasError ? TechColors.glowRed : TechColors.glowGreen;

    return Container(
      margin: const EdgeInsets.only(bottom: 3),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: TechColors.bgMedium.withOpacity(0.4),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(
          color: hasError
              ? TechColors.glowRed.withOpacity(0.3)
              : TechColors.borderDark.withOpacity(0.2),
        ),
      ),
      child: Row(
        children: [
          // 序号
          SizedBox(
            width: 20,
            child: Text(
              '${index + 1}',
              style: const TextStyle(
                color: TechColors.textSecondary,
                fontSize: 10,
                fontFamily: 'Roboto Mono',
              ),
            ),
          ),
          // 状态灯
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: accentColor,
              boxShadow: [
                BoxShadow(
                  color: accentColor.withOpacity(0.5),
                  blurRadius: 3,
                  spreadRadius: 1,
                ),
              ],
            ),
          ),
          const SizedBox(width: 6),
          // 设备名
          Expanded(
            child: Text(
              status.deviceName,
              style: const TextStyle(
                color: TechColors.textPrimary,
                fontSize: 11,
                fontFamily: 'Roboto Mono',
              ),
              overflow: TextOverflow.ellipsis,
              maxLines: 1,
            ),
          ),
          // E值 (Error位)
          _buildValueBadge('E', status.error ? '1' : '0', status.error),
          const SizedBox(width: 4),
          // S值 (Status Code - 十六进制)
          _buildValueBadge(
            'S',
            status.statusCode.toRadixString(16).toUpperCase().padLeft(4, '0'),
            status.statusCode != 0,
          ),
        ],
      ),
    );
  }

  /// 通用值徽章 (合并原 _buildCompactValue 和 _buildCompactStatus)
  Widget _buildValueBadge(String label, String value, bool isError) {
    final color = isError ? TechColors.glowRed : TechColors.textSecondary;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          '$label:',
          style: const TextStyle(color: TechColors.textSecondary, fontSize: 9),
        ),
        const SizedBox(width: 2),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
          decoration: BoxDecoration(
            color: isError
                ? TechColors.glowRed.withOpacity(0.2)
                : TechColors.bgMedium.withOpacity(0.3),
            borderRadius: BorderRadius.circular(2),
          ),
          child: Text(
            value,
            style: TextStyle(
              color: color,
              fontSize: 10,
              fontWeight: FontWeight.bold,
              fontFamily: 'Roboto Mono',
            ),
          ),
        ),
      ],
    );
  }
}

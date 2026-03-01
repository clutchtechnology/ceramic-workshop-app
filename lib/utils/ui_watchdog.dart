import 'dart:async';
import 'dart:ui';
import 'package:flutter/scheduler.dart';
import 'app_logger.dart';
import 'timer_manager.dart';

/// UI 看门狗健康状态
enum WatchdogState { normal, degraded, critical }

/// [CRITICAL] UI 看门狗 - 监控主线程健康度，自动降级节流参数
///
/// Flutter 单 Isolate 限制：看门狗运行在主线程上，无法检测完全卡死。
/// 但能检测"接近卡死"状态并主动降级，在主线程彻底失控前减负：
///
/// 1. 心跳延迟检测：2s Timer 如果延迟到 6+s 触发 = 主线程事件队列积压
/// 2. 帧率监控：统计慢帧(>32ms)比例，超过阈值输出诊断日志
/// 3. 自动降级：切换状态后，页面通过 getThrottle() 获取更大的节流间隔
/// 4. 自动恢复：连续正常心跳后恢复 normal 状态
/// 5. 投票防抖：连续 2 次异常才触发状态切换，避免单次抖动误报
///
/// 页面使用方式：
/// ```dart
/// Duration get _wsUiThrottle => UIWatchdog().getThrottle(
///   normal: Duration(seconds: 1),
///   degraded: Duration(seconds: 3),
///   critical: Duration(seconds: 5),
/// );
/// ```
class UIWatchdog {
  static final UIWatchdog _instance = UIWatchdog._internal();
  factory UIWatchdog() => _instance;
  UIWatchdog._internal();

  // ============================================================
  // 状态
  // ============================================================

  WatchdogState _state = WatchdogState.normal;
  WatchdogState get state => _state;
  bool _isRunning = false;

  // ============================================================
  // 心跳
  // ============================================================

  Timer? _heartbeatTimer;
  DateTime _lastHeartbeat = DateTime.now();

  // ============================================================
  // 帧率统计
  // ============================================================

  int _slowFrameCount = 0;
  int _totalFrameCount = 0;
  DateTime _frameStatsStart = DateTime.now();
  bool _frameMonitorRegistered = false;

  // ============================================================
  // 投票防抖（防止单次抖动导致频繁切换）
  // ============================================================

  int _degradeVotes = 0;
  int _recoverVotes = 0;

  // ============================================================
  // 配置常量
  // ============================================================

  // 心跳间隔 2s，Timer 正常偏差 <100ms
  // 主线程卡顿时事件循环排队延迟显著增大
  static const Duration _heartbeatInterval = Duration(seconds: 2);

  // 心跳延迟超过 6s = degraded（主线程排队了 4+ 秒的事件）
  static const Duration _degradeDelay = Duration(seconds: 6);

  // 心跳延迟超过 15s = critical（主线程几乎无响应）
  static const Duration _criticalDelay = Duration(seconds: 15);

  // 帧耗时 >32ms 算慢帧（低于 30fps）
  static const int _slowFrameThresholdMs = 32;

  // 帧率统计周期 30s，仅异常时输出日志
  static const int _frameStatsWindowSeconds = 30;

  // 慢帧比例超过 30% 记录告警
  static const double _slowFrameWarnRatio = 0.3;

  // 连续 2 次异常投票才切换状态
  static const int _votesRequired = 2;

  // ============================================================
  // 公开接口
  // ============================================================

  /// 启动看门狗（在 main.dart 初始化时调用）
  void start() {
    if (_isRunning) return;
    _isRunning = true;
    _state = WatchdogState.normal;
    _degradeVotes = 0;
    _recoverVotes = 0;
    _startHeartbeat();
    _startFrameMonitor();
    logger.info('[Watchdog] UI看门狗已启动');
  }

  /// 停止看门狗（在资源清理时调用）
  void stop() {
    if (!_isRunning) return;
    _isRunning = false;
    _heartbeatTimer?.cancel();
    _heartbeatTimer = null;
    // [注意] addTimingsCallback 无法移除，靠 _isRunning 守卫跳过回调
    logger.info('[Watchdog] UI看门狗已停止');
  }

  /// 获取当前状态对应的节流时长
  ///
  /// 页面在 WS 回调节流判断时调用，替代固定常量：
  /// - normal: 正常节流间隔（推荐 1s）
  /// - degraded: 增大间隔（推荐 3s），减少主线程压力
  /// - critical: 最大间隔（推荐 5s），最低限度保持数据更新
  Duration getThrottle({
    required Duration normal,
    required Duration degraded,
    required Duration critical,
  }) {
    switch (_state) {
      case WatchdogState.normal:
        return normal;
      case WatchdogState.degraded:
        return degraded;
      case WatchdogState.critical:
        return critical;
    }
  }

  // ============================================================
  // 心跳检测
  // ============================================================

  void _startHeartbeat() {
    _heartbeatTimer?.cancel();
    _lastHeartbeat = DateTime.now();

    _heartbeatTimer = Timer.periodic(_heartbeatInterval, (_) {
      if (!_isRunning) return;

      final now = DateTime.now();
      final delay = now.difference(_lastHeartbeat);
      _lastHeartbeat = now;

      if (delay > _criticalDelay) {
        // 心跳延迟超过 15s，主线程严重阻塞
        _voteDegrade(WatchdogState.critical);
        logger.error(
          '[Watchdog] 主线程严重卡顿: 心跳延迟 ${delay.inMilliseconds}ms '
          '(预期 ${_heartbeatInterval.inMilliseconds}ms)',
        );
      } else if (delay > _degradeDelay) {
        // 心跳延迟超过 6s，主线程过载
        _voteDegrade(WatchdogState.degraded);
        logger.warning(
          '[Watchdog] 主线程卡顿: 心跳延迟 ${delay.inMilliseconds}ms '
          '(预期 ${_heartbeatInterval.inMilliseconds}ms)',
        );
      } else {
        // 心跳正常
        _voteRecover();
      }
    });
  }

  // ============================================================
  // 帧率监控（诊断日志，不参与状态投票）
  // ============================================================

  void _startFrameMonitor() {
    // addTimingsCallback 无法移除，只注册一次
    if (_frameMonitorRegistered) return;
    _frameMonitorRegistered = true;

    _frameStatsStart = DateTime.now();
    _slowFrameCount = 0;
    _totalFrameCount = 0;

    SchedulerBinding.instance.addTimingsCallback(_onFrameTimings);
  }

  void _onFrameTimings(List<FrameTiming> timings) {
    if (!_isRunning) return;

    for (final timing in timings) {
      _totalFrameCount++;
      if (timing.totalSpan.inMilliseconds > _slowFrameThresholdMs) {
        _slowFrameCount++;
      }
    }

    // 每 30s 统计一次，仅异常时输出日志
    final elapsed = DateTime.now().difference(_frameStatsStart);
    if (elapsed.inSeconds >= _frameStatsWindowSeconds && _totalFrameCount > 0) {
      final slowRatio = _slowFrameCount / _totalFrameCount;

      if (slowRatio > _slowFrameWarnRatio) {
        final pct = (slowRatio * 100).toStringAsFixed(1);
        logger.warning(
          '[Watchdog] 帧率告警: 慢帧 $_slowFrameCount/$_totalFrameCount '
          '($pct%) 过去 ${elapsed.inSeconds}s',
        );
      }

      // 重置统计窗口
      _slowFrameCount = 0;
      _totalFrameCount = 0;
      _frameStatsStart = DateTime.now();
    }
  }

  // ============================================================
  // 状态投票机制（防止单次抖动误报）
  // ============================================================

  /// 投票降级：连续 N 次异常才真正切换
  void _voteDegrade(WatchdogState target) {
    _recoverVotes = 0;
    _degradeVotes++;
    if (_degradeVotes >= _votesRequired) {
      _updateState(target);
    }
  }

  /// 投票恢复：连续 N 次正常才恢复
  void _voteRecover() {
    _degradeVotes = 0;
    _recoverVotes++;
    if (_recoverVotes >= _votesRequired && _state != WatchdogState.normal) {
      _updateState(WatchdogState.normal);
    }
  }

  void _updateState(WatchdogState newState) {
    if (_state == newState) return;

    final oldState = _state;
    _state = newState;
    _degradeVotes = 0;
    _recoverVotes = 0;

    if (newState == WatchdogState.normal) {
      logger.info('[Watchdog] 状态恢复: $oldState -> normal');
    } else {
      logger.warning('[Watchdog] 状态降级: $oldState -> $newState');
      // 触发 TimerManager 诊断，输出所有 Timer 健康状态
      TimerManager().diagnose();
    }
  }
}

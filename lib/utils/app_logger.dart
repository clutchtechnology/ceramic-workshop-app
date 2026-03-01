import 'dart:io';
import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';

/// 应用日志系统 - 用于追踪崩溃和异常
class AppLogger {
  static final AppLogger _instance = AppLogger._internal();
  factory AppLogger() => _instance;
  AppLogger._internal();

  File? _logFile;
  final _dateFormat = DateFormat('yyyy-MM-dd HH:mm:ss.SSS');
  final _fileNameFormat = DateFormat('yyyy-MM-dd');
  bool _initialized = false;

  //  新增: 心跳定时器
  Timer? _heartbeatTimer;
  int _heartbeatCount = 0;
  DateTime? _startTime;

  // [CRITICAL] 缓冲写入: 日志先攒到 buffer，定时刷盘
  // 避免 10Hz WS 回调下每条日志都触发磁盘 I/O + flush
  final StringBuffer _writeBuffer = StringBuffer();
  Timer? _flushTimer;
  bool _isFlushing = false;
  static const Duration _flushInterval = Duration(seconds: 5);

  /// 初始化日志系统
  Future<void> initialize() async {
    if (_initialized) return;

    try {
      _startTime = DateTime.now();

      // 获取日志目录
      final Directory logDir = await _getLogDirectory();

      // 创建日志文件（每天一个文件）
      final String fileName =
          'app_log_${_fileNameFormat.format(DateTime.now())}.log';
      _logFile = File('${logDir.path}${Platform.pathSeparator}$fileName');

      // 确保文件存在，新建时写入 UTF-8 BOM，使 Windows GBK 系统能正确识别 UTF-8 编码
      if (!await _logFile!.exists()) {
        await _logFile!.create(recursive: true);
        await _logFile!.writeAsBytes([0xEF, 0xBB, 0xBF]);
      }

      _initialized = true;

      // 记录启动信息
      await _writeLog('INFO', '========================================');
      await _writeLog('INFO', 'APP STARTED');
      await _writeLog('INFO', 'Version: 1.0.0');
      await _writeLog('INFO',
          'Platform: ${Platform.operatingSystem} ${Platform.operatingSystemVersion}');
      await _writeLog('INFO', 'Log file: ${_logFile!.path}');
      await _writeLog('INFO', '========================================');

      // 清理旧日志（保留最近60天）
      await _cleanOldLogs(logDir, 60);

      //  启动心跳监控（每60秒记录一次）
      _startHeartbeat();

      // [CRITICAL] 启动定时刷盘 Timer（每5秒将缓冲区写入磁盘）
      _startFlushTimer();
    } catch (e) {
      debugPrint('[AppLogger] 初始化失败: $e');
    }
  }

  ///  心跳监控：每12小时记录一次，减少日志噪音
  void _startHeartbeat() {
    _heartbeatTimer?.cancel();
    _heartbeatTimer = Timer.periodic(const Duration(hours: 12), (timer) async {
      try {
        _heartbeatCount++;
        final uptime = DateTime.now().difference(_startTime!);
        final hours = uptime.inHours;
        final minutes = uptime.inMinutes % 60;

        await _writeLog(
            'HEARTBEAT', '应用运行中 #$_heartbeatCount | 已运行: ${hours}h${minutes}m');
      } catch (e) {
        // 心跳异常不应该中断定时器
        debugPrint('[AppLogger] 心跳记录异常: $e');
      }
    });
  }

  /// 获取日志目录
  Future<Directory> _getLogDirectory() async {
    Directory logDir;

    if (Platform.isWindows) {
      // Windows: 使用应用程序所在目录的 logs/
      final exePath = Platform.resolvedExecutable;
      final exeDir = File(exePath).parent;
      logDir = Directory('${exeDir.path}${Platform.pathSeparator}logs');
    } else {
      // 其他平台: 使用应用文档目录
      final appDocDir = await getApplicationDocumentsDirectory();
      logDir = Directory('${appDocDir.path}${Platform.pathSeparator}logs');
    }

    if (!await logDir.exists()) {
      await logDir.create(recursive: true);
    }

    return logDir;
  }

  /// 清理旧日志文件
  Future<void> _cleanOldLogs(Directory logDir, int daysToKeep) async {
    try {
      final now = DateTime.now();
      final files = logDir.listSync();

      for (var file in files) {
        if (file is File && file.path.endsWith('.log')) {
          final stat = await file.stat();
          final age = now.difference(stat.modified).inDays;

          if (age > daysToKeep) {
            await file.delete();
            debugPrint('[AppLogger] 删除旧日志: ${file.path}');
          }
        }
      }
    } catch (e) {
      debugPrint('[AppLogger] 清理旧日志失败: $e');
    }
  }

  /// 写入日志
  /// [CRITICAL] 使用缓冲写入: 日志先写入内存 buffer，由 _flushTimer 定时刷盘
  /// 避免 10Hz WS 回调下每条日志都触发独立的磁盘 I/O + flush 导致主线程卡死
  Future<void> _writeLog(String level, String message) async {
    if (!_initialized || _logFile == null) return;

    try {
      final timestamp = _dateFormat.format(DateTime.now());
      final logEntry = '[$timestamp] [$level] $message\n';

      // 写入内存缓冲区（零 I/O 开销）
      _writeBuffer.write(logEntry);

      // 同时输出到控制台
      debugPrint(logEntry.trim());
    } catch (e) {
      debugPrint('[AppLogger] 写入日志失败: $e');
    }
  }

  /// [CRITICAL] 启动定时刷盘 Timer
  void _startFlushTimer() {
    _flushTimer?.cancel();
    _flushTimer = Timer.periodic(_flushInterval, (_) {
      _flushBuffer();
    });
  }

  /// [CRITICAL] 将缓冲区内容刷入磁盘（异步、非阻塞）
  Future<void> _flushBuffer() async {
    if (_isFlushing || _writeBuffer.isEmpty || _logFile == null) return;
    _isFlushing = true;

    try {
      // 取出 buffer 内容，立即清空（防止下一次 flush 重复写入）
      final content = _writeBuffer.toString();
      _writeBuffer.clear();

      await _logFile!.writeAsString(
        content,
        mode: FileMode.append,
        flush: true,
        encoding: utf8,
      );
    } catch (e) {
      debugPrint('[AppLogger] 刷盘失败: $e');
    } finally {
      _isFlushing = false;
    }
  }

  // ============ 公共日志方法 ============

  /// 信息日志
  Future<void> info(String message) async {
    await _writeLog('INFO', message);
  }

  /// 警告日志
  Future<void> warning(String message) async {
    await _writeLog('WARNING', message);
  }

  /// 错误日志
  Future<void> error(String message,
      [Object? error, StackTrace? stackTrace]) async {
    final errorMsg = StringBuffer(message);
    if (error != null) {
      errorMsg.write('\nError: $error');
    }
    if (stackTrace != null) {
      errorMsg.write('\nStackTrace:\n$stackTrace');
    }
    await _writeLog('ERROR', errorMsg.toString());
  }

  /// 严重错误日志
  Future<void> fatal(String message,
      [Object? error, StackTrace? stackTrace]) async {
    final errorMsg = StringBuffer('[FATAL] $message');
    if (error != null) {
      errorMsg.write('\nError: $error');
    }
    if (stackTrace != null) {
      errorMsg.write('\nStackTrace:\n$stackTrace');
    }
    await _writeLog('FATAL', errorMsg.toString());
  }

  /// 网络请求日志
  Future<void> network(String method, String url,
      {int? statusCode, String? error}) async {
    final msg = StringBuffer('$method $url');
    if (statusCode != null) {
      msg.write(' → $statusCode');
    }
    if (error != null) {
      msg.write(' [ERROR: $error]');
    }
    await _writeLog('NETWORK', msg.toString());
  }

  /// 内存使用日志
  Future<void> memory(String context, int usedMB, int totalMB) async {
    final percent = (usedMB / totalMB * 100).toStringAsFixed(1);
    await _writeLog('MEMORY',
        '$context - Used: ${usedMB}MB / Total: ${totalMB}MB ($percent%)');
  }

  /// 生命周期日志
  Future<void> lifecycle(String event) async {
    await _writeLog('LIFECYCLE', event);
  }

  /// 用户操作日志
  Future<void> userAction(String action) async {
    await _writeLog('ACTION', action);
  }

  /// 获取当前日志文件路径
  String? get logFilePath => _logFile?.path;

  /// 关闭日志系统
  Future<void> close() async {
    if (_initialized) {
      //  停止心跳定时器
      _heartbeatTimer?.cancel();
      _heartbeatTimer = null;

      // [CRITICAL] 停止刷盘定时器
      _flushTimer?.cancel();
      _flushTimer = null;

      final uptime = DateTime.now().difference(_startTime!);
      final hours = uptime.inHours;
      final minutes = uptime.inMinutes % 60;

      await _writeLog('INFO', '========================================');
      await _writeLog('INFO', 'APP CLOSED NORMALLY');
      await _writeLog('INFO', '总运行时长: ${hours}小时${minutes}分钟');
      await _writeLog('INFO', '心跳次数: $_heartbeatCount');
      await _writeLog('INFO', '========================================');

      // [CRITICAL] 关闭前将剩余缓冲区全部刷入磁盘
      await _flushBuffer();

      _initialized = false;
    }
  }
}

/// 全局日志实例
final logger = AppLogger();

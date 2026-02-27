import 'dart:async';
import 'dart:convert';

import 'package:web_socket_channel/web_socket_channel.dart';

import '../api/api.dart';
import '../models/hopper_model.dart';
import '../models/roller_kiln_model.dart';
import '../models/scr_fan_model.dart';
import '../models/sensor_status_model.dart';
import '../models/ws_messages.dart';
import '../utils/app_logger.dart';

enum WebSocketState {
  disconnected,
  connecting,
  connected,
  reconnecting,
}

class RealtimeWsData {
  final Map<String, HopperData> hopperData;
  final RollerKilnData? rollerKilnData;
  final ScrFanBatchData? scrFanData;
  final DateTime? timestamp;
  final String? source;

  RealtimeWsData({
    required this.hopperData,
    required this.rollerKilnData,
    required this.scrFanData,
    this.timestamp,
    this.source,
  });
}

class WebSocketService {
  static final WebSocketService _instance = WebSocketService._internal();
  factory WebSocketService() => _instance;
  WebSocketService._internal();

  WebSocketChannel? _channel;
  StreamSubscription? _streamSubscription;
  Timer? _heartbeatTimer;
  Timer? _reconnectTimer;
  Timer? _watchdogTimer;

  final Set<String> _desiredChannels = <String>{};
  final Map<String, int> _channelRefCount = <String, int>{};

  WebSocketState _state = WebSocketState.disconnected;
  bool _manualDisconnect = false;
  int _reconnectAttempts = 0;
  DateTime _lastDataTime = DateTime.now();

  static const Duration _heartbeatInterval = Duration(seconds: 15);
  static const Duration _watchdogInterval = Duration(seconds: 5);
  // 数据超时: 已连接但超过此时间没收到任何消息 (含心跳回复)，认为连接已死
  static const Duration _dataTimeout = Duration(seconds: 30);

  final StreamController<RealtimeWsData> _realtimeController =
      StreamController<RealtimeWsData>.broadcast();
  final StreamController<AllStatusResponse> _deviceStatusController =
      StreamController<AllStatusResponse>.broadcast();

  Stream<RealtimeWsData> get realtimeStream => _realtimeController.stream;
  Stream<AllStatusResponse> get deviceStatusStream =>
      _deviceStatusController.stream;

  void Function(WebSocketState state)? onStateChanged;
  void Function(String error)? onError;

  WebSocketState get state => _state;
  bool get isConnected => _state == WebSocketState.connected;

  Future<void> ensureConnected() async {
    if (_state == WebSocketState.connected ||
        _state == WebSocketState.connecting ||
        _state == WebSocketState.reconnecting) {
      return;
    }

    _manualDisconnect = false;
    _setState(WebSocketState.connecting);

    // 启动看门狗（首次连接时启动，全局只启动一次）
    _startWatchdog();

    try {
      final channel = WebSocketChannel.connect(Uri.parse(Api.wsRealtimeUrl));
      _channel = channel;

      // 等待实际 TCP 握手完成，连接失败会在这里抛异常
      await channel.ready;

      // 如果 await 期间 _forceReconnect() 被调用，channel 已被替换，放弃旧连接
      if (_channel != channel) return;

      _streamSubscription = channel.stream.listen(
        _onMessage,
        onError: _onStreamError,
        onDone: _onStreamDone,
        cancelOnError: true,
      );

      _reconnectAttempts = 0;
      _lastDataTime = DateTime.now();
      _setState(WebSocketState.connected);
      _startHeartbeat();
      _resubscribeDesiredChannels();
    } catch (e) {
      _emitError('WebSocket 连接失败: $e');
      // 清理失败的 channel
      _channel = null;
      _scheduleReconnect();
    }
  }

  Future<void> disconnect() async {
    _manualDisconnect = true;
    _stopHeartbeat();
    _cancelReconnect();
    _stopWatchdog();

    await _streamSubscription?.cancel();
    _streamSubscription = null;

    try {
      await _channel?.sink.close();
    } catch (_) {}
    _channel = null;

    _setState(WebSocketState.disconnected);
  }

  Future<void> subscribe(WsChannel channel) async {
    final key = channel.value;
    final count = (_channelRefCount[key] ?? 0) + 1;
    _channelRefCount[key] = count;
    _desiredChannels.add(key);

    await ensureConnected();

    if (isConnected && count == 1) {
      _send(WsSubscribeMessage(channel).toJson());
    }
  }

  void unsubscribe(WsChannel channel) {
    final key = channel.value;
    final current = _channelRefCount[key] ?? 0;
    if (current <= 1) {
      _channelRefCount.remove(key);
      _desiredChannels.remove(key);
      if (isConnected) {
        _send(WsUnsubscribeMessage(channel).toJson());
      }
      logger.info('WebSocket 取消订阅频道: $key');
      return;
    }

    _channelRefCount[key] = current - 1;
  }

  Future<void> subscribeRealtime() => subscribe(WsChannel.realtime);
  Future<void> subscribeDeviceStatus() => subscribe(WsChannel.deviceStatus);
  void unsubscribeRealtime() => unsubscribe(WsChannel.realtime);
  void unsubscribeDeviceStatus() => unsubscribe(WsChannel.deviceStatus);

  void _onMessage(dynamic raw) {
    _lastDataTime = DateTime.now();
    try {
      final Map<String, dynamic> json =
          raw is String ? jsonDecode(raw) as Map<String, dynamic> : raw;

      final envelope = WsEnvelope.fromJson(json);

      switch (envelope.type) {
        case 'realtime_data':
          _handleRealtimeMessage(envelope);
          break;
        case 'device_status':
          _handleDeviceStatusMessage(envelope);
          break;
        case 'error':
          _emitError(
              'WebSocket 错误: ${envelope.code ?? ''} ${envelope.message ?? ''}');
          break;
        case 'heartbeat':
          break;
        default:
          logger.warning('未知 WebSocket 消息类型: ${envelope.type}');
      }
    } catch (e) {
      _emitError('解析 WebSocket 消息失败: $e');
    }
  }

  void _onStreamError(dynamic error) {
    _emitError('WebSocket 连接错误: $error');
    _stopHeartbeat();
    _streamSubscription = null;
    _channel = null;
    _scheduleReconnect();
  }

  void _onStreamDone() {
    _stopHeartbeat();
    _streamSubscription = null;
    _channel = null;
    if (_manualDisconnect) {
      _setState(WebSocketState.disconnected);
      return;
    }
    _scheduleReconnect();
  }

  void _handleRealtimeMessage(WsEnvelope envelope) {
    final data = envelope.data;
    if (data == null) return;

    final payload = _convertRealtimePayload(data);
    final ts = envelope.timestamp != null
        ? DateTime.tryParse(envelope.timestamp!)
        : null;

    _realtimeController.add(
      RealtimeWsData(
        hopperData: payload.hopperData,
        rollerKilnData: payload.rollerKilnData,
        scrFanData: payload.scrFanData,
        timestamp: ts,
        source: envelope.source,
      ),
    );
  }

  void _handleDeviceStatusMessage(WsEnvelope envelope) {
    final data = envelope.data;
    if (data == null) return;

    final response = AllStatusResponse.fromJson({
      'success': envelope.success ?? true,
      'data': data,
      'summary': envelope.summary,
      'error': null,
    });

    _deviceStatusController.add(response);
  }

  ({
    Map<String, HopperData> hopperData,
    RollerKilnData? rollerKilnData,
    ScrFanBatchData? scrFanData,
  }) _convertRealtimePayload(Map<String, dynamic> rawPayload) {
    final hopperMap = <String, HopperData>{};
    final scrDevices = <Map<String, dynamic>>[];
    final fanDevices = <Map<String, dynamic>>[];

    Map<String, dynamic>? rollerDevice;
    Map<String, dynamic>? rollerTotalDevice;

    for (final entry in rawPayload.entries) {
      final value = entry.value;
      if (value is! Map<String, dynamic>) continue;

      final deviceType = (value['device_type'] ?? '').toString();
      switch (deviceType) {
        case 'short_hopper':
        case 'no_hopper':
        case 'long_hopper':
          final hopper = HopperData.fromJson(value);
          if (hopper.deviceId.isNotEmpty) {
            hopperMap[hopper.deviceId] = hopper;
          }
          break;
        case 'roller_kiln':
          rollerDevice = value;
          break;
        case 'scr':
          scrDevices.add(value);
          break;
        case 'fan':
          fanDevices.add(value);
          break;
      }

      if ((value['device_id'] ?? '').toString() == 'roller_kiln_total') {
        rollerTotalDevice = value;
      }
    }

    final rollerData = _parseRollerKilnData(rollerDevice, rollerTotalDevice);

    ScrFanBatchData? scrFanData;
    if (scrDevices.isNotEmpty || fanDevices.isNotEmpty) {
      scrDevices.sort((a, b) => (a['device_id'] ?? '')
          .toString()
          .compareTo((b['device_id'] ?? '').toString()));
      fanDevices.sort((a, b) => (a['device_id'] ?? '')
          .toString()
          .compareTo((b['device_id'] ?? '').toString()));

      scrFanData = ScrFanBatchData.fromJson({
        'total': scrDevices.length + fanDevices.length,
        'scr': {
          'total': scrDevices.length,
          'devices': scrDevices,
        },
        'fan': {
          'total': fanDevices.length,
          'devices': fanDevices,
        },
      });
    }

    return (
      hopperData: hopperMap,
      rollerKilnData: rollerData,
      scrFanData: scrFanData,
    );
  }

  RollerKilnData? _parseRollerKilnData(
    Map<String, dynamic>? rollerDevice,
    Map<String, dynamic>? rollerTotalDevice,
  ) {
    if (rollerDevice == null) return null;

    final modules = rollerDevice['modules'];
    if (modules is! Map<String, dynamic>) return null;

    final zones = <Map<String, dynamic>>[];
    for (int i = 1; i <= 6; i++) {
      final temp = _extractFields(modules['zone${i}_temp']);
      final meter = _extractFields(modules['zone${i}_meter']);
      zones.add({
        'zone_id': 'zone$i',
        'zone_name': '${i}号温区',
        'temperature': _toDouble(temp['temperature']),
        'Pt': _toDouble(meter['Pt']),
        'ImpEp': _toDouble(meter['ImpEp']),
        'Ua_0': _toDouble(meter['Ua_0']),
        'I_0': _toDouble(meter['I_0']),
        'I_1': _toDouble(meter['I_1']),
        'I_2': _toDouble(meter['I_2']),
      });
    }

    final totalFields =
        _extractFields(rollerTotalDevice?['modules']?['total_meter']);
    final total = {
      'Pt': _toDouble(totalFields['Pt'],
          fallback: zones.fold(0.0, (p, z) => p + _toDouble(z['Pt']))),
      'ImpEp': _toDouble(totalFields['ImpEp'],
          fallback: zones.fold(0.0, (p, z) => p + _toDouble(z['ImpEp']))),
      'Ua_0': _toDouble(totalFields['Ua_0'],
          fallback: zones.isEmpty
              ? 0.0
              : zones.fold(0.0, (p, z) => p + _toDouble(z['Ua_0'])) /
                  zones.length),
      'I_0': _toDouble(totalFields['I_0'],
          fallback: zones.fold(0.0, (p, z) => p + _toDouble(z['I_0']))),
      'I_1': _toDouble(totalFields['I_1'],
          fallback: zones.fold(0.0, (p, z) => p + _toDouble(z['I_1']))),
      'I_2': _toDouble(totalFields['I_2'],
          fallback: zones.fold(0.0, (p, z) => p + _toDouble(z['I_2']))),
    };

    return RollerKilnData.fromJson({
      'device_id': rollerDevice['device_id'] ?? 'roller_kiln_1',
      'timestamp': rollerDevice['timestamp'],
      'zones': zones,
      'total': total,
    });
  }

  Map<String, dynamic> _extractFields(dynamic module) {
    if (module is! Map<String, dynamic>) return {};
    final fields = module['fields'];
    if (fields is! Map<String, dynamic>) return {};
    return fields;
  }

  double _toDouble(dynamic value, {double fallback = 0.0}) {
    if (value is num) return value.toDouble();
    return fallback;
  }

  void _resubscribeDesiredChannels() {
    for (final channel in _desiredChannels) {
      _send({'type': 'subscribe', 'channel': channel});
    }
  }

  void _startHeartbeat() {
    _stopHeartbeat();
    _heartbeatTimer = Timer.periodic(_heartbeatInterval, (_) {
      if (!isConnected) return;
      _send(WsHeartbeatMessage().toJson());
    });
  }

  void _stopHeartbeat() {
    _heartbeatTimer?.cancel();
    _heartbeatTimer = null;
  }

  // 看门狗: 检测"假连接"(已连接但无数据) 和"遗漏重连"(断开但未重连)
  void _startWatchdog() {
    if (_watchdogTimer != null) return;
    _watchdogTimer = Timer.periodic(_watchdogInterval, (_) {
      if (_manualDisconnect) return;
      if (_desiredChannels.isEmpty) return;

      // 场景 1: 状态已连接但长时间无数据 → 连接已死，强制重连
      if (_state == WebSocketState.connected) {
        final elapsed = DateTime.now().difference(_lastDataTime);
        if (elapsed > _dataTimeout) {
          logger.info(
            '[WebSocket] 看门狗: 连接无响应 ${elapsed.inSeconds}s，强制重连',
          );
          _forceReconnect();
        }
        return;
      }

      // 场景 2: 断开状态且无重连计划 → 触发重连
      if (_state == WebSocketState.disconnected) {
        logger.info('[WebSocket] 看门狗: 检测到断线，触发重连');
        ensureConnected();
      }
      // reconnecting 状态不干预，尊重指数退避策略
    });
  }

  void _stopWatchdog() {
    _watchdogTimer?.cancel();
    _watchdogTimer = null;
  }

  /// 应用恢复前台时调用 (息屏唤醒/焦点恢复)
  void notifyAppResumed() {
    if (_manualDisconnect) return;

    if (_state == WebSocketState.connected) {
      // 检查连接是否仍然活跃
      final elapsed = DateTime.now().difference(_lastDataTime);
      if (elapsed > _dataTimeout) {
        logger.info(
          '[WebSocket] 唤醒检查: 连接无响应 ${elapsed.inSeconds}s，强制重连',
        );
        _forceReconnect();
      } else {
        // 连接正常，发送心跳确认
        _send(WsHeartbeatMessage().toJson());
      }
    } else if (_state == WebSocketState.reconnecting) {
      // 重连 timer 可能被 OS 延迟，醒屏后立即重连一次
      _cancelReconnect();
      _reconnectAttempts = 0;
      _setState(WebSocketState.disconnected);
      ensureConnected();
    } else {
      ensureConnected();
    }
  }

  // 强制断开旧连接并立即重连
  void _forceReconnect() {
    _stopHeartbeat();
    _cancelReconnect();
    _streamSubscription?.cancel();
    _streamSubscription = null;
    try {
      _channel?.sink.close();
    } catch (_) {}
    _channel = null;
    _reconnectAttempts = 0;
    _setState(WebSocketState.disconnected);
    ensureConnected();
  }

  void _scheduleReconnect() {
    if (_manualDisconnect) return;
    _cancelReconnect();
    _stopHeartbeat();

    _setState(WebSocketState.reconnecting);

    final seconds = _reconnectSeconds(_reconnectAttempts);
    _reconnectAttempts = (_reconnectAttempts + 1).clamp(0, 10);

    logger.info('[WebSocket] 第$_reconnectAttempts次重连，${seconds}s 后执行');

    _reconnectTimer = Timer(Duration(seconds: seconds), () {
      _setState(WebSocketState.disconnected);
      ensureConnected();
    });
  }

  int _reconnectSeconds(int attempts) {
    if (attempts <= 0) return 1;
    final value = 1 << attempts;
    if (value > 30) return 30;
    return value;
  }

  void _cancelReconnect() {
    _reconnectTimer?.cancel();
    _reconnectTimer = null;
  }

  void _send(Map<String, dynamic> message) {
    if (!isConnected || _channel == null) return;
    try {
      _channel!.sink.add(jsonEncode(message));
    } catch (e) {
      _emitError('发送 WebSocket 消息失败: $e');
      // 发送失败说明连接已死，立即重连
      _forceReconnect();
    }
  }

  void _setState(WebSocketState newState) {
    if (_state == newState) return;
    _state = newState;
    onStateChanged?.call(newState);
  }

  void _emitError(String message) {
    logger.warning(message);
    onError?.call(message);
  }
}

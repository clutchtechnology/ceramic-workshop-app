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

  final Set<String> _desiredChannels = <String>{};
  final Map<String, int> _channelRefCount = <String, int>{};

  WebSocketState _state = WebSocketState.disconnected;
  bool _manualDisconnect = false;
  int _reconnectAttempts = 0;

  static const Duration _heartbeatInterval = Duration(seconds: 15);

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

    try {
      logger.info('[TEST][前端→后端] 开始建立WebSocket连接: ${Api.wsRealtimeUrl}');
      _channel = WebSocketChannel.connect(Uri.parse(Api.wsRealtimeUrl));
      _streamSubscription = _channel!.stream.listen(
        _onMessage,
        onError: _onStreamError,
        onDone: _onStreamDone,
        cancelOnError: true,
      );

      _reconnectAttempts = 0;
      _setState(WebSocketState.connected);
      _startHeartbeat();
      _resubscribeDesiredChannels();
      logger.info('[TEST][前端→后端] WebSocket 连接成功');
    } catch (e) {
      _emitError('WebSocket 连接失败: $e');
      _scheduleReconnect();
    }
  }

  Future<void> disconnect() async {
    _manualDisconnect = true;
    _stopHeartbeat();
    _cancelReconnect();

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
      logger.info('[TEST][前端→后端] 发送订阅请求: $key');
      _send(WsSubscribeMessage(channel).toJson());
      logger.info('[TEST][前端→后端] 订阅请求已发送: $key');
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
    try {
      final Map<String, dynamic> json =
          raw is String ? jsonDecode(raw) as Map<String, dynamic> : raw;

      final envelope = WsEnvelope.fromJson(json);

      logger.info('[TEST][后端→前端] 收到消息 | type=${envelope.type} | timestamp=${envelope.timestamp}');

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
    _scheduleReconnect();
  }

  void _onStreamDone() {
    if (_manualDisconnect) {
      _setState(WebSocketState.disconnected);
      return;
    }
    _scheduleReconnect();
  }

  void _handleRealtimeMessage(WsEnvelope envelope) {
    final data = envelope.data;
    if (data == null) return;

    logger.info('[TEST][后端→前端] 开始解析实时数据');
    
    final payload = _convertRealtimePayload(data);
    final ts = envelope.timestamp != null
        ? DateTime.tryParse(envelope.timestamp!)
        : null;

    logger.info(
      '[TEST][后端→前端] 数据解析完成 | '
      '料仓=${payload.hopperData.length} | '
      '辊道窑=${payload.rollerKilnData != null ? "有" : "无"} | '
      'SCR+风机=${payload.scrFanData != null ? "有" : "无"}'
    );

    _realtimeController.add(
      RealtimeWsData(
        hopperData: payload.hopperData,
        rollerKilnData: payload.rollerKilnData,
        scrFanData: payload.scrFanData,
        timestamp: ts,
        source: envelope.source,
      ),
    );
    
    logger.info('[TEST][后端→前端] 数据已发送到Stream');
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

  void _scheduleReconnect() {
    if (_manualDisconnect) return;
    _cancelReconnect();

    _setState(WebSocketState.reconnecting);

    final seconds = _reconnectSeconds(_reconnectAttempts);
    _reconnectAttempts = (_reconnectAttempts + 1).clamp(0, 10);

    _reconnectTimer = Timer(Duration(seconds: seconds), () {
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

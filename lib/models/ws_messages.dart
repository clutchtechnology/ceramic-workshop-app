enum WsChannel {
  realtime,
  deviceStatus,
}

extension WsChannelExtension on WsChannel {
  String get value {
    switch (this) {
      case WsChannel.realtime:
        return 'realtime';
      case WsChannel.deviceStatus:
        return 'device_status';
    }
  }
}

class WsSubscribeMessage {
  final WsChannel channel;

  WsSubscribeMessage(this.channel);

  Map<String, dynamic> toJson() => {
        'type': 'subscribe',
        'channel': channel.value,
      };
}

class WsUnsubscribeMessage {
  final WsChannel channel;

  WsUnsubscribeMessage(this.channel);

  Map<String, dynamic> toJson() => {
        'type': 'unsubscribe',
        'channel': channel.value,
      };
}

class WsHeartbeatMessage {
  Map<String, dynamic> toJson() => {
        'type': 'heartbeat',
        'timestamp': DateTime.now().toUtc().toIso8601String(),
      };
}

class WsEnvelope {
  final String type;
  final bool? success;
  final String? timestamp;
  final String? source;
  final Map<String, dynamic>? data;
  final Map<String, dynamic>? summary;
  final String? code;
  final String? message;

  WsEnvelope({
    required this.type,
    this.success,
    this.timestamp,
    this.source,
    this.data,
    this.summary,
    this.code,
    this.message,
  });

  factory WsEnvelope.fromJson(Map<String, dynamic> json) {
    final dynamic data = json['data'];
    final dynamic summary = json['summary'];

    return WsEnvelope(
      type: (json['type'] ?? '').toString(),
      success: json['success'] as bool?,
      timestamp: json['timestamp']?.toString(),
      source: json['source']?.toString(),
      data: data is Map<String, dynamic> ? data : null,
      summary: summary is Map<String, dynamic> ? summary : null,
      code: json['code']?.toString(),
      message: json['message']?.toString(),
    );
  }
}

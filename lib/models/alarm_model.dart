// 报警数据模型

class AlarmRecord {
  final String time;
  final String deviceId;
  final String alarmType;
  final String paramName;
  final String level; // 'warning' | 'alarm'
  final double? value;
  final double? threshold;

  const AlarmRecord({
    required this.time,
    required this.deviceId,
    required this.alarmType,
    required this.paramName,
    required this.level,
    this.value,
    this.threshold,
  });

  factory AlarmRecord.fromJson(Map<String, dynamic> json) {
    return AlarmRecord(
      time: json['time'] as String? ?? '',
      deviceId: json['device_id'] as String? ?? '',
      alarmType: json['alarm_type'] as String? ?? '',
      paramName: json['param_name'] as String? ?? '',
      level: json['level'] as String? ?? '',
      value: (json['value'] as num?)?.toDouble(),
      threshold: (json['threshold'] as num?)?.toDouble(),
    );
  }
}

class AlarmCount {
  final int warning;
  final int alarm;
  final int total;

  const AlarmCount({
    required this.warning,
    required this.alarm,
    required this.total,
  });

  factory AlarmCount.fromJson(Map<String, dynamic> json) {
    return AlarmCount(
      warning: (json['warning'] as num?)?.toInt() ?? 0,
      alarm: (json['alarm'] as num?)?.toInt() ?? 0,
      total: (json['total'] as num?)?.toInt() ?? 0,
    );
  }

  static const AlarmCount zero = AlarmCount(warning: 0, alarm: 0, total: 0);
}

class AlarmThresholdConfig {
  final double warningMax;
  final double alarmMax;
  final bool enabled;

  const AlarmThresholdConfig({
    required this.warningMax,
    required this.alarmMax,
    this.enabled = true,
  });

  factory AlarmThresholdConfig.fromJson(Map<String, dynamic> json) {
    return AlarmThresholdConfig(
      warningMax: (json['warning_max'] as num?)?.toDouble() ?? 0,
      alarmMax: (json['alarm_max'] as num?)?.toDouble() ?? 0,
      enabled: json['enabled'] as bool? ?? true,
    );
  }

  Map<String, dynamic> toJson() => {
        'warning_max': warningMax,
        'alarm_max': alarmMax,
        'enabled': enabled,
      };
}

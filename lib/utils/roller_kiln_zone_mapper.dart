import '../models/roller_kiln_model.dart';

class RollerKilnDisplayZone {
  final int displayIndex;
  final String displayLabel;
  final int temperatureZoneNumber;
  final int meterZoneNumber;

  const RollerKilnDisplayZone({
    required this.displayIndex,
    required this.displayLabel,
    required this.temperatureZoneNumber,
    required this.meterZoneNumber,
  });

  String get temperatureZoneId => 'zone$temperatureZoneNumber';
  String get temperatureKey => '${temperatureZoneId}_temp';
  int get temperatureConfigIndex => temperatureZoneNumber - 1;

  String get meterZoneId => 'zone$meterZoneNumber';
  String get meterKey => '${meterZoneId}_meter';

  String get backendZoneId => temperatureZoneId;
  String get backendTempKey => temperatureKey;
  int get backendConfigIndex => temperatureConfigIndex;
  int get backendZoneNumber => temperatureZoneNumber;

  int? get displayZoneNumber {
    final match = RegExp(r'温区(\d+)').firstMatch(displayLabel);
    return match == null ? null : int.tryParse(match.group(1)!);
  }
}

class RollerKilnZoneMapper {
  static const List<RollerKilnDisplayZone> displayZones = [
    RollerKilnDisplayZone(
      displayIndex: 0,
      displayLabel: '高温区',
      temperatureZoneNumber: 1,
      meterZoneNumber: 6,
    ),
    RollerKilnDisplayZone(
      displayIndex: 1,
      displayLabel: '温区1',
      temperatureZoneNumber: 6,
      meterZoneNumber: 5,
    ),
    RollerKilnDisplayZone(
      displayIndex: 2,
      displayLabel: '温区2',
      temperatureZoneNumber: 5,
      meterZoneNumber: 4,
    ),
    RollerKilnDisplayZone(
      displayIndex: 3,
      displayLabel: '温区3',
      temperatureZoneNumber: 3,
      meterZoneNumber: 3,
    ),
    RollerKilnDisplayZone(
      displayIndex: 4,
      displayLabel: '温区4',
      temperatureZoneNumber: 4,
      meterZoneNumber: 2,
    ),
    RollerKilnDisplayZone(
      displayIndex: 5,
      displayLabel: '温区5',
      temperatureZoneNumber: 2,
      meterZoneNumber: 1,
    ),
    RollerKilnDisplayZone(
      displayIndex: 6,
      displayLabel: '温区6',
      temperatureZoneNumber: 2,
      meterZoneNumber: 1,
    ),
  ];

  static int get displayCount => displayZones.length;

  static RollerKilnDisplayZone byDisplayIndex(int displayIndex) {
    return displayZones[displayIndex];
  }

  static String labelForDisplayIndex(int displayIndex) {
    return byDisplayIndex(displayIndex).displayLabel;
  }

  static String backendZoneIdForDisplayIndex(int displayIndex) {
    return temperatureZoneIdForDisplayIndex(displayIndex);
  }

  static String backendTempKeyForDisplayIndex(int displayIndex) {
    return temperatureKeyForDisplayIndex(displayIndex);
  }

  static int backendConfigIndexForDisplayIndex(int displayIndex) {
    return temperatureConfigIndexForDisplayIndex(displayIndex);
  }

  static String temperatureZoneIdForDisplayIndex(int displayIndex) {
    return byDisplayIndex(displayIndex).temperatureZoneId;
  }

  static String temperatureKeyForDisplayIndex(int displayIndex) {
    return byDisplayIndex(displayIndex).temperatureKey;
  }

  static int temperatureConfigIndexForDisplayIndex(int displayIndex) {
    return byDisplayIndex(displayIndex).temperatureConfigIndex;
  }

  static String meterZoneIdForDisplayIndex(int displayIndex) {
    return byDisplayIndex(displayIndex).meterZoneId;
  }

  static String meterKeyForDisplayIndex(int displayIndex) {
    return byDisplayIndex(displayIndex).meterKey;
  }

  static RollerKilnZone? sourceZoneForDisplay(
    List<RollerKilnZone>? zones,
    int displayIndex,
  ) {
    return temperatureSourceZoneForDisplay(zones, displayIndex);
  }

  static RollerKilnZone? temperatureSourceZoneForDisplay(
    List<RollerKilnZone>? zones,
    int displayIndex,
  ) {
    return _sourceZoneForBackendZoneNumber(
      zones,
      byDisplayIndex(displayIndex).temperatureZoneNumber,
    );
  }

  static RollerKilnZone? meterSourceZoneForDisplay(
    List<RollerKilnZone>? zones,
    int displayIndex,
  ) {
    return _sourceZoneForBackendZoneNumber(
      zones,
      byDisplayIndex(displayIndex).meterZoneNumber,
    );
  }

  static RollerKilnZone? _sourceZoneForBackendZoneNumber(
    List<RollerKilnZone>? zones,
    int backendZoneNumber,
  ) {
    if (zones == null || zones.isEmpty) return null;

    final backendZoneId = 'zone$backendZoneNumber';
    for (final zone in zones) {
      if (zone.zoneId == backendZoneId) return zone;
    }

    final fallbackIndex = backendZoneNumber - 1;
    if (fallbackIndex >= 0 && fallbackIndex < zones.length) {
      return zones[fallbackIndex];
    }
    return null;
  }

  static List<RollerKilnDisplayZone> displayZonesForBackendZoneId(
    String backendZoneId,
  ) {
    return displayZonesForTemperatureBackendZoneId(backendZoneId);
  }

  static List<RollerKilnDisplayZone> displayZonesForTemperatureBackendZoneId(
    String backendZoneId,
  ) {
    return displayZones
        .where((zone) => zone.temperatureZoneId == backendZoneId)
        .toList(growable: false);
  }

  static List<RollerKilnDisplayZone> displayZonesForMeterBackendZoneId(
    String backendZoneId,
  ) {
    return displayZones
        .where((zone) => zone.meterZoneId == backendZoneId)
        .toList(growable: false);
  }

  static String labelForBackendZoneId(String backendZoneId) {
    return labelForTemperatureBackendZoneId(backendZoneId);
  }

  static String labelForTemperatureBackendZoneId(String backendZoneId) {
    return _labelForMatches(
      backendZoneId,
      displayZonesForTemperatureBackendZoneId(backendZoneId),
    );
  }

  static String labelForMeterBackendZoneId(String backendZoneId) {
    return _labelForMatches(
      backendZoneId,
      displayZonesForMeterBackendZoneId(backendZoneId),
    );
  }

  static String _labelForMatches(
    String backendZoneId,
    List<RollerKilnDisplayZone> matches,
  ) {
    if (matches.isEmpty) return backendZoneId;
    if (matches.length == 1) return matches.first.displayLabel;
    return matches.map((zone) => zone.displayLabel).join('/');
  }

  static String? backendZoneIdFromText(String? text) {
    if (text == null || text.isEmpty) return null;
    final match = RegExp(r'zone([1-6])').firstMatch(text);
    if (match == null) return null;
    return 'zone${match.group(1)}';
  }

  static String? displayLabelFromDisplaySuffix(String? text) {
    if (text == null || text.isEmpty) return null;
    final match = RegExp(r'_display(\d+)').firstMatch(text);
    if (match == null) return null;
    final displayZoneNumber = int.tryParse(match.group(1)!);
    if (displayZoneNumber == null) return null;
    for (final zone in displayZones) {
      if (zone.displayZoneNumber == displayZoneNumber) {
        return zone.displayLabel;
      }
    }
    return null;
  }

  static bool looksLikeTemperatureText(String text) {
    final lower = text.toLowerCase();
    return lower.contains('temp') || text.contains('温');
  }

  static bool looksLikeMeterText(String text) {
    final lower = text.toLowerCase();
    return lower.contains('meter') ||
        lower.contains('power') ||
        lower.contains('energy') ||
        text.contains('电') ||
        text.contains('功率') ||
        text.contains('能耗');
  }
}

import 'package:ceramic_workshop_app/models/roller_kiln_model.dart';
import 'package:ceramic_workshop_app/utils/roller_kiln_zone_mapper.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('RollerKilnZoneMapper', () {
    test('maps seven display zones to backend temperature zones', () {
      expect(RollerKilnZoneMapper.displayCount, 7);

      expect(RollerKilnZoneMapper.labelForDisplayIndex(0), '高温区');
      expect(
        RollerKilnZoneMapper.temperatureZoneIdForDisplayIndex(0),
        'zone1',
      );

      expect(RollerKilnZoneMapper.temperatureZoneIdForDisplayIndex(1), 'zone6');
      expect(RollerKilnZoneMapper.temperatureZoneIdForDisplayIndex(2), 'zone5');
      expect(RollerKilnZoneMapper.temperatureZoneIdForDisplayIndex(3), 'zone3');
      expect(RollerKilnZoneMapper.temperatureZoneIdForDisplayIndex(4), 'zone4');
      expect(RollerKilnZoneMapper.temperatureZoneIdForDisplayIndex(5), 'zone2');
      expect(RollerKilnZoneMapper.temperatureZoneIdForDisplayIndex(6), 'zone2');
    });

    test('maps seven display zones to backend meter zones', () {
      expect(RollerKilnZoneMapper.meterZoneIdForDisplayIndex(0), 'zone6');
      expect(RollerKilnZoneMapper.meterZoneIdForDisplayIndex(1), 'zone5');
      expect(RollerKilnZoneMapper.meterZoneIdForDisplayIndex(2), 'zone4');
      expect(RollerKilnZoneMapper.meterZoneIdForDisplayIndex(3), 'zone3');
      expect(RollerKilnZoneMapper.meterZoneIdForDisplayIndex(4), 'zone2');
      expect(RollerKilnZoneMapper.meterZoneIdForDisplayIndex(5), 'zone1');
      expect(RollerKilnZoneMapper.meterZoneIdForDisplayIndex(6), 'zone1');
    });

    test('uses separate source zones for temperature and meter data', () {
      final zones = List.generate(6, (index) {
        final zoneNumber = index + 1;
        return RollerKilnZone(
          zoneId: 'zone$zoneNumber',
          zoneName: 'zone$zoneNumber',
          temperature: zoneNumber * 100,
          power: zoneNumber * 10,
          energy: zoneNumber * 1000,
          voltage: 220,
          currentA: zoneNumber.toDouble(),
          currentB: zoneNumber.toDouble(),
          currentC: zoneNumber.toDouble(),
        );
      });

      expect(
        RollerKilnZoneMapper.temperatureSourceZoneForDisplay(zones, 0)?.zoneId,
        'zone1',
      );
      expect(
        RollerKilnZoneMapper.meterSourceZoneForDisplay(zones, 0)?.zoneId,
        'zone6',
      );
      expect(
        RollerKilnZoneMapper.temperatureSourceZoneForDisplay(zones, 1)?.zoneId,
        'zone6',
      );
      expect(
        RollerKilnZoneMapper.meterSourceZoneForDisplay(zones, 1)?.zoneId,
        'zone5',
      );
      expect(
        RollerKilnZoneMapper.temperatureSourceZoneForDisplay(zones, 5)?.zoneId,
        'zone2',
      );
      expect(
        RollerKilnZoneMapper.temperatureSourceZoneForDisplay(zones, 6)?.zoneId,
        'zone2',
      );
      expect(
        RollerKilnZoneMapper.meterSourceZoneForDisplay(zones, 5)?.zoneId,
        'zone1',
      );
      expect(
        RollerKilnZoneMapper.meterSourceZoneForDisplay(zones, 6)?.zoneId,
        'zone1',
      );
    });

    test('labels temperature and meter backend zones separately', () {
      expect(
        RollerKilnZoneMapper.labelForTemperatureBackendZoneId('zone1'),
        '高温区',
      );
      expect(
        RollerKilnZoneMapper.labelForTemperatureBackendZoneId('zone2'),
        '温区5/温区6',
      );
      expect(
        RollerKilnZoneMapper.labelForMeterBackendZoneId('zone6'),
        '高温区',
      );
      expect(
        RollerKilnZoneMapper.labelForMeterBackendZoneId('zone1'),
        '温区5/温区6',
      );
    });
  });
}

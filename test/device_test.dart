import 'package:flutter_test/flutter_test.dart';
import 'package:netis_manager/domain/entities/device.dart';

void main() {
  group('Device', () {
    const mac = 'AA:BB:CC:DD:EE:FF';
    const ip = '192.168.1.100';

    test('displayName returns hostname when set', () {
      const device = Device(mac: mac, ip: ip, hostname: 'my-phone');
      expect(device.displayName, equals('my-phone'));
    });

    test('displayName falls back to MAC when hostname is null', () {
      const device = Device(mac: mac, ip: ip);
      expect(device.displayName, equals(mac));
    });

    test('displayName falls back to MAC when hostname is empty', () {
      const device = Device(mac: mac, ip: ip, hostname: '');
      expect(device.displayName, equals(mac));
    });

    test('isBlocked defaults to false', () {
      const device = Device(mac: mac, ip: ip);
      expect(device.isBlocked, isFalse);
    });

    test('copyWith overrides isBlocked', () {
      const device = Device(mac: mac, ip: ip, isBlocked: false);
      final blocked = device.copyWith(isBlocked: true);
      expect(blocked.isBlocked, isTrue);
      expect(blocked.mac, equals(mac)); // unchanged
    });

    test('equality is based on MAC address', () {
      const d1 = Device(mac: mac, ip: ip, hostname: 'phone');
      const d2 = Device(mac: mac, ip: '192.168.1.200', hostname: 'other');
      expect(d1, equals(d2));
    });

    test('devices with different MACs are not equal', () {
      const d1 = Device(mac: 'AA:BB:CC:DD:EE:FF', ip: ip);
      const d2 = Device(mac: '11:22:33:44:55:66', ip: ip);
      expect(d1, isNot(equals(d2)));
    });
  });
}

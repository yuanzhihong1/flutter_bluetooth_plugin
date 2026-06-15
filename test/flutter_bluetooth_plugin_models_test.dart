import 'package:flutter_bluetooth_plugin/flutter_bluetooth_plugin_models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('BluetoothScanResult accepts numeric connectable values', () {
    final result = BluetoothScanResult.fromMap(<String, dynamic>{
      'device': <String, dynamic>{
        'id': 'device-1',
        'isConnected': 1,
        'isBonded': 0,
      },
      'rssi': -61,
      'isConnectable': 1,
    });

    expect(result.device.isConnected, isTrue);
    expect(result.device.isBonded, isFalse);
    expect(result.isConnectable, isTrue);
  });

  test('BluetoothGattService accepts numeric primary values', () {
    final service = BluetoothGattService.fromMap(<String, dynamic>{
      'uuid': '0000fff0-0000-1000-8000-00805f9b34fb',
      'isPrimary': 0,
    });

    expect(service.isPrimary, isFalse);
  });

  test('BluetoothAdapterInfo accepts numeric capability values', () {
    final info = BluetoothAdapterInfo.fromMap(<String, dynamic>{
      'isSupported': 1,
      'state': 'poweredOn',
      'isBleSupported': 1,
      'isDiscovering': 0,
    });

    expect(info.isSupported, isTrue);
    expect(info.isBleSupported, isTrue);
    expect(info.isDiscovering, isFalse);
  });
}

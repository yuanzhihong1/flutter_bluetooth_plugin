import 'package:flutter/cupertino.dart';
import 'package:flutter_bluetooth_plugin/flutter_bluetooth_plugin.dart';
import 'package:flutter_bluetooth_plugin/flutter_bluetooth_plugin_platform_interface.dart';
import 'package:flutter_bluetooth_plugin_example/main.dart';
import 'package:flutter_test/flutter_test.dart';

class FakeBluetoothPlatform extends FlutterBluetoothPluginPlatform {
  @override
  Future<String?> getPlatformVersion() async => 'Test OS 1.0';

  @override
  Future<bool> isSupported() async => true;

  @override
  Future<BluetoothAdapterState> getAdapterState() async {
    return BluetoothAdapterState.poweredOn;
  }

  @override
  Future<Map<String, BluetoothPermissionStatus>> checkPermissions() async {
    return const <String, BluetoothPermissionStatus>{
      'bluetooth': BluetoothPermissionStatus.granted,
    };
  }

  @override
  Stream<BluetoothAdapterState> get adapterState {
    return const Stream<BluetoothAdapterState>.empty();
  }

  @override
  Stream<BluetoothScanResult> get scanResults {
    return const Stream<BluetoothScanResult>.empty();
  }

  @override
  Stream<BluetoothConnectionStateEvent> get connectionState {
    return const Stream<BluetoothConnectionStateEvent>.empty();
  }

  @override
  Stream<BluetoothCharacteristicValue> get characteristicValues {
    return const Stream<BluetoothCharacteristicValue>.empty();
  }

  @override
  Stream<BluetoothDescriptorValue> get descriptorValues {
    return const Stream<BluetoothDescriptorValue>.empty();
  }

  @override
  Stream<BluetoothRssiEvent> get rssiUpdates {
    return const Stream<BluetoothRssiEvent>.empty();
  }

  @override
  Stream<BluetoothMtuEvent> get mtuUpdates {
    return const Stream<BluetoothMtuEvent>.empty();
  }

  @override
  Stream<BluetoothBondStateEvent> get bondState {
    return const Stream<BluetoothBondStateEvent>.empty();
  }
}

void main() {
  testWidgets('Bluetooth tester uses CupertinoApp', (
    WidgetTester tester,
  ) async {
    FlutterBluetoothPluginPlatform.instance = FakeBluetoothPlatform();

    await tester.pumpWidget(const BluetoothTestApp());
    await tester.pump();

    expect(find.byType(CupertinoApp), findsOneWidget);
    expect(find.text('Bluetooth Lab'), findsOneWidget);
    expect(find.text('Native Bluetooth Tester'), findsOneWidget);
    expect(find.text('Test OS 1.0'), findsOneWidget);
  });
}

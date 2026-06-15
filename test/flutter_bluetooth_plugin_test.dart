import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_bluetooth_plugin/flutter_bluetooth_plugin.dart';
import 'package:flutter_bluetooth_plugin/flutter_bluetooth_plugin_platform_interface.dart';
import 'package:flutter_bluetooth_plugin/flutter_bluetooth_plugin_method_channel.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

class MockFlutterBluetoothPluginPlatform
    with MockPlatformInterfaceMixin
    implements FlutterBluetoothPluginPlatform {
  @override
  Future<String?> getPlatformVersion() => Future.value('42');
}

void main() {
  final FlutterBluetoothPluginPlatform initialPlatform = FlutterBluetoothPluginPlatform.instance;

  test('$MethodChannelFlutterBluetoothPlugin is the default instance', () {
    expect(initialPlatform, isInstanceOf<MethodChannelFlutterBluetoothPlugin>());
  });

  test('getPlatformVersion', () async {
    FlutterBluetoothPlugin flutterBluetoothPlugin = FlutterBluetoothPlugin();
    MockFlutterBluetoothPluginPlatform fakePlatform = MockFlutterBluetoothPluginPlatform();
    FlutterBluetoothPluginPlatform.instance = fakePlatform;

    expect(await flutterBluetoothPlugin.getPlatformVersion(), '42');
  });
}

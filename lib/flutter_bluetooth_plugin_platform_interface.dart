import 'package:plugin_platform_interface/plugin_platform_interface.dart';

import 'flutter_bluetooth_plugin_method_channel.dart';

abstract class FlutterBluetoothPluginPlatform extends PlatformInterface {
  /// Constructs a FlutterBluetoothPluginPlatform.
  FlutterBluetoothPluginPlatform() : super(token: _token);

  static final Object _token = Object();

  static FlutterBluetoothPluginPlatform _instance = MethodChannelFlutterBluetoothPlugin();

  /// The default instance of [FlutterBluetoothPluginPlatform] to use.
  ///
  /// Defaults to [MethodChannelFlutterBluetoothPlugin].
  static FlutterBluetoothPluginPlatform get instance => _instance;

  /// Platform-specific implementations should set this with their own
  /// platform-specific class that extends [FlutterBluetoothPluginPlatform] when
  /// they register themselves.
  static set instance(FlutterBluetoothPluginPlatform instance) {
    PlatformInterface.verifyToken(instance, _token);
    _instance = instance;
  }

  Future<String?> getPlatformVersion() {
    throw UnimplementedError('platformVersion() has not been implemented.');
  }
}

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'flutter_bluetooth_plugin_platform_interface.dart';

/// An implementation of [FlutterBluetoothPluginPlatform] that uses method channels.
class MethodChannelFlutterBluetoothPlugin extends FlutterBluetoothPluginPlatform {
  /// The method channel used to interact with the native platform.
  @visibleForTesting
  final methodChannel = const MethodChannel('flutter_bluetooth_plugin');

  @override
  Future<String?> getPlatformVersion() async {
    final version = await methodChannel.invokeMethod<String>(
      'getPlatformVersion',
    );
    return version;
  }
}

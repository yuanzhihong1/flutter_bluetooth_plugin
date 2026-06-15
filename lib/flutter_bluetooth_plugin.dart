
import 'flutter_bluetooth_plugin_platform_interface.dart';

class FlutterBluetoothPlugin {
  Future<String?> getPlatformVersion() {
    return FlutterBluetoothPluginPlatform.instance.getPlatformVersion();
  }
}

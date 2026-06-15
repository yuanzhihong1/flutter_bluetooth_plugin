#ifndef FLUTTER_PLUGIN_FLUTTER_BLUETOOTH_PLUGIN_H_
#define FLUTTER_PLUGIN_FLUTTER_BLUETOOTH_PLUGIN_H_

#include <flutter/method_channel.h>
#include <flutter/plugin_registrar_windows.h>

#include <memory>

namespace flutter_bluetooth_plugin {

class FlutterBluetoothPlugin : public flutter::Plugin {
 public:
  static void RegisterWithRegistrar(flutter::PluginRegistrarWindows *registrar);

  FlutterBluetoothPlugin();

  virtual ~FlutterBluetoothPlugin();

  // Disallow copy and assign.
  FlutterBluetoothPlugin(const FlutterBluetoothPlugin&) = delete;
  FlutterBluetoothPlugin& operator=(const FlutterBluetoothPlugin&) = delete;

  // Called when a method is called on this plugin's channel from Dart.
  void HandleMethodCall(
      const flutter::MethodCall<flutter::EncodableValue> &method_call,
      std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result);
};

}  // namespace flutter_bluetooth_plugin

#endif  // FLUTTER_PLUGIN_FLUTTER_BLUETOOTH_PLUGIN_H_

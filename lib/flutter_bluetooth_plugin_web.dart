// In order to *not* need this ignore, consider extracting the "web" version
// of your plugin as a separate package, instead of inlining it in the same
// package as the core of your plugin.
// ignore: avoid_web_libraries_in_flutter

import 'dart:async';

import 'package:flutter_web_plugins/flutter_web_plugins.dart';
import 'package:web/web.dart' as web;

import 'flutter_bluetooth_plugin_models.dart';
import 'flutter_bluetooth_plugin_platform_interface.dart';

/// A web implementation of the FlutterBluetoothPluginPlatform of the FlutterBluetoothPlugin plugin.
class FlutterBluetoothPluginWeb extends FlutterBluetoothPluginPlatform {
  /// Constructs a FlutterBluetoothPluginWeb
  FlutterBluetoothPluginWeb();

  static void registerWith(Registrar registrar) {
    FlutterBluetoothPluginPlatform.instance = FlutterBluetoothPluginWeb();
  }

  /// Returns a [String] containing the version of the platform.
  @override
  Future<String?> getPlatformVersion() async {
    return web.window.navigator.userAgent;
  }

  @override
  Future<bool> isSupported() async => false;

  @override
  Future<BluetoothAdapterState> getAdapterState() async {
    return BluetoothAdapterState.unsupported;
  }

  @override
  Stream<BluetoothAdapterState> get adapterState {
    return Stream<BluetoothAdapterState>.value(
      BluetoothAdapterState.unsupported,
    );
  }

  @override
  Future<Map<String, BluetoothPermissionStatus>> checkPermissions() async {
    return const <String, BluetoothPermissionStatus>{
      'bluetooth': BluetoothPermissionStatus.notApplicable,
    };
  }

  @override
  Future<Map<String, BluetoothPermissionStatus>> requestPermissions() {
    return checkPermissions();
  }

  @override
  Future<bool> requestEnable() async => false;

  @override
  Future<void> openBluetoothSettings() async {}

  @override
  Future<void> startScan({
    List<String> serviceUuids = const <String>[],
    Duration? timeout,
    bool allowDuplicates = false,
    BluetoothScanMode scanMode = BluetoothScanMode.ble,
  }) {
    throw UnsupportedError('Bluetooth scanning is not implemented for web.');
  }

  @override
  Future<void> stopScan() async {}

  @override
  Stream<BluetoothScanResult> get scanResults =>
      const Stream<BluetoothScanResult>.empty();

  @override
  Future<List<BluetoothDevice>> getBondedDevices() async =>
      const <BluetoothDevice>[];

  @override
  Future<List<BluetoothDevice>> getConnectedDevices({
    List<String> serviceUuids = const <String>[],
  }) async {
    return const <BluetoothDevice>[];
  }

  @override
  Future<void> connect(
    String deviceId, {
    bool autoConnect = false,
    Duration? timeout,
  }) {
    throw UnsupportedError(
      'Bluetooth connections are not implemented for web.',
    );
  }

  @override
  Future<void> disconnect(String deviceId) async {}

  @override
  Future<BluetoothConnectionState> getConnectionState(String deviceId) async {
    return BluetoothConnectionState.disconnected;
  }

  @override
  Stream<BluetoothConnectionStateEvent> get connectionState {
    return const Stream<BluetoothConnectionStateEvent>.empty();
  }

  @override
  Future<List<BluetoothGattService>> discoverServices(String deviceId) {
    throw UnsupportedError(
      'GATT service discovery is not implemented for web.',
    );
  }

  @override
  Future<List<int>> readCharacteristic({
    required String deviceId,
    required String serviceUuid,
    required String characteristicUuid,
  }) {
    throw UnsupportedError(
      'GATT characteristic reads are not implemented for web.',
    );
  }

  @override
  Future<void> writeCharacteristic({
    required String deviceId,
    required String serviceUuid,
    required String characteristicUuid,
    required List<int> value,
    BluetoothWriteType writeType = BluetoothWriteType.withResponse,
  }) {
    throw UnsupportedError(
      'GATT characteristic writes are not implemented for web.',
    );
  }

  @override
  Future<void> setCharacteristicNotification({
    required String deviceId,
    required String serviceUuid,
    required String characteristicUuid,
    required bool enable,
  }) {
    throw UnsupportedError('GATT notifications are not implemented for web.');
  }

  @override
  Stream<BluetoothCharacteristicValue> get characteristicValues {
    return const Stream<BluetoothCharacteristicValue>.empty();
  }

  @override
  Future<List<int>> readDescriptor({
    required String deviceId,
    required String serviceUuid,
    required String characteristicUuid,
    required String descriptorUuid,
  }) {
    throw UnsupportedError(
      'GATT descriptor reads are not implemented for web.',
    );
  }

  @override
  Future<void> writeDescriptor({
    required String deviceId,
    required String serviceUuid,
    required String characteristicUuid,
    required String descriptorUuid,
    required List<int> value,
  }) {
    throw UnsupportedError(
      'GATT descriptor writes are not implemented for web.',
    );
  }

  @override
  Stream<BluetoothDescriptorValue> get descriptorValues {
    return const Stream<BluetoothDescriptorValue>.empty();
  }

  @override
  Future<int> readRssi(String deviceId) {
    throw UnsupportedError('RSSI reads are not implemented for web.');
  }

  @override
  Stream<BluetoothRssiEvent> get rssiUpdates =>
      const Stream<BluetoothRssiEvent>.empty();

  @override
  Future<int> requestMtu(String deviceId, int mtu) async => 0;

  @override
  Stream<BluetoothMtuEvent> get mtuUpdates =>
      const Stream<BluetoothMtuEvent>.empty();

  @override
  Future<bool> requestConnectionPriority(
    String deviceId,
    BluetoothConnectionPriority priority,
  ) async {
    return false;
  }

  @override
  Future<bool> createBond(String deviceId) async => false;

  @override
  Future<bool> removeBond(String deviceId) async => false;

  @override
  Stream<BluetoothBondStateEvent> get bondState {
    return const Stream<BluetoothBondStateEvent>.empty();
  }
}

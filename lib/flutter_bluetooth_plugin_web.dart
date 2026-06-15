// In order to *not* need this ignore, consider extracting the "web" version
// of your plugin as a separate package, instead of inlining it in the same
// package as the core of your plugin.
// ignore: avoid_web_libraries_in_flutter

import 'dart:async';

import 'package:flutter_web_plugins/flutter_web_plugins.dart';
import 'package:web/web.dart' as web;

import 'flutter_bluetooth_plugin_models.dart';
import 'flutter_bluetooth_plugin_platform_interface.dart';

/// Web 平台实现。
///
/// 当前 Web 端仅返回不支持状态、空流或抛出不支持错误；参数说明和默认值与平台接口保持一致。
class FlutterBluetoothPluginWeb extends FlutterBluetoothPluginPlatform {
  /// 创建 Web 平台实现。
  ///
  /// 无参数、无默认值。
  FlutterBluetoothPluginWeb();

  /// 注册 Web 平台实现。
  ///
  /// 参数：
  /// - [registrar]：Flutter Web 插件注册器，无默认值。
  static void registerWith(Registrar registrar) {
    FlutterBluetoothPluginPlatform.instance = FlutterBluetoothPluginWeb();
  }

  /// 返回浏览器 User-Agent 作为平台版本字符串。
  ///
  /// 无参数；其它 API 的参数、默认值和平台差异见平台接口文档。
  /// 实现 [FlutterBluetoothPluginPlatform.getPlatformVersion]。
  ///
  /// 参数、默认值、平台差异和推荐值见平台接口文档。
  @override
  Future<String?> getPlatformVersion() async {
    return web.window.navigator.userAgent;
  }

  /// 实现 [FlutterBluetoothPluginPlatform.isSupported]。
  ///
  /// 参数、默认值、平台差异和推荐值见平台接口文档。
  @override
  Future<bool> isSupported() async => false;

  /// 实现 [FlutterBluetoothPluginPlatform.getAdapterState]。
  ///
  /// 参数、默认值、平台差异和推荐值见平台接口文档。
  @override
  Future<BluetoothAdapterState> getAdapterState() async {
    return BluetoothAdapterState.unsupported;
  }

  /// 实现 [FlutterBluetoothPluginPlatform.getAdapterInfo]。
  ///
  /// 参数、默认值、平台差异和推荐值见平台接口文档。
  @override
  Future<BluetoothAdapterInfo> getAdapterInfo() async {
    return const BluetoothAdapterInfo(
      isSupported: false,
      state: BluetoothAdapterState.unsupported,
    );
  }

  /// 实现 [FlutterBluetoothPluginPlatform.isScanning]。
  ///
  /// 参数、默认值、平台差异和推荐值见平台接口文档。
  @override
  Future<bool> isScanning() async => false;

  /// 实现 [FlutterBluetoothPluginPlatform.setAdapterName]。
  ///
  /// 参数、默认值、平台差异和推荐值见平台接口文档。
  @override
  Future<bool> setAdapterName(String name) async => false;

  /// 实现 [FlutterBluetoothPluginPlatform.adapterState]。
  ///
  /// 参数、默认值、平台差异和推荐值见平台接口文档。
  @override
  Stream<BluetoothAdapterState> get adapterState {
    return Stream<BluetoothAdapterState>.value(
      BluetoothAdapterState.unsupported,
    );
  }

  /// 实现 [FlutterBluetoothPluginPlatform.checkPermissions]。
  ///
  /// 参数、默认值、平台差异和推荐值见平台接口文档。
  @override
  Future<Map<String, BluetoothPermissionStatus>> checkPermissions() async {
    return const <String, BluetoothPermissionStatus>{
      'bluetooth': BluetoothPermissionStatus.notApplicable,
    };
  }

  /// 实现 [FlutterBluetoothPluginPlatform.requestPermissions]。
  ///
  /// 参数、默认值、平台差异和推荐值见平台接口文档。
  @override
  Future<Map<String, BluetoothPermissionStatus>> requestPermissions() {
    return checkPermissions();
  }

  /// 实现 [FlutterBluetoothPluginPlatform.requestEnable]。
  ///
  /// 参数、默认值、平台差异和推荐值见平台接口文档。
  @override
  Future<bool> requestEnable() async => false;

  /// 实现 [FlutterBluetoothPluginPlatform.openBluetoothSettings]。
  ///
  /// 参数、默认值、平台差异和推荐值见平台接口文档。
  @override
  Future<void> openBluetoothSettings() async {}

  /// 实现 [FlutterBluetoothPluginPlatform.startScan]。
  ///
  /// 参数、默认值、平台差异和推荐值见平台接口文档。
  @override
  Future<void> startScan({
    List<String> serviceUuids = const <String>[],
    Duration? timeout,
    bool allowDuplicates = false,
    BluetoothScanMode scanMode = BluetoothScanMode.ble,
  }) {
    throw UnsupportedError('Bluetooth scanning is not implemented for web.');
  }

  /// 实现 [FlutterBluetoothPluginPlatform.stopScan]。
  ///
  /// 参数、默认值、平台差异和推荐值见平台接口文档。
  @override
  Future<void> stopScan() async {}

  /// 实现 [FlutterBluetoothPluginPlatform.scanResults]。
  ///
  /// 参数、默认值、平台差异和推荐值见平台接口文档。
  @override
  Stream<BluetoothScanResult> get scanResults =>
      const Stream<BluetoothScanResult>.empty();

  /// 实现 [FlutterBluetoothPluginPlatform.getBondedDevices]。
  ///
  /// 参数、默认值、平台差异和推荐值见平台接口文档。
  @override
  Future<List<BluetoothDevice>> getBondedDevices() async =>
      const <BluetoothDevice>[];

  /// 实现 [FlutterBluetoothPluginPlatform.getConnectedDevices]。
  ///
  /// 参数、默认值、平台差异和推荐值见平台接口文档。
  @override
  Future<List<BluetoothDevice>> getConnectedDevices({
    List<String> serviceUuids = const <String>[],
  }) async {
    return const <BluetoothDevice>[];
  }

  /// 实现 [FlutterBluetoothPluginPlatform.getDevice]。
  ///
  /// 参数、默认值、平台差异和推荐值见平台接口文档。
  @override
  Future<BluetoothDevice?> getDevice(String deviceId) async => null;

  /// 实现 [FlutterBluetoothPluginPlatform.getDevices]。
  ///
  /// 参数、默认值、平台差异和推荐值见平台接口文档。
  @override
  Future<List<BluetoothDevice>> getDevices(List<String> deviceIds) async {
    return const <BluetoothDevice>[];
  }

  /// 实现 [FlutterBluetoothPluginPlatform.connect]。
  ///
  /// 参数、默认值、平台差异和推荐值见平台接口文档。
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

  /// 实现 [FlutterBluetoothPluginPlatform.disconnect]。
  ///
  /// 参数、默认值、平台差异和推荐值见平台接口文档。
  @override
  Future<void> disconnect(String deviceId) async {}

  /// 实现 [FlutterBluetoothPluginPlatform.getConnectionState]。
  ///
  /// 参数、默认值、平台差异和推荐值见平台接口文档。
  @override
  Future<BluetoothConnectionState> getConnectionState(String deviceId) async {
    return BluetoothConnectionState.disconnected;
  }

  /// 实现 [FlutterBluetoothPluginPlatform.connectionState]。
  ///
  /// 参数、默认值、平台差异和推荐值见平台接口文档。
  @override
  Stream<BluetoothConnectionStateEvent> get connectionState {
    return const Stream<BluetoothConnectionStateEvent>.empty();
  }

  /// 实现 [FlutterBluetoothPluginPlatform.discoverServices]。
  ///
  /// 参数、默认值、平台差异和推荐值见平台接口文档。
  @override
  Future<List<BluetoothGattService>> discoverServices(String deviceId) {
    throw UnsupportedError(
      'GATT service discovery is not implemented for web.',
    );
  }

  /// 实现 [FlutterBluetoothPluginPlatform.readCharacteristic]。
  ///
  /// 参数、默认值、平台差异和推荐值见平台接口文档。
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

  /// 实现 [FlutterBluetoothPluginPlatform.writeCharacteristic]。
  ///
  /// 参数、默认值、平台差异和推荐值见平台接口文档。
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

  /// 实现 [FlutterBluetoothPluginPlatform.setCharacteristicNotification]。
  ///
  /// 参数、默认值、平台差异和推荐值见平台接口文档。
  @override
  Future<void> setCharacteristicNotification({
    required String deviceId,
    required String serviceUuid,
    required String characteristicUuid,
    required bool enable,
  }) {
    throw UnsupportedError('GATT notifications are not implemented for web.');
  }

  /// 实现 [FlutterBluetoothPluginPlatform.characteristicValues]。
  ///
  /// 参数、默认值、平台差异和推荐值见平台接口文档。
  @override
  Stream<BluetoothCharacteristicValue> get characteristicValues {
    return const Stream<BluetoothCharacteristicValue>.empty();
  }

  /// 实现 [FlutterBluetoothPluginPlatform.readDescriptor]。
  ///
  /// 参数、默认值、平台差异和推荐值见平台接口文档。
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

  /// 实现 [FlutterBluetoothPluginPlatform.writeDescriptor]。
  ///
  /// 参数、默认值、平台差异和推荐值见平台接口文档。
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

  /// 实现 [FlutterBluetoothPluginPlatform.descriptorValues]。
  ///
  /// 参数、默认值、平台差异和推荐值见平台接口文档。
  @override
  Stream<BluetoothDescriptorValue> get descriptorValues {
    return const Stream<BluetoothDescriptorValue>.empty();
  }

  /// 实现 [FlutterBluetoothPluginPlatform.readRssi]。
  ///
  /// 参数、默认值、平台差异和推荐值见平台接口文档。
  @override
  Future<int> readRssi(String deviceId) {
    throw UnsupportedError('RSSI reads are not implemented for web.');
  }

  /// 实现 [FlutterBluetoothPluginPlatform.rssiUpdates]。
  ///
  /// 参数、默认值、平台差异和推荐值见平台接口文档。
  @override
  Stream<BluetoothRssiEvent> get rssiUpdates =>
      const Stream<BluetoothRssiEvent>.empty();

  /// 实现 [FlutterBluetoothPluginPlatform.requestMtu]。
  ///
  /// 参数、默认值、平台差异和推荐值见平台接口文档。
  @override
  Future<int> requestMtu(String deviceId, int mtu) async => 0;

  /// 实现 [FlutterBluetoothPluginPlatform.getMaximumWriteLength]。
  ///
  /// 参数、默认值、平台差异和推荐值见平台接口文档。
  @override
  Future<int> getMaximumWriteLength(
    String deviceId, {
    bool withoutResponse = true,
  }) async {
    return 0;
  }

  /// 实现 [FlutterBluetoothPluginPlatform.mtuUpdates]。
  ///
  /// 参数、默认值、平台差异和推荐值见平台接口文档。
  @override
  Stream<BluetoothMtuEvent> get mtuUpdates =>
      const Stream<BluetoothMtuEvent>.empty();

  /// 实现 [FlutterBluetoothPluginPlatform.setPreferredPhy]。
  ///
  /// 参数、默认值、平台差异和推荐值见平台接口文档。
  @override
  Future<void> setPreferredPhy({
    required String deviceId,
    required BluetoothPhy txPhy,
    required BluetoothPhy rxPhy,
    int phyOptions = 0,
  }) {
    throw UnsupportedError('LE PHY APIs are not implemented for web.');
  }

  /// 实现 [FlutterBluetoothPluginPlatform.readPhy]。
  ///
  /// 参数、默认值、平台差异和推荐值见平台接口文档。
  @override
  Future<BluetoothPhyEvent> readPhy(String deviceId) async {
    return BluetoothPhyEvent(
      deviceId: deviceId,
      txPhy: BluetoothPhy.unknown,
      rxPhy: BluetoothPhy.unknown,
    );
  }

  /// 实现 [FlutterBluetoothPluginPlatform.phyUpdates]。
  ///
  /// 参数、默认值、平台差异和推荐值见平台接口文档。
  @override
  Stream<BluetoothPhyEvent> get phyUpdates {
    return const Stream<BluetoothPhyEvent>.empty();
  }

  /// 实现 [FlutterBluetoothPluginPlatform.requestConnectionPriority]。
  ///
  /// 参数、默认值、平台差异和推荐值见平台接口文档。
  @override
  Future<bool> requestConnectionPriority(
    String deviceId,
    BluetoothConnectionPriority priority,
  ) async {
    return false;
  }

  /// 实现 [FlutterBluetoothPluginPlatform.createBond]。
  ///
  /// 参数、默认值、平台差异和推荐值见平台接口文档。
  @override
  Future<bool> createBond(String deviceId) async => false;

  /// 实现 [FlutterBluetoothPluginPlatform.removeBond]。
  ///
  /// 参数、默认值、平台差异和推荐值见平台接口文档。
  @override
  Future<bool> removeBond(String deviceId) async => false;

  /// 实现 [FlutterBluetoothPluginPlatform.bondState]。
  ///
  /// 参数、默认值、平台差异和推荐值见平台接口文档。
  @override
  Stream<BluetoothBondStateEvent> get bondState {
    return const Stream<BluetoothBondStateEvent>.empty();
  }

  /// 实现 [FlutterBluetoothPluginPlatform.isPeripheralSupported]。
  ///
  /// 参数、默认值、平台差异和推荐值见平台接口文档。
  @override
  Future<bool> isPeripheralSupported() async => false;

  /// 实现 [FlutterBluetoothPluginPlatform.startAdvertising]。
  ///
  /// 参数、默认值、平台差异和推荐值见平台接口文档。
  @override
  Future<void> startAdvertising({
    BluetoothAdvertisementData advertisementData =
        const BluetoothAdvertisementData(),
    BluetoothAdvertisementData? scanResponse,
    BluetoothAdvertisingSettings settings =
        const BluetoothAdvertisingSettings(),
  }) {
    throw UnsupportedError('BLE advertising is not implemented for web.');
  }

  /// 实现 [FlutterBluetoothPluginPlatform.stopAdvertising]。
  ///
  /// 参数、默认值、平台差异和推荐值见平台接口文档。
  @override
  Future<void> stopAdvertising() async {}

  /// 实现 [FlutterBluetoothPluginPlatform.advertisingState]。
  ///
  /// 参数、默认值、平台差异和推荐值见平台接口文档。
  @override
  Stream<BluetoothAdvertisingStateEvent> get advertisingState {
    return const Stream<BluetoothAdvertisingStateEvent>.empty();
  }

  /// 实现 [FlutterBluetoothPluginPlatform.setGattServerServices]。
  ///
  /// 参数、默认值、平台差异和推荐值见平台接口文档。
  @override
  Future<void> setGattServerServices(List<BluetoothGattService> services) {
    throw UnsupportedError('GATT server APIs are not implemented for web.');
  }

  /// 实现 [FlutterBluetoothPluginPlatform.clearGattServerServices]。
  ///
  /// 参数、默认值、平台差异和推荐值见平台接口文档。
  @override
  Future<void> clearGattServerServices() async {}

  /// 实现 [FlutterBluetoothPluginPlatform.updateLocalCharacteristicValue]。
  ///
  /// 参数、默认值、平台差异和推荐值见平台接口文档。
  @override
  Future<void> updateLocalCharacteristicValue({
    required String serviceUuid,
    required String characteristicUuid,
    required List<int> value,
  }) {
    throw UnsupportedError('GATT server APIs are not implemented for web.');
  }

  /// 实现 [FlutterBluetoothPluginPlatform.notifyGattServerCharacteristic]。
  ///
  /// 参数、默认值、平台差异和推荐值见平台接口文档。
  @override
  Future<bool> notifyGattServerCharacteristic({
    String? deviceId,
    required String serviceUuid,
    required String characteristicUuid,
    required List<int> value,
    bool confirm = false,
  }) async {
    return false;
  }

  /// 实现 [FlutterBluetoothPluginPlatform.gattServerRequests]。
  ///
  /// 参数、默认值、平台差异和推荐值见平台接口文档。
  @override
  Stream<BluetoothGattServerRequest> get gattServerRequests {
    return const Stream<BluetoothGattServerRequest>.empty();
  }

  /// 实现 [FlutterBluetoothPluginPlatform.connectClassic]。
  ///
  /// 参数、默认值、平台差异和推荐值见平台接口文档。
  @override
  Future<void> connectClassic({
    required String deviceId,
    required String serviceUuid,
    bool secure = true,
    Duration? timeout,
  }) {
    throw UnsupportedError('Classic Bluetooth is not implemented for web.');
  }

  /// 实现 [FlutterBluetoothPluginPlatform.startClassicServer]。
  ///
  /// 参数、默认值、平台差异和推荐值见平台接口文档。
  @override
  Future<void> startClassicServer({
    required String serviceUuid,
    String serviceName = 'FlutterBluetoothPlugin',
    bool secure = true,
  }) {
    throw UnsupportedError('Classic Bluetooth is not implemented for web.');
  }

  /// 实现 [FlutterBluetoothPluginPlatform.stopClassicServer]。
  ///
  /// 参数、默认值、平台差异和推荐值见平台接口文档。
  @override
  Future<void> stopClassicServer() async {}

  /// 实现 [FlutterBluetoothPluginPlatform.disconnectClassic]。
  ///
  /// 参数、默认值、平台差异和推荐值见平台接口文档。
  @override
  Future<void> disconnectClassic(String deviceId) async {}

  /// 实现 [FlutterBluetoothPluginPlatform.writeClassic]。
  ///
  /// 参数、默认值、平台差异和推荐值见平台接口文档。
  @override
  Future<void> writeClassic(String deviceId, List<int> value) {
    throw UnsupportedError('Classic Bluetooth is not implemented for web.');
  }

  /// 实现 [FlutterBluetoothPluginPlatform.classicConnectionState]。
  ///
  /// 参数、默认值、平台差异和推荐值见平台接口文档。
  @override
  Stream<BluetoothClassicConnectionEvent> get classicConnectionState {
    return const Stream<BluetoothClassicConnectionEvent>.empty();
  }

  /// 实现 [FlutterBluetoothPluginPlatform.classicData]。
  ///
  /// 参数、默认值、平台差异和推荐值见平台接口文档。
  @override
  Stream<BluetoothClassicDataEvent> get classicData {
    return const Stream<BluetoothClassicDataEvent>.empty();
  }
}

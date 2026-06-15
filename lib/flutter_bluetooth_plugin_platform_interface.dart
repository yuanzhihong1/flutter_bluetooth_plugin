import 'package:plugin_platform_interface/plugin_platform_interface.dart';

import 'flutter_bluetooth_plugin_method_channel.dart';
import 'flutter_bluetooth_plugin_models.dart';

abstract class FlutterBluetoothPluginPlatform extends PlatformInterface {
  /// Constructs a FlutterBluetoothPluginPlatform.
  FlutterBluetoothPluginPlatform() : super(token: _token);

  static final Object _token = Object();

  static FlutterBluetoothPluginPlatform _instance =
      MethodChannelFlutterBluetoothPlugin();

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

  Future<bool> isSupported() {
    throw UnimplementedError('isSupported() has not been implemented.');
  }

  Future<BluetoothAdapterState> getAdapterState() {
    throw UnimplementedError('getAdapterState() has not been implemented.');
  }

  Future<BluetoothAdapterInfo> getAdapterInfo() {
    throw UnimplementedError('getAdapterInfo() has not been implemented.');
  }

  Future<bool> isScanning() {
    throw UnimplementedError('isScanning() has not been implemented.');
  }

  Future<bool> setAdapterName(String name) {
    throw UnimplementedError('setAdapterName() has not been implemented.');
  }

  Stream<BluetoothAdapterState> get adapterState {
    throw UnimplementedError('adapterState has not been implemented.');
  }

  Future<Map<String, BluetoothPermissionStatus>> checkPermissions() {
    throw UnimplementedError('checkPermissions() has not been implemented.');
  }

  Future<Map<String, BluetoothPermissionStatus>> requestPermissions() {
    throw UnimplementedError('requestPermissions() has not been implemented.');
  }

  Future<bool> requestEnable() {
    throw UnimplementedError('requestEnable() has not been implemented.');
  }

  Future<void> openBluetoothSettings() {
    throw UnimplementedError(
      'openBluetoothSettings() has not been implemented.',
    );
  }

  Future<void> startScan({
    List<String> serviceUuids = const <String>[],
    Duration? timeout,
    bool allowDuplicates = false,
    BluetoothScanMode scanMode = BluetoothScanMode.ble,
  }) {
    throw UnimplementedError('startScan() has not been implemented.');
  }

  Future<void> stopScan() {
    throw UnimplementedError('stopScan() has not been implemented.');
  }

  Stream<BluetoothScanResult> get scanResults {
    throw UnimplementedError('scanResults has not been implemented.');
  }

  Future<List<BluetoothDevice>> getBondedDevices() {
    throw UnimplementedError('getBondedDevices() has not been implemented.');
  }

  Future<List<BluetoothDevice>> getConnectedDevices({
    List<String> serviceUuids = const <String>[],
  }) {
    throw UnimplementedError('getConnectedDevices() has not been implemented.');
  }

  Future<BluetoothDevice?> getDevice(String deviceId) {
    throw UnimplementedError('getDevice() has not been implemented.');
  }

  Future<List<BluetoothDevice>> getDevices(List<String> deviceIds) {
    throw UnimplementedError('getDevices() has not been implemented.');
  }

  Future<void> connect(
    String deviceId, {
    bool autoConnect = false,
    Duration? timeout,
  }) {
    throw UnimplementedError('connect() has not been implemented.');
  }

  Future<void> disconnect(String deviceId) {
    throw UnimplementedError('disconnect() has not been implemented.');
  }

  Future<BluetoothConnectionState> getConnectionState(String deviceId) {
    throw UnimplementedError('getConnectionState() has not been implemented.');
  }

  Stream<BluetoothConnectionStateEvent> get connectionState {
    throw UnimplementedError('connectionState has not been implemented.');
  }

  Future<List<BluetoothGattService>> discoverServices(String deviceId) {
    throw UnimplementedError('discoverServices() has not been implemented.');
  }

  Future<List<int>> readCharacteristic({
    required String deviceId,
    required String serviceUuid,
    required String characteristicUuid,
  }) {
    throw UnimplementedError('readCharacteristic() has not been implemented.');
  }

  Future<void> writeCharacteristic({
    required String deviceId,
    required String serviceUuid,
    required String characteristicUuid,
    required List<int> value,
    BluetoothWriteType writeType = BluetoothWriteType.withResponse,
  }) {
    throw UnimplementedError('writeCharacteristic() has not been implemented.');
  }

  Future<void> setCharacteristicNotification({
    required String deviceId,
    required String serviceUuid,
    required String characteristicUuid,
    required bool enable,
  }) {
    throw UnimplementedError(
      'setCharacteristicNotification() has not been implemented.',
    );
  }

  Stream<BluetoothCharacteristicValue> get characteristicValues {
    throw UnimplementedError('characteristicValues has not been implemented.');
  }

  Future<List<int>> readDescriptor({
    required String deviceId,
    required String serviceUuid,
    required String characteristicUuid,
    required String descriptorUuid,
  }) {
    throw UnimplementedError('readDescriptor() has not been implemented.');
  }

  Future<void> writeDescriptor({
    required String deviceId,
    required String serviceUuid,
    required String characteristicUuid,
    required String descriptorUuid,
    required List<int> value,
  }) {
    throw UnimplementedError('writeDescriptor() has not been implemented.');
  }

  Stream<BluetoothDescriptorValue> get descriptorValues {
    throw UnimplementedError('descriptorValues has not been implemented.');
  }

  Future<int> readRssi(String deviceId) {
    throw UnimplementedError('readRssi() has not been implemented.');
  }

  Stream<BluetoothRssiEvent> get rssiUpdates {
    throw UnimplementedError('rssiUpdates has not been implemented.');
  }

  Future<int> requestMtu(String deviceId, int mtu) {
    throw UnimplementedError('requestMtu() has not been implemented.');
  }

  Future<int> getMaximumWriteLength(
    String deviceId, {
    bool withoutResponse = true,
  }) {
    throw UnimplementedError(
      'getMaximumWriteLength() has not been implemented.',
    );
  }

  Stream<BluetoothMtuEvent> get mtuUpdates {
    throw UnimplementedError('mtuUpdates has not been implemented.');
  }

  Future<void> setPreferredPhy({
    required String deviceId,
    required BluetoothPhy txPhy,
    required BluetoothPhy rxPhy,
    int phyOptions = 0,
  }) {
    throw UnimplementedError('setPreferredPhy() has not been implemented.');
  }

  Future<BluetoothPhyEvent> readPhy(String deviceId) {
    throw UnimplementedError('readPhy() has not been implemented.');
  }

  Stream<BluetoothPhyEvent> get phyUpdates {
    throw UnimplementedError('phyUpdates has not been implemented.');
  }

  Future<bool> requestConnectionPriority(
    String deviceId,
    BluetoothConnectionPriority priority,
  ) {
    throw UnimplementedError(
      'requestConnectionPriority() has not been implemented.',
    );
  }

  Future<bool> createBond(String deviceId) {
    throw UnimplementedError('createBond() has not been implemented.');
  }

  Future<bool> removeBond(String deviceId) {
    throw UnimplementedError('removeBond() has not been implemented.');
  }

  Stream<BluetoothBondStateEvent> get bondState {
    throw UnimplementedError('bondState has not been implemented.');
  }

  Future<bool> isPeripheralSupported() {
    throw UnimplementedError(
      'isPeripheralSupported() has not been implemented.',
    );
  }

  Future<void> startAdvertising({
    BluetoothAdvertisementData advertisementData =
        const BluetoothAdvertisementData(),
    BluetoothAdvertisementData? scanResponse,
    BluetoothAdvertisingSettings settings =
        const BluetoothAdvertisingSettings(),
  }) {
    throw UnimplementedError('startAdvertising() has not been implemented.');
  }

  Future<void> stopAdvertising() {
    throw UnimplementedError('stopAdvertising() has not been implemented.');
  }

  Stream<BluetoothAdvertisingStateEvent> get advertisingState {
    throw UnimplementedError('advertisingState has not been implemented.');
  }

  Future<void> setGattServerServices(List<BluetoothGattService> services) {
    throw UnimplementedError(
      'setGattServerServices() has not been implemented.',
    );
  }

  Future<void> clearGattServerServices() {
    throw UnimplementedError(
      'clearGattServerServices() has not been implemented.',
    );
  }

  Future<void> updateLocalCharacteristicValue({
    required String serviceUuid,
    required String characteristicUuid,
    required List<int> value,
  }) {
    throw UnimplementedError(
      'updateLocalCharacteristicValue() has not been implemented.',
    );
  }

  Future<bool> notifyGattServerCharacteristic({
    String? deviceId,
    required String serviceUuid,
    required String characteristicUuid,
    required List<int> value,
    bool confirm = false,
  }) {
    throw UnimplementedError(
      'notifyGattServerCharacteristic() has not been implemented.',
    );
  }

  Stream<BluetoothGattServerRequest> get gattServerRequests {
    throw UnimplementedError('gattServerRequests has not been implemented.');
  }

  Future<void> connectClassic({
    required String deviceId,
    required String serviceUuid,
    bool secure = true,
    Duration? timeout,
  }) {
    throw UnimplementedError('connectClassic() has not been implemented.');
  }

  Future<void> startClassicServer({
    required String serviceUuid,
    String serviceName = 'FlutterBluetoothPlugin',
    bool secure = true,
  }) {
    throw UnimplementedError('startClassicServer() has not been implemented.');
  }

  Future<void> stopClassicServer() {
    throw UnimplementedError('stopClassicServer() has not been implemented.');
  }

  Future<void> disconnectClassic(String deviceId) {
    throw UnimplementedError('disconnectClassic() has not been implemented.');
  }

  Future<void> writeClassic(String deviceId, List<int> value) {
    throw UnimplementedError('writeClassic() has not been implemented.');
  }

  Stream<BluetoothClassicConnectionEvent> get classicConnectionState {
    throw UnimplementedError(
      'classicConnectionState has not been implemented.',
    );
  }

  Stream<BluetoothClassicDataEvent> get classicData {
    throw UnimplementedError('classicData has not been implemented.');
  }
}

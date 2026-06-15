import 'flutter_bluetooth_plugin_models.dart';
import 'flutter_bluetooth_plugin_platform_interface.dart';

export 'flutter_bluetooth_plugin_models.dart';

class FlutterBluetoothPlugin {
  const FlutterBluetoothPlugin();

  FlutterBluetoothPluginPlatform get _platform =>
      FlutterBluetoothPluginPlatform.instance;

  Future<String?> getPlatformVersion() {
    return _platform.getPlatformVersion();
  }

  Future<bool> isSupported() {
    return _platform.isSupported();
  }

  Future<BluetoothAdapterState> getAdapterState() {
    return _platform.getAdapterState();
  }

  Stream<BluetoothAdapterState> get adapterState => _platform.adapterState;

  Future<Map<String, BluetoothPermissionStatus>> checkPermissions() {
    return _platform.checkPermissions();
  }

  Future<Map<String, BluetoothPermissionStatus>> requestPermissions() {
    return _platform.requestPermissions();
  }

  Future<bool> requestEnable() {
    return _platform.requestEnable();
  }

  Future<void> openBluetoothSettings() {
    return _platform.openBluetoothSettings();
  }

  Future<void> startScan({
    List<String> serviceUuids = const <String>[],
    Duration? timeout,
    bool allowDuplicates = false,
    BluetoothScanMode scanMode = BluetoothScanMode.ble,
  }) {
    return _platform.startScan(
      serviceUuids: serviceUuids,
      timeout: timeout,
      allowDuplicates: allowDuplicates,
      scanMode: scanMode,
    );
  }

  Future<void> stopScan() {
    return _platform.stopScan();
  }

  Stream<BluetoothScanResult> get scanResults => _platform.scanResults;

  Future<List<BluetoothDevice>> getBondedDevices() {
    return _platform.getBondedDevices();
  }

  Future<List<BluetoothDevice>> getConnectedDevices({
    List<String> serviceUuids = const <String>[],
  }) {
    return _platform.getConnectedDevices(serviceUuids: serviceUuids);
  }

  Future<void> connect(
    String deviceId, {
    bool autoConnect = false,
    Duration? timeout,
  }) {
    return _platform.connect(
      deviceId,
      autoConnect: autoConnect,
      timeout: timeout,
    );
  }

  Future<void> disconnect(String deviceId) {
    return _platform.disconnect(deviceId);
  }

  Future<BluetoothConnectionState> getConnectionState(String deviceId) {
    return _platform.getConnectionState(deviceId);
  }

  Stream<BluetoothConnectionStateEvent> get connectionState =>
      _platform.connectionState;

  Future<List<BluetoothGattService>> discoverServices(String deviceId) {
    return _platform.discoverServices(deviceId);
  }

  Future<List<int>> readCharacteristic({
    required String deviceId,
    required String serviceUuid,
    required String characteristicUuid,
  }) {
    return _platform.readCharacteristic(
      deviceId: deviceId,
      serviceUuid: serviceUuid,
      characteristicUuid: characteristicUuid,
    );
  }

  Future<void> writeCharacteristic({
    required String deviceId,
    required String serviceUuid,
    required String characteristicUuid,
    required List<int> value,
    BluetoothWriteType writeType = BluetoothWriteType.withResponse,
  }) {
    return _platform.writeCharacteristic(
      deviceId: deviceId,
      serviceUuid: serviceUuid,
      characteristicUuid: characteristicUuid,
      value: value,
      writeType: writeType,
    );
  }

  Future<void> setCharacteristicNotification({
    required String deviceId,
    required String serviceUuid,
    required String characteristicUuid,
    required bool enable,
  }) {
    return _platform.setCharacteristicNotification(
      deviceId: deviceId,
      serviceUuid: serviceUuid,
      characteristicUuid: characteristicUuid,
      enable: enable,
    );
  }

  Stream<BluetoothCharacteristicValue> get characteristicValues {
    return _platform.characteristicValues;
  }

  Future<List<int>> readDescriptor({
    required String deviceId,
    required String serviceUuid,
    required String characteristicUuid,
    required String descriptorUuid,
  }) {
    return _platform.readDescriptor(
      deviceId: deviceId,
      serviceUuid: serviceUuid,
      characteristicUuid: characteristicUuid,
      descriptorUuid: descriptorUuid,
    );
  }

  Future<void> writeDescriptor({
    required String deviceId,
    required String serviceUuid,
    required String characteristicUuid,
    required String descriptorUuid,
    required List<int> value,
  }) {
    return _platform.writeDescriptor(
      deviceId: deviceId,
      serviceUuid: serviceUuid,
      characteristicUuid: characteristicUuid,
      descriptorUuid: descriptorUuid,
      value: value,
    );
  }

  Stream<BluetoothDescriptorValue> get descriptorValues =>
      _platform.descriptorValues;

  Future<int> readRssi(String deviceId) {
    return _platform.readRssi(deviceId);
  }

  Stream<BluetoothRssiEvent> get rssiUpdates => _platform.rssiUpdates;

  Future<int> requestMtu(String deviceId, int mtu) {
    return _platform.requestMtu(deviceId, mtu);
  }

  Stream<BluetoothMtuEvent> get mtuUpdates => _platform.mtuUpdates;

  Future<bool> requestConnectionPriority(
    String deviceId,
    BluetoothConnectionPriority priority,
  ) {
    return _platform.requestConnectionPriority(deviceId, priority);
  }

  Future<bool> createBond(String deviceId) {
    return _platform.createBond(deviceId);
  }

  Future<bool> removeBond(String deviceId) {
    return _platform.removeBond(deviceId);
  }

  Stream<BluetoothBondStateEvent> get bondState => _platform.bondState;
}

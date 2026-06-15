import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'flutter_bluetooth_plugin_models.dart';
import 'flutter_bluetooth_plugin_platform_interface.dart';

/// An implementation of [FlutterBluetoothPluginPlatform] that uses method channels.
class MethodChannelFlutterBluetoothPlugin
    extends FlutterBluetoothPluginPlatform {
  /// The method channel used to interact with the native platform.
  @visibleForTesting
  final methodChannel = const MethodChannel('flutter_bluetooth_plugin');

  /// The event channel used for scans, state changes, notifications, RSSI, and MTU updates.
  @visibleForTesting
  final eventChannel = const EventChannel('flutter_bluetooth_plugin/events');

  Stream<Map<String, dynamic>>? _events;

  Stream<Map<String, dynamic>> get _eventStream {
    _events ??= eventChannel.receiveBroadcastStream().map((Object? event) {
      return Map<String, dynamic>.from(event as Map<dynamic, dynamic>);
    }).asBroadcastStream();
    return _events!;
  }

  @override
  Future<String?> getPlatformVersion() async {
    final version = await methodChannel.invokeMethod<String>(
      'getPlatformVersion',
    );
    return version;
  }

  @override
  Future<bool> isSupported() async {
    return await methodChannel.invokeMethod<bool>('isSupported') ?? false;
  }

  @override
  Future<BluetoothAdapterState> getAdapterState() async {
    final state = await methodChannel.invokeMethod<String>('getAdapterState');
    return bluetoothAdapterStateFromString(state);
  }

  @override
  Future<BluetoothAdapterInfo> getAdapterInfo() async {
    final response = await methodChannel.invokeMapMethod<String, dynamic>(
      'getAdapterInfo',
    );
    return BluetoothAdapterInfo.fromMap(response ?? <String, dynamic>{});
  }

  @override
  Future<bool> isScanning() async {
    return await methodChannel.invokeMethod<bool>('isScanning') ?? false;
  }

  @override
  Future<bool> setAdapterName(String name) async {
    return await methodChannel.invokeMethod<bool>(
          'setAdapterName',
          <String, dynamic>{'name': name},
        ) ??
        false;
  }

  @override
  Stream<BluetoothAdapterState> get adapterState {
    return _eventStream
        .where((event) => event['type'] == 'adapterState')
        .map(
          (event) =>
              bluetoothAdapterStateFromString(event['state']?.toString()),
        );
  }

  @override
  Future<Map<String, BluetoothPermissionStatus>> checkPermissions() async {
    final response = await methodChannel.invokeMapMethod<String, dynamic>(
      'checkPermissions',
    );
    return _permissionMapFromPlatform(response);
  }

  @override
  Future<Map<String, BluetoothPermissionStatus>> requestPermissions() async {
    final response = await methodChannel.invokeMapMethod<String, dynamic>(
      'requestPermissions',
    );
    return _permissionMapFromPlatform(response);
  }

  @override
  Future<bool> requestEnable() async {
    return await methodChannel.invokeMethod<bool>('requestEnable') ?? false;
  }

  @override
  Future<void> openBluetoothSettings() async {
    await methodChannel.invokeMethod<void>('openBluetoothSettings');
  }

  @override
  Future<void> startScan({
    List<String> serviceUuids = const <String>[],
    Duration? timeout,
    bool allowDuplicates = false,
    BluetoothScanMode scanMode = BluetoothScanMode.ble,
  }) async {
    await methodChannel.invokeMethod<void>('startScan', <String, dynamic>{
      'serviceUuids': serviceUuids,
      'timeoutMs': timeout?.inMilliseconds,
      'allowDuplicates': allowDuplicates,
      'scanMode': scanMode.name,
    });
  }

  @override
  Future<void> stopScan() async {
    await methodChannel.invokeMethod<void>('stopScan');
  }

  @override
  Stream<BluetoothScanResult> get scanResults {
    return _eventStream
        .where((event) => event['type'] == 'scanResult')
        .map(BluetoothScanResult.fromMap);
  }

  @override
  Future<List<BluetoothDevice>> getBondedDevices() async {
    final response = await methodChannel.invokeListMethod<dynamic>(
      'getBondedDevices',
    );
    return _deviceListFromPlatform(response);
  }

  @override
  Future<List<BluetoothDevice>> getConnectedDevices({
    List<String> serviceUuids = const <String>[],
  }) async {
    final response = await methodChannel.invokeListMethod<dynamic>(
      'getConnectedDevices',
      <String, dynamic>{'serviceUuids': serviceUuids},
    );
    return _deviceListFromPlatform(response);
  }

  @override
  Future<BluetoothDevice?> getDevice(String deviceId) async {
    final response = await methodChannel.invokeMapMethod<String, dynamic>(
      'getDevice',
      <String, dynamic>{'deviceId': deviceId},
    );
    if (response == null || response.isEmpty) {
      return null;
    }
    return BluetoothDevice.fromMap(response);
  }

  @override
  Future<List<BluetoothDevice>> getDevices(List<String> deviceIds) async {
    final response = await methodChannel.invokeListMethod<dynamic>(
      'getDevices',
      <String, dynamic>{'deviceIds': deviceIds},
    );
    return _deviceListFromPlatform(response);
  }

  @override
  Future<void> connect(
    String deviceId, {
    bool autoConnect = false,
    Duration? timeout,
  }) async {
    await methodChannel.invokeMethod<void>('connect', <String, dynamic>{
      'deviceId': deviceId,
      'autoConnect': autoConnect,
      'timeoutMs': timeout?.inMilliseconds,
    });
  }

  @override
  Future<void> disconnect(String deviceId) async {
    await methodChannel.invokeMethod<void>('disconnect', <String, dynamic>{
      'deviceId': deviceId,
    });
  }

  @override
  Future<BluetoothConnectionState> getConnectionState(String deviceId) async {
    final state = await methodChannel.invokeMethod<String>(
      'getConnectionState',
      <String, dynamic>{'deviceId': deviceId},
    );
    return bluetoothConnectionStateFromString(state);
  }

  @override
  Stream<BluetoothConnectionStateEvent> get connectionState {
    return _eventStream
        .where((event) => event['type'] == 'connectionState')
        .map(BluetoothConnectionStateEvent.fromMap);
  }

  @override
  Future<List<BluetoothGattService>> discoverServices(String deviceId) async {
    final response = await methodChannel.invokeListMethod<dynamic>(
      'discoverServices',
      <String, dynamic>{'deviceId': deviceId},
    );
    return (response ?? const <dynamic>[])
        .map((item) => BluetoothGattService.fromMap(_asStringMap(item)))
        .toList(growable: false);
  }

  @override
  Future<List<int>> readCharacteristic({
    required String deviceId,
    required String serviceUuid,
    required String characteristicUuid,
  }) async {
    final response = await methodChannel
        .invokeListMethod<dynamic>('readCharacteristic', <String, dynamic>{
          'deviceId': deviceId,
          'serviceUuid': serviceUuid,
          'characteristicUuid': characteristicUuid,
        });
    return _byteListFromPlatform(response);
  }

  @override
  Future<void> writeCharacteristic({
    required String deviceId,
    required String serviceUuid,
    required String characteristicUuid,
    required List<int> value,
    BluetoothWriteType writeType = BluetoothWriteType.withResponse,
  }) async {
    await methodChannel
        .invokeMethod<void>('writeCharacteristic', <String, dynamic>{
          'deviceId': deviceId,
          'serviceUuid': serviceUuid,
          'characteristicUuid': characteristicUuid,
          'value': value,
          'writeType': writeType.name,
        });
  }

  @override
  Future<void> setCharacteristicNotification({
    required String deviceId,
    required String serviceUuid,
    required String characteristicUuid,
    required bool enable,
  }) async {
    await methodChannel
        .invokeMethod<void>('setCharacteristicNotification', <String, dynamic>{
          'deviceId': deviceId,
          'serviceUuid': serviceUuid,
          'characteristicUuid': characteristicUuid,
          'enable': enable,
        });
  }

  @override
  Stream<BluetoothCharacteristicValue> get characteristicValues {
    return _eventStream
        .where((event) => event['type'] == 'characteristicValue')
        .map(BluetoothCharacteristicValue.fromMap);
  }

  @override
  Future<List<int>> readDescriptor({
    required String deviceId,
    required String serviceUuid,
    required String characteristicUuid,
    required String descriptorUuid,
  }) async {
    final response = await methodChannel
        .invokeListMethod<dynamic>('readDescriptor', <String, dynamic>{
          'deviceId': deviceId,
          'serviceUuid': serviceUuid,
          'characteristicUuid': characteristicUuid,
          'descriptorUuid': descriptorUuid,
        });
    return _byteListFromPlatform(response);
  }

  @override
  Future<void> writeDescriptor({
    required String deviceId,
    required String serviceUuid,
    required String characteristicUuid,
    required String descriptorUuid,
    required List<int> value,
  }) async {
    await methodChannel.invokeMethod<void>('writeDescriptor', <String, dynamic>{
      'deviceId': deviceId,
      'serviceUuid': serviceUuid,
      'characteristicUuid': characteristicUuid,
      'descriptorUuid': descriptorUuid,
      'value': value,
    });
  }

  @override
  Stream<BluetoothDescriptorValue> get descriptorValues {
    return _eventStream
        .where((event) => event['type'] == 'descriptorValue')
        .map(BluetoothDescriptorValue.fromMap);
  }

  @override
  Future<int> readRssi(String deviceId) async {
    return await methodChannel.invokeMethod<int>('readRssi', <String, dynamic>{
          'deviceId': deviceId,
        }) ??
        0;
  }

  @override
  Stream<BluetoothRssiEvent> get rssiUpdates {
    return _eventStream
        .where((event) => event['type'] == 'rssi')
        .map(BluetoothRssiEvent.fromMap);
  }

  @override
  Future<int> requestMtu(String deviceId, int mtu) async {
    return await methodChannel.invokeMethod<int>(
          'requestMtu',
          <String, dynamic>{'deviceId': deviceId, 'mtu': mtu},
        ) ??
        0;
  }

  @override
  Future<int> getMaximumWriteLength(
    String deviceId, {
    bool withoutResponse = true,
  }) async {
    return await methodChannel.invokeMethod<int>(
          'getMaximumWriteLength',
          <String, dynamic>{
            'deviceId': deviceId,
            'withoutResponse': withoutResponse,
          },
        ) ??
        0;
  }

  @override
  Stream<BluetoothMtuEvent> get mtuUpdates {
    return _eventStream
        .where((event) => event['type'] == 'mtu')
        .map(BluetoothMtuEvent.fromMap);
  }

  @override
  Future<void> setPreferredPhy({
    required String deviceId,
    required BluetoothPhy txPhy,
    required BluetoothPhy rxPhy,
    int phyOptions = 0,
  }) async {
    await methodChannel.invokeMethod<void>('setPreferredPhy', <String, dynamic>{
      'deviceId': deviceId,
      'txPhy': txPhy.name,
      'rxPhy': rxPhy.name,
      'phyOptions': phyOptions,
    });
  }

  @override
  Future<BluetoothPhyEvent> readPhy(String deviceId) async {
    final response = await methodChannel.invokeMapMethod<String, dynamic>(
      'readPhy',
      <String, dynamic>{'deviceId': deviceId},
    );
    return BluetoothPhyEvent.fromMap(response ?? <String, dynamic>{});
  }

  @override
  Stream<BluetoothPhyEvent> get phyUpdates {
    return _eventStream
        .where((event) => event['type'] == 'phy')
        .map(BluetoothPhyEvent.fromMap);
  }

  @override
  Future<bool> requestConnectionPriority(
    String deviceId,
    BluetoothConnectionPriority priority,
  ) async {
    return await methodChannel.invokeMethod<bool>(
          'requestConnectionPriority',
          <String, dynamic>{'deviceId': deviceId, 'priority': priority.name},
        ) ??
        false;
  }

  @override
  Future<bool> createBond(String deviceId) async {
    return await methodChannel.invokeMethod<bool>(
          'createBond',
          <String, dynamic>{'deviceId': deviceId},
        ) ??
        false;
  }

  @override
  Future<bool> removeBond(String deviceId) async {
    return await methodChannel.invokeMethod<bool>(
          'removeBond',
          <String, dynamic>{'deviceId': deviceId},
        ) ??
        false;
  }

  @override
  Stream<BluetoothBondStateEvent> get bondState {
    return _eventStream
        .where((event) => event['type'] == 'bondState')
        .map(BluetoothBondStateEvent.fromMap);
  }

  @override
  Future<bool> isPeripheralSupported() async {
    return await methodChannel.invokeMethod<bool>('isPeripheralSupported') ??
        false;
  }

  @override
  Future<void> startAdvertising({
    BluetoothAdvertisementData advertisementData =
        const BluetoothAdvertisementData(),
    BluetoothAdvertisementData? scanResponse,
    BluetoothAdvertisingSettings settings =
        const BluetoothAdvertisingSettings(),
  }) async {
    await methodChannel
        .invokeMethod<void>('startAdvertising', <String, dynamic>{
          'advertisementData': advertisementData.toMap(),
          'scanResponse': scanResponse?.toMap(),
          'settings': settings.toMap(),
        });
  }

  @override
  Future<void> stopAdvertising() async {
    await methodChannel.invokeMethod<void>('stopAdvertising');
  }

  @override
  Stream<BluetoothAdvertisingStateEvent> get advertisingState {
    return _eventStream
        .where((event) => event['type'] == 'advertisingState')
        .map(BluetoothAdvertisingStateEvent.fromMap);
  }

  @override
  Future<void> setGattServerServices(
    List<BluetoothGattService> services,
  ) async {
    await methodChannel.invokeMethod<void>(
      'setGattServerServices',
      <String, dynamic>{
        'services': services.map((service) => service.toMap()).toList(),
      },
    );
  }

  @override
  Future<void> clearGattServerServices() async {
    await methodChannel.invokeMethod<void>('clearGattServerServices');
  }

  @override
  Future<void> updateLocalCharacteristicValue({
    required String serviceUuid,
    required String characteristicUuid,
    required List<int> value,
  }) async {
    await methodChannel
        .invokeMethod<void>('updateLocalCharacteristicValue', <String, dynamic>{
          'serviceUuid': serviceUuid,
          'characteristicUuid': characteristicUuid,
          'value': value,
        });
  }

  @override
  Future<bool> notifyGattServerCharacteristic({
    String? deviceId,
    required String serviceUuid,
    required String characteristicUuid,
    required List<int> value,
    bool confirm = false,
  }) async {
    return await methodChannel.invokeMethod<bool>(
          'notifyGattServerCharacteristic',
          <String, dynamic>{
            'deviceId': deviceId,
            'serviceUuid': serviceUuid,
            'characteristicUuid': characteristicUuid,
            'value': value,
            'confirm': confirm,
          },
        ) ??
        false;
  }

  @override
  Stream<BluetoothGattServerRequest> get gattServerRequests {
    return _eventStream
        .where((event) => event['type'] == 'gattServerRequest')
        .map(BluetoothGattServerRequest.fromMap);
  }

  @override
  Future<void> connectClassic({
    required String deviceId,
    required String serviceUuid,
    bool secure = true,
    Duration? timeout,
  }) async {
    await methodChannel.invokeMethod<void>('connectClassic', <String, dynamic>{
      'deviceId': deviceId,
      'serviceUuid': serviceUuid,
      'secure': secure,
      'timeoutMs': timeout?.inMilliseconds,
    });
  }

  @override
  Future<void> startClassicServer({
    required String serviceUuid,
    String serviceName = 'FlutterBluetoothPlugin',
    bool secure = true,
  }) async {
    await methodChannel.invokeMethod<void>(
      'startClassicServer',
      <String, dynamic>{
        'serviceUuid': serviceUuid,
        'serviceName': serviceName,
        'secure': secure,
      },
    );
  }

  @override
  Future<void> stopClassicServer() async {
    await methodChannel.invokeMethod<void>('stopClassicServer');
  }

  @override
  Future<void> disconnectClassic(String deviceId) async {
    await methodChannel.invokeMethod<void>(
      'disconnectClassic',
      <String, dynamic>{'deviceId': deviceId},
    );
  }

  @override
  Future<void> writeClassic(String deviceId, List<int> value) async {
    await methodChannel.invokeMethod<void>('writeClassic', <String, dynamic>{
      'deviceId': deviceId,
      'value': value,
    });
  }

  @override
  Stream<BluetoothClassicConnectionEvent> get classicConnectionState {
    return _eventStream
        .where((event) => event['type'] == 'classicConnection')
        .map(BluetoothClassicConnectionEvent.fromMap);
  }

  @override
  Stream<BluetoothClassicDataEvent> get classicData {
    return _eventStream
        .where((event) => event['type'] == 'classicData')
        .map(BluetoothClassicDataEvent.fromMap);
  }

  Map<String, BluetoothPermissionStatus> _permissionMapFromPlatform(
    Map<String, dynamic>? response,
  ) {
    return (response ?? const <String, dynamic>{}).map(
      (key, value) =>
          MapEntry(key, bluetoothPermissionStatusFromString(value?.toString())),
    );
  }

  List<BluetoothDevice> _deviceListFromPlatform(List<dynamic>? response) {
    return (response ?? const <dynamic>[])
        .map((item) => BluetoothDevice.fromMap(_asStringMap(item)))
        .toList(growable: false);
  }

  List<int> _byteListFromPlatform(List<dynamic>? response) {
    return (response ?? const <dynamic>[])
        .map((item) => (item as num).toInt())
        .toList(growable: false);
  }

  Map<String, dynamic> _asStringMap(Object? value) {
    return Map<String, dynamic>.from(value as Map<dynamic, dynamic>);
  }
}

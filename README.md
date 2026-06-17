# flutter_bluetooth_plugin

[简体中文](README.zh-CN.md)

A Flutter Bluetooth plugin for Android, iOS, macOS, Linux, Windows, and Web.
It exposes a single Dart API for adapter state, permissions, BLE scanning,
GATT client operations, local GATT server/peripheral mode, advertising,
notifications, RSSI, MTU, PHY, bonding, Android connection priority, Android
Classic RFCOMM sockets, BlueZ, WinRT, and Web Bluetooth.

> Bluetooth APIs differ significantly by operating system. Unsupported features
> are handled consistently: safe stop/clear calls become no-ops, capability
> queries return `false`, unavailable numeric values return `0`, streams stay
> empty, and operations that cannot be represented on the platform throw an
> unsupported platform error.

## Contents

- [Platform coverage](#platform-coverage)
- [Install](#install)
- [Permissions and setup](#permissions-and-setup)
- [Quick start](#quick-start)
- [GATT client](#gatt-client)
- [Peripheral, GATT server, and advertising](#peripheral-gatt-server-and-advertising)
- [Android Classic RFCOMM](#android-classic-rfcomm)
- [API overview](#api-overview)
- [Example test app](#example-test-app)
- [Platform notes](#platform-notes)
- [License](#license)

## Platform coverage

| Feature | Android | iOS | macOS | Linux | Windows | Web |
| --- | --- | --- | --- | --- | --- | --- |
| Adapter state/info | Yes | Yes | Yes | BlueZ | WinRT | Web Bluetooth availability |
| Runtime permission helpers | Yes | Yes | Yes | DBus availability | OS availability | Permission state only |
| BLE scan/device selection | Yes | Yes | Yes | BlueZ discovery | BLE advertisements | Browser chooser |
| Connected/bonded devices | Yes | Limited | Limited | BlueZ | Paired BLE | Site-authorized devices |
| BLE GATT client | Yes | Yes | Yes | Yes | Yes | Yes, chooser-authorized services |
| Characteristic notify/indicate | Yes | Yes | Yes | Yes | Yes | Yes |
| Descriptor read/write | Yes | Yes | Yes | Yes | Yes | Yes |
| RSSI | Connected RSSI | Connected RSSI | Connected RSSI | Cached advertisement RSSI | Cached advertisement RSSI | No |
| MTU / max write length | MTU negotiation | Max write length | Max write length | No | No | No |
| PHY control | Android 8+ | No | No | No | No | No |
| Bond management | Yes | No public API | No public API | Pair/remove | No | No |
| Local GATT server | Yes | Yes | Yes | No | No | No |
| BLE advertising | Yes | Yes | Yes | No | No | No |
| Connection priority | Android only | No | No | No | No | No |
| Classic RFCOMM | Android only | No | No | No | No | No |

## Install

Add the dependency to your app:

```yaml
dependencies:
  flutter_bluetooth_plugin: ^0.0.1
```

Import the package:

```dart
import 'package:flutter_bluetooth_plugin/flutter_bluetooth_plugin.dart';
```

## Permissions and setup

Call `requestPermissions()` before scanning, connecting, or advertising:

```dart
final bluetooth = FlutterBluetoothPlugin();
final permissions = await bluetooth.requestPermissions();
final info = await bluetooth.getAdapterInfo();
```

### Android

The plugin manifest declares the Bluetooth permissions and merges them into the
host app automatically:

- Android 12+: `BLUETOOTH_SCAN`, `BLUETOOTH_CONNECT`, `BLUETOOTH_ADVERTISE`
- Android 6-11: `ACCESS_FINE_LOCATION` for scan results
- Android 11 and lower: `BLUETOOTH`, `BLUETOOTH_ADMIN`

Apps may still need to explain the permission request to users and request
runtime permissions before scanning or connecting.

### iOS

Add Bluetooth usage descriptions to the host app `Info.plist`:

```xml
<key>NSBluetoothAlwaysUsageDescription</key>
<string>This app uses Bluetooth to scan, connect, and exchange data with nearby devices.</string>
<key>NSBluetoothPeripheralUsageDescription</key>
<string>This app uses Bluetooth to communicate with nearby peripherals.</string>
```

### macOS

Add the usage description and, for sandboxed apps, the Bluetooth entitlement:

```xml
<key>NSBluetoothAlwaysUsageDescription</key>
<string>This app uses Bluetooth to scan, connect, and exchange data with nearby devices.</string>
```

```xml
<key>com.apple.security.device.bluetooth</key>
<true/>
```

### Linux

Linux support uses BlueZ over system DBus. `requestPermissions()` maps adapter
availability to a permission status; it does not show a runtime prompt.
`requestEnable()` attempts to set the BlueZ adapter `Powered` property, and
`openBluetoothSettings()` tries common desktop Bluetooth settings tools.

### Windows

Windows support uses WinRT BLE APIs. Bluetooth access is controlled by the OS;
`requestPermissions()` reports whether a BLE adapter is available, and
`openBluetoothSettings()` opens the system Bluetooth settings page.

### Web

Web Bluetooth requires HTTPS or localhost and must be triggered by a user
gesture. `requestPermissions()` cannot open a global Bluetooth prompt; call
`startScan(serviceUuids: [...])` from a button or tap handler to open the
browser device chooser. Include the GATT service UUIDs you need so the browser
also grants access to those services after connection.

## Quick start

```dart
final bluetooth = FlutterBluetoothPlugin();

await bluetooth.requestPermissions();

final state = await bluetooth.getAdapterState();
if (state != BluetoothAdapterState.poweredOn) {
  final opened = await bluetooth.requestEnable();
  if (!opened) {
    await bluetooth.openBluetoothSettings();
  }
}

final scanSub = bluetooth.scanResults.listen((result) {
  print('${result.device.id} ${result.device.name} RSSI=${result.rssi}');
});

await bluetooth.startScan(
  serviceUuids: const <String>[],
  timeout: const Duration(seconds: 10),
  allowDuplicates: false,
  scanMode: BluetoothScanMode.ble,
);

await Future<void>.delayed(const Duration(seconds: 10));
await bluetooth.stopScan();
await scanSub.cancel();
```

## GATT client

```dart
await bluetooth.connect(deviceId, timeout: const Duration(seconds: 15));

final services = await bluetooth.discoverServices(deviceId);
final characteristic = services.first.characteristics.first;

final value = await bluetooth.readCharacteristic(
  deviceId: deviceId,
  serviceUuid: characteristic.serviceUuid,
  characteristicUuid: characteristic.uuid,
);

await bluetooth.writeCharacteristic(
  deviceId: deviceId,
  serviceUuid: characteristic.serviceUuid,
  characteristicUuid: characteristic.uuid,
  value: value,
  writeType: BluetoothWriteType.withResponse,
);

await bluetooth.setCharacteristicNotification(
  deviceId: deviceId,
  serviceUuid: characteristic.serviceUuid,
  characteristicUuid: characteristic.uuid,
  enable: true,
);

final valueSub = bluetooth.characteristicValues.listen((event) {
  print('${event.characteristicUuid}: ${event.value}');
});
```

Useful connection helpers:

```dart
final connected = await bluetooth.getConnectedDevices(
  serviceUuids: const <String>[],
);
final state = await bluetooth.getConnectionState(deviceId);
final rssi = await bluetooth.readRssi(deviceId);
final mtu = await bluetooth.requestMtu(deviceId, 247);
final maxWrite = await bluetooth.getMaximumWriteLength(deviceId);
```

## Peripheral, GATT server, and advertising

```dart
const serviceUuid = '0000fff0-0000-1000-8000-00805f9b34fb';
const characteristicUuid = '0000fff1-0000-1000-8000-00805f9b34fb';

final supported = await bluetooth.isPeripheralSupported();
if (supported) {
  await bluetooth.setGattServerServices(
    const <BluetoothGattService>[
      BluetoothGattService(
        uuid: serviceUuid,
        characteristics: <BluetoothGattCharacteristic>[
          BluetoothGattCharacteristic(
            uuid: characteristicUuid,
            serviceUuid: serviceUuid,
            properties: <String>['read', 'write', 'writeWithoutResponse', 'notify'],
            permissions: <String>['read', 'write'],
            value: <int>[72, 101, 108, 108, 111],
          ),
        ],
      ),
    ],
  );

  await bluetooth.startAdvertising(
    advertisementData: const BluetoothAdvertisementData(
      localName: 'Flutter BT',
      serviceUuids: <String>[serviceUuid],
      includeDeviceName: true,
      includeTxPowerLevel: true,
    ),
    settings: const BluetoothAdvertisingSettings(
      mode: BluetoothAdvertisingMode.lowLatency,
      txPowerLevel: BluetoothTxPowerLevel.high,
      connectable: true,
    ),
  );
}

final serverSub = bluetooth.gattServerRequests.listen((event) {
  print('${event.event} ${event.deviceId} ${event.value}');
});
```

Update and notify a local characteristic:

```dart
await bluetooth.updateLocalCharacteristicValue(
  serviceUuid: serviceUuid,
  characteristicUuid: characteristicUuid,
  value: const <int>[1, 2, 3],
);

final sent = await bluetooth.notifyGattServerCharacteristic(
  serviceUuid: serviceUuid,
  characteristicUuid: characteristicUuid,
  value: const <int>[1, 2, 3],
  confirm: false,
);
```

## Android Classic RFCOMM

```dart
const sppUuid = '00001101-0000-1000-8000-00805f9b34fb';

await bluetooth.startClassicServer(
  serviceUuid: sppUuid,
  serviceName: 'FlutterBluetoothPlugin',
);

await bluetooth.connectClassic(
  deviceId: macAddress,
  serviceUuid: sppUuid,
  secure: true,
  timeout: const Duration(seconds: 15),
);

await bluetooth.writeClassic(macAddress, const <int>[1, 2, 3]);

final classicSub = bluetooth.classicData.listen((event) {
  print('classic ${event.deviceId}: ${event.value}');
});
```

## API overview

### Adapter and permissions

- `getPlatformVersion()`
- `isSupported()`
- `getAdapterState()` / `adapterState`
- `getAdapterInfo()`
- `isScanning()`
- `setAdapterName(name)`
- `checkPermissions()` / `requestPermissions()`
- `requestEnable()`
- `openBluetoothSettings()`

### Discovery and devices

- `startScan(...)` / `stopScan()` / `scanResults`
- `getBondedDevices()`
- `getConnectedDevices(serviceUuids: ...)`
- `getDevice(deviceId)`
- `getDevices(deviceIds)`

### BLE connection and GATT client

- `connect(...)` / `disconnect(deviceId)`
- `getConnectionState(deviceId)` / `connectionState`
- `discoverServices(deviceId)`
- `readCharacteristic(...)` / `writeCharacteristic(...)`
- `setCharacteristicNotification(...)` / `characteristicValues`
- `readDescriptor(...)` / `writeDescriptor(...)` / `descriptorValues`
- `readRssi(deviceId)` / `rssiUpdates`
- `requestMtu(deviceId, mtu)` / `getMaximumWriteLength(...)` / `mtuUpdates`
- `setPreferredPhy(...)` / `readPhy(deviceId)` / `phyUpdates`
- `requestConnectionPriority(deviceId, priority)`
- `createBond(deviceId)` / `removeBond(deviceId)` / `bondState`

### Peripheral, advertising, and Classic

- `isPeripheralSupported()`
- `setGattServerServices(services)` / `clearGattServerServices()`
- `startAdvertising(...)` / `stopAdvertising()` / `advertisingState`
- `updateLocalCharacteristicValue(...)`
- `notifyGattServerCharacteristic(...)`
- `gattServerRequests`
- `connectClassic(...)`
- `startClassicServer(...)` / `stopClassicServer()`
- `disconnectClassic(deviceId)`
- `writeClassic(deviceId, value)`
- `classicConnectionState` / `classicData`

## Example test app

The `example/` app is a Cupertino-based Bluetooth testing console. It is built
to exercise as many plugin APIs as possible from one screen:

- Platform, adapter, permission, scanning, and settings diagnostics
- BLE scan modes, duplicate scan events, bonded devices, connected devices, and
  device lookup helpers
- Connection state, service discovery, GATT characteristic/descriptor IO,
  notifications, RSSI, MTU, maximum write length, PHY, connection priority, and
  bonding actions
- Local GATT server setup, advertising, local value updates, notifications, and
  service cleanup
- Android Classic RFCOMM client/server socket actions
- Live event log for every plugin event stream

Run it with:

```sh
cd example
flutter run
```

## Platform notes

- iOS and macOS do not expose public Classic Bluetooth RFCOMM APIs.
- iOS, macOS, Windows, and Web cannot enable Bluetooth programmatically.
- Web Bluetooth is chooser-based and limited to site-authorized BLE devices and
  services.
- Linux support depends on BlueZ, system DBus access, and desktop Bluetooth
  tooling availability.
- Windows support currently focuses on BLE Central/GATT Client APIs.
- Android has the broadest platform API surface, including Classic RFCOMM,
  bonding, connection priority, MTU, PHY, and detailed adapter capabilities.

## License

This project is released under the [MIT License](LICENSE).

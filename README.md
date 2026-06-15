# flutter_bluetooth_plugin

A Flutter Bluetooth plugin backed by native Android and iOS APIs.

The plugin exposes a MethodChannel API for Bluetooth permissions, adapter state,
scanning, connections, GATT service discovery, characteristic and descriptor IO,
notifications, RSSI, MTU, Android bonding, and Android connection priority.

## Platform coverage

- Android: BluetoothAdapter, BluetoothLeScanner, BluetoothGatt, runtime permissions,
  Classic discovery, bonded devices, bond/unbond, RSSI, MTU, and connection priority.
- iOS: CoreBluetooth central APIs for authorization, adapter state, BLE scanning,
  peripheral connections, service discovery, characteristic/descriptor IO,
  notifications, and RSSI.
- Web: currently returns unsupported states and empty streams.

Some platform APIs do not exist publicly on both systems. iOS cannot enable
Bluetooth programmatically, does not expose Classic Bluetooth discovery/pairing
or public MTU negotiation, and does not expose Android-style connection priority.
Those APIs return `false`, empty lists, or the current iOS maximum write length.

## Permissions

Call `requestPermissions()` before scanning or connecting:

```dart
final bluetooth = FlutterBluetoothPlugin();
final permissions = await bluetooth.requestPermissions();
final state = await bluetooth.getAdapterState();
```

Android permissions are declared in the plugin manifest and merged into the host
app automatically:

- Android 12+: `BLUETOOTH_SCAN`, `BLUETOOTH_CONNECT`, `BLUETOOTH_ADVERTISE`
- Android 6-11: `ACCESS_FINE_LOCATION` for Bluetooth scan results
- Android 11 and lower: `BLUETOOTH`, `BLUETOOTH_ADMIN`

For iOS, the host app must include usage descriptions in `Info.plist`:

```xml
<key>NSBluetoothAlwaysUsageDescription</key>
<string>This app uses Bluetooth to scan, connect, and exchange data with nearby devices.</string>
<key>NSBluetoothPeripheralUsageDescription</key>
<string>This app uses Bluetooth to communicate with nearby peripherals.</string>
```

## Basic usage

```dart
final bluetooth = FlutterBluetoothPlugin();

await bluetooth.requestPermissions();

if (await bluetooth.getAdapterState() != BluetoothAdapterState.poweredOn) {
  await bluetooth.requestEnable(); // Android only; iOS returns false.
}

final sub = bluetooth.scanResults.listen((result) {
  print('${result.device.id} ${result.device.name} RSSI=${result.rssi}');
});

await bluetooth.startScan(timeout: const Duration(seconds: 10));
await Future<void>.delayed(const Duration(seconds: 10));
await bluetooth.stopScan();
await sub.cancel();
```

## GATT usage

```dart
await bluetooth.connect(deviceId, timeout: const Duration(seconds: 15));
final services = await bluetooth.discoverServices(deviceId);

final value = await bluetooth.readCharacteristic(
  deviceId: deviceId,
  serviceUuid: services.first.uuid,
  characteristicUuid: services.first.characteristics.first.uuid,
);

await bluetooth.writeCharacteristic(
  deviceId: deviceId,
  serviceUuid: services.first.uuid,
  characteristicUuid: services.first.characteristics.first.uuid,
  value: value,
);
```

Listen to streams for asynchronous native events:

- `adapterState`
- `scanResults`
- `connectionState`
- `characteristicValues`
- `descriptorValues`
- `rssiUpdates`
- `mtuUpdates`
- `bondState`

# flutter_bluetooth_plugin

A Flutter Bluetooth plugin backed by native Android, iOS, macOS APIs and the
browser Web Bluetooth API.

The plugin exposes a cross-platform API for Bluetooth permissions, adapter state,
scanning/device selection, connections, GATT client operations, GATT
server/peripheral mode, advertising, notifications, RSSI, MTU, PHY, Android
bonding, Android connection priority, and Android Classic RFCOMM sockets.

## Platform coverage

- Android: `BluetoothAdapter`, `BluetoothLeScanner`, `BluetoothGatt`,
  `BluetoothGattServer`, `BluetoothLeAdvertiser`, runtime permissions, Classic
  discovery, RFCOMM client/server sockets, bonded devices, bond/unbond, RSSI,
  MTU, LE PHY, adapter capability queries, and connection priority.
- iOS: CoreBluetooth central APIs and peripheral-manager APIs for authorization,
  adapter state, BLE scanning, peripheral connections, service discovery,
  characteristic/descriptor IO, notifications, RSSI, local GATT services, and
  advertising with local name/service UUIDs.
- macOS: CoreBluetooth central APIs and peripheral-manager APIs for authorization,
  adapter state, BLE scanning, peripheral connections, service discovery,
  characteristic/descriptor IO, notifications, RSSI, local GATT services, and
  advertising with local name/service UUIDs. macOS uses CoreBluetooth UUIDs for
  device IDs and does not expose Bluetooth adapter addresses.
- Web: Web Bluetooth BLE Central/GATT Client support in secure contexts.
  `startScan()` opens the browser device chooser and emits the selected device
  as one scan result. Web does not support passive/background scanning, RSSI,
  MTU negotiation, PHY, bonding management, BLE advertising/peripheral mode, or
  Classic Bluetooth.

Some platform APIs do not exist publicly on every system. iOS and macOS cannot
enable Bluetooth programmatically, do not expose Classic Bluetooth RFCOMM,
do not expose Android-style bonding or connection priority, and do not expose
public MTU negotiation. Web Bluetooth is chooser-based and exposes only
site-authorized BLE GATT devices/services. Unsupported APIs return `false`,
empty lists/streams, no-op for safe stop/clear calls, `0` for unavailable MTU or
write-length values, or an unsupported error for operations that cannot be
represented on that platform.

## Permissions

Call `requestPermissions()` before scanning, connecting, or advertising:

```dart
final bluetooth = FlutterBluetoothPlugin();
final permissions = await bluetooth.requestPermissions();
final info = await bluetooth.getAdapterInfo();
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

For Web, Bluetooth access must be triggered from a user gesture in a secure
context (HTTPS or localhost). `requestPermissions()` only reports status; call
`startScan(serviceUuids: [...])` from a button/tap handler to open the browser
device chooser. Pass the GATT service UUIDs you need so the browser grants
access to those services after connection.

For macOS, the host app should include a usage description and, when sandboxed,
the Bluetooth entitlement:

```xml
<key>NSBluetoothAlwaysUsageDescription</key>
<string>This app uses Bluetooth to scan, connect, and exchange data with nearby devices.</string>
```

```xml
<key>com.apple.security.device.bluetooth</key>
<true/>
```

## Basic central usage

```dart
final bluetooth = FlutterBluetoothPlugin();

await bluetooth.requestPermissions();

if (await bluetooth.getAdapterState() != BluetoothAdapterState.poweredOn) {
  await bluetooth.requestEnable(); // Android only; iOS/macOS return false.
}

final sub = bluetooth.scanResults.listen((result) {
  print('${result.device.id} ${result.device.name} RSSI=${result.rssi}');
});

// On Web this must run from a user gesture and opens the browser chooser.
await bluetooth.startScan(timeout: const Duration(seconds: 10));
await Future<void>.delayed(const Duration(seconds: 10));
await bluetooth.stopScan();
await sub.cancel();
```

## GATT client usage

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

## Advertising and local GATT server

```dart
const serviceUuid = '0000fff0-0000-1000-8000-00805f9b34fb';
const characteristicUuid = '0000fff1-0000-1000-8000-00805f9b34fb';

await bluetooth.setGattServerServices(
  const [
    BluetoothGattService(
      uuid: serviceUuid,
      characteristics: [
        BluetoothGattCharacteristic(
          uuid: characteristicUuid,
          serviceUuid: serviceUuid,
          properties: ['read', 'write', 'notify'],
          permissions: ['read', 'write'],
          value: [72, 101, 108, 108, 111],
        ),
      ],
    ),
  ],
);

await bluetooth.startAdvertising(
  advertisementData: const BluetoothAdvertisementData(
    localName: 'Flutter BT',
    serviceUuids: [serviceUuid],
    includeDeviceName: true,
  ),
);

bluetooth.gattServerRequests.listen((event) {
  print('${event.event} ${event.deviceId} ${event.value}');
});
```

## Android Classic RFCOMM

```dart
const sppUuid = '00001101-0000-1000-8000-00805f9b34fb';

await bluetooth.startClassicServer(serviceUuid: sppUuid);
await bluetooth.connectClassic(deviceId: macAddress, serviceUuid: sppUuid);
await bluetooth.writeClassic(macAddress, [1, 2, 3]);

bluetooth.classicData.listen((event) {
  print('classic ${event.deviceId}: ${event.value}');
});
```

## Event streams

- `adapterState`
- `scanResults`
- `connectionState`
- `characteristicValues`
- `descriptorValues`
- `rssiUpdates`
- `mtuUpdates`
- `phyUpdates`
- `bondState`
- `advertisingState`
- `gattServerRequests`
- `classicConnectionState`
- `classicData`

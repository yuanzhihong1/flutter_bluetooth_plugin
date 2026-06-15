# flutter_bluetooth_plugin

A Flutter Bluetooth plugin backed by native Android, iOS, macOS, Linux BlueZ,
Windows BLE APIs and the browser Web Bluetooth API.

The plugin exposes a cross-platform API for Bluetooth permissions, adapter state,
scanning/device selection, connections, GATT client operations, GATT
server/peripheral mode, advertising, notifications, RSSI, MTU, PHY, Android
bonding, Android connection priority, Android Classic RFCOMM sockets, Linux
BlueZ BLE central/GATT client operations, and Windows BLE central/GATT client
operations.

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
- Linux: BlueZ DBus adapter state, BlueZ discovery with BLE/classic/dual
  transport filters, paired and connected device enumeration, BLE GATT client
  connection, service discovery, characteristic/descriptor reads and writes,
  characteristic notifications, BlueZ pairing/removal, Bluetooth settings tool
  launch, and cached advertisement RSSI. Linux currently does not implement
  local GATT server, BLE advertising/peripheral mode, Classic RFCOMM sockets,
  MTU negotiation, PHY control, or connection priority hints.
- Windows: WinRT Bluetooth LE adapter state, BLE advertisement scanning, paired
  BLE device enumeration, BLE GATT client connection bootstrap, service
  discovery, characteristic/descriptor reads and writes, characteristic
  notifications, Bluetooth settings launch, and cached advertisement RSSI.
  Windows currently does not implement Classic RFCOMM, local GATT server, BLE
  advertising/peripheral mode, MTU negotiation, PHY control, bonding management,
  or connection priority hints.
- Web: Web Bluetooth BLE Central/GATT Client support in secure contexts.
  `startScan()` opens the browser device chooser and emits the selected device
  as one scan result. Web does not support passive/background scanning, RSSI,
  MTU negotiation, PHY, bonding management, BLE advertising/peripheral mode, or
  Classic Bluetooth.

Some platform APIs do not exist publicly on every system. Linux can attempt to
power the BlueZ adapter on, but iOS, macOS, Windows, and Web cannot enable
Bluetooth programmatically through this plugin. iOS and macOS do not expose
Classic Bluetooth RFCOMM; Linux/Windows Classic RFCOMM is not implemented here;
and non-Android platforms do not expose Android connection priority. iOS/macOS
do not expose public MTU negotiation, while Linux/Windows/Web return `0` for
unavailable MTU and write-length values. Web Bluetooth is chooser-based and
exposes only site-authorized BLE GATT devices/services. Unsupported APIs return
`false`, empty lists/streams, no-op for safe stop/clear calls, `0` for
unavailable MTU or write-length values, or an unsupported error for operations
that cannot be represented on that platform.

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

For Linux desktop, Bluetooth access is handled by BlueZ and system DBus policy.
`requestPermissions()` reports `bluetooth: granted` when a BlueZ adapter is
available and `notApplicable` otherwise; it does not display a runtime prompt.
`requestEnable()` attempts to set the adapter `Powered` property, and
`openBluetoothSettings()` tries common desktop Bluetooth settings tools.

For Windows desktop, Bluetooth access is handled by the OS and WinRT device
APIs. `requestPermissions()` reports `bluetooth: granted` when a BLE adapter is
available and `notApplicable` otherwise; it does not display a runtime prompt.
Use `openBluetoothSettings()` to send users to the Windows Bluetooth settings
page when Bluetooth is off.

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
  await bluetooth.requestEnable(); // Android; Linux attempts BlueZ Powered; others return false.
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

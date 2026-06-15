# flutter_bluetooth_plugin

[English](README.md)

一个面向 Android、iOS、macOS、Linux、Windows 和 Web 的 Flutter 蓝牙插件。它提供统一的 Dart API，用于蓝牙适配器状态、权限、BLE 扫描、GATT Client、本地 GATT Server/外设模式、广播、通知、RSSI、MTU、PHY、绑定、Android 连接优先级、Android Classic RFCOMM、Linux BlueZ、Windows WinRT 以及浏览器 Web Bluetooth。

> 各个平台的蓝牙能力差异很大。插件会尽量用一致语义处理不支持的能力：安全的 stop/clear 调用会变成空操作，能力查询返回 `false`，不可用的数值返回 `0`，事件流保持为空，无法模拟的平台操作会抛出 unsupported 错误。

## 目录

- [平台能力](#平台能力)
- [安装](#安装)
- [权限与平台配置](#权限与平台配置)
- [快速开始](#快速开始)
- [GATT Client](#gatt-client)
- [外设、GATT Server 与广播](#外设gatt-server-与广播)
- [Android Classic RFCOMM](#android-classic-rfcomm)
- [API 总览](#api-总览)
- [示例测试 App](#示例测试-app)
- [平台说明](#平台说明)
- [开源协议](#开源协议)

## 平台能力

| 能力 | Android | iOS | macOS | Linux | Windows | Web |
| --- | --- | --- | --- | --- | --- | --- |
| 适配器状态/信息 | 支持 | 支持 | 支持 | BlueZ | WinRT | Web Bluetooth availability |
| 权限辅助 | 支持 | 支持 | 支持 | DBus 可用性映射 | 系统可用性映射 | 仅权限状态 |
| BLE 扫描/设备选择 | 支持 | 支持 | 支持 | BlueZ discovery | BLE 广播扫描 | 浏览器设备选择器 |
| 已连接/已绑定设备 | 支持 | 有限 | 有限 | BlueZ | 已配对 BLE | 当前站点授权设备 |
| BLE GATT Client | 支持 | 支持 | 支持 | 支持 | 支持 | 支持，受浏览器授权限制 |
| 特征通知/指示 | 支持 | 支持 | 支持 | 支持 | 支持 | 支持 |
| 描述符读写 | 支持 | 支持 | 支持 | 支持 | 支持 | 支持 |
| RSSI | 已连接 RSSI | 已连接 RSSI | 已连接 RSSI | 缓存广播 RSSI | 缓存广播 RSSI | 不支持 |
| MTU / 最大写入长度 | MTU 协商 | 最大写入长度 | 最大写入长度 | 不支持 | 不支持 | 不支持 |
| PHY 控制 | Android 8+ | 不支持 | 不支持 | 不支持 | 不支持 | 不支持 |
| 绑定管理 | 支持 | 无公开 API | 无公开 API | Pair/remove | 不支持 | 不支持 |
| 本地 GATT Server | 支持 | 支持 | 支持 | 不支持 | 不支持 | 不支持 |
| BLE 广播 | 支持 | 支持 | 支持 | 不支持 | 不支持 | 不支持 |
| 连接优先级 | Android 专属 | 不支持 | 不支持 | 不支持 | 不支持 | 不支持 |
| Classic RFCOMM | Android 专属 | 不支持 | 不支持 | 不支持 | 不支持 | 不支持 |

## 安装

在业务 App 中添加依赖：

```yaml
dependencies:
  flutter_bluetooth_plugin: ^0.0.1
```

本仓库自带的 `example/` 使用本地 path 依赖，方便直接验证当前源码：

```yaml
dependencies:
  flutter_bluetooth_plugin:
    path: ../
```

导入插件：

```dart
import 'package:flutter_bluetooth_plugin/flutter_bluetooth_plugin.dart';
```

## 权限与平台配置

扫描、连接、广播前建议先调用 `requestPermissions()`：

```dart
final bluetooth = FlutterBluetoothPlugin();
final permissions = await bluetooth.requestPermissions();
final info = await bluetooth.getAdapterInfo();
```

### Android

插件 manifest 会自动合并常用蓝牙权限到宿主 App：

- Android 12+：`BLUETOOTH_SCAN`、`BLUETOOTH_CONNECT`、`BLUETOOTH_ADVERTISE`
- Android 6-11：扫描结果需要 `ACCESS_FINE_LOCATION`
- Android 11 及以下：`BLUETOOTH`、`BLUETOOTH_ADMIN`

业务 App 仍需要在合适的 UI 时机解释权限用途，并触发运行时权限申请。

### iOS

宿主 App 的 `Info.plist` 需要加入蓝牙用途说明：

```xml
<key>NSBluetoothAlwaysUsageDescription</key>
<string>This app uses Bluetooth to scan, connect, and exchange data with nearby devices.</string>
<key>NSBluetoothPeripheralUsageDescription</key>
<string>This app uses Bluetooth to communicate with nearby peripherals.</string>
```

### macOS

需要用途说明；沙盒 App 还需要蓝牙 entitlement：

```xml
<key>NSBluetoothAlwaysUsageDescription</key>
<string>This app uses Bluetooth to scan, connect, and exchange data with nearby devices.</string>
```

```xml
<key>com.apple.security.device.bluetooth</key>
<true/>
```

### Linux

Linux 通过 BlueZ 和 system DBus 工作。`requestPermissions()` 会把适配器可用性映射为权限状态，不会弹系统权限框。`requestEnable()` 会尝试设置 BlueZ Adapter 的 `Powered` 属性，`openBluetoothSettings()` 会尝试打开常见桌面蓝牙设置工具。

### Windows

Windows 使用 WinRT BLE API。蓝牙访问由系统控制；`requestPermissions()` 仅报告 BLE 适配器是否可用，`openBluetoothSettings()` 会打开系统蓝牙设置页。

### Web

Web Bluetooth 需要 HTTPS 或 localhost，并且必须从用户手势触发。`requestPermissions()` 不能打开全局蓝牙授权框；请在按钮点击中调用 `startScan(serviceUuids: [...])` 打开浏览器设备选择器。需要连接后访问哪些 GATT 服务，就把这些服务 UUID 传入扫描参数。

## 快速开始

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

## GATT Client

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

常用连接辅助 API：

```dart
final connected = await bluetooth.getConnectedDevices(
  serviceUuids: const <String>[],
);
final state = await bluetooth.getConnectionState(deviceId);
final rssi = await bluetooth.readRssi(deviceId);
final mtu = await bluetooth.requestMtu(deviceId, 247);
final maxWrite = await bluetooth.getMaximumWriteLength(deviceId);
```

## 外设、GATT Server 与广播

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

更新并通知本地特征：

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

## API 总览

### 适配器与权限

- `getPlatformVersion()`
- `isSupported()`
- `getAdapterState()` / `adapterState`
- `getAdapterInfo()`
- `isScanning()`
- `setAdapterName(name)`
- `checkPermissions()` / `requestPermissions()`
- `requestEnable()`
- `openBluetoothSettings()`

### 发现与设备

- `startScan(...)` / `stopScan()` / `scanResults`
- `getBondedDevices()`
- `getConnectedDevices(serviceUuids: ...)`
- `getDevice(deviceId)`
- `getDevices(deviceIds)`

### BLE 连接与 GATT Client

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

### 外设、广播与 Classic

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

## 示例测试 App

`example/` 已改造成一个 Cupertino 风格的蓝牙测试控制台，目标是在一个页面里尽可能覆盖插件 API：

- 平台、适配器、权限、扫描、设置页等诊断能力
- BLE 扫描模式、重复扫描事件、已绑定设备、已连接设备、设备查询 API
- 连接状态、服务发现、GATT 特征/描述符读写、通知、RSSI、MTU、最大写入长度、PHY、连接优先级、绑定操作
- 本地 GATT Server、BLE 广播、本地值更新、通知发送、服务清理
- Android Classic RFCOMM 客户端/服务端 Socket 操作
- 插件所有事件流的实时日志

运行示例：

```sh
cd example
flutter run
```

## 平台说明

- iOS 和 macOS 不公开 Classic Bluetooth RFCOMM API。
- iOS、macOS、Windows 和 Web 不能由应用直接开启蓝牙。
- Web Bluetooth 基于浏览器设备选择器，只能访问当前站点已授权的 BLE 设备和服务。
- Linux 能力依赖 BlueZ、system DBus 权限以及桌面蓝牙设置工具。
- Windows 当前主要覆盖 BLE Central/GATT Client。
- Android 平台能力最完整，包含 Classic RFCOMM、绑定、连接优先级、MTU、PHY 和更丰富的适配器能力。

## 开源协议

本项目基于 [MIT License](LICENSE) 开源。

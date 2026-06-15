/// Shared models and enums used by the Flutter Bluetooth plugin API.
library;

enum BluetoothAdapterState {
  unknown,
  unsupported,
  unauthorized,
  poweredOff,
  poweredOn,
  resetting,
  turningOn,
  turningOff,
}

enum BluetoothPermissionStatus {
  unknown,
  notDetermined,
  granted,
  denied,
  restricted,
  permanentlyDenied,
  notApplicable,
}

enum BluetoothScanMode { ble, classic, dual }

enum BluetoothConnectionState {
  disconnected,
  connecting,
  connected,
  disconnecting,
  unknown,
}

enum BluetoothBondState { none, bonding, bonded, unknown }

enum BluetoothWriteType { withResponse, withoutResponse }

enum BluetoothConnectionPriority { balanced, high, lowPower }

BluetoothAdapterState bluetoothAdapterStateFromString(String? value) {
  return BluetoothAdapterState.values.firstWhere(
    (state) => state.name == value,
    orElse: () => BluetoothAdapterState.unknown,
  );
}

BluetoothPermissionStatus bluetoothPermissionStatusFromString(String? value) {
  return BluetoothPermissionStatus.values.firstWhere(
    (status) => status.name == value,
    orElse: () => BluetoothPermissionStatus.unknown,
  );
}

BluetoothConnectionState bluetoothConnectionStateFromString(String? value) {
  return BluetoothConnectionState.values.firstWhere(
    (state) => state.name == value,
    orElse: () => BluetoothConnectionState.unknown,
  );
}

BluetoothBondState bluetoothBondStateFromString(String? value) {
  return BluetoothBondState.values.firstWhere(
    (state) => state.name == value,
    orElse: () => BluetoothBondState.unknown,
  );
}

Map<String, dynamic> _asStringMap(Object? value) {
  if (value == null) {
    return <String, dynamic>{};
  }
  return Map<String, dynamic>.from(value as Map<dynamic, dynamic>);
}

List<String> _asStringList(Object? value) {
  if (value == null) {
    return const <String>[];
  }
  return (value as List<dynamic>).map((item) => item.toString()).toList();
}

List<int> _asByteList(Object? value) {
  if (value == null) {
    return const <int>[];
  }
  return (value as List<dynamic>).map((item) => (item as num).toInt()).toList();
}

Map<int, List<int>> _asManufacturerData(Object? value) {
  final map = _asStringMap(value);
  return map.map(
    (key, bytes) => MapEntry(int.tryParse(key) ?? 0, _asByteList(bytes)),
  );
}

Map<String, List<int>> _asServiceData(Object? value) {
  final map = _asStringMap(value);
  return map.map((key, bytes) => MapEntry(key, _asByteList(bytes)));
}

class BluetoothDevice {
  const BluetoothDevice({
    required this.id,
    this.name,
    this.address,
    this.type,
    this.isConnected = false,
    this.isBonded = false,
    this.raw = const <String, dynamic>{},
  });

  factory BluetoothDevice.fromMap(Map<String, dynamic> map) {
    return BluetoothDevice(
      id: map['id']?.toString() ?? '',
      name: map['name']?.toString(),
      address: map['address']?.toString(),
      type: map['type']?.toString(),
      isConnected: map['isConnected'] == true,
      isBonded: map['isBonded'] == true,
      raw: map,
    );
  }

  final String id;
  final String? name;
  final String? address;
  final String? type;
  final bool isConnected;
  final bool isBonded;
  final Map<String, dynamic> raw;

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'id': id,
      if (name != null) 'name': name,
      if (address != null) 'address': address,
      if (type != null) 'type': type,
      'isConnected': isConnected,
      'isBonded': isBonded,
    };
  }

  @override
  String toString() {
    return 'BluetoothDevice(id: $id, name: $name, type: $type)';
  }
}

class BluetoothScanResult {
  const BluetoothScanResult({
    required this.device,
    required this.rssi,
    this.localName,
    this.serviceUuids = const <String>[],
    this.manufacturerData = const <int, List<int>>{},
    this.serviceData = const <String, List<int>>{},
    this.txPowerLevel,
    this.isConnectable,
    this.raw = const <String, dynamic>{},
  });

  factory BluetoothScanResult.fromMap(Map<String, dynamic> map) {
    final deviceMap = _asStringMap(map['device']);
    return BluetoothScanResult(
      device: BluetoothDevice.fromMap(deviceMap),
      rssi: (map['rssi'] as num?)?.toInt() ?? 0,
      localName: map['localName']?.toString(),
      serviceUuids: _asStringList(map['serviceUuids']),
      manufacturerData: _asManufacturerData(map['manufacturerData']),
      serviceData: _asServiceData(map['serviceData']),
      txPowerLevel: (map['txPowerLevel'] as num?)?.toInt(),
      isConnectable: map['isConnectable'] as bool?,
      raw: map,
    );
  }

  final BluetoothDevice device;
  final int rssi;
  final String? localName;
  final List<String> serviceUuids;
  final Map<int, List<int>> manufacturerData;
  final Map<String, List<int>> serviceData;
  final int? txPowerLevel;
  final bool? isConnectable;
  final Map<String, dynamic> raw;

  @override
  String toString() {
    return 'BluetoothScanResult(device: $device, rssi: $rssi)';
  }
}

class BluetoothGattDescriptor {
  const BluetoothGattDescriptor({
    required this.uuid,
    this.characteristicUuid,
    this.value = const <int>[],
    this.raw = const <String, dynamic>{},
  });

  factory BluetoothGattDescriptor.fromMap(Map<String, dynamic> map) {
    return BluetoothGattDescriptor(
      uuid: map['uuid']?.toString() ?? '',
      characteristicUuid: map['characteristicUuid']?.toString(),
      value: _asByteList(map['value']),
      raw: map,
    );
  }

  final String uuid;
  final String? characteristicUuid;
  final List<int> value;
  final Map<String, dynamic> raw;

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'uuid': uuid,
      if (characteristicUuid != null) 'characteristicUuid': characteristicUuid,
      'value': value,
    };
  }
}

class BluetoothGattCharacteristic {
  const BluetoothGattCharacteristic({
    required this.uuid,
    required this.serviceUuid,
    this.properties = const <String>[],
    this.permissions = const <String>[],
    this.value = const <int>[],
    this.descriptors = const <BluetoothGattDescriptor>[],
    this.raw = const <String, dynamic>{},
  });

  factory BluetoothGattCharacteristic.fromMap(Map<String, dynamic> map) {
    final descriptors =
        (map['descriptors'] as List<dynamic>? ?? const <dynamic>[])
            .map((item) => BluetoothGattDescriptor.fromMap(_asStringMap(item)))
            .toList(growable: false);
    return BluetoothGattCharacteristic(
      uuid: map['uuid']?.toString() ?? '',
      serviceUuid: map['serviceUuid']?.toString() ?? '',
      properties: _asStringList(map['properties']),
      permissions: _asStringList(map['permissions']),
      value: _asByteList(map['value']),
      descriptors: descriptors,
      raw: map,
    );
  }

  final String uuid;
  final String serviceUuid;
  final List<String> properties;
  final List<String> permissions;
  final List<int> value;
  final List<BluetoothGattDescriptor> descriptors;
  final Map<String, dynamic> raw;

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'uuid': uuid,
      'serviceUuid': serviceUuid,
      'properties': properties,
      'permissions': permissions,
      'value': value,
      'descriptors': descriptors
          .map((descriptor) => descriptor.toMap())
          .toList(),
    };
  }

  bool get canRead => properties.contains('read');
  bool get canWrite => properties.contains('write');
  bool get canWriteWithoutResponse =>
      properties.contains('writeWithoutResponse');
  bool get canNotify => properties.contains('notify');
  bool get canIndicate => properties.contains('indicate');
}

class BluetoothGattService {
  const BluetoothGattService({
    required this.uuid,
    this.isPrimary = true,
    this.characteristics = const <BluetoothGattCharacteristic>[],
    this.includedServices = const <String>[],
    this.raw = const <String, dynamic>{},
  });

  factory BluetoothGattService.fromMap(Map<String, dynamic> map) {
    final characteristics =
        (map['characteristics'] as List<dynamic>? ?? const <dynamic>[])
            .map(
              (item) => BluetoothGattCharacteristic.fromMap(_asStringMap(item)),
            )
            .toList(growable: false);
    return BluetoothGattService(
      uuid: map['uuid']?.toString() ?? '',
      isPrimary: map['isPrimary'] != false,
      characteristics: characteristics,
      includedServices: _asStringList(map['includedServices']),
      raw: map,
    );
  }

  final String uuid;
  final bool isPrimary;
  final List<BluetoothGattCharacteristic> characteristics;
  final List<String> includedServices;
  final Map<String, dynamic> raw;

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'uuid': uuid,
      'isPrimary': isPrimary,
      'includedServices': includedServices,
      'characteristics': characteristics
          .map((characteristic) => characteristic.toMap())
          .toList(),
    };
  }
}

class BluetoothConnectionStateEvent {
  const BluetoothConnectionStateEvent({
    required this.deviceId,
    required this.state,
    this.status,
  });

  factory BluetoothConnectionStateEvent.fromMap(Map<String, dynamic> map) {
    return BluetoothConnectionStateEvent(
      deviceId: map['deviceId']?.toString() ?? '',
      state: bluetoothConnectionStateFromString(map['state']?.toString()),
      status: (map['status'] as num?)?.toInt(),
    );
  }

  final String deviceId;
  final BluetoothConnectionState state;
  final int? status;
}

class BluetoothCharacteristicValue {
  const BluetoothCharacteristicValue({
    required this.deviceId,
    required this.serviceUuid,
    required this.characteristicUuid,
    required this.value,
  });

  factory BluetoothCharacteristicValue.fromMap(Map<String, dynamic> map) {
    return BluetoothCharacteristicValue(
      deviceId: map['deviceId']?.toString() ?? '',
      serviceUuid: map['serviceUuid']?.toString() ?? '',
      characteristicUuid: map['characteristicUuid']?.toString() ?? '',
      value: _asByteList(map['value']),
    );
  }

  final String deviceId;
  final String serviceUuid;
  final String characteristicUuid;
  final List<int> value;
}

class BluetoothDescriptorValue {
  const BluetoothDescriptorValue({
    required this.deviceId,
    required this.serviceUuid,
    required this.characteristicUuid,
    required this.descriptorUuid,
    required this.value,
  });

  factory BluetoothDescriptorValue.fromMap(Map<String, dynamic> map) {
    return BluetoothDescriptorValue(
      deviceId: map['deviceId']?.toString() ?? '',
      serviceUuid: map['serviceUuid']?.toString() ?? '',
      characteristicUuid: map['characteristicUuid']?.toString() ?? '',
      descriptorUuid: map['descriptorUuid']?.toString() ?? '',
      value: _asByteList(map['value']),
    );
  }

  final String deviceId;
  final String serviceUuid;
  final String characteristicUuid;
  final String descriptorUuid;
  final List<int> value;
}

class BluetoothRssiEvent {
  const BluetoothRssiEvent({required this.deviceId, required this.rssi});

  factory BluetoothRssiEvent.fromMap(Map<String, dynamic> map) {
    return BluetoothRssiEvent(
      deviceId: map['deviceId']?.toString() ?? '',
      rssi: (map['rssi'] as num?)?.toInt() ?? 0,
    );
  }

  final String deviceId;
  final int rssi;
}

class BluetoothMtuEvent {
  const BluetoothMtuEvent({required this.deviceId, required this.mtu});

  factory BluetoothMtuEvent.fromMap(Map<String, dynamic> map) {
    return BluetoothMtuEvent(
      deviceId: map['deviceId']?.toString() ?? '',
      mtu: (map['mtu'] as num?)?.toInt() ?? 0,
    );
  }

  final String deviceId;
  final int mtu;
}

class BluetoothBondStateEvent {
  const BluetoothBondStateEvent({required this.deviceId, required this.state});

  factory BluetoothBondStateEvent.fromMap(Map<String, dynamic> map) {
    return BluetoothBondStateEvent(
      deviceId: map['deviceId']?.toString() ?? '',
      state: bluetoothBondStateFromString(map['state']?.toString()),
    );
  }

  final String deviceId;
  final BluetoothBondState state;
}

enum BluetoothAdvertisingMode { lowPower, balanced, lowLatency }

enum BluetoothTxPowerLevel { ultraLow, low, medium, high }

enum BluetoothPhy { le1m, le2m, leCoded, unknown }

BluetoothPhy bluetoothPhyFromString(String? value) {
  return BluetoothPhy.values.firstWhere(
    (phy) => phy.name == value,
    orElse: () => BluetoothPhy.unknown,
  );
}

class BluetoothAdapterInfo {
  const BluetoothAdapterInfo({
    required this.isSupported,
    required this.state,
    this.name,
    this.address,
    this.isBleSupported = false,
    this.isMultipleAdvertisementSupported = false,
    this.isOffloadedFilteringSupported = false,
    this.isOffloadedScanBatchingSupported = false,
    this.isLe2MPhySupported = false,
    this.isLeCodedPhySupported = false,
    this.isLeExtendedAdvertisingSupported = false,
    this.isLePeriodicAdvertisingSupported = false,
    this.isDiscovering = false,
    this.raw = const <String, dynamic>{},
  });

  factory BluetoothAdapterInfo.fromMap(Map<String, dynamic> map) {
    return BluetoothAdapterInfo(
      isSupported: map['isSupported'] == true,
      state: bluetoothAdapterStateFromString(map['state']?.toString()),
      name: map['name']?.toString(),
      address: map['address']?.toString(),
      isBleSupported: map['isBleSupported'] == true,
      isMultipleAdvertisementSupported:
          map['isMultipleAdvertisementSupported'] == true,
      isOffloadedFilteringSupported:
          map['isOffloadedFilteringSupported'] == true,
      isOffloadedScanBatchingSupported:
          map['isOffloadedScanBatchingSupported'] == true,
      isLe2MPhySupported: map['isLe2MPhySupported'] == true,
      isLeCodedPhySupported: map['isLeCodedPhySupported'] == true,
      isLeExtendedAdvertisingSupported:
          map['isLeExtendedAdvertisingSupported'] == true,
      isLePeriodicAdvertisingSupported:
          map['isLePeriodicAdvertisingSupported'] == true,
      isDiscovering: map['isDiscovering'] == true,
      raw: map,
    );
  }

  final bool isSupported;
  final BluetoothAdapterState state;
  final String? name;
  final String? address;
  final bool isBleSupported;
  final bool isMultipleAdvertisementSupported;
  final bool isOffloadedFilteringSupported;
  final bool isOffloadedScanBatchingSupported;
  final bool isLe2MPhySupported;
  final bool isLeCodedPhySupported;
  final bool isLeExtendedAdvertisingSupported;
  final bool isLePeriodicAdvertisingSupported;
  final bool isDiscovering;
  final Map<String, dynamic> raw;
}

class BluetoothAdvertisementData {
  const BluetoothAdvertisementData({
    this.localName,
    this.includeDeviceName = false,
    this.includeTxPowerLevel = false,
    this.serviceUuids = const <String>[],
    this.manufacturerData = const <int, List<int>>{},
    this.serviceData = const <String, List<int>>{},
  });

  final String? localName;
  final bool includeDeviceName;
  final bool includeTxPowerLevel;
  final List<String> serviceUuids;
  final Map<int, List<int>> manufacturerData;
  final Map<String, List<int>> serviceData;

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      if (localName != null) 'localName': localName,
      'includeDeviceName': includeDeviceName,
      'includeTxPowerLevel': includeTxPowerLevel,
      'serviceUuids': serviceUuids,
      'manufacturerData': manufacturerData.map(
        (key, value) => MapEntry(key.toString(), value),
      ),
      'serviceData': serviceData,
    };
  }
}

class BluetoothAdvertisingSettings {
  const BluetoothAdvertisingSettings({
    this.mode = BluetoothAdvertisingMode.balanced,
    this.txPowerLevel = BluetoothTxPowerLevel.medium,
    this.connectable = true,
    this.timeout,
  });

  final BluetoothAdvertisingMode mode;
  final BluetoothTxPowerLevel txPowerLevel;
  final bool connectable;
  final Duration? timeout;

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'mode': mode.name,
      'txPowerLevel': txPowerLevel.name,
      'connectable': connectable,
      'timeoutMs': timeout?.inMilliseconds,
    };
  }
}

class BluetoothAdvertisingStateEvent {
  const BluetoothAdvertisingStateEvent({
    required this.isAdvertising,
    this.errorCode,
    this.message,
  });

  factory BluetoothAdvertisingStateEvent.fromMap(Map<String, dynamic> map) {
    return BluetoothAdvertisingStateEvent(
      isAdvertising: map['isAdvertising'] == true,
      errorCode: (map['errorCode'] as num?)?.toInt(),
      message: map['message']?.toString(),
    );
  }

  final bool isAdvertising;
  final int? errorCode;
  final String? message;
}

class BluetoothGattServerRequest {
  const BluetoothGattServerRequest({
    required this.event,
    required this.deviceId,
    this.serviceUuid,
    this.characteristicUuid,
    this.descriptorUuid,
    this.requestId,
    this.offset = 0,
    this.value = const <int>[],
    this.preparedWrite = false,
    this.responseNeeded = false,
    this.raw = const <String, dynamic>{},
  });

  factory BluetoothGattServerRequest.fromMap(Map<String, dynamic> map) {
    return BluetoothGattServerRequest(
      event: map['event']?.toString() ?? '',
      deviceId: map['deviceId']?.toString() ?? '',
      serviceUuid: map['serviceUuid']?.toString(),
      characteristicUuid: map['characteristicUuid']?.toString(),
      descriptorUuid: map['descriptorUuid']?.toString(),
      requestId: (map['requestId'] as num?)?.toInt(),
      offset: (map['offset'] as num?)?.toInt() ?? 0,
      value: _asByteList(map['value']),
      preparedWrite: map['preparedWrite'] == true,
      responseNeeded: map['responseNeeded'] == true,
      raw: map,
    );
  }

  final String event;
  final String deviceId;
  final String? serviceUuid;
  final String? characteristicUuid;
  final String? descriptorUuid;
  final int? requestId;
  final int offset;
  final List<int> value;
  final bool preparedWrite;
  final bool responseNeeded;
  final Map<String, dynamic> raw;
}

class BluetoothPhyEvent {
  const BluetoothPhyEvent({
    required this.deviceId,
    required this.txPhy,
    required this.rxPhy,
    this.status,
  });

  factory BluetoothPhyEvent.fromMap(Map<String, dynamic> map) {
    return BluetoothPhyEvent(
      deviceId: map['deviceId']?.toString() ?? '',
      txPhy: bluetoothPhyFromString(map['txPhy']?.toString()),
      rxPhy: bluetoothPhyFromString(map['rxPhy']?.toString()),
      status: (map['status'] as num?)?.toInt(),
    );
  }

  final String deviceId;
  final BluetoothPhy txPhy;
  final BluetoothPhy rxPhy;
  final int? status;
}

class BluetoothClassicConnectionEvent {
  const BluetoothClassicConnectionEvent({
    required this.deviceId,
    required this.state,
    this.error,
  });

  factory BluetoothClassicConnectionEvent.fromMap(Map<String, dynamic> map) {
    return BluetoothClassicConnectionEvent(
      deviceId: map['deviceId']?.toString() ?? '',
      state: bluetoothConnectionStateFromString(map['state']?.toString()),
      error: map['error']?.toString(),
    );
  }

  final String deviceId;
  final BluetoothConnectionState state;
  final String? error;
}

class BluetoothClassicDataEvent {
  const BluetoothClassicDataEvent({
    required this.deviceId,
    required this.value,
  });

  factory BluetoothClassicDataEvent.fromMap(Map<String, dynamic> map) {
    return BluetoothClassicDataEvent(
      deviceId: map['deviceId']?.toString() ?? '',
      value: _asByteList(map['value']),
    );
  }

  final String deviceId;
  final List<int> value;
}

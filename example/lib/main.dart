import 'dart:async';
import 'dart:convert';

import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bluetooth_plugin/flutter_bluetooth_plugin.dart';

void main() {
  runApp(const BluetoothTestApp());
}

class BluetoothTestApp extends StatelessWidget {
  const BluetoothTestApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const CupertinoApp(
      debugShowCheckedModeBanner: false,
      title: 'Bluetooth Lab',
      theme: CupertinoThemeData(
        brightness: Brightness.light,
        primaryColor: CupertinoColors.activeBlue,
        scaffoldBackgroundColor: CupertinoColors.systemGroupedBackground,
        textTheme: CupertinoTextThemeData(
          navLargeTitleTextStyle: TextStyle(
            fontSize: 34,
            fontWeight: FontWeight.w800,
            color: CupertinoColors.label,
          ),
        ),
      ),
      home: BluetoothTesterPage(),
    );
  }
}

class BluetoothTesterPage extends StatefulWidget {
  const BluetoothTesterPage({super.key});

  @override
  State<BluetoothTesterPage> createState() => _BluetoothTesterPageState();
}

class _BluetoothTesterPageState extends State<BluetoothTesterPage> {
  static const Duration _scanTimeout = Duration(seconds: 15);
  static const String _sampleServiceUuid =
      '0000fff0-0000-1000-8000-00805f9b34fb';
  static const String _sampleCharacteristicUuid =
      '0000fff1-0000-1000-8000-00805f9b34fb';
  static const String _classicSerialPortUuid =
      '00001101-0000-1000-8000-00805f9b34fb';

  final FlutterBluetoothPlugin _bluetooth = const FlutterBluetoothPlugin();
  final TextEditingController _writeController = TextEditingController(
    text: 'hello',
  );
  final TextEditingController _adapterNameController = TextEditingController(
    text: 'Flutter BT',
  );
  final TextEditingController _serviceFilterController = TextEditingController(
    text: _sampleServiceUuid,
  );
  final TextEditingController _descriptorWriteController =
      TextEditingController(text: '01 00');
  final TextEditingController _classicWriteController = TextEditingController(
    text: 'hello classic',
  );
  final ScrollController _scrollController = ScrollController();
  final Map<String, BluetoothScanResult> _scanResults =
      <String, BluetoothScanResult>{};
  final List<String> _logs = <String>[];

  late final List<StreamSubscription<dynamic>> _subscriptions;
  Timer? _scanTimer;

  String _platformVersion = 'Loading...';
  bool _supported = false;
  bool _peripheralSupported = false;
  bool _busy = false;
  bool _scanning = false;
  bool _advertising = false;
  bool _allowDuplicates = false;
  BluetoothScanMode _scanMode = BluetoothScanMode.ble;
  BluetoothAdapterState _adapterState = BluetoothAdapterState.unknown;
  Map<String, BluetoothPermissionStatus> _permissions =
      <String, BluetoothPermissionStatus>{};
  BluetoothAdapterInfo? _adapterInfo;
  List<BluetoothDevice> _bondedDevices = <BluetoothDevice>[];
  List<BluetoothDevice> _connectedDevices = <BluetoothDevice>[];
  String _deviceLookupSummary = 'No lookup yet';

  BluetoothDevice? _activeDevice;
  BluetoothConnectionState _connectionState =
      BluetoothConnectionState.disconnected;
  List<BluetoothGattService> _services = <BluetoothGattService>[];
  BluetoothGattCharacteristic? _selectedCharacteristic;
  BluetoothGattDescriptor? _selectedDescriptor;
  List<int> _lastCharacteristicValue = <int>[];
  List<int> _lastDescriptorValue = <int>[];
  int? _lastRssi;
  int? _lastMtu;
  BluetoothPhyEvent? _lastPhy;
  BluetoothConnectionState _classicState =
      BluetoothConnectionState.disconnected;

  @override
  void initState() {
    super.initState();
    _subscriptions = <StreamSubscription<dynamic>>[
      _bluetooth.adapterState.listen((BluetoothAdapterState state) {
        if (!mounted) return;
        setState(() => _adapterState = state);
        _addLog('Adapter state: ${state.name}');
      }),
      _bluetooth.scanResults.listen((BluetoothScanResult result) {
        if (!mounted) return;
        setState(() => _scanResults[result.device.id] = result);
      }),
      _bluetooth.connectionState.listen((BluetoothConnectionStateEvent event) {
        if (!mounted) return;
        if (_activeDevice?.id == event.deviceId) {
          setState(() => _connectionState = event.state);
        }
        _addLog('Connection ${event.deviceId}: ${event.state.name}');
      }),
      _bluetooth.characteristicValues.listen((
        BluetoothCharacteristicValue value,
      ) {
        if (!mounted) return;
        setState(() => _lastCharacteristicValue = value.value);
        _addLog(
          'Characteristic ${value.characteristicUuid}: ${_bytesPreview(value.value)}',
        );
      }),
      _bluetooth.descriptorValues.listen((BluetoothDescriptorValue value) {
        if (!mounted) return;
        setState(() => _lastDescriptorValue = value.value);
        _addLog(
          'Descriptor ${value.descriptorUuid}: ${_bytesPreview(value.value)}',
        );
      }),
      _bluetooth.rssiUpdates.listen((BluetoothRssiEvent event) {
        if (!mounted) return;
        setState(() => _lastRssi = event.rssi);
        _addLog('RSSI ${event.deviceId}: ${event.rssi} dBm');
      }),
      _bluetooth.mtuUpdates.listen((BluetoothMtuEvent event) {
        if (!mounted) return;
        setState(() => _lastMtu = event.mtu);
        _addLog('MTU ${event.deviceId}: ${event.mtu}');
      }),
      _bluetooth.bondState.listen((BluetoothBondStateEvent event) {
        if (!mounted) return;
        _addLog('Bond ${event.deviceId}: ${event.state.name}');
      }),
      _bluetooth.advertisingState.listen((
        BluetoothAdvertisingStateEvent event,
      ) {
        if (!mounted) return;
        setState(() => _advertising = event.isAdvertising);
        _addLog(
          'Advertising: ${event.isAdvertising ? 'on' : 'off'} ${event.message ?? ''}',
        );
      }),
      _bluetooth.gattServerRequests.listen((BluetoothGattServerRequest event) {
        if (!mounted) return;
        _addLog(
          'GATT server ${event.event}: ${event.deviceId} ${event.characteristicUuid ?? event.serviceUuid ?? ''}',
        );
      }),
      _bluetooth.phyUpdates.listen((BluetoothPhyEvent event) {
        if (!mounted) return;
        setState(() => _lastPhy = event);
        _addLog(
          'PHY ${event.deviceId}: tx=${event.txPhy.name} rx=${event.rxPhy.name}',
        );
      }),
      _bluetooth.classicConnectionState.listen((
        BluetoothClassicConnectionEvent event,
      ) {
        if (!mounted) return;
        setState(() => _classicState = event.state);
        _addLog('Classic ${event.deviceId}: ${event.state.name}');
      }),
      _bluetooth.classicData.listen((BluetoothClassicDataEvent event) {
        if (!mounted) return;
        _addLog(
          'Classic data ${event.deviceId}: ${_bytesPreview(event.value)}',
        );
      }),
    ];
    unawaited(_refreshAll());
  }

  @override
  void dispose() {
    _scanTimer?.cancel();
    for (final StreamSubscription<dynamic> subscription in _subscriptions) {
      subscription.cancel();
    }
    _writeController.dispose();
    _adapterNameController.dispose();
    _serviceFilterController.dispose();
    _descriptorWriteController.dispose();
    _classicWriteController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      navigationBar: CupertinoNavigationBar(
        middle: const Text('Bluetooth Lab'),
        trailing: _busy
            ? const CupertinoActivityIndicator(radius: 10)
            : CupertinoButton(
                padding: EdgeInsets.zero,
                onPressed: _refreshAll,
                child: const Icon(CupertinoIcons.refresh),
              ),
      ),
      child: CupertinoScrollbar(
        controller: _scrollController,
        child: ListView(
          controller: _scrollController,
          children: <Widget>[
            _heroPanel(context),
            const SizedBox(height: 14),
            _diagnosticsSection(context),
            _permissionsSection(context),
            _scanSection(context),
            _connectionSection(context),
            _gattSection(context),
            _peripheralSection(context),
            _classicSection(context),
            _logSection(context),
          ],
        ),
      ),
    );
  }

  Widget _heroPanel(BuildContext context) {
    final Color accent = _adapterColor(context, _adapterState);
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(26),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: <Color>[
            accent.withValues(alpha: 0.20),
            CupertinoColors.systemIndigo
                .resolveFrom(context)
                .withValues(alpha: 0.08),
            CupertinoColors.white.withValues(alpha: 0.90),
          ],
        ),
        border: Border.all(color: accent.withValues(alpha: 0.20)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                Container(
                  width: 54,
                  height: 54,
                  decoration: BoxDecoration(
                    color: accent.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: Icon(
                    CupertinoIcons.bluetooth,
                    color: accent,
                    size: 30,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      const Text(
                        'Native Bluetooth Tester',
                        style: TextStyle(
                          fontSize: 23,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _platformVersion,
                        style: TextStyle(
                          color: CupertinoColors.secondaryLabel.resolveFrom(
                            context,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: <Widget>[
                _StatusPill(
                  label: _supported ? 'Supported' : 'Unsupported',
                  color: _supported
                      ? CupertinoColors.activeGreen.resolveFrom(context)
                      : CupertinoColors.systemRed.resolveFrom(context),
                ),
                _StatusPill(label: _adapterState.name, color: accent),
                _StatusPill(
                  label: _connectionState.name,
                  color: _connectionColor(context, _connectionState),
                ),
                _StatusPill(
                  label: _peripheralSupported
                      ? 'Peripheral OK'
                      : 'Central only',
                  color: _peripheralSupported
                      ? CupertinoColors.activeGreen.resolveFrom(context)
                      : CupertinoColors.systemGrey.resolveFrom(context),
                ),
                if (_advertising)
                  _StatusPill(
                    label: 'Advertising',
                    color: CupertinoColors.activeBlue.resolveFrom(context),
                  ),
                if (_lastRssi != null)
                  _StatusPill(
                    label: 'RSSI $_lastRssi dBm',
                    color: CupertinoColors.systemOrange.resolveFrom(context),
                  ),
                if (_lastMtu != null)
                  _StatusPill(
                    label: 'MTU $_lastMtu',
                    color: CupertinoColors.systemPurple.resolveFrom(context),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _permissionsSection(BuildContext context) {
    return CupertinoListSection.insetGrouped(
      header: const Text('Permissions'),
      footer: const Text(
        'Use this before scanning. Android requests runtime permissions; iOS triggers CoreBluetooth authorization when needed.',
      ),
      children: <Widget>[
        CupertinoListTile(
          title: const Text('Current permissions'),
          subtitle: Text(_permissionSummary()),
          leading: const Icon(CupertinoIcons.lock_shield),
        ),
        CupertinoListTile(
          title: const Text('Adapter info'),
          subtitle: Text(_adapterInfoSummary()),
          leading: const Icon(CupertinoIcons.info_circle),
        ),
        CupertinoListTile(
          title: const Text('Request permissions'),
          leading: const Icon(CupertinoIcons.checkmark_shield),
          trailing: const Icon(CupertinoIcons.chevron_forward, size: 18),
          onTap: () => _guard('Request permissions', () async {
            final Map<String, BluetoothPermissionStatus> permissions =
                await _bluetooth.requestPermissions();
            setState(() => _permissions = permissions);
          }),
        ),
        CupertinoListTile(
          title: const Text('Request enable'),
          subtitle: const Text(
            'Android only; iOS cannot enable Bluetooth programmatically.',
          ),
          leading: const Icon(CupertinoIcons.power),
          trailing: const Icon(CupertinoIcons.chevron_forward, size: 18),
          onTap: () => _guard('Request enable', () async {
            final bool enabled = await _bluetooth.requestEnable();
            _addLog('Request enable result: $enabled');
            await _readPlatformState();
          }),
        ),
        CupertinoListTile(
          title: const Text('Open Bluetooth settings'),
          leading: const Icon(CupertinoIcons.settings),
          trailing: const Icon(CupertinoIcons.chevron_forward, size: 18),
          onTap: () =>
              _guard('Open settings', _bluetooth.openBluetoothSettings),
        ),
      ],
    );
  }

  Widget _diagnosticsSection(BuildContext context) {
    return CupertinoListSection.insetGrouped(
      header: const Text('Diagnostics'),
      footer: const Text(
        'Exercises adapter rename, scanning flag, connected-device queries, single/multiple device lookup, and current connection-state APIs.',
      ),
      children: <Widget>[
        Padding(
          padding: const EdgeInsets.fromLTRB(18, 12, 18, 6),
          child: CupertinoTextField(
            controller: _adapterNameController,
            placeholder: 'Adapter/local name',
            prefix: const Padding(
              padding: EdgeInsets.only(left: 10),
              child: Icon(CupertinoIcons.tag, size: 18),
            ),
          ),
        ),
        CupertinoListTile(
          title: const Text('Set adapter name'),
          subtitle: const Text(
            'Android/Linux may apply this; Apple, Windows, and Web usually return false.',
          ),
          leading: const Icon(CupertinoIcons.pencil_circle),
          trailing: const Icon(CupertinoIcons.chevron_forward, size: 18),
          onTap: _setAdapterName,
        ),
        CupertinoListTile(
          title: const Text('Read isScanning()'),
          subtitle: Text(
            _scanning ? 'Last known: scanning' : 'Last known: idle',
          ),
          leading: const Icon(CupertinoIcons.scope),
          trailing: const Icon(CupertinoIcons.chevron_forward, size: 18),
          onTap: _checkScanningFlag,
        ),
        CupertinoListTile(
          title: const Text('Load connected devices'),
          subtitle: Text(
            _connectedDevices.isEmpty
                ? 'No connected devices cached'
                : '${_connectedDevices.length} connected device(s)',
          ),
          leading: const Icon(CupertinoIcons.list_bullet_below_rectangle),
          trailing: const Icon(CupertinoIcons.chevron_forward, size: 18),
          onTap: _loadConnectedDevices,
        ),
        for (final BluetoothDevice device in _connectedDevices)
          CupertinoListTile(
            title: Text(_deviceTitle(device)),
            subtitle: Text('${device.id} · ${device.type ?? 'unknown'}'),
            leading: const Icon(CupertinoIcons.checkmark_circle),
            trailing: CupertinoButton(
              padding: EdgeInsets.zero,
              child: const Text('Use'),
              onPressed: () => setState(() => _activeDevice = device),
            ),
          ),
        CupertinoListTile(
          title: const Text('Lookup active/scanned device'),
          subtitle: Text(_deviceLookupSummary),
          leading: const Icon(CupertinoIcons.search_circle),
          trailing: const Icon(CupertinoIcons.chevron_forward, size: 18),
          onTap: _lookupSingleDevice,
        ),
        CupertinoListTile(
          title: const Text('Lookup all visible devices'),
          subtitle: const Text(
            'Calls getDevices() with scan, bonded, and connected IDs.',
          ),
          leading: const Icon(CupertinoIcons.square_stack_3d_up),
          trailing: const Icon(CupertinoIcons.chevron_forward, size: 18),
          onTap: _lookupKnownDevices,
        ),
        CupertinoListTile(
          title: const Text('Read active connection state'),
          subtitle: Text(_connectionState.name),
          leading: const Icon(CupertinoIcons.dot_radiowaves_left_right),
          trailing: const Icon(CupertinoIcons.chevron_forward, size: 18),
          onTap: _activeDevice == null ? null : _refreshConnectionState,
        ),
      ],
    );
  }

  Widget _scanSection(BuildContext context) {
    final List<BluetoothScanResult> results = _scanResults.values.toList()
      ..sort(
        (BluetoothScanResult a, BluetoothScanResult b) =>
            b.rssi.compareTo(a.rssi),
      );

    return CupertinoListSection.insetGrouped(
      header: const Text('Scan'),
      footer: Text(
        'Found ${results.length} device(s). Service UUID filters are especially important on Web.',
      ),
      children: <Widget>[
        Padding(
          padding: const EdgeInsets.fromLTRB(18, 12, 18, 4),
          child: CupertinoTextField(
            controller: _serviceFilterController,
            placeholder: 'Service UUID filters, comma separated',
            prefix: const Padding(
              padding: EdgeInsets.only(left: 10),
              child: Icon(CupertinoIcons.slider_horizontal_3, size: 18),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(18, 10, 18, 4),
          child: CupertinoSlidingSegmentedControl<BluetoothScanMode>(
            groupValue: _scanMode,
            children: const <BluetoothScanMode, Widget>{
              BluetoothScanMode.ble: Padding(
                padding: EdgeInsets.symmetric(horizontal: 8),
                child: Text('BLE'),
              ),
              BluetoothScanMode.classic: Padding(
                padding: EdgeInsets.symmetric(horizontal: 8),
                child: Text('Classic'),
              ),
              BluetoothScanMode.dual: Padding(
                padding: EdgeInsets.symmetric(horizontal: 8),
                child: Text('Dual'),
              ),
            },
            onValueChanged: (BluetoothScanMode? value) {
              if (value != null) {
                setState(() => _scanMode = value);
              }
            },
          ),
        ),
        CupertinoListTile(
          title: const Text('Allow duplicate events'),
          leading: const Icon(CupertinoIcons.repeat),
          trailing: CupertinoSwitch(
            value: _allowDuplicates,
            onChanged: (bool value) => setState(() => _allowDuplicates = value),
          ),
        ),
        CupertinoListTile(
          title: Text(_scanning ? 'Stop scan' : 'Start 15s scan'),
          subtitle: Text(
            _scanning
                ? 'Scanning in ${_scanMode.name} mode'
                : 'Scan mode: ${_scanMode.name}',
          ),
          leading: Icon(
            _scanning
                ? CupertinoIcons.stop_circle
                : CupertinoIcons.waveform_path_ecg,
          ),
          trailing: _scanning
              ? const CupertinoActivityIndicator(radius: 10)
              : const Icon(CupertinoIcons.chevron_forward, size: 18),
          onTap: _scanning ? _stopScan : _startScan,
        ),
        CupertinoListTile(
          title: const Text('Load bonded devices'),
          subtitle: Text(
            _bondedDevices.isEmpty
                ? 'No cached bonded devices'
                : '${_bondedDevices.length} bonded device(s)',
          ),
          leading: const Icon(CupertinoIcons.link),
          trailing: const Icon(CupertinoIcons.chevron_forward, size: 18),
          onTap: _loadBondedDevices,
        ),
        for (final BluetoothDevice device in _bondedDevices)
          CupertinoListTile(
            title: Text(_deviceTitle(device)),
            subtitle: Text('Bonded · ${device.type ?? 'unknown'}'),
            leading: const Icon(CupertinoIcons.link_circle),
            trailing: CupertinoButton(
              padding: EdgeInsets.zero,
              child: const Text('Connect'),
              onPressed: () => _connect(device),
            ),
          ),
        for (final BluetoothScanResult result in results)
          CupertinoListTile(
            title: Text(_deviceTitle(result.device)),
            subtitle: Text(
              '${result.device.type ?? 'unknown'} · RSSI ${result.rssi} · ${result.device.id}',
            ),
            leading: Icon(
              result.device.type == 'classic'
                  ? CupertinoIcons.device_phone_portrait
                  : CupertinoIcons.bluetooth,
            ),
            trailing: CupertinoButton(
              padding: EdgeInsets.zero,
              child: const Text('Connect'),
              onPressed: () => _connect(result.device),
            ),
          ),
      ],
    );
  }

  Widget _connectionSection(BuildContext context) {
    final BluetoothDevice? device = _activeDevice;
    return CupertinoListSection.insetGrouped(
      header: const Text('Connection'),
      footer: const Text(
        'Connect first, then discover services and test GATT operations.',
      ),
      children: <Widget>[
        CupertinoListTile(
          title: Text(
            device == null ? 'No active device' : _deviceTitle(device),
          ),
          subtitle: Text(
            device == null
                ? 'Pick a device from scan results'
                : '${device.id} · ${_connectionState.name}',
          ),
          leading: const Icon(CupertinoIcons.dot_radiowaves_left_right),
        ),
        CupertinoListTile(
          title: const Text('Discover services'),
          subtitle: Text('${_services.length} service(s) loaded'),
          leading: const Icon(CupertinoIcons.square_stack_3d_down_right),
          trailing: const Icon(CupertinoIcons.chevron_forward, size: 18),
          onTap: device == null ? null : _discoverServices,
        ),
        CupertinoListTile(
          title: const Text('Read RSSI'),
          subtitle: Text(
            _lastRssi == null ? 'No RSSI yet' : 'Last RSSI: $_lastRssi dBm',
          ),
          leading: const Icon(CupertinoIcons.antenna_radiowaves_left_right),
          trailing: const Icon(CupertinoIcons.chevron_forward, size: 18),
          onTap: device == null ? null : _readRssi,
        ),
        CupertinoListTile(
          title: const Text('Request MTU 247'),
          subtitle: Text(
            _lastMtu == null
                ? 'Android negotiates MTU; iOS returns max write length'
                : 'Last MTU: $_lastMtu',
          ),
          leading: const Icon(CupertinoIcons.resize),
          trailing: const Icon(CupertinoIcons.chevron_forward, size: 18),
          onTap: device == null ? null : () => _requestMtu(247),
        ),
        CupertinoListTile(
          title: const Text('Maximum write length'),
          subtitle: const Text(
            'iOS reports CoreBluetooth maximum; Android uses current MTU - 3.',
          ),
          leading: const Icon(CupertinoIcons.arrow_left_right),
          trailing: const Icon(CupertinoIcons.chevron_forward, size: 18),
          onTap: device == null ? null : _getMaximumWriteLength,
        ),
        CupertinoListTile(
          title: const Text('Read PHY'),
          subtitle: Text(
            _lastPhy == null
                ? 'Android 8+; iOS returns unknown'
                : 'tx=${_lastPhy!.txPhy.name}, rx=${_lastPhy!.rxPhy.name}',
          ),
          leading: const Icon(CupertinoIcons.dot_radiowaves_right),
          trailing: const Icon(CupertinoIcons.chevron_forward, size: 18),
          onTap: device == null ? null : _readPhy,
        ),
        CupertinoListTile(
          title: const Text('Prefer 2M PHY'),
          subtitle: const Text('Android 8+ only'),
          leading: const Icon(CupertinoIcons.bolt_horizontal_circle),
          trailing: const Icon(CupertinoIcons.chevron_forward, size: 18),
          onTap: device == null ? null : _prefer2MPhy,
        ),
        CupertinoListTile(
          title: const Text('Connection priority'),
          subtitle: const Text(
            'Android only. Try balanced/high/low power hints.',
          ),
          leading: const Icon(CupertinoIcons.speedometer),
          trailing: device == null
              ? null
              : Wrap(
                  spacing: 6,
                  children: <Widget>[
                    _InlineAction(
                      label: 'Bal',
                      onPressed: () => _requestPriority(
                        BluetoothConnectionPriority.balanced,
                      ),
                    ),
                    _InlineAction(
                      label: 'High',
                      onPressed: () =>
                          _requestPriority(BluetoothConnectionPriority.high),
                    ),
                    _InlineAction(
                      label: 'Low',
                      onPressed: () => _requestPriority(
                        BluetoothConnectionPriority.lowPower,
                      ),
                    ),
                  ],
                ),
        ),
        CupertinoListTile(
          title: const Text('Create bond'),
          subtitle: const Text('Android only'),
          leading: const Icon(CupertinoIcons.plus_circle),
          trailing: const Icon(CupertinoIcons.chevron_forward, size: 18),
          onTap: device == null ? null : _createBond,
        ),
        CupertinoListTile(
          title: const Text('Remove bond'),
          subtitle: const Text('Android only'),
          leading: const Icon(CupertinoIcons.minus_circle),
          trailing: const Icon(CupertinoIcons.chevron_forward, size: 18),
          onTap: device == null ? null : _removeBond,
        ),
        CupertinoListTile(
          title: const Text('Disconnect'),
          leading: const Icon(CupertinoIcons.xmark_circle),
          trailing: const Icon(CupertinoIcons.chevron_forward, size: 18),
          onTap: device == null ? null : _disconnect,
        ),
      ],
    );
  }

  Widget _gattSection(BuildContext context) {
    final BluetoothGattCharacteristic? selected = _selectedCharacteristic;
    final BluetoothGattDescriptor? descriptor = _selectedDescriptor;
    return CupertinoListSection.insetGrouped(
      header: const Text('GATT Explorer'),
      footer: const Text(
        'Tap a characteristic or descriptor to target read/write/notify actions.',
      ),
      children: <Widget>[
        if (_services.isEmpty)
          const CupertinoListTile(
            title: Text('No services discovered'),
            subtitle: Text('Use Discover services after connecting.'),
            leading: Icon(CupertinoIcons.square_stack_3d_down_right),
          ),
        for (final BluetoothGattService service in _services) ...<Widget>[
          CupertinoListTile(
            title: Text(service.uuid),
            subtitle: Text(
              service.isPrimary ? 'Primary service' : 'Secondary service',
            ),
            leading: const Icon(CupertinoIcons.cube_box),
          ),
          for (final BluetoothGattCharacteristic characteristic
              in service.characteristics)
            CupertinoListTile(
              title: Text(characteristic.uuid),
              subtitle: Text(characteristic.properties.join(', ')),
              leading: Icon(
                selected?.uuid == characteristic.uuid &&
                        selected?.serviceUuid == characteristic.serviceUuid
                    ? CupertinoIcons.largecircle_fill_circle
                    : CupertinoIcons.circle,
              ),
              trailing: const Icon(CupertinoIcons.chevron_forward, size: 18),
              onTap: () {
                setState(() {
                  _selectedCharacteristic = characteristic;
                  _selectedDescriptor = null;
                });
              },
            ),
          for (final BluetoothGattCharacteristic characteristic
              in service.characteristics)
            for (final BluetoothGattDescriptor item
                in characteristic.descriptors)
              CupertinoListTile(
                title: Text(item.uuid),
                subtitle: Text('Descriptor of ${characteristic.uuid}'),
                leading: Icon(
                  descriptor?.uuid == item.uuid &&
                          descriptor?.characteristicUuid == characteristic.uuid
                      ? CupertinoIcons.smallcircle_fill_circle
                      : CupertinoIcons.smallcircle_circle,
                ),
                trailing: const Icon(CupertinoIcons.chevron_forward, size: 18),
                onTap: () {
                  setState(() {
                    _selectedCharacteristic = characteristic;
                    _selectedDescriptor = item;
                  });
                },
              ),
        ],
        if (selected != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 14, 18, 6),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                Text(
                  'Selected characteristic',
                  style: TextStyle(
                    color: CupertinoColors.secondaryLabel.resolveFrom(context),
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  selected.uuid,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 10),
                CupertinoTextField(
                  controller: _writeController,
                  placeholder: 'Text or hex bytes, e.g. hello / 01 02',
                  prefix: const Padding(
                    padding: EdgeInsets.only(left: 10),
                    child: Icon(CupertinoIcons.text_cursor, size: 18),
                  ),
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: <Widget>[
                    _SmallActionButton(
                      label: 'Read',
                      onPressed: _readCharacteristic,
                    ),
                    _SmallActionButton(
                      label: 'Write',
                      onPressed: _writeCharacteristic,
                    ),
                    _SmallActionButton(
                      label: 'Write no response',
                      onPressed: _writeCharacteristicWithoutResponse,
                    ),
                    _SmallActionButton(
                      label: 'Notify on',
                      onPressed: () => _setNotification(true),
                    ),
                    _SmallActionButton(
                      label: 'Notify off',
                      onPressed: () => _setNotification(false),
                    ),
                  ],
                ),
                if (_lastCharacteristicValue.isNotEmpty) ...<Widget>[
                  const SizedBox(height: 10),
                  Text(
                    'Last value: ${_bytesPreview(_lastCharacteristicValue)}',
                  ),
                ],
              ],
            ),
          ),
        if (descriptor != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 14, 18, 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                Text(
                  'Selected descriptor',
                  style: TextStyle(
                    color: CupertinoColors.secondaryLabel.resolveFrom(context),
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  descriptor.uuid,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 10),
                CupertinoTextField(
                  controller: _descriptorWriteController,
                  placeholder: 'Hex bytes, e.g. 01 00',
                  prefix: const Padding(
                    padding: EdgeInsets.only(left: 10),
                    child: Icon(CupertinoIcons.number, size: 18),
                  ),
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: <Widget>[
                    _SmallActionButton(
                      label: 'Read descriptor',
                      onPressed: _readDescriptor,
                    ),
                    _SmallActionButton(
                      label: 'Write descriptor',
                      onPressed: _writeDescriptor,
                    ),
                  ],
                ),
                if (_lastDescriptorValue.isNotEmpty) ...<Widget>[
                  const SizedBox(height: 10),
                  Text(
                    'Last descriptor: ${_bytesPreview(_lastDescriptorValue)}',
                  ),
                ],
              ],
            ),
          ),
      ],
    );
  }

  Widget _peripheralSection(BuildContext context) {
    return CupertinoListSection.insetGrouped(
      header: const Text('Peripheral / Advertiser'),
      footer: const Text(
        'Creates a sample GATT server and advertises it. iOS supports local name and service UUID advertising; Android also supports manufacturer/service data.',
      ),
      children: <Widget>[
        CupertinoListTile(
          title: const Text('Peripheral support'),
          subtitle: Text(_peripheralSupported ? 'Available' : 'Unavailable'),
          leading: const Icon(CupertinoIcons.antenna_radiowaves_left_right),
        ),
        CupertinoListTile(
          title: const Text('Install sample GATT service'),
          subtitle: const Text(
            'FFF0 service with FFF1 read/write/notify characteristic',
          ),
          leading: const Icon(CupertinoIcons.cube_box_fill),
          trailing: const Icon(CupertinoIcons.chevron_forward, size: 18),
          onTap: _setSampleGattServer,
        ),
        CupertinoListTile(
          title: Text(_advertising ? 'Stop advertising' : 'Start advertising'),
          subtitle: Text(
            _advertising ? 'Advertising sample service' : _sampleServiceUuid,
          ),
          leading: Icon(
            _advertising
                ? CupertinoIcons.stop_circle
                : CupertinoIcons.radiowaves_right,
          ),
          trailing: _advertising
              ? const CupertinoActivityIndicator(radius: 10)
              : const Icon(CupertinoIcons.chevron_forward, size: 18),
          onTap: _advertising ? _stopAdvertising : _startAdvertising,
        ),
        CupertinoListTile(
          title: const Text('Notify sample value'),
          subtitle: const Text(
            'Sends the text from the write field to subscribed centrals',
          ),
          leading: const Icon(CupertinoIcons.bell),
          trailing: const Icon(CupertinoIcons.chevron_forward, size: 18),
          onTap: _notifySampleCharacteristic,
        ),
        CupertinoListTile(
          title: const Text('Indicate sample value'),
          subtitle: const Text(
            'Uses confirm: true when the platform supports it.',
          ),
          leading: const Icon(CupertinoIcons.bell_circle),
          trailing: const Icon(CupertinoIcons.chevron_forward, size: 18),
          onTap: () => _notifySampleCharacteristic(confirm: true),
        ),
        CupertinoListTile(
          title: const Text('Clear GATT services'),
          subtitle: const Text('Stops exposing the local sample service.'),
          leading: const Icon(CupertinoIcons.clear_circled),
          trailing: const Icon(CupertinoIcons.chevron_forward, size: 18),
          onTap: _clearGattServerServices,
        ),
      ],
    );
  }

  Widget _classicSection(BuildContext context) {
    final BluetoothDevice? device = _activeDevice;
    return CupertinoListSection.insetGrouped(
      header: const Text('Classic RFCOMM'),
      footer: const Text(
        'Android only. Uses the Serial Port Profile UUID by default.',
      ),
      children: <Widget>[
        CupertinoListTile(
          title: const Text('Classic socket state'),
          subtitle: Text(_classicState.name),
          leading: const Icon(CupertinoIcons.device_phone_portrait),
        ),
        CupertinoListTile(
          title: const Text('Start RFCOMM server'),
          subtitle: Text(_classicSerialPortUuid),
          leading: const Icon(CupertinoIcons.tray_full),
          trailing: const Icon(CupertinoIcons.chevron_forward, size: 18),
          onTap: _startClassicServer,
        ),
        CupertinoListTile(
          title: const Text('Stop RFCOMM server'),
          leading: const Icon(CupertinoIcons.stop),
          trailing: const Icon(CupertinoIcons.chevron_forward, size: 18),
          onTap: _stopClassicServer,
        ),
        CupertinoListTile(
          title: const Text('Connect active device via RFCOMM'),
          subtitle: Text(
            device == null
                ? 'Select a scanned Classic/Dual device first'
                : device.id,
          ),
          leading: const Icon(CupertinoIcons.link),
          trailing: const Icon(CupertinoIcons.chevron_forward, size: 18),
          onTap: device == null ? null : _connectClassic,
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(18, 10, 18, 6),
          child: CupertinoTextField(
            controller: _classicWriteController,
            placeholder: 'Classic socket text or hex bytes',
            prefix: const Padding(
              padding: EdgeInsets.only(left: 10),
              child: Icon(CupertinoIcons.text_bubble, size: 18),
            ),
          ),
        ),
        CupertinoListTile(
          title: const Text('Write classic data'),
          leading: const Icon(CupertinoIcons.paperplane),
          trailing: const Icon(CupertinoIcons.chevron_forward, size: 18),
          onTap: device == null ? null : _writeClassic,
        ),
        CupertinoListTile(
          title: const Text('Disconnect classic socket'),
          leading: const Icon(CupertinoIcons.xmark_circle),
          trailing: const Icon(CupertinoIcons.chevron_forward, size: 18),
          onTap: device == null ? null : _disconnectClassic,
        ),
      ],
    );
  }

  Widget _logSection(BuildContext context) {
    return CupertinoListSection.insetGrouped(
      header: const Text('Event Log'),
      children: <Widget>[
        if (_logs.isEmpty)
          const CupertinoListTile(
            title: Text('No events yet'),
            leading: Icon(CupertinoIcons.doc_text),
          ),
        for (final String log in _logs.take(18))
          CupertinoListTile(
            title: Text(log),
            leading: const Icon(CupertinoIcons.chevron_right_circle),
          ),
      ],
    );
  }

  Future<void> _refreshAll() async {
    await _guard(
      'Refresh platform state',
      _readPlatformState,
      silentSuccess: true,
    );
  }

  Future<void> _readPlatformState() async {
    final String version =
        await _bluetooth.getPlatformVersion() ?? 'Unknown platform';
    final bool supported = await _bluetooth.isSupported();
    final bool peripheralSupported = await _bluetooth.isPeripheralSupported();
    final BluetoothAdapterState state = await _bluetooth.getAdapterState();
    final bool scanning = await _bluetooth.isScanning();
    final BluetoothAdapterInfo adapterInfo = await _bluetooth.getAdapterInfo();
    final Map<String, BluetoothPermissionStatus> permissions = await _bluetooth
        .checkPermissions();
    if (!mounted) return;
    setState(() {
      _platformVersion = version;
      _supported = supported;
      _peripheralSupported = peripheralSupported;
      _adapterState = state;
      _scanning = scanning;
      _adapterInfo = adapterInfo;
      _permissions = permissions;
    });
  }

  Future<void> _setAdapterName() async {
    await _guard('Set adapter name', () async {
      final String name = _adapterNameController.text.trim();
      if (name.isEmpty) {
        await _showError('Adapter name', 'Enter a non-empty name first.');
        return;
      }
      final bool changed = await _bluetooth.setAdapterName(name);
      _addLog('Adapter name changed: $changed');
      final BluetoothAdapterInfo adapterInfo = await _bluetooth
          .getAdapterInfo();
      setState(() => _adapterInfo = adapterInfo);
    });
  }

  Future<void> _checkScanningFlag() async {
    await _guard('Read isScanning()', () async {
      final bool scanning = await _bluetooth.isScanning();
      setState(() => _scanning = scanning);
      _addLog('isScanning(): $scanning');
    });
  }

  Future<void> _startScan() async {
    await _guard('Start scan', () async {
      setState(() {
        _scanResults.clear();
        _scanning = true;
      });
      await _bluetooth.startScan(
        serviceUuids: _serviceFilters(),
        scanMode: _scanMode,
        timeout: _scanTimeout,
        allowDuplicates: _allowDuplicates,
      );
      _scanTimer?.cancel();
      _scanTimer = Timer(_scanTimeout, () {
        if (mounted) {
          setState(() => _scanning = false);
        }
      });
    });
  }

  Future<void> _loadConnectedDevices() async {
    await _guard('Load connected devices', () async {
      final List<BluetoothDevice> devices = await _bluetooth
          .getConnectedDevices(serviceUuids: _serviceFilters());
      setState(() => _connectedDevices = devices);
    });
  }

  Future<void> _lookupSingleDevice() async {
    await _guard('Lookup single device', () async {
      final List<String> ids = _candidateDeviceIds();
      final String? deviceId = ids.isEmpty ? null : ids.first;
      if (deviceId == null) {
        await _showError('Lookup device', 'Scan or select a device first.');
        return;
      }
      final BluetoothDevice? device = await _bluetooth.getDevice(deviceId);
      setState(() {
        _deviceLookupSummary = device == null
            ? 'No device for $deviceId'
            : '${_deviceTitle(device)} · ${device.id}';
      });
    });
  }

  Future<void> _lookupKnownDevices() async {
    await _guard('Lookup known devices', () async {
      final List<String> ids = _candidateDeviceIds();
      if (ids.isEmpty) {
        await _showError('Lookup devices', 'Scan or load devices first.');
        return;
      }
      final List<BluetoothDevice> devices = await _bluetooth.getDevices(ids);
      setState(() {
        _deviceLookupSummary =
            'Resolved ${devices.length}/${ids.length} visible device(s)';
      });
    });
  }

  Future<void> _stopScan() async {
    await _guard('Stop scan', () async {
      await _bluetooth.stopScan();
      _scanTimer?.cancel();
      setState(() => _scanning = false);
    });
  }

  Future<void> _loadBondedDevices() async {
    await _guard('Load bonded devices', () async {
      final List<BluetoothDevice> devices = await _bluetooth.getBondedDevices();
      setState(() => _bondedDevices = devices);
    });
  }

  Future<void> _connect(BluetoothDevice device) async {
    await _guard('Connect ${device.name ?? device.id}', () async {
      await _bluetooth.connect(device.id, timeout: const Duration(seconds: 15));
      final BluetoothConnectionState state = await _bluetooth
          .getConnectionState(device.id);
      setState(() {
        _activeDevice = device;
        _connectionState = state;
        _services = <BluetoothGattService>[];
        _selectedCharacteristic = null;
        _selectedDescriptor = null;
      });
    });
  }

  Future<void> _refreshConnectionState() async {
    final BluetoothDevice? device = _activeDevice;
    if (device == null) return;
    await _guard('Read connection state', () async {
      final BluetoothConnectionState state = await _bluetooth
          .getConnectionState(device.id);
      setState(() => _connectionState = state);
    });
  }

  Future<void> _disconnect() async {
    final BluetoothDevice? device = _activeDevice;
    if (device == null) return;
    await _guard('Disconnect', () async {
      await _bluetooth.disconnect(device.id);
      setState(() {
        _connectionState = BluetoothConnectionState.disconnected;
        _services = <BluetoothGattService>[];
        _selectedCharacteristic = null;
        _selectedDescriptor = null;
      });
    });
  }

  Future<void> _discoverServices() async {
    final BluetoothDevice? device = _activeDevice;
    if (device == null) return;
    await _guard('Discover services', () async {
      final List<BluetoothGattService> services = await _bluetooth
          .discoverServices(device.id);
      setState(() {
        _services = services;
        _selectedCharacteristic = null;
        _selectedDescriptor = null;
      });
    });
  }

  Future<void> _readCharacteristic() async {
    final CharacteristicTarget? target = _characteristicTarget();
    if (target == null) return;
    await _guard('Read characteristic', () async {
      final List<int> value = await _bluetooth.readCharacteristic(
        deviceId: target.deviceId,
        serviceUuid: target.characteristic.serviceUuid,
        characteristicUuid: target.characteristic.uuid,
      );
      setState(() => _lastCharacteristicValue = value);
    });
  }

  Future<void> _writeCharacteristic() async {
    await _writeSelectedCharacteristic(BluetoothWriteType.withResponse);
  }

  Future<void> _writeCharacteristicWithoutResponse() async {
    await _writeSelectedCharacteristic(BluetoothWriteType.withoutResponse);
  }

  Future<void> _writeSelectedCharacteristic(
    BluetoothWriteType writeType,
  ) async {
    final CharacteristicTarget? target = _characteristicTarget();
    if (target == null) return;
    await _guard('Write characteristic', () async {
      await _bluetooth.writeCharacteristic(
        deviceId: target.deviceId,
        serviceUuid: target.characteristic.serviceUuid,
        characteristicUuid: target.characteristic.uuid,
        value: _parseBytes(_writeController.text),
        writeType: writeType,
      );
    });
  }

  Future<void> _setNotification(bool enable) async {
    final CharacteristicTarget? target = _characteristicTarget();
    if (target == null) return;
    await _guard(
      enable ? 'Enable notifications' : 'Disable notifications',
      () async {
        await _bluetooth.setCharacteristicNotification(
          deviceId: target.deviceId,
          serviceUuid: target.characteristic.serviceUuid,
          characteristicUuid: target.characteristic.uuid,
          enable: enable,
        );
      },
    );
  }

  Future<void> _readDescriptor() async {
    final DescriptorTarget? target = _descriptorTarget();
    if (target == null) return;
    await _guard('Read descriptor', () async {
      final List<int> value = await _bluetooth.readDescriptor(
        deviceId: target.deviceId,
        serviceUuid: target.characteristic.serviceUuid,
        characteristicUuid: target.characteristic.uuid,
        descriptorUuid: target.descriptor.uuid,
      );
      setState(() => _lastDescriptorValue = value);
    });
  }

  Future<void> _writeDescriptor() async {
    final DescriptorTarget? target = _descriptorTarget();
    if (target == null) return;
    await _guard('Write descriptor', () async {
      await _bluetooth.writeDescriptor(
        deviceId: target.deviceId,
        serviceUuid: target.characteristic.serviceUuid,
        characteristicUuid: target.characteristic.uuid,
        descriptorUuid: target.descriptor.uuid,
        value: _parseBytes(_descriptorWriteController.text),
      );
    });
  }

  Future<void> _readRssi() async {
    final BluetoothDevice? device = _activeDevice;
    if (device == null) return;
    await _guard('Read RSSI', () async {
      final int rssi = await _bluetooth.readRssi(device.id);
      setState(() => _lastRssi = rssi);
    });
  }

  Future<void> _requestMtu(int mtu) async {
    final BluetoothDevice? device = _activeDevice;
    if (device == null) return;
    await _guard('Request MTU', () async {
      final int resolvedMtu = await _bluetooth.requestMtu(device.id, mtu);
      setState(() => _lastMtu = resolvedMtu);
    });
  }

  Future<void> _getMaximumWriteLength() async {
    final BluetoothDevice? device = _activeDevice;
    if (device == null) return;
    await _guard('Get maximum write length', () async {
      final int withoutResponse = await _bluetooth.getMaximumWriteLength(
        device.id,
      );
      final int withResponse = await _bluetooth.getMaximumWriteLength(
        device.id,
        withoutResponse: false,
      );
      _addLog(
        'Maximum write length: withoutResponse=$withoutResponse, withResponse=$withResponse',
      );
    });
  }

  Future<void> _readPhy() async {
    final BluetoothDevice? device = _activeDevice;
    if (device == null) return;
    await _guard('Read PHY', () async {
      final BluetoothPhyEvent phy = await _bluetooth.readPhy(device.id);
      setState(() => _lastPhy = phy);
    });
  }

  Future<void> _prefer2MPhy() async {
    final BluetoothDevice? device = _activeDevice;
    if (device == null) return;
    await _guard('Prefer 2M PHY', () async {
      await _bluetooth.setPreferredPhy(
        deviceId: device.id,
        txPhy: BluetoothPhy.le2m,
        rxPhy: BluetoothPhy.le2m,
      );
    });
  }

  Future<void> _requestPriority(BluetoothConnectionPriority priority) async {
    final BluetoothDevice? device = _activeDevice;
    if (device == null) return;
    await _guard('Request ${priority.name} priority', () async {
      final bool accepted = await _bluetooth.requestConnectionPriority(
        device.id,
        priority,
      );
      _addLog('${priority.name} priority accepted: $accepted');
    });
  }

  Future<void> _createBond() async {
    final BluetoothDevice? device = _activeDevice;
    if (device == null) return;
    await _guard('Create bond', () async {
      final bool started = await _bluetooth.createBond(device.id);
      _addLog('Create bond started: $started');
    });
  }

  Future<void> _removeBond() async {
    final BluetoothDevice? device = _activeDevice;
    if (device == null) return;
    await _guard('Remove bond', () async {
      final bool removed = await _bluetooth.removeBond(device.id);
      _addLog('Remove bond result: $removed');
    });
  }

  Future<void> _setSampleGattServer() async {
    await _guard('Install sample GATT service', () async {
      await _bluetooth.setGattServerServices(const <BluetoothGattService>[
        BluetoothGattService(
          uuid: _sampleServiceUuid,
          characteristics: <BluetoothGattCharacteristic>[
            BluetoothGattCharacteristic(
              uuid: _sampleCharacteristicUuid,
              serviceUuid: _sampleServiceUuid,
              properties: <String>[
                'read',
                'write',
                'writeWithoutResponse',
                'notify',
              ],
              permissions: <String>['read', 'write'],
              value: <int>[72, 101, 108, 108, 111],
              descriptors: <BluetoothGattDescriptor>[
                BluetoothGattDescriptor(
                  uuid: '00002901-0000-1000-8000-00805f9b34fb',
                  characteristicUuid: _sampleCharacteristicUuid,
                  value: <int>[83, 97, 109, 112, 108, 101],
                ),
              ],
            ),
          ],
        ),
      ]);
    });
  }

  Future<void> _startAdvertising() async {
    await _guard('Start advertising', () async {
      await _bluetooth.startAdvertising(
        advertisementData: BluetoothAdvertisementData(
          localName: _adapterNameController.text.trim().isEmpty
              ? 'Flutter BT'
              : _adapterNameController.text.trim(),
          serviceUuids: <String>[_sampleServiceUuid],
          includeDeviceName: true,
          includeTxPowerLevel: true,
          manufacturerData: const <int, List<int>>{
            0xffff: <int>[0x46, 0x42],
          },
          serviceData: const <String, List<int>>{
            _sampleServiceUuid: <int>[0x01, 0x02],
          },
        ),
        scanResponse: const BluetoothAdvertisementData(
          localName: 'Flutter BT Test',
          serviceUuids: <String>[_sampleServiceUuid],
          manufacturerData: <int, List<int>>{
            0xffff: <int>[0x54, 0x45, 0x53, 0x54],
          },
        ),
        settings: const BluetoothAdvertisingSettings(
          mode: BluetoothAdvertisingMode.lowLatency,
          txPowerLevel: BluetoothTxPowerLevel.high,
          connectable: true,
          timeout: Duration(minutes: 3),
        ),
      );
      setState(() => _advertising = true);
    });
  }

  Future<void> _stopAdvertising() async {
    await _guard('Stop advertising', () async {
      await _bluetooth.stopAdvertising();
      setState(() => _advertising = false);
    });
  }

  Future<void> _notifySampleCharacteristic({bool confirm = false}) async {
    await _guard(
      confirm
          ? 'Indicate sample characteristic'
          : 'Notify sample characteristic',
      () async {
        final List<int> value = _parseBytes(_writeController.text);
        await _bluetooth.updateLocalCharacteristicValue(
          serviceUuid: _sampleServiceUuid,
          characteristicUuid: _sampleCharacteristicUuid,
          value: value,
        );
        final bool sent = await _bluetooth.notifyGattServerCharacteristic(
          serviceUuid: _sampleServiceUuid,
          characteristicUuid: _sampleCharacteristicUuid,
          value: value,
          confirm: confirm,
        );
        _addLog('Local ${confirm ? 'indication' : 'notification'} sent: $sent');
      },
    );
  }

  Future<void> _clearGattServerServices() async {
    await _guard('Clear GATT services', _bluetooth.clearGattServerServices);
  }

  Future<void> _connectClassic() async {
    final BluetoothDevice? device = _activeDevice;
    if (device == null) return;
    await _guard('Connect classic', () async {
      await _bluetooth.connectClassic(
        deviceId: device.id,
        serviceUuid: _classicSerialPortUuid,
        timeout: const Duration(seconds: 15),
      );
    });
  }

  Future<void> _startClassicServer() async {
    await _guard('Start classic server', () async {
      await _bluetooth.startClassicServer(
        serviceUuid: _classicSerialPortUuid,
        serviceName: 'FlutterBluetoothPlugin',
      );
    });
  }

  Future<void> _stopClassicServer() async {
    await _guard('Stop classic server', _bluetooth.stopClassicServer);
  }

  Future<void> _writeClassic() async {
    final BluetoothDevice? device = _activeDevice;
    if (device == null) return;
    await _guard('Write classic data', () async {
      await _bluetooth.writeClassic(
        device.id,
        _parseBytes(_classicWriteController.text),
      );
    });
  }

  Future<void> _disconnectClassic() async {
    final BluetoothDevice? device = _activeDevice;
    if (device == null) return;
    await _guard('Disconnect classic', () async {
      await _bluetooth.disconnectClassic(device.id);
    });
  }

  CharacteristicTarget? _characteristicTarget() {
    final BluetoothDevice? device = _activeDevice;
    final BluetoothGattCharacteristic? characteristic = _selectedCharacteristic;
    if (device == null || characteristic == null) {
      unawaited(
        _showError(
          'Select target',
          'Connect to a device and select a characteristic first.',
        ),
      );
      return null;
    }
    return CharacteristicTarget(device.id, characteristic);
  }

  DescriptorTarget? _descriptorTarget() {
    final CharacteristicTarget? characteristicTarget = _characteristicTarget();
    final BluetoothGattDescriptor? descriptor = _selectedDescriptor;
    if (characteristicTarget == null) return null;
    if (descriptor == null) {
      unawaited(_showError('Select target', 'Select a descriptor first.'));
      return null;
    }
    return DescriptorTarget(
      characteristicTarget.deviceId,
      characteristicTarget.characteristic,
      descriptor,
    );
  }

  Future<void> _guard(
    String label,
    Future<void> Function() operation, {
    bool silentSuccess = false,
  }) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await operation();
      if (!silentSuccess) {
        _addLog('$label completed');
      }
    } on PlatformException catch (error) {
      final String message = error.message ?? error.code;
      _addLog('$label failed: $message');
      await _showError(label, message);
    } catch (error) {
      _addLog('$label failed: $error');
      await _showError(label, error.toString());
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  Future<void> _showError(String title, String message) async {
    if (!mounted) return;
    await showCupertinoDialog<void>(
      context: context,
      builder: (BuildContext context) {
        return CupertinoAlertDialog(
          title: Text(title),
          content: Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(message),
          ),
          actions: <Widget>[
            CupertinoDialogAction(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('OK'),
            ),
          ],
        );
      },
    );
  }

  void _addLog(String message) {
    if (!mounted) return;
    setState(() {
      _logs.insert(
        0,
        '${DateTime.now().toIso8601String().substring(11, 19)}  $message',
      );
      if (_logs.length > 80) {
        _logs.removeRange(80, _logs.length);
      }
    });
  }

  String _permissionSummary() {
    if (_permissions.isEmpty) {
      return 'Unknown';
    }
    return _permissions.entries
        .map(
          (MapEntry<String, BluetoothPermissionStatus> entry) =>
              '${entry.key}: ${entry.value.name}',
        )
        .join('\n');
  }

  String _adapterInfoSummary() {
    final BluetoothAdapterInfo? info = _adapterInfo;
    if (info == null) {
      return 'Unknown';
    }
    return <String>[
      'state: ${info.state.name}',
      if (info.name != null) 'name: ${info.name}',
      if (info.address != null) 'address: ${info.address}',
      'BLE: ${info.isBleSupported}',
      'advertising: ${info.isMultipleAdvertisementSupported}',
      '2M PHY: ${info.isLe2MPhySupported}',
      'coded PHY: ${info.isLeCodedPhySupported}',
      'discovering: ${info.isDiscovering}',
    ].join('\n');
  }

  List<String> _serviceFilters() {
    return _serviceFilterController.text
        .split(RegExp(r'[\s,;]+'))
        .map((String value) => value.trim())
        .where((String value) => value.isNotEmpty)
        .toList(growable: false);
  }

  List<String> _candidateDeviceIds() {
    return <String>{
      if (_activeDevice != null) _activeDevice!.id,
      for (final BluetoothScanResult result in _scanResults.values)
        result.device.id,
      for (final BluetoothDevice device in _bondedDevices) device.id,
      for (final BluetoothDevice device in _connectedDevices) device.id,
    }.toList(growable: false);
  }

  String _deviceTitle(BluetoothDevice device) {
    return device.name?.isNotEmpty == true ? device.name! : device.id;
  }

  List<int> _parseBytes(String text) {
    final String trimmed = text.trim();
    if (trimmed.isEmpty) return <int>[];

    final RegExp hexLike = RegExp(
      r'^(0x)?[0-9a-fA-F]{2}([\s,;:\-]*[0-9a-fA-F]{2})*$',
    );
    if (hexLike.hasMatch(trimmed)) {
      final String hex = trimmed
          .replaceFirst(RegExp(r'^0x'), '')
          .replaceAll(RegExp(r'[^0-9a-fA-F]'), '');
      return <int>[
        for (int index = 0; index < hex.length; index += 2)
          int.parse(hex.substring(index, index + 2), radix: 16),
      ];
    }
    return utf8.encode(text);
  }

  String _bytesPreview(List<int> bytes) {
    if (bytes.isEmpty) return '<empty>';
    final String hex = bytes
        .map((int byte) => byte.toRadixString(16).padLeft(2, '0'))
        .join(' ');
    final String text = utf8.decode(bytes, allowMalformed: true);
    return '$hex  ·  "$text"';
  }

  Color _adapterColor(BuildContext context, BluetoothAdapterState state) {
    return switch (state) {
      BluetoothAdapterState.poweredOn =>
        CupertinoColors.activeGreen.resolveFrom(context),
      BluetoothAdapterState.poweredOff =>
        CupertinoColors.systemOrange.resolveFrom(context),
      BluetoothAdapterState.unauthorized =>
        CupertinoColors.systemRed.resolveFrom(context),
      BluetoothAdapterState.unsupported =>
        CupertinoColors.systemGrey.resolveFrom(context),
      _ => CupertinoColors.activeBlue.resolveFrom(context),
    };
  }

  Color _connectionColor(BuildContext context, BluetoothConnectionState state) {
    return switch (state) {
      BluetoothConnectionState.connected =>
        CupertinoColors.activeGreen.resolveFrom(context),
      BluetoothConnectionState.connecting ||
      BluetoothConnectionState.disconnecting =>
        CupertinoColors.systemOrange.resolveFrom(context),
      BluetoothConnectionState.disconnected =>
        CupertinoColors.systemGrey.resolveFrom(context),
      BluetoothConnectionState.unknown =>
        CupertinoColors.activeBlue.resolveFrom(context),
    };
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.22)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        child: Text(
          label,
          style: TextStyle(
            color: color,
            fontSize: 13,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}

class _SmallActionButton extends StatelessWidget {
  const _SmallActionButton({required this.label, required this.onPressed});

  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return CupertinoButton(
      padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 8),
      color: CupertinoColors.activeBlue.resolveFrom(context),
      borderRadius: BorderRadius.circular(12),
      onPressed: onPressed,
      child: Text(
        label,
        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
      ),
    );
  }
}

class _InlineAction extends StatelessWidget {
  const _InlineAction({required this.label, required this.onPressed});

  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return CupertinoButton(
      minimumSize: Size.zero,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      color: CupertinoColors.systemGrey5.resolveFrom(context),
      borderRadius: BorderRadius.circular(10),
      onPressed: onPressed,
      child: Text(
        label,
        style: TextStyle(
          color: CupertinoColors.activeBlue.resolveFrom(context),
          fontSize: 12,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class CharacteristicTarget {
  const CharacteristicTarget(this.deviceId, this.characteristic);

  final String deviceId;
  final BluetoothGattCharacteristic characteristic;
}

class DescriptorTarget {
  const DescriptorTarget(this.deviceId, this.characteristic, this.descriptor);

  final String deviceId;
  final BluetoothGattCharacteristic characteristic;
  final BluetoothGattDescriptor descriptor;
}

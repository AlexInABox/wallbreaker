import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:haptic_feedback/haptic_feedback.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import 'oui_database.dart';
import 'oui_lookup_bottom_sheet.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  FlutterBluePlus.setLogLevel(LogLevel.none);
  await AppHaptics.init();
  await OuiDatabase().init();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});
  @override
  Widget build(BuildContext context) {
    const colorScheme = ColorScheme.light(
      primary: Colors.black,
      onPrimary: Colors.white,
      surface: Colors.white,
      onSurface: Colors.black,
    );
    const darkColorScheme = ColorScheme.dark(
      primary: Colors.white,
      onPrimary: Colors.black,
      surface: Colors.black,
      onSurface: Colors.white,
    );
    return MaterialApp(
      title: 'WALLBREAKER',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        scaffoldBackgroundColor: Colors.white,
        colorScheme: colorScheme,
      ),
      darkTheme: ThemeData(
        useMaterial3: true,
        scaffoldBackgroundColor: Colors.black,
        colorScheme: darkColorScheme,
      ),
      themeMode: ThemeMode.system,
      home: const BluetoothScannerScreen(),
    );
  }
}

class CyberButton extends StatelessWidget {
  final String text;
  final VoidCallback onTap;
  final Color? color;
  final Color? textColor;
  final double fontSize;
  final Widget? icon;

  const CyberButton({
    super.key,
    required this.text,
    required this.onTap,
    this.color,
    this.textColor,
    this.fontSize = 10,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    return InkWell(
      onTap: () {
        AppHaptics.light();
        onTap();
      },
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
        decoration: BoxDecoration(
          color: color,
          border: Border.all(color: primary, width: 2),
        ),
        alignment: Alignment.center,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (icon != null) ...[icon!, const SizedBox(width: 6)],
            Text(
              text,
              style: TextStyle(
                color:
                    textColor ??
                    (color == null
                        ? primary
                        : Theme.of(context).colorScheme.onPrimary),
                fontWeight: FontWeight.bold,
                fontSize: fontSize,
                letterSpacing: 1,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class CyberHeader extends StatelessWidget {
  final String title;
  const CyberHeader({super.key, required this.title});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        CyberButton(
          text: 'RETURN',
          icon: Icon(
            Icons.arrow_back,
            size: 16,
            color: Theme.of(context).colorScheme.primary,
          ),
          fontSize: 11,
          onTap: () => Navigator.of(context).pop(),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerRight,
            child: Text(
              title,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w900,
                letterSpacing: 1,
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

ScanResult _mockResult(
  String name,
  String mac,
  int rssi, {
  Map<int, List<int>>? mfrData,
}) {
  return ScanResult(
    device: BluetoothDevice(remoteId: DeviceIdentifier(mac)),
    advertisementData: AdvertisementData(
      advName: name,
      txPowerLevel: -8,
      appearance: null,
      connectable: true,
      manufacturerData: mfrData ?? const {},
      serviceData: const {},
      serviceUuids: const [],
    ),
    rssi: rssi,
    timeStamp: DateTime.now(),
  );
}

class BluetoothScannerScreen extends StatefulWidget {
  const BluetoothScannerScreen({super.key});
  @override
  State<BluetoothScannerScreen> createState() => _BluetoothScannerScreenState();
}

class _BluetoothScannerScreenState extends State<BluetoothScannerScreen> {
  BluetoothAdapterState _adapterState = BluetoothAdapterState.unknown;
  StreamSubscription<BluetoothAdapterState>? _adapterStateSubscription;
  List<ScanResult> _scanResults = [];
  StreamSubscription<List<ScanResult>>? _scanResultsSubscription;
  bool _isScanning = false;
  StreamSubscription<bool>? _isScanningSubscription;

  bool _btGranted = false;
  bool _locGranted = false; // Android only; always true on iOS
  Timer? _permPollTimer;
  bool _isSimulationMode = false;

  List<ScanResult> get _placeholders => [
    _mockResult('WALLBREAKER_NEXUS', 'DE:AD:BE:EF:00:01', -56),
    _mockResult('WALLBREAKER_AEROPULSE', 'DE:AD:BE:EF:00:02', -72),
  ];

  @override
  void initState() {
    super.initState();
    _adapterStateSubscription = FlutterBluePlus.adapterState.listen((state) {
      if (mounted) {
        setState(() => _adapterState = state);
        _startScanFlow();
      }
    });

    _scanResultsSubscription = FlutterBluePlus.scanResults.listen((results) {
      if (mounted && !_isSimulationMode) {
        setState(() {
          final merged = <String, ScanResult>{};
          for (var r in results) {
            final name = r.advertisementData.advName.trim().toUpperCase();
            final pName = r.device.platformName.trim().toUpperCase();
            if (name.startsWith('WALLBREAKER_') ||
                pName.startsWith('WALLBREAKER_')) {
              merged[r.device.remoteId.toString()] = r;
            }
          }
          if (merged.isEmpty) {
            for (var p in _placeholders) {
              merged[p.device.remoteId.toString()] = p;
            }
          }
          _scanResults = merged.values.toList()
            ..sort((a, b) => b.rssi.compareTo(a.rssi));
        });
      }
    });

    _isScanningSubscription = FlutterBluePlus.isScanning.listen((state) {
      if (mounted) {
        setState(() => _isScanning = state);
        if (!state &&
            _adapterState == BluetoothAdapterState.on &&
            _btGranted &&
            _locGranted &&
            !_isSimulationMode) {
          _startContinuousScan();
        }
      }
    });

    _startPolling();
  }

  void _startPolling() {
    _permPollTimer?.cancel();
    _checkPermissions();
    _permPollTimer = Timer.periodic(const Duration(milliseconds: 500), (_) {
      _checkPermissions();
    });
  }

  Future<void> _checkPermissions() async {
    final wasGranted = _btGranted && _locGranted;
    await _refreshPermStates();
    final isGranted = _btGranted && _locGranted;

    if (isGranted && !wasGranted) {
      _startScanFlow();
    } else if (!isGranted && wasGranted) {
      setState(() {
        _isSimulationMode = true;
        _isScanning = false;
        _scanResults = [];
      });
      FlutterBluePlus.stopScan().catchError((_) {});
    }
  }

  Future<void> _refreshPermStates() async {
    bool bt, loc;
    if (defaultTargetPlatform == TargetPlatform.iOS) {
      bt = await Permission.bluetooth.isGranted;
      loc = true; // Not separately required on iOS
    } else {
      bt =
          await Permission.bluetoothScan.isGranted &&
          await Permission.bluetoothConnect.isGranted;
      loc = await Permission.location.isGranted;
    }
    if (mounted) {
      setState(() {
        _btGranted = bt;
        _locGranted = loc;
      });
    }
  }

  @override
  void dispose() {
    _permPollTimer?.cancel();
    _adapterStateSubscription?.cancel();
    _scanResultsSubscription?.cancel();
    _isScanningSubscription?.cancel();
    super.dispose();
  }

  void _startScanFlow() {
    final hasPerms = _btGranted && _locGranted;
    if (!hasPerms) {
      setState(() {
        _isSimulationMode = true;
        _isScanning = true;
        _scanResults = List.from(_placeholders);
      });
      return;
    }
    if (_adapterState == BluetoothAdapterState.on) {
      setState(() {
        _isSimulationMode = false;
        _isScanning = true;
      });
      _startContinuousScan();
    } else {
      setState(() {
        _isSimulationMode = true;
        _isScanning = true;
        _scanResults = List.from(_placeholders);
      });
    }
  }

  Future<void> _startContinuousScan() async {
    try {
      await FlutterBluePlus.startScan(
        timeout: const Duration(seconds: 15),
        androidUsesFineLocation: true,
      );
    } catch (e) {
      debugPrint("Scan failed: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'WALLBREAKER',
                style: TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 4,
                  color: primary,
                ),
              ),
              const SizedBox(height: 16),
              Container(height: 3, color: primary),
              const SizedBox(height: 16),

              if (!_btGranted || !_locGranted)
                GestureDetector(
                  onTap: () async {
                    AppHaptics.light();
                    await Future.delayed(const Duration(milliseconds: 50));
                    await openAppSettings();
                  },
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 16),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFEB3B),
                      border: Border.all(color: Colors.black, width: 2),
                    ),
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            'PERMISSIONS REQUIRED. TAP TO OPEN APP SETTINGS.',
                            style: TextStyle(
                              fontSize: 9,
                              fontWeight: FontWeight.bold,
                              color: Colors.black,
                            ),
                          ),
                        ),
                        Icon(
                          Icons.chevron_right,
                          size: 16,
                          color: Colors.black,
                        ),
                      ],
                    ),
                  ),
                ),

              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'AVAILABLE DEVICES',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1.5,
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                  ),
                  Row(
                    children: [
                      Container(
                        width: 6,
                        height: 6,
                        color: _isScanning
                            ? Colors.red
                            : Theme.of(
                                context,
                              ).colorScheme.onSurface.withValues(alpha: 0.26),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        _isScanning ? 'SCANNING' : 'OFFLINE',
                        style: TextStyle(
                          fontFamily: 'monospace',
                          fontSize: 9,
                          fontWeight: FontWeight.bold,
                          color: _isScanning
                              ? Colors.red
                              : Theme.of(
                                  context,
                                ).colorScheme.onSurface.withValues(alpha: 0.38),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Expanded(child: _buildDevicesList()),
              const SizedBox(height: 16),
              Stack(
                clipBehavior: Clip.none,
                children: [
                  CyberButton(
                    text: 'SETTINGS',
                    fontSize: 12,
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const SettingsScreen()),
                    ),
                  ),
                  if (OuiDatabase().isStale)
                    Positioned(
                      top: -5,
                      right: -5,
                      child: Container(
                        width: 12,
                        height: 12,
                        decoration: const BoxDecoration(
                          color: Colors.orange,
                          shape: BoxShape.circle,
                        ),
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDevicesList() {
    final primary = Theme.of(context).colorScheme.primary;
    if (_scanResults.isEmpty) {
      return Container(
        decoration: BoxDecoration(border: Border.all(color: primary, width: 2)),
        padding: const EdgeInsets.all(24),
        alignment: Alignment.center,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.crop_square, size: 36, color: primary),
            const SizedBox(height: 16),
            const Text(
              'FEED EMPTY',
              style: TextStyle(
                fontWeight: FontWeight.w900,
                fontSize: 13,
                letterSpacing: 2,
              ),
            ),
          ],
        ),
      );
    }
    return ListView.builder(
      physics: const BouncingScrollPhysics(),
      itemCount: _scanResults.length,
      itemBuilder: (context, idx) => _DeviceTile(result: _scanResults[idx]),
    );
  }
}

class _DeviceTile extends StatelessWidget {
  final ScanResult result;
  const _DeviceTile({required this.result});

  @override
  Widget build(BuildContext context) {
    final name = result.advertisementData.advName.trim().isNotEmpty
        ? result.advertisementData.advName.trim().toUpperCase()
        : result.device.platformName.trim().isNotEmpty
        ? result.device.platformName.trim().toUpperCase()
        : 'UNNAMED SIGNAL';
    final id = result.device.remoteId.toString();
    final theme = Theme.of(context);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        border: Border.all(color: theme.colorScheme.primary, width: 2),
      ),
      child: InkWell(
        onTap: () {
          AppHaptics.light();
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => WallbreakerMonitorScreen(
                device: result.device,
                name: name,
                initialScanResult: result,
              ),
            ),
          );
        },
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            name,
                            style: const TextStyle(
                              fontWeight: FontWeight.w900,
                              fontSize: 13,
                              letterSpacing: 1,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (id.contains('DE:AD:BE:EF')) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 4,
                              vertical: 2,
                            ),
                            color: Colors.amber,
                            child: const Text(
                              'MOCK',
                              style: TextStyle(
                                color: Colors.black,
                                fontSize: 8,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      id,
                      style: TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 11,
                        color: theme.colorScheme.onSurface.withValues(
                          alpha: 0.54,
                        ),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '${result.rssi} DBM',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                      letterSpacing: 1,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Text(
                        'MONITOR',
                        style: TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.w900,
                          color: theme.colorScheme.primary,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Icon(
                        Icons.arrow_forward_ios,
                        size: 9,
                        color: theme.colorScheme.primary,
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class LogEntry {
  final DateTime timestamp;
  final String type;
  final String message;
  final String? sender;
  final String? receiver;
  final int? rssi;
  LogEntry({
    required this.timestamp,
    required this.type,
    required this.message,
    this.sender,
    this.receiver,
    this.rssi,
  });
}

class WifiPacket {
  final DateTime timestamp;
  final String sender;
  final String receiver;
  final int rssi;
  WifiPacket({
    required this.timestamp,
    required this.sender,
    required this.receiver,
    required this.rssi,
  });
}

class WallbreakerMonitorScreen extends StatefulWidget {
  final BluetoothDevice device;
  final String name;
  final ScanResult? initialScanResult;
  const WallbreakerMonitorScreen({
    super.key,
    required this.device,
    required this.name,
    this.initialScanResult,
  });
  @override
  State<WallbreakerMonitorScreen> createState() =>
      _WallbreakerMonitorScreenState();
}

class _WallbreakerMonitorScreenState extends State<WallbreakerMonitorScreen> {
  ScanResult? _latestScanResult;
  final List<LogEntry> _logs = [];
  final Set<String> _uniqueClients = {};
  Timer? _simulationTimer, _channelTimer, _reconnectTimer;
  BluetoothConnectionState _connectionState =
      BluetoothConnectionState.disconnected;
  StreamSubscription<BluetoothConnectionState>? _connectionStateSubscription;
  StreamSubscription<List<int>>? _notificationSubscription;
  bool _isSimMode = false;
  int _currentChannel = 1, _channelIdx = 0;
  final ScrollController _scrollController = ScrollController();
  String? _lastLoggedPayloadSig;
  DateTime? _lastLogTime;

  final List<int> _channelsList = const [
    1,
    2,
    3,
    4,
    5,
    6,
    7,
    8,
    9,
    10,
    11,
    12,
    13,
    36,
    40,
    44,
    48,
    52,
    56,
    60,
    64,
    100,
    104,
    108,
    112,
    116,
    120,
    124,
    128,
    132,
    136,
    140,
  ];

  final List<WifiPacket> _allPackets = [];
  String _receiverFilter = '';
  String? _lockedSender;
  final TextEditingController _receiverFilterController =
      TextEditingController();
  DateTime? _lastLocatorHapticTime;

  @override
  void initState() {
    super.initState();
    _latestScanResult = widget.initialScanResult;
    _isSimMode = widget.device.remoteId.toString().contains('DE:AD:BE:EF');

    _addLog('SYS', 'SYSTEM INTERFACES INITIALIZED.');
    _addLog('SYS', 'TARGET DEVICE: ${widget.name}');
    _addLog('SYS', 'TARGET ID: ${widget.device.remoteId}');

    _channelTimer = Timer.periodic(const Duration(milliseconds: 600), (_) {
      if (mounted) {
        setState(() {
          _channelIdx = (_channelIdx + 1) % _channelsList.length;
          _currentChannel = _channelsList[_channelIdx];
        });
      }
    });

    if (_isSimMode) {
      _startSimulation();
    } else {
      _startListening();
    }
  }

  @override
  void dispose() {
    _connectionStateSubscription?.cancel();
    _notificationSubscription?.cancel();
    _reconnectTimer?.cancel();
    _simulationTimer?.cancel();
    _channelTimer?.cancel();
    _scrollController.dispose();
    _receiverFilterController.dispose();
    if (!_isSimMode) widget.device.disconnect().catchError((_) {});
    super.dispose();
  }

  void _addLog(
    String type,
    String message, {
    String? sender,
    String? receiver,
    int? rssi,
  }) {
    setState(
      () => _logs.add(
        LogEntry(
          timestamp: DateTime.now(),
          type: type,
          message: message,
          sender: sender,
          receiver: receiver,
          rssi: rssi,
        ),
      ),
    );
    if (_scrollController.hasClients) {
      Future.delayed(const Duration(milliseconds: 50), () {
        if (_scrollController.hasClients) {
          _scrollController.animateTo(
            _scrollController.position.maxScrollExtent,
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeOut,
          );
        }
      });
    }
  }

  void _onPacketReceived(
    String sender,
    String receiver,
    int rssi, {
    int? channel,
  }) {
    final packet = WifiPacket(
      timestamp: DateTime.now(),
      sender: sender,
      receiver: receiver,
      rssi: rssi,
    );
    setState(() {
      _allPackets.add(packet);
      _uniqueClients.addAll([sender, receiver]);
    });

    final now = DateTime.now();
    final sig = "${sender}_${receiver}_$rssi";
    if (_lastLoggedPayloadSig != sig ||
        _lastLogTime == null ||
        now.difference(_lastLogTime!) > const Duration(seconds: 2)) {
      _lastLoggedPayloadSig = sig;
      _lastLogTime = now;
      final chanStr = channel != null ? 'CH $channel: ' : '';
      _addLog(
        'WIFI',
        '${chanStr}SNIFFED: $sender -> $receiver | RSSI: $rssi dBm',
        sender: sender,
        receiver: receiver,
        rssi: rssi,
      );
    }

    if (_lockedSender == sender) {
      _triggerLocatorHapticTick(rssi);
    }
  }

  void _triggerLocatorHapticTick(int rssi) {
    final now = DateTime.now();
    if (_lastLocatorHapticTime != null &&
        now.difference(_lastLocatorHapticTime!) <
            const Duration(milliseconds: 300)) {
      return;
    }
    _lastLocatorHapticTime = now;

    if (rssi >= -60) {
      AppHaptics.heavy();
    } else if (rssi >= -80) {
      AppHaptics.medium();
    } else {
      AppHaptics.light();
    }
  }

  void _startSimulation() {
    _addLog('SYS', 'SIMULATION STREAM STARTED.');
    const mockMacs = [
      '74:AC:5F:1B:C0:22',
      '04:D4:C4:F3:D8:1A',
      'D8:9C:E1:45:90:3F',
      'B0:19:C7:E2:4F:9C',
      'AC:DE:48:00:11:22',
    ];
    _simulationTimer = Timer.periodic(const Duration(milliseconds: 1500), (_) {
      if (!mounted) return;
      final bleRssi = -50 - math.Random().nextInt(35);
      if (math.Random().nextDouble() < 0.8) {
        final sender = mockMacs[math.Random().nextInt(mockMacs.length)];
        final receiver = mockMacs.firstWhere((m) => m != sender);
        final wifiRssi = -40 - math.Random().nextInt(56);
        setState(() {
          _latestScanResult = _mockResult(
            widget.name,
            widget.device.remoteId.toString(),
            bleRssi,
            mfrData: {
              0xFFFF: [
                ...sender.split(':').map((s) => int.parse(s, radix: 16)),
                ...receiver.split(':').map((s) => int.parse(s, radix: 16)),
                wifiRssi & 0xFF,
              ],
            },
          );
        });
        _onPacketReceived(sender, receiver, wifiRssi, channel: _currentChannel);
      } else {
        setState(
          () => _latestScanResult = _mockResult(
            widget.name,
            widget.device.remoteId.toString(),
            bleRssi,
          ),
        );
        _addLog('SYS', 'CH $_currentChannel: SCANNING... (NO TARGET)');
      }
    });
  }

  void _startListening() {
    _addLog('SYS', 'SYS: INITIALIZING CONNECTION...');
    _connectionStateSubscription = widget.device.connectionState.listen((
      state,
    ) {
      if (!mounted) return;
      setState(() => _connectionState = state);
      if (state == BluetoothConnectionState.connected) {
        _addLog('SYS', 'SYS: CONNECTED');
        _setupGatt();
      } else if (state == BluetoothConnectionState.disconnected) {
        _addLog('SYS', 'SYS: DISCONNECTED, RETRYING...');
        _reconnect();
      }
    });
    _connect();
  }

  Future<void> _connect() async {
    try {
      _addLog('SYS', 'SYS: CONNECTING...');
      await widget.device.connect(
        license: License.nonprofit,
        autoConnect: false,
        timeout: const Duration(seconds: 5),
      );
    } catch (e) {
      if (mounted &&
          _connectionState == BluetoothConnectionState.disconnected) {
        _reconnect();
      }
    }
  }

  void _reconnect() {
    _reconnectTimer?.cancel();
    _reconnectTimer = Timer(const Duration(seconds: 2), () {
      if (mounted &&
          _connectionState == BluetoothConnectionState.disconnected) {
        _connect();
      }
    });
  }

  Future<void> _setupGatt() async {
    try {
      _addLog('SYS', 'SYS: NEGOTIATING MTU (REQUESTING 247)...');
      try {
        await widget.device.requestMtu(247, timeout: 5);
      } catch (_) {}
      _addLog('SYS', 'SYS: DISCOVERING GATT SERVICES...');
      final services = await widget.device.discoverServices();
      BluetoothCharacteristic? targetChar;

      for (var s in services) {
        final sUuid = s.uuid.toString().toLowerCase().replaceAll('-', '');
        if (sUuid == 'ffe0' || sUuid == '0000ffe000001000800000805f9b34fb') {
          for (var c in s.characteristics) {
            final cUuid = c.uuid.toString().toLowerCase().replaceAll('-', '');
            if (cUuid == 'ffe1' ||
                cUuid == '0000ffe100001000800000805f9b34fb') {
              targetChar = c;
              break;
            }
          }
          break;
        }
      }

      if (targetChar != null) {
        _addLog('SYS', 'SYS: SUBSCRIBING TO NOTIFICATIONS...');
        await targetChar.setNotifyValue(true);
        _notificationSubscription?.cancel();
        _notificationSubscription = targetChar.onValueReceived.listen(
          _parseBatchedPackets,
        );
      } else {
        _addLog(
          'SYS',
          'SYS: ERROR - CUSTOM GATT SERVICE/CHARACTERISTIC NOT FOUND.',
        );
        for (var s in services) {
          _addLog(
            'SYS',
            ' - SVC: ${s.uuid} [CHARS: ${s.characteristics.map((c) => c.uuid.toString()).join(", ")}]',
          );
        }
      }
    } catch (e) {
      _addLog('SYS', 'SYS: GATT SETUP ERROR: $e');
    }
  }

  String _formatMac(List<int> mac) => mac
      .map((b) => b.toRadixString(16).padLeft(2, '0').toUpperCase())
      .join(':');

  void _parseBatchedPackets(List<int> bytes) {
    if (bytes.length < 13) return;
    final int numPackets = bytes.length ~/ 13;

    for (int i = 0; i < numPackets; i++) {
      final offset = i * 13;
      final senderMacBytes = bytes.sublist(offset, offset + 6);
      if (senderMacBytes.every((b) => b == 0)) continue;

      final receiverMacBytes = bytes.sublist(offset + 6, offset + 12);
      int rssi = bytes[offset + 12];
      if (rssi >= 128) rssi -= 256;

      final senderMac = _formatMac(senderMacBytes);
      final receiverMac = _formatMac(receiverMacBytes);

      setState(() {
        _latestScanResult = _mockResult(
          widget.name,
          widget.device.remoteId.toString(),
          rssi,
          mfrData: {0xFFFF: bytes.sublist(offset, offset + 13)},
        );
      });

      _onPacketReceived(senderMac, receiverMac, rssi);
    }
  }

  void _injectSimulatedPacket() {
    AppHaptics.light();
    if (!_isSimMode) return;
    const macs = [
      'AC:DE:48:88:99:AA',
      'AA:BB:CC:DD:EE:FF',
      '00:11:22:33:44:55',
      '74:AC:5F:1B:C0:22',
      '04:D4:C4:F3:D8:1A',
    ];
    final sender = macs[math.Random().nextInt(macs.length)];
    final receiver = macs.firstWhere((m) => m != sender);
    final wifiRssi = -30 - math.Random().nextInt(30);

    setState(() {
      _latestScanResult = _mockResult(
        widget.name,
        widget.device.remoteId.toString(),
        -45,
        mfrData: {
          0xFFFF: [
            ...sender.split(':').map((s) => int.parse(s, radix: 16)),
            ...receiver.split(':').map((s) => int.parse(s, radix: 16)),
            wifiRssi & 0xFF,
          ],
        },
      );
    });
    _onPacketReceived(sender, receiver, wifiRssi, channel: _currentChannel);
  }

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    final theme = Theme.of(context);
    final bleRssi = _latestScanResult?.rssi ?? -99;

    Color signalStrengthColor = theme.colorScheme.onSurface.withValues(
      alpha: 0.5,
    );
    if (_latestScanResult != null) {
      signalStrengthColor = bleRssi >= -60
          ? Colors.green
          : (bleRssi >= -80 ? Colors.blue : Colors.red);
    }

    final filteredLogs = _logs;

    final Map<String, WifiPacket> receiverMap = {};
    for (var p in _allPackets) {
      if (_receiverFilter.trim().isEmpty ||
          p.receiver.toUpperCase().contains(_receiverFilter.toUpperCase())) {
        receiverMap[p.receiver] = p;
      }
    }
    final activeReceivers = receiverMap.values.toList()
      ..sort((a, b) => b.timestamp.compareTo(a.timestamp));

    final Map<String, int> senderCounts = {};
    for (var p in _allPackets) {
      senderCounts[p.sender] = (senderCounts[p.sender] ?? 0) + 1;
    }

    final Map<String, WifiPacket> senderMap = {};
    for (var p in _allPackets) {
      if (_receiverFilter.trim().isEmpty ||
          p.receiver.toUpperCase().contains(_receiverFilter.toUpperCase())) {
        senderMap[p.sender] = p;
      }
    }

    final Map<String, double> senderAvgRssi = {};
    for (var sender in senderMap.keys) {
      int count = 0;
      double sum = 0;
      for (int i = _allPackets.length - 1; i >= 0; i--) {
        final p = _allPackets[i];
        if (p.sender == sender) {
          sum += p.rssi;
          count++;
          if (count == 5) break;
        }
      }
      senderAvgRssi[sender] = count > 0 ? sum / count : -999.0;
    }

    final activeSenders = senderMap.values.toList()
      ..sort((a, b) {
        final avgA = senderAvgRssi[a.sender] ?? -999.0;
        final avgB = senderAvgRssi[b.sender] ?? -999.0;
        return avgB.compareTo(avgA);
      });

    return Scaffold(
      resizeToAvoidBottomInset: false,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              CyberHeader(title: widget.name),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  border: Border.all(color: primary, width: 2),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _BlinkingIndicator(
                          color: _isSimMode
                              ? Colors.cyan
                              : (_connectionState ==
                                        BluetoothConnectionState.connected
                                    ? Colors.green
                                    : Colors.red),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          _isSimMode
                              ? 'SIMULATION'
                              : (_connectionState ==
                                        BluetoothConnectionState.connected
                                    ? 'CONNECTED'
                                    : 'DISCONNECTED'),
                          style: TextStyle(
                            fontFamily: 'monospace',
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: primary,
                          ),
                        ),
                      ],
                    ),
                    Container(width: 2, height: 12, color: primary),
                    Text(
                      _latestScanResult != null
                          ? 'RSSI: $bleRssi DBM'
                          : 'RSSI: N/A',
                      style: TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: _latestScanResult != null
                            ? signalStrengthColor
                            : primary,
                      ),
                    ),
                    Container(width: 2, height: 12, color: primary),
                    Text(
                      'CLIENTS: ${_uniqueClients.length}',
                      style: TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: primary,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              // Receiver Filter Card
              Container(
                decoration: BoxDecoration(
                  border: Border.all(color: primary, width: 2),
                  color: theme.colorScheme.surface,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 4,
                      ),
                      child: Row(
                        children: [
                          Text(
                            'RCV FILTER:',
                            style: TextStyle(
                              fontFamily: 'monospace',
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: primary,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: TextField(
                              enableSuggestions: false,
                              autocorrect: false,
                              textCapitalization: TextCapitalization.characters,
                              controller: _receiverFilterController,
                              style: TextStyle(
                                fontFamily: 'monospace',
                                fontSize: 11,
                                color: primary,
                              ),
                              decoration: InputDecoration(
                                hintText: 'ENTER RECEIVER MAC ADDRESS...',
                                hintStyle: TextStyle(
                                  fontFamily: 'monospace',
                                  fontSize: 9,
                                  color: primary.withValues(alpha: 0.36),
                                ),
                                border: InputBorder.none,
                                isDense: true,
                                contentPadding: const EdgeInsets.symmetric(
                                  vertical: 6,
                                ),
                              ),
                              onChanged: (val) {
                                setState(() {
                                  _receiverFilter = val;
                                });
                              },
                            ),
                          ),
                          if (_receiverFilter.isNotEmpty)
                            IconButton(
                              icon: Icon(Icons.close, size: 14, color: primary),
                              onPressed: () {
                                setState(() {
                                  _receiverFilterController.clear();
                                  _receiverFilter = '';
                                });
                              },
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(),
                            ),
                        ],
                      ),
                    ),
                    if (activeReceivers.isNotEmpty) ...[
                      Container(
                        height: 1,
                        color: primary.withValues(alpha: 0.2),
                      ),
                      SizedBox(
                        height: 28,
                        child: ListView.builder(
                          scrollDirection: Axis.horizontal,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          itemCount: activeReceivers.length.clamp(0, 8),
                          itemBuilder: (context, idx) {
                            final mac = activeReceivers[idx].receiver;
                            final isSelected =
                                _receiverFilter.toUpperCase() ==
                                mac.toUpperCase();
                            return GestureDetector(
                              onTap: () {
                                AppHaptics.selection();
                                setState(() {
                                  if (isSelected) {
                                    _receiverFilterController.clear();
                                    _receiverFilter = '';
                                  } else {
                                    _receiverFilterController.text = mac;
                                    _receiverFilter = mac;
                                  }
                                });
                              },
                              onLongPress: () {
                                AppHaptics.selection();
                                OuiLookupBottomSheet.show(
                                  context,
                                  initialMac: mac,
                                );
                              },
                              child: Container(
                                margin: const EdgeInsets.only(right: 6),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 6,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: isSelected
                                      ? primary
                                      : Colors.transparent,
                                  border: Border.all(color: primary, width: 1),
                                ),
                                alignment: Alignment.center,
                                child: Text(
                                  mac,
                                  style: TextStyle(
                                    fontFamily: 'monospace',
                                    fontSize: 8,
                                    fontWeight: FontWeight.bold,
                                    color: isSelected
                                        ? theme.colorScheme.onPrimary
                                        : primary,
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 16),
              // Target Lock / RSSI Graph Panel
              if (_lockedSender == null)
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: primary.withValues(alpha: 0.02),
                    border: Border.all(color: primary, width: 2),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.gps_fixed, size: 14, color: primary),
                          const SizedBox(width: 6),
                          Text(
                            _receiverFilter.trim().isEmpty
                                ? 'TARGET LOCK SELECTOR'
                                : 'TARGET LOCK SELECTOR (${activeSenders.length} CLIENTS)',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 1.5,
                              color: primary,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      if (activeSenders.isEmpty)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          child: Text(
                            'AWAITING SENDER SIGNALS...',
                            style: TextStyle(
                              fontFamily: 'monospace',
                              fontSize: 11,
                              color: primary.withValues(alpha: 0.5),
                              fontWeight: FontWeight.bold,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        )
                      else ...[
                        Text(
                          'SELECT A SENDER MAC BELOW TO LOCK ONTO ITS RSSI SIGNAL STRENGTH:',
                          style: TextStyle(
                            fontFamily: 'monospace',
                            fontSize: 8,
                            color: primary.withValues(alpha: 0.7),
                          ),
                        ),
                        const SizedBox(height: 8),
                        SizedBox(
                          height: 74,
                          child: ListView.builder(
                            scrollDirection: Axis.horizontal,
                            physics: const BouncingScrollPhysics(),
                            itemCount: activeSenders.length,
                            itemBuilder: (context, idx) {
                              final p = activeSenders[idx];
                              return GestureDetector(
                                onTap: () {
                                  AppHaptics.success();
                                  setState(() {
                                    _lockedSender = p.sender;
                                  });
                                },
                                onLongPress: () {
                                  AppHaptics.selection();
                                  OuiLookupBottomSheet.show(
                                    context,
                                    initialMac: p.sender,
                                  );
                                },
                                child: Container(
                                  margin: const EdgeInsets.only(right: 8),
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: theme.colorScheme.surface,
                                    border: Border.all(
                                      color: primary,
                                      width: 1.5,
                                    ),
                                  ),
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        p.sender,
                                        style: const TextStyle(
                                          fontFamily: 'monospace',
                                          fontSize: 10,
                                          fontWeight: FontWeight.w900,
                                        ),
                                      ),
                                      (() {
                                        final vendor = OuiDatabase().lookup(
                                          p.sender,
                                        );
                                        return Container(
                                          constraints: const BoxConstraints(
                                            maxWidth: 120,
                                          ),
                                          child: Text(
                                            vendor?.organization
                                                    .toUpperCase() ??
                                                ' ',
                                            style: TextStyle(
                                              fontFamily: 'monospace',
                                              fontSize: 7,
                                              fontWeight: FontWeight.bold,
                                              color: vendor == null
                                                  ? Colors.transparent
                                                  : primary.withValues(
                                                      alpha: 0.6,
                                                    ),
                                            ),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        );
                                      })(),
                                      const SizedBox(height: 2),
                                      Row(
                                        children: [
                                          Icon(
                                            Icons.wifi_tethering,
                                            size: 10,
                                            color: p.rssi >= -65
                                                ? Colors.green
                                                : (p.rssi >= -80
                                                      ? Colors.blue
                                                      : Colors.orange),
                                          ),
                                          const SizedBox(width: 4),
                                          Text(
                                            '${p.rssi} dBm (${senderCounts[p.sender] ?? 0} pkts)',
                                            style: TextStyle(
                                              fontFamily: 'monospace',
                                              fontSize: 9,
                                              fontWeight: FontWeight.bold,
                                              color: p.rssi >= -65
                                                  ? Colors.green
                                                  : (p.rssi >= -80
                                                        ? Colors.blue
                                                        : Colors.orange),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                      ],
                    ],
                  ),
                )
              else
                (() {
                  final lockedPackets = _allPackets
                      .where((p) => p.sender == _lockedSender)
                      .toList();
                  final latestLockedRssi = lockedPackets.isNotEmpty
                      ? lockedPackets.last.rssi
                      : -99;
                  int minRssi = -100;
                  int maxRssi = -30;
                  if (lockedPackets.isNotEmpty) {
                    minRssi = lockedPackets.map((p) => p.rssi).reduce(math.min);
                    maxRssi = lockedPackets.map((p) => p.rssi).reduce(math.max);
                  }
                  return Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: primary.withValues(alpha: 0.02),
                      border: Border.all(color: primary, width: 2),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: GestureDetector(
                                onTap: () {
                                  if (_lockedSender != null) {
                                    AppHaptics.selection();
                                    OuiLookupBottomSheet.show(
                                      context,
                                      initialMac: _lockedSender,
                                    );
                                  }
                                },
                                child: FittedBox(
                                  fit: BoxFit.scaleDown,
                                  alignment: Alignment.centerLeft,
                                  child: Text(
                                    'MAC: $_lockedSender',
                                    style: TextStyle(
                                      fontFamily: 'monospace',
                                      fontSize: 14,
                                      fontWeight: FontWeight.w900,
                                      color: primary,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            GestureDetector(
                              onTap: () {
                                AppHaptics.warning();
                                setState(() {
                                  _lockedSender = null;
                                });
                              },
                              child: const Padding(
                                padding: EdgeInsets.symmetric(horizontal: 4),
                                child: Icon(
                                  Icons.close,
                                  size: 20,
                                  color: Colors.redAccent,
                                ),
                              ),
                            ),
                          ],
                        ),
                        (() {
                          final vendor = OuiDatabase().lookup(
                            _lockedSender ?? '',
                          );
                          if (vendor == null) return const SizedBox.shrink();
                          return Padding(
                            padding: const EdgeInsets.only(top: 4.0),
                            child: Text(
                              'VENDOR: ${vendor.organization.toUpperCase()}${vendor.country != null ? ' [${getFlagEmoji(vendor.country!)} ${vendor.country}]' : ''}',
                              style: TextStyle(
                                fontFamily: 'monospace',
                                fontSize: 9,
                                fontWeight: FontWeight.bold,
                                color: primary.withValues(alpha: 0.7),
                              ),
                            ),
                          );
                        })(),
                        const SizedBox(height: 8),
                        // Graph of RSSI over time
                        RssiGraphWidget(packets: lockedPackets, height: 120),
                        const SizedBox(height: 8),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: FittedBox(
                                fit: BoxFit.scaleDown,
                                alignment: Alignment.centerLeft,
                                child: Text(
                                  'MIN: $minRssi dBm / MAX: $maxRssi dBm / PKTS: ${lockedPackets.length}',
                                  style: TextStyle(
                                    fontFamily: 'monospace',
                                    fontSize: 8,
                                    color: primary.withValues(alpha: 0.6),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'CURRENT: $latestLockedRssi dBm',
                              style: TextStyle(
                                fontFamily: 'monospace',
                                fontSize: 9,
                                fontWeight: FontWeight.bold,
                                color: latestLockedRssi >= -65
                                    ? Colors.green
                                    : (latestLockedRssi >= -80
                                          ? Colors.blue
                                          : Colors.orange),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  );
                })(),
              const SizedBox(height: 16),
              Text(
                'STREAM LOG TERMINAL',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1,
                  color: primary,
                ),
              ),
              const SizedBox(height: 6),
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFF0F0F0F),
                    border: Border.all(color: primary, width: 2),
                  ),
                  child: filteredLogs.isEmpty
                      ? const Center(
                          child: Text(
                            'NO STREAM DATA RECEIVED',
                            style: TextStyle(
                              fontFamily: 'monospace',
                              color: Colors.white24,
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        )
                      : ListView.builder(
                          controller: _scrollController,
                          physics: const BouncingScrollPhysics(),
                          itemCount: filteredLogs.length,
                          itemBuilder: (context, index) {
                            final log = filteredLogs[index];
                            final timeStr =
                                "${log.timestamp.toIso8601String().substring(11, 19)}.${log.timestamp.millisecond ~/ 100}";
                            final typeColor = log.type == 'WIFI'
                                ? Colors.greenAccent
                                : (log.type == 'BLE'
                                      ? Colors.purpleAccent
                                      : Colors.cyanAccent);
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 4.0),
                              child: RichText(
                                text: TextSpan(
                                  style: const TextStyle(
                                    fontFamily: 'monospace',
                                    fontSize: 10,
                                    color: Colors.white,
                                    height: 1.2,
                                  ),
                                  children: [
                                    TextSpan(
                                      text: '[$timeStr] ',
                                      style: const TextStyle(
                                        color: Colors.white54,
                                      ),
                                    ),
                                    TextSpan(
                                      text: '${log.type}: ',
                                      style: TextStyle(
                                        color: typeColor,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    TextSpan(text: log.message),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                ),
              ),
              if (_isSimMode) ...[
                const SizedBox(height: 12),
                CyberButton(
                  text: 'INJECT',
                  color: primary,
                  onTap: _injectSimulatedPacket,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class RssiGraphWidget extends StatelessWidget {
  final List<WifiPacket> packets;
  final double? height;
  const RssiGraphWidget({super.key, required this.packets, this.height});

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    final color = primary.withValues(alpha: 0.3);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      height: height,
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(border: Border.all(color: color, width: 1.5)),
      child: CustomPaint(
        painter: RssiGraphPainter(packets, labelColor: color, isDark: isDark),
        child: Container(),
      ),
    );
  }
}

class RssiGraphPainter extends CustomPainter {
  final List<WifiPacket> packets;
  final int maxPoints;
  final Color labelColor;
  final bool isDark;

  RssiGraphPainter(
    this.packets, {
    this.maxPoints = 40,
    required this.labelColor,
    this.isDark = true,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paintGrid = Paint()
      ..color = labelColor.withValues(alpha: 0.2)
      ..strokeWidth = 1.0;

    final graphColor = isDark ? Colors.cyanAccent : const Color(0xFF007C91);

    final paintLine = Paint()
      ..color = graphColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0
      ..strokeCap = StrokeCap.round;

    final paintFill = Paint()..style = PaintingStyle.fill;

    const minRssi = -100.0;
    const maxRssi = -30.0;
    final double range = maxRssi - minRssi;
    const double leftOffset = 50.0;

    final double stepY = size.height / 4;
    for (int i = 0; i <= 4; i++) {
      final y = i * stepY;

      // Draw grid line only for internal divisions (not top and bottom edges)
      // and start from leftOffset to avoid touching/overlapping the dBm labels.
      if (i > 0 && i < 4) {
        canvas.drawLine(
          Offset(leftOffset, y),
          Offset(size.width, y),
          paintGrid,
        );
      }

      final rssiVal = (maxRssi - (i * (range / 4))).round();
      final textPainter = TextPainter(
        text: TextSpan(
          text: '$rssiVal dBm',
          style: TextStyle(
            color: labelColor,
            fontSize: 8,
            fontFamily: 'monospace',
          ),
        ),
        textDirection: TextDirection.ltr,
      );
      textPainter.layout();
      textPainter.paint(canvas, Offset(4, y - (i == 0 ? 0 : 8)));
    }

    if (packets.isEmpty) return;

    final displayPackets = packets.length > maxPoints
        ? packets.sublist(packets.length - maxPoints)
        : packets;

    final double stepX = (size.width - leftOffset) / math.max(1, maxPoints - 1);
    final path = Path();
    final fillPath = Path();

    Offset getOffset(int index, int rssi) {
      final x = leftOffset + index * stepX;
      final clampedRssi = rssi.clamp(minRssi.toInt(), maxRssi.toInt());
      final y = size.height - ((clampedRssi - minRssi) / range) * size.height;
      return Offset(x, y);
    }

    final firstOffset = getOffset(0, displayPackets[0].rssi);
    path.moveTo(firstOffset.dx, firstOffset.dy);
    fillPath.moveTo(firstOffset.dx, size.height);
    fillPath.lineTo(firstOffset.dx, firstOffset.dy);

    for (int i = 1; i < displayPackets.length; i++) {
      final offset = getOffset(i, displayPackets[i].rssi);
      path.lineTo(offset.dx, offset.dy);
      fillPath.lineTo(offset.dx, offset.dy);
    }

    fillPath.lineTo(
      getOffset(displayPackets.length - 1, displayPackets.last.rssi).dx,
      size.height,
    );
    fillPath.close();

    final fillGradient = LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [
        graphColor.withValues(alpha: isDark ? 0.2 : 0.15),
        graphColor.withValues(alpha: 0.0),
      ],
    );
    paintFill.shader = fillGradient.createShader(
      Rect.fromLTWH(0, 0, size.width, size.height),
    );
    canvas.drawPath(fillPath, paintFill);
    canvas.drawPath(path, paintLine);

    if (displayPackets.isNotEmpty) {
      final lastIdx = displayPackets.length - 1;
      final lastOffset = getOffset(lastIdx, displayPackets.last.rssi);

      final paintPulseOuter = Paint()
        ..color = graphColor.withValues(alpha: 0.3)
        ..style = PaintingStyle.fill;
      final paintPulseInner = Paint()
        ..color = graphColor
        ..style = PaintingStyle.fill;

      canvas.drawCircle(lastOffset, 5.0, paintPulseOuter);
      canvas.drawCircle(lastOffset, 2.5, paintPulseInner);
    }
  }

  @override
  bool shouldRepaint(covariant RssiGraphPainter oldDelegate) {
    return oldDelegate.packets != packets || oldDelegate.isDark != isDark;
  }
}

class _BlinkingIndicator extends StatefulWidget {
  final Color color;
  const _BlinkingIndicator({required this.color});
  @override
  State<_BlinkingIndicator> createState() => _BlinkingIndicatorState();
}

class _BlinkingIndicatorState extends State<_BlinkingIndicator> {
  late final Timer _timer = Timer.periodic(
    const Duration(milliseconds: 600),
    (_) => mounted ? setState(() => _visible = !_visible) : null,
  );
  bool _visible = true;
  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedOpacity(
    opacity: _visible ? 1.0 : 0.0,
    duration: const Duration(milliseconds: 100),
    child: Container(width: 8, height: 8, color: widget.color),
  );
}

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});
  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _hapticsEnabled = AppHaptics.enabled;
  String _appVersion = 'UNKNOWN';

  @override
  void initState() {
    super.initState();
    _loadAppVersion();
  }

  Future<void> _loadAppVersion() async {
    try {
      final packageInfo = await PackageInfo.fromPlatform();
      setState(() => _appVersion = packageInfo.version);
    } catch (_) {}
  }

  Future<void> _toggleHaptics(bool value) async {
    setState(() => _hapticsEnabled = value);
    await AppHaptics.setEnabled(value);
    AppHaptics.light();
  }

  Future<void> _openDeveloperWebsite() async {
    AppHaptics.light();
    try {
      await launchUrl(
        Uri.parse('https://alexinabox.de'),
        mode: LaunchMode.externalApplication,
      );
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const CyberHeader(title: 'SETTINGS'),
              const SizedBox(height: 16),
              Container(height: 3, color: primary),
              const SizedBox(height: 24),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  border: Border.all(color: primary, width: 2),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'HAPTIC FEEDBACK',
                            style: TextStyle(
                              fontWeight: FontWeight.w900,
                              fontSize: 13,
                              letterSpacing: 1,
                              color: primary,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Vibrate on button clicks and actions',
                            style: TextStyle(
                              fontFamily: 'monospace',
                              fontSize: 10,
                              color: Theme.of(
                                context,
                              ).colorScheme.onSurface.withValues(alpha: 0.6),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Switch(
                      value: _hapticsEnabled,
                      onChanged: _toggleHaptics,
                      activeThumbColor: primary,
                      activeTrackColor: primary.withValues(alpha: 0.2),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              const _OuiUpdateCard(),
              const Spacer(),
              CyberButton(
                text: '© ALEXANDER BETKE • v$_appVersion',
                color: primary.withValues(alpha: 0.03),
                textColor: primary,
                fontSize: 11,
                onTap: _openDeveloperWebsite,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── OUI Database Update Card ────────────────────────────────────────────────

class _OuiUpdateCard extends StatefulWidget {
  const _OuiUpdateCard();

  @override
  State<_OuiUpdateCard> createState() => _OuiUpdateCardState();
}

enum _DownloadState { idle, downloading, success, error }

class _OuiUpdateCardState extends State<_OuiUpdateCard> {
  _DownloadState _dlState = _DownloadState.idle;
  double _progress = 0.0;
  String _errorMsg = '';

  Future<void> _update() async {
    AppHaptics.light();
    setState(() {
      _dlState = _DownloadState.downloading;
      _progress = 0.0;
    });
    try {
      await OuiDatabase().update(
        onProgress: (p) {
          if (mounted) setState(() => _progress = p);
        },
      );
      if (mounted) {
        setState(() => _dlState = _DownloadState.success);
        AppHaptics.success();
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _dlState = _DownloadState.error;
          _errorMsg = e.toString();
        });
        AppHaptics.error();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final primary = theme.colorScheme.primary;
    final muted = theme.colorScheme.onSurface.withValues(alpha: 0.55);
    final db = OuiDatabase();
    final lastUpdated = db.lastUpdated;
    final neverUpdated = !db.wasUpdatedByApp;

    String lastUpdatedStr;
    if (lastUpdated == null) {
      lastUpdatedStr = 'BUNDLED (never updated)';
    } else {
      final d = lastUpdated;
      lastUpdatedStr =
          '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}  '
          '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
    }

    return Stack(
      clipBehavior: Clip.none,
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            border: Border.all(color: primary, width: 2),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header row
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'OUI VENDOR DATABASE',
                          style: TextStyle(
                            fontWeight: FontWeight.w900,
                            fontSize: 13,
                            letterSpacing: 1,
                            color: primary,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Offline MAC address vendor lookup',
                          style: TextStyle(
                            fontFamily: 'monospace',
                            fontSize: 10,
                            color: muted,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  if (_dlState != _DownloadState.downloading)
                    GestureDetector(
                      onTap: _dlState == _DownloadState.downloading
                          ? null
                          : _update,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(color: primary),
                        child: Text(
                          'UPDATE',
                          style: TextStyle(
                            fontFamily: 'monospace',
                            fontSize: 10,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 1,
                            color: theme.colorScheme.onPrimary,
                          ),
                        ),
                      ),
                    ),
                ],
              ),

              const SizedBox(height: 12),
              Container(height: 1, color: primary.withValues(alpha: 0.2)),
              const SizedBox(height: 12),

              // Stats row
              Row(
                children: [
                  _StatChip(
                    label: 'PREFIXES',
                    value: db.prefixCount > 0 ? '${db.prefixCount}' : '—',
                    primary: primary,
                  ),
                  const SizedBox(width: 16),
                  _StatChip(
                    label: 'LAST UPDATED',
                    value: lastUpdatedStr,
                    primary: primary,
                    valueColor: OuiDatabase().isStale ? Colors.orange : null,
                  ),
                ],
              ),

              // Out-of-date warning
              if (neverUpdated) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 7,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.orange.withValues(alpha: 0.08),
                    border: Border.all(color: Colors.orange, width: 1),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.warning_amber_rounded,
                        size: 13,
                        color: Colors.orange,
                      ),
                      const SizedBox(width: 7),
                      Expanded(
                        child: Text(
                          'Using bundled DB — may be out of date. Tap UPDATE to fetch the latest.',
                          style: const TextStyle(
                            fontFamily: 'monospace',
                            fontSize: 9,
                            color: Colors.orange,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],

              // Download progress
              if (_dlState == _DownloadState.downloading) ...[
                const SizedBox(height: 14),
                Row(
                  children: [
                    Text(
                      'DOWNLOADING',
                      style: TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 9,
                        fontWeight: FontWeight.bold,
                        color: primary,
                      ),
                    ),
                    const Spacer(),
                    Text(
                      '${(_progress * 100).toStringAsFixed(0)}%',
                      style: TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 9,
                        fontWeight: FontWeight.bold,
                        color: primary,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                ClipRect(
                  child: SizedBox(
                    height: 3,
                    child: LinearProgressIndicator(
                      value: _progress,
                      backgroundColor: primary.withValues(alpha: 0.15),
                      valueColor: AlwaysStoppedAnimation<Color>(primary),
                    ),
                  ),
                ),
              ],

              // Success banner
              if (_dlState == _DownloadState.success) ...[
                const SizedBox(height: 12),
                Row(
                  children: [
                    Icon(
                      Icons.check_circle_outline,
                      size: 13,
                      color: Colors.green,
                    ),
                    const SizedBox(width: 7),
                    Text(
                      'DATABASE UPDATED SUCCESSFULLY',
                      style: const TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 9,
                        fontWeight: FontWeight.bold,
                        color: Colors.green,
                      ),
                    ),
                  ],
                ),
              ],

              // Error banner
              if (_dlState == _DownloadState.error) ...[
                const SizedBox(height: 12),
                Row(
                  children: [
                    const Icon(
                      Icons.error_outline,
                      size: 13,
                      color: Colors.redAccent,
                    ),
                    const SizedBox(width: 7),
                    Expanded(
                      child: Text(
                        'UPDATE FAILED: $_errorMsg',
                        style: const TextStyle(
                          fontFamily: 'monospace',
                          fontSize: 9,
                          fontWeight: FontWeight.bold,
                          color: Colors.redAccent,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
        if (OuiDatabase().isStale)
          Positioned(
            top: -6,
            right: -6,
            child: Container(
              width: 13,
              height: 13,
              decoration: const BoxDecoration(
                color: Colors.orange,
                shape: BoxShape.circle,
              ),
            ),
          ),
      ],
    );
  }
}

class _StatChip extends StatelessWidget {
  final String label;
  final String value;
  final Color primary;
  final Color? valueColor;
  const _StatChip({
    required this.label,
    required this.value,
    required this.primary,
    this.valueColor,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontFamily: 'monospace',
            fontSize: 8,
            color: primary.withValues(alpha: 0.5),
            fontWeight: FontWeight.bold,
            letterSpacing: 0.5,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: TextStyle(
            fontFamily: 'monospace',
            fontSize: 10,
            color: valueColor ?? primary,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────

class AppHaptics {
  static bool enabled = true;
  static Future<void> init() async => enabled =
      (await SharedPreferences.getInstance()).getBool('haptics_enabled') ??
      true;
  static Future<void> setEnabled(bool val) async {
    enabled = val;
    await (await SharedPreferences.getInstance()).setBool(
      'haptics_enabled',
      val,
    );
  }

  static void light() => _trigger(HapticsType.light);
  static void medium() => _trigger(HapticsType.medium);
  static void heavy() => _trigger(HapticsType.heavy);
  static void selection() => _trigger(HapticsType.selection);
  static void success() => _trigger(HapticsType.success);
  static void warning() => _trigger(HapticsType.warning);
  static void error() => _trigger(HapticsType.error);
  static Future<void> _trigger(HapticsType type) async {
    if (enabled && await Haptics.canVibrate()) await Haptics.vibrate(type);
  }
}

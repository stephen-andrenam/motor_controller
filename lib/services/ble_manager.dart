import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';

// ── UUIDs must match the Arduino sketch exactly ───────────────
const _kServiceUuid = '12345678-1234-5678-1234-56789abcdef0';
const _kCharUuid    = '12345678-1234-5678-1234-56789abcdef1';
const _kDeviceName  = 'ESP32 Motor';

enum BleStatus { idle, scanning, connecting, connected, error }

/// Singleton BLE manager.  Widgets listen via [addListener] /
/// [ListenableBuilder] — no extra state-management package needed.
class BleManager extends ChangeNotifier {
  BleManager._();
  static final BleManager instance = BleManager._();

  // ── Public state ────────────────────────────────────────────
  BleStatus get status         => _status;
  bool      get isConnected    => _status == BleStatus.connected;
  String    get statusMessage  => _statusMessage;

  // ── Private state ───────────────────────────────────────────
  BleStatus  _status        = BleStatus.idle;
  String     _statusMessage = 'Not connected';

  BluetoothDevice?         _device;
  BluetoothCharacteristic? _char;
  StreamSubscription?      _connStateSub;

  // ── Connect ─────────────────────────────────────────────────
  Future<void> connect() async {
    if (_status == BleStatus.scanning || _status == BleStatus.connecting) return;

    // Check adapter
    final adapterState = await FlutterBluePlus.adapterState.first;
    if (adapterState != BluetoothAdapterState.on) {
      _set(BleStatus.error, 'Bluetooth is off — enable it and try again');
      return;
    }

    _set(BleStatus.scanning, 'Scanning for $_kDeviceName…');

    BluetoothDevice? found;

    final scanSub = FlutterBluePlus.onScanResults.listen((results) {
      for (final r in results) {
        if (r.device.platformName == _kDeviceName) {
          found = r.device;
          FlutterBluePlus.stopScan();
        }
      }
    });

    await FlutterBluePlus.startScan(timeout: const Duration(seconds: 10));
    // Wait until the scan has fully stopped (timeout or we called stopScan)
    await FlutterBluePlus.isScanning.where((v) => !v).first;
    await scanSub.cancel();

    if (found == null) {
      _set(BleStatus.error, '$_kDeviceName not found — is the ESP32 on?');
      return;
    }

    _set(BleStatus.connecting, 'Connecting…');
    _device = found;

    // Track connection-state changes (handles unexpected disconnect)
    _connStateSub?.cancel();
    _connStateSub = found!.connectionState.listen((state) {
      if (state == BluetoothConnectionState.disconnected) {
        _char = null;
        _set(BleStatus.idle, 'Disconnected');
      }
    });

    try {
      await found!.connect(
        license: License.free,
        timeout: const Duration(seconds: 10),
      );
    } catch (e) {
      _set(BleStatus.error, 'Connection failed: $e');
      return;
    }

    // Discover services
    List<BluetoothService> services;
    try {
      services = await found!.discoverServices();
    } catch (e) {
      _set(BleStatus.error, 'Service discovery failed: $e');
      return;
    }

    for (final svc in services) {
      if (svc.serviceUuid.toString().toLowerCase() == _kServiceUuid) {
        for (final c in svc.characteristics) {
          if (c.characteristicUuid.toString().toLowerCase() == _kCharUuid) {
            _char = c;
            break;
          }
        }
      }
    }

    if (_char == null) {
      _set(BleStatus.error, 'Motor characteristic not found on device');
      await found!.disconnect();
      return;
    }

    _set(BleStatus.connected, 'Connected to $_kDeviceName');
  }

  // ── Disconnect ───────────────────────────────────────────────
  Future<void> disconnect() async {
    await _device?.disconnect();
    _char = null;
    _connStateSub?.cancel();
    _set(BleStatus.idle, 'Disconnected');
  }

  // ── Send a command string ────────────────────────────────────
  /// Returns true on success, false if not connected or write failed.
  Future<bool> sendCommand(String command) async {
    if (_char == null || !isConnected) return false;
    try {
      await _char!.write(
        utf8.encode(command),
        withoutResponse: false,
      );
      return true;
    } catch (e) {
      _set(BleStatus.error, 'Send failed: $e');
      return false;
    }
  }

  // ── Internal ─────────────────────────────────────────────────
  void _set(BleStatus s, String msg) {
    _status        = s;
    _statusMessage = msg;
    notifyListeners();
  }
}

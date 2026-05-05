import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';

// ── UUIDs must match the Arduino sketch exactly ───────────────
const _kServiceUuid = '12345678-1234-5678-1234-56789abcdef0';
const _kCharUuid    = '12345678-1234-5678-1234-56789abcdef1';
const _kDeviceName  = 'ESP32 Motor';

enum BleStatus { idle, scanning, connecting, connected, error }

/// Singleton BLE manager.
/// Registered as a [WidgetsBindingObserver] in main() so it can
/// disconnect cleanly when the app is backgrounded, preventing iOS
/// CoreBluetooth from queuing stale events that crash the next launch.
class BleManager extends ChangeNotifier with WidgetsBindingObserver {
  BleManager._();
  static final BleManager instance = BleManager._();

  // ── Public state ─────────────────────────────────────────────
  BleStatus get status        => _status;
  bool      get isConnected   => _status == BleStatus.connected;
  String    get statusMessage => _statusMessage;

  // ── Private state ────────────────────────────────────────────
  BleStatus  _status        = BleStatus.idle;
  String     _statusMessage = 'Not connected';

  BluetoothDevice?         _device;
  BluetoothCharacteristic? _char;
  StreamSubscription?      _connStateSub;

  // ── App lifecycle ────────────────────────────────────────────
  // When iOS backgrounds and then kills the app while a BLE connection
  // is open, CoreBluetooth queues a disconnect event. On the next cold
  // launch flutter_blue_plus's native layer tries to deliver it before
  // Dart is ready → crash. Disconnecting on pause eliminates that queued
  // event entirely. The ESP32 will continue its last command regardless.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused && _device != null) {
      disconnect();
    }
  }

  // ── Connect ──────────────────────────────────────────────────
  Future<void> connect() async {
    if (_status == BleStatus.scanning || _status == BleStatus.connecting) return;

    // Wait for a settled adapter state — the first emission can be
    // BluetoothAdapterState.unknown while CoreBluetooth is still initializing.
    final adapterState = await FlutterBluePlus.adapterState
        .where((s) => s != BluetoothAdapterState.unknown)
        .first
        .timeout(
          const Duration(seconds: 5),
          onTimeout: () => BluetoothAdapterState.unknown,
        );
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
    await FlutterBluePlus.isScanning.where((v) => !v).first;
    await scanSub.cancel();

    if (found == null) {
      _set(BleStatus.error, '$_kDeviceName not found — is the ESP32 on?');
      return;
    }

    _set(BleStatus.connecting, 'Connecting…');
    _device = found;

    // ── Connect first, subscribe to state changes after ───────
    // flutter_blue_plus re-emits the last known connection state the
    // moment you subscribe. If iOS remembers the device as disconnected
    // from the previous session and we subscribe before connect(), that
    // replay fires our listener immediately, resetting status to idle
    // in the middle of the connect sequence. Subscribing after connect()
    // succeeds avoids that race entirely.
    try {
      await found!.connect(
        license: License.free,
        timeout: const Duration(seconds: 10),
      );
    } catch (e) {
      _device = null;
      _set(BleStatus.error, 'Connection failed: $e');
      return;
    }

    // Discover services
    List<BluetoothService> services;
    try {
      services = await found!.discoverServices();
    } catch (e) {
      await found!.disconnect();
      _device = null;
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
      await found!.disconnect();
      _device = null;
      _set(BleStatus.error, 'Motor characteristic not found on device');
      return;
    }

    _set(BleStatus.connected, 'Connected to $_kDeviceName');

    // Now safe to watch for unexpected disconnects — we're fully set up
    // so no stale replay can interfere.
    _connStateSub?.cancel();
    _connStateSub = _device!.connectionState.listen((state) {
      if (state == BluetoothConnectionState.disconnected) {
        _char  = null;
        _device = null;
        _connStateSub?.cancel();
        _connStateSub = null;
        _set(BleStatus.idle, 'Disconnected');
      }
    });
  }

  // ── Disconnect ───────────────────────────────────────────────
  Future<void> disconnect() async {
    _connStateSub?.cancel();
    _connStateSub = null;
    _char = null;
    try {
      await _device?.disconnect();
    } catch (_) {
      // Ignore errors during disconnect — we're cleaning up regardless.
    }
    _device = null;
    _set(BleStatus.idle, 'Disconnected');
  }

  // ── Send a command string ────────────────────────────────────
  Future<bool> sendCommand(String command) async {
    if (_char == null || !isConnected) return false;
    try {
      await _char!.write(utf8.encode(command), withoutResponse: false);
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

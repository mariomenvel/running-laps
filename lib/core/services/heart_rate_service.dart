import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_reactive_ble/flutter_reactive_ble.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';

// UUIDs estándar Heart Rate Service (BLE GATT)
final _heartRateServiceUuid =
    Uuid.parse('0000180D-0000-1000-8000-00805F9B34FB');
final _heartRateMeasurementUuid =
    Uuid.parse('00002A37-0000-1000-8000-00805F9B34FB');

enum HrConnectionState {
  disconnected,
  scanning,
  connecting,
  connected,
  error,
}

class HeartRateService {
  static final HeartRateService _instance = HeartRateService._internal();
  factory HeartRateService() => _instance;
  HeartRateService._internal();

  final _ble = FlutterReactiveBle();

  // Estado público
  final ValueNotifier<HrConnectionState> connectionState =
      ValueNotifier(HrConnectionState.disconnected);
  final ValueNotifier<int?> heartRate = ValueNotifier(null);
  final ValueNotifier<List<DiscoveredDevice>> scannedDevices =
      ValueNotifier([]);
  final ValueNotifier<String?> connectedDeviceName = ValueNotifier(null);

  StreamSubscription<DiscoveredDevice>? _scanSub;
  StreamSubscription<ConnectionStateUpdate>? _connectionSub;
  StreamSubscription<List<int>>? _measurementSub;
  String? _connectedDeviceId;

  static const _prefKey = 'last_hr_device_id';

  // Solicitar permisos BLE
  Future<bool> requestPermissions() async {
    final statuses = await [
      Permission.bluetooth,
      Permission.bluetoothScan,
      Permission.bluetoothConnect,
      Permission.locationWhenInUse,
    ].request();
    return statuses.values.every(
      (s) =>
          s == PermissionStatus.granted || s == PermissionStatus.limited,
    );
  }

  // Escanear dispositivos con Heart Rate Service
  Future<void> startScan({
    Duration timeout = const Duration(seconds: 10),
  }) async {
    scannedDevices.value = [];
    connectionState.value = HrConnectionState.scanning;

    _scanSub?.cancel();
    _scanSub = _ble
        .scanForDevices(
          withServices: [_heartRateServiceUuid],
          scanMode: ScanMode.lowLatency,
        )
        .listen(
          (device) {
            final current =
                List<DiscoveredDevice>.from(scannedDevices.value);
            final idx = current.indexWhere((d) => d.id == device.id);
            if (idx >= 0) {
              current[idx] = device;
            } else {
              current.add(device);
            }
            scannedDevices.value = current;
          },
          onError: (e) {
            debugPrint('[HeartRateService] scan error: $e');
            connectionState.value = HrConnectionState.error;
          },
        );

    await Future.delayed(timeout);
    await stopScan();
  }

  Future<void> stopScan() async {
    await _scanSub?.cancel();
    _scanSub = null;
    if (connectionState.value == HrConnectionState.scanning) {
      connectionState.value = HrConnectionState.disconnected;
    }
  }

  // Conectar a un dispositivo
  Future<void> connect(String deviceId, {String? deviceName}) async {
    await disconnect();
    connectionState.value = HrConnectionState.connecting;

    _connectionSub = _ble
        .connectToDevice(
          id: deviceId,
          connectionTimeout: const Duration(seconds: 10),
        )
        .listen(
          (update) async {
            if (update.connectionState ==
                DeviceConnectionState.connected) {
              _connectedDeviceId = deviceId;
              connectedDeviceName.value = deviceName;
              connectionState.value = HrConnectionState.connected;
              await _saveLastDevice(deviceId);
              await _subscribeToHeartRate(deviceId);
            } else if (update.connectionState ==
                DeviceConnectionState.disconnected) {
              connectionState.value = HrConnectionState.disconnected;
              heartRate.value = null;
            }
          },
          onError: (e) {
            debugPrint('[HeartRateService] connection error: $e');
            connectionState.value = HrConnectionState.error;
          },
        );
  }

  // Suscribirse a las mediciones de FC
  Future<void> _subscribeToHeartRate(String deviceId) async {
    final characteristic = QualifiedCharacteristic(
      serviceId:        _heartRateServiceUuid,
      characteristicId: _heartRateMeasurementUuid,
      deviceId:         deviceId,
    );

    _measurementSub?.cancel();
    _measurementSub =
        _ble.subscribeToCharacteristic(characteristic).listen(
          (data) {
            heartRate.value = _parseHeartRate(data);
          },
          onError: (e) {
            debugPrint('[HeartRateService] measurement error: $e');
          },
        );
  }

  // Parsear datos Heart Rate Measurement (formato GATT estándar)
  int _parseHeartRate(List<int> data) {
    if (data.isEmpty) return 0;
    final flags   = data[0];
    final is16bit = (flags & 0x01) != 0;
    if (is16bit && data.length >= 3) {
      return data[1] + (data[2] << 8);
    } else if (data.length >= 2) {
      return data[1];
    }
    return 0;
  }

  // Desconectar
  Future<void> disconnect() async {
    await _measurementSub?.cancel();
    await _connectionSub?.cancel();
    _measurementSub        = null;
    _connectionSub         = null;
    _connectedDeviceId     = null;
    heartRate.value        = null;
    connectedDeviceName.value = null;
    connectionState.value  = HrConnectionState.disconnected;
  }

  // Reconexión automática al último dispositivo conocido
  Future<void> autoReconnect() async {
    final prefs  = await SharedPreferences.getInstance();
    final lastId = prefs.getString(_prefKey);
    if (lastId != null) {
      debugPrint('[HeartRateService] auto-reconnecting to $lastId');
      await connect(lastId);
    }
  }

  Future<void> _saveLastDevice(String deviceId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefKey, deviceId);
  }

  Future<String?> getLastDeviceId() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_prefKey);
  }

  // Eliminar dispositivo guardado y desconectar
  Future<void> forgetDevice() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_prefKey);
    await disconnect();
  }

  void dispose() {
    _scanSub?.cancel();
    _connectionSub?.cancel();
    _measurementSub?.cancel();
    connectionState.dispose();
    heartRate.dispose();
    scannedDevices.dispose();
    connectedDeviceName.dispose();
  }
}

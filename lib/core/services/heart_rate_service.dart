import 'dart:async';
import 'dart:io';
import 'package:device_info_plus/device_info_plus.dart';
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

/// Motivo concreto por el que no se puede escanear, para que la vista diga
/// qué hacer en vez de un "Bluetooth no disponible" genérico.
enum HrPermissionResult {
  granted,
  denied,
  deniedPermanently,
  bluetoothOff,
  unauthorized,
  locationServiceOff,
  unsupported,
}

class HeartRateService {
  static HeartRateService? _instance;
  factory HeartRateService() => _instance ??= HeartRateService._internal();

  // Lazy: instanciar FlutterReactiveBle crea el CBCentralManager en iOS,
  // lo que dispara el diálogo de permiso de Bluetooth del sistema. Solo se
  // crea cuando algo necesita BLE de verdad (scan/connect/status) — nunca
  // por el mero hecho de construir el servicio al arrancar la app.
  // En Web no se llega a crear: todos los métodos que lo usan hacen
  // early-return con kIsWeb antes.
  FlutterReactiveBle? _bleInstance;
  FlutterReactiveBle get _ble => _bleInstance ??= FlutterReactiveBle();

  HeartRateService._internal();

  // Estado público
  final ValueNotifier<HrConnectionState> connectionState =
      ValueNotifier(HrConnectionState.disconnected);
  final ValueNotifier<int?> heartRate = ValueNotifier(null);
  final ValueNotifier<List<DiscoveredDevice>> scannedDevices =
      ValueNotifier([]);
  final ValueNotifier<String?> connectedDeviceName = ValueNotifier(null);

  /// Explicación de por qué el último escaneo no dio resultados (o falló).
  /// `null` = sin nada que contar.
  final ValueNotifier<String?> scanDiagnostic = ValueNotifier(null);

  /// ¿El anuncio BLE del dispositivo declara el Heart Rate Service (0x180D)?
  /// No todas las bandas lo incluyen en el paquete de advertising, así que
  /// sirve para ordenar/etiquetar la lista, nunca para descartar candidatos.
  static bool advertisesHeartRate(DiscoveredDevice d) =>
      d.serviceUuids.contains(_heartRateServiceUuid);

  StreamSubscription<DiscoveredDevice>? _scanSub;
  StreamSubscription<ConnectionStateUpdate>? _connectionSub;
  StreamSubscription<List<int>>? _measurementSub;

  // Generación del escaneo activo: si se lanza un startScan mientras otro
  // espera su timeout, el timeout del viejo no debe parar el escaneo nuevo.
  int _scanGeneration = 0;

  static const _prefKey = 'last_hr_device_id';

  // Solicitar permisos BLE
  Future<HrPermissionResult> requestPermissions() async {
    if (kIsWeb) return HrPermissionResult.unsupported;

    if (Platform.isAndroid) {
      final sdkInt = await DeviceInfoPlugin()
          .androidInfo
          .then((i) => i.version.sdkInt);

      // API 31+: BLUETOOTH_SCAN/CONNECT son permisos runtime.
      // API ≤ 30: BLUETOOTH y BLUETOOTH_ADMIN son de instalación (no se
      // piden), y quien realmente gatea el escaneo es la ubicación.
      final needed = sdkInt >= 31
          ? [Permission.bluetoothScan, Permission.bluetoothConnect]
          : [Permission.locationWhenInUse];

      final statuses = await needed.request();
      if (statuses.values.any((s) => s.isPermanentlyDenied)) {
        return HrPermissionResult.deniedPermanently;
      }
      if (!statuses.values.every((s) => s.isGranted || s.isLimited)) {
        return HrPermissionResult.denied;
      }

      // Android ≤ 11: con la ubicación del sistema apagada el escaneo BLE
      // devuelve cero resultados **sin error** — hay que avisar aparte.
      if (sdkInt < 31 &&
          !await Permission.location.serviceStatus.isEnabled) {
        return HrPermissionResult.locationServiceOff;
      }

      return _resultFromStatus(await getBleStatus());
    }

    // iOS: flutter_reactive_ble gestiona CoreBluetooth directamente.
    // El diálogo del sistema aparece automáticamente al iniciar el scan.
    if (Platform.isIOS) {
      return _resultFromStatus(await getBleStatus());
    }

    return HrPermissionResult.unsupported;
  }

  HrPermissionResult _resultFromStatus(BleStatus status) => switch (status) {
        BleStatus.poweredOff   => HrPermissionResult.bluetoothOff,
        BleStatus.unauthorized => HrPermissionResult.unauthorized,
        BleStatus.unsupported  => HrPermissionResult.unsupported,
        BleStatus.locationServicesDisabled =>
          HrPermissionResult.locationServiceOff,
        // `unknown` (timeout del adaptador) se deja pasar: mejor intentar el
        // escaneo y fallar ahí que bloquear por un estado que aún no llegó.
        _ => HrPermissionResult.granted,
      };

  /// Estado del adaptador BLE. Espera a un estado **definitivo**: el primer
  /// valor de `statusStream` siempre es `unknown` mientras el cliente nativo
  /// arranca, y quedarse con ese era leer el estado antes de tiempo.
  Future<BleStatus> getBleStatus({
    Duration timeout = const Duration(seconds: 6),
  }) async {
    if (kIsWeb) return BleStatus.unsupported;
    try {
      return await _ble.statusStream
          .firstWhere((s) => s != BleStatus.unknown)
          .timeout(timeout);
    } catch (e) {
      debugPrint('[HeartRateService] BLE status timeout: $e');
      return BleStatus.unknown;
    }
  }

  // Escanear pulsómetros
  //
  // ⚠️ Sin filtro nativo por servicio: `withServices: [0x180D]` traduce a un
  // ScanFilter de Android y a un filtro de CoreBluetooth, y ambos miran solo
  // el paquete de advertising. Muchas bandas (Polar, Garmin, Coospo…) no
  // meten el 0x180D ahí — lo exponen al hacer discovery, ya conectados —, así
  // que el filtro las descartaba antes de que la app pudiera verlas: escaneo
  // eterno con cero resultados. Se escanea abierto y se filtra en Dart.
  Future<void> startScan({
    Duration timeout = const Duration(seconds: 12),
  }) async {
    if (kIsWeb) return;
    scannedDevices.value = [];
    scanDiagnostic.value = null;
    connectionState.value = HrConnectionState.scanning;

    final generation = ++_scanGeneration;
    await _scanSub?.cancel();
    _scanSub = null;

    // El escaneo lanzado antes de que el adaptador esté listo se pierde en
    // silencio; esperar aquí es lo que evita el "no encuentra nada" del
    // primer intento tras abrir la app.
    final status = await getBleStatus();
    if (generation != _scanGeneration) return;

    // `unknown` (el adaptador no llegó a contestar) no bloquea: se intenta el
    // escaneo y, si falla de verdad, lo dirá el onError. Bloquear aquí sería
    // cambiar un falso negativo por otro.
    if (status != BleStatus.ready && status != BleStatus.unknown) {
      connectionState.value = HrConnectionState.error;
      scanDiagnostic.value = switch (status) {
        BleStatus.poweredOff =>
          'El Bluetooth está apagado. Actívalo y vuelve a buscar.',
        BleStatus.unauthorized =>
          'Running Laps no tiene permiso de Bluetooth. Actívalo en los '
              'ajustes del sistema.',
        BleStatus.locationServicesDisabled =>
          'Activa la ubicación del sistema: sin ella el escaneo Bluetooth no '
              'devuelve nada, aunque el pulsómetro no use el GPS.',
        BleStatus.unsupported =>
          'Este dispositivo no soporta Bluetooth LE.',
        _ => 'No se ha podido acceder al Bluetooth. Inténtalo de nuevo.',
      };
      return;
    }
    if (status == BleStatus.unknown) {
      debugPrint('[HeartRateService] estado BLE unknown — se escanea igual');
    }

    _scanSub = _ble
        .scanForDevices(
          withServices: const [],
          scanMode: ScanMode.lowLatency,
        )
        .listen(
          (device) {
            // Un anuncio sin nombre y sin 0x180D no es algo a lo que el
            // usuario pueda decidir conectarse: solo ensucia la lista.
            if (!advertisesHeartRate(device) && device.name.trim().isEmpty) {
              return;
            }

            final current =
                List<DiscoveredDevice>.from(scannedDevices.value);
            final idx = current.indexWhere((d) => d.id == device.id);
            if (idx >= 0) {
              current[idx] = device;
            } else {
              current.add(device);
            }
            // Pulsómetros confirmados primero; dentro de cada grupo, el más
            // cercano arriba (el que llevas puesto).
            current.sort((a, b) {
              final byService = (advertisesHeartRate(b) ? 1 : 0)
                  .compareTo(advertisesHeartRate(a) ? 1 : 0);
              return byService != 0 ? byService : b.rssi.compareTo(a.rssi);
            });
            scannedDevices.value = current;
          },
          onError: (e) {
            debugPrint('[HeartRateService] scan error: $e');
            connectionState.value = HrConnectionState.error;
            scanDiagnostic.value =
                'Error al buscar dispositivos. Comprueba que el Bluetooth '
                'está activado y vuelve a intentarlo.';
          },
        );

    await Future.delayed(timeout);
    // Solo parar si este sigue siendo el escaneo activo
    if (generation == _scanGeneration) {
      final foundNothing = scannedDevices.value.isEmpty;
      await stopScan();
      if (foundNothing &&
          connectionState.value != HrConnectionState.error) {
        scanDiagnostic.value =
            'No se ha encontrado ningún dispositivo.\n\n'
            '• Si emparejaste el pulsómetro en los ajustes de Bluetooth del '
            'móvil, quítalo de ahí. Una banda BLE solo admite una conexión: '
            'mientras el sistema la tiene cogida deja de anunciarse y ninguna '
            'app puede verla.\n'
            '• Póntela puesta y humedece la banda — la mayoría solo emiten al '
            'detectar contacto con la piel.\n'
            '• Acércala al móvil (menos de un metro) y comprueba la pila.';
      }
    }
  }

  Future<void> stopScan() async {
    // Invalida cualquier startScan que siga esperando su timeout o el estado
    // del adaptador.
    _scanGeneration++;
    await _scanSub?.cancel();
    _scanSub = null;
    if (connectionState.value == HrConnectionState.scanning) {
      connectionState.value = HrConnectionState.disconnected;
    }
  }

  // Conectar a un dispositivo
  Future<void> connect(String deviceId, {String? deviceName}) async {
    if (kIsWeb) return;
    // Escanear y conectar a la vez va mal en Android (el escaneo se lleva la
    // radio y la conexión tarda o falla), y deja vivo el timeout del escaneo.
    await stopScan();
    await disconnect();
    scanDiagnostic.value  = null;
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
            // Como la lista de escaneo ya no está filtrada por servicio, aquí
            // se cae también cuando el usuario conecta con algo que no es un
            // pulsómetro (auriculares, báscula…): sin 0x180D/0x2A37 no hay
            // característica a la que suscribirse.
            debugPrint('[HeartRateService] measurement error: $e');
            connectionState.value = HrConnectionState.error;
            scanDiagnostic.value =
                'Ese dispositivo no envía frecuencia cardíaca. Elige tu '
                'pulsómetro en la lista.';
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
    scanDiagnostic.dispose();
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_reactive_ble/flutter_reactive_ble.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:running_laps/core/services/heart_rate_service.dart';
import 'package:running_laps/core/theme/app_colors.dart';
import 'package:running_laps/core/widgets/app_header.dart';

class HeartRateMonitorView extends StatelessWidget {
  const HeartRateMonitorView({super.key});

  // ── Acciones ───────────────────────────────────────────────────────────────

  Future<void> _startScan(BuildContext context) async {
    final granted = await HeartRateService().requestPermissions();
    if (!context.mounted) return;

    if (!granted) {
      final bleStatus = await HeartRateService().getBleStatus();
      if (!context.mounted) return;

      final String title;
      final String message;
      final bool showSettings;

      if (bleStatus == BleStatus.poweredOff) {
        title = 'Bluetooth desactivado';
        message = 'Activa el Bluetooth en el Centro de Control para conectar tu pulsómetro.';
        showSettings = false;
      } else if (bleStatus == BleStatus.unauthorized) {
        title = 'Permiso de Bluetooth necesario';
        message = 'Ve a Ajustes → Running Laps → Bluetooth y actívalo.';
        showSettings = true;
      } else {
        title = 'Bluetooth no disponible';
        message = 'Comprueba que el Bluetooth está activado e inténtalo de nuevo.';
        showSettings = false;
      }

      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: const Color(0xFF1C1C1E),
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16)),
          title: Text(title,
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 17,
                  fontWeight: FontWeight.w600)),
          content: Text(message,
              style: const TextStyle(
                  color: Color(0xFFEBEBF5),
                  fontSize: 15,
                  height: 1.5)),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Cancelar',
                    style: TextStyle(color: Color(0xFF8E8E93)))),
            if (showSettings)
              FilledButton(
                style: FilledButton.styleFrom(
                    backgroundColor: AppColors.brand),
                onPressed: () {
                  Navigator.pop(ctx);
                  openAppSettings();
                },
                child: const Text('Abrir Ajustes'),
              ),
          ],
        ),
      );
      return;
    }

    HeartRateService().startScan();
  }

  void _connectTo(DiscoveredDevice device) {
    final name = device.name.isNotEmpty ? device.name : null;
    HeartRateService().connect(device.id, deviceName: name);
  }

  Future<void> _forgetDevice(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Olvidar dispositivo'),
        content: const Text(
            '¿Seguro que quieres olvidar este pulsómetro? '
            'Tendrás que buscarlo y conectarlo de nuevo.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.rpeMax),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Olvidar'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await HeartRateService().forgetDevice();
    }
  }

  // ── UI de estado ───────────────────────────────────────────────────────────

  Widget _buildStatusCard(
    BuildContext context, {
    required HrConnectionState state,
    required int? heartRate,
    required bool isDark,
  }) {
    Color bgColor;
    switch (state) {
      case HrConnectionState.connected:
        bgColor = AppColors.rpeLow.withOpacity(0.1);
      case HrConnectionState.scanning:
      case HrConnectionState.connecting:
        bgColor = AppColors.brand.withOpacity(0.1);
      case HrConnectionState.error:
        bgColor = AppColors.rpeMax.withOpacity(0.1);
      case HrConnectionState.disconnected:
        bgColor = isDark ? const Color(0xFF1C1C1E) : const Color(0xFFF2F2F7);
    }

    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color:        bgColor,
        borderRadius: BorderRadius.circular(16),
      ),
      child: switch (state) {
        HrConnectionState.disconnected => _StatusContent(
            icon: const Icon(Icons.bluetooth_disabled_rounded,
                color: Color(0xFF8E8E93), size: 32),
            title: 'Sin pulsómetro conectado',
            subtitle: 'Busca y conecta tu pulsómetro BLE',
          ),
        HrConnectionState.scanning => _StatusContent(
            icon: const SizedBox(
              width: 32,
              height: 32,
              child: CircularProgressIndicator(
                  color: AppColors.brand, strokeWidth: 3),
            ),
            title: 'Buscando pulsómetros...',
            subtitle: 'Asegúrate de que está encendido y cerca',
          ),
        HrConnectionState.connecting => _StatusContent(
            icon: const SizedBox(
              width: 32,
              height: 32,
              child: CircularProgressIndicator(
                  color: AppColors.brand, strokeWidth: 3),
            ),
            title: 'Conectando...',
            subtitle: null,
          ),
        HrConnectionState.connected => Column(
            children: [
              const Icon(Icons.favorite_rounded,
                  color: AppColors.rpeMax, size: 32),
              const SizedBox(height: 8),
              const Text(
                'Conectado',
                style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: AppColors.rpeLow),
              ),
              if (heartRate != null) ...[
                const SizedBox(height: 12),
                Text(
                  '$heartRate ppm',
                  style: const TextStyle(
                    fontSize:   48,
                    fontWeight: FontWeight.w700,
                    color:      AppColors.rpeMax,
                  ),
                ),
                const Text(
                  'frecuencia cardíaca',
                  style: TextStyle(fontSize: 13, color: Color(0xFF8E8E93)),
                ),
              ],
              const SizedBox(height: 16),
              OutlinedButton(
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.rpeMax,
                  side: const BorderSide(color: AppColors.rpeMax),
                ),
                onPressed: () => HeartRateService().disconnect(),
                child: const Text('Desconectar'),
              ),
              TextButton(
                style: TextButton.styleFrom(
                    foregroundColor: const Color(0xFF8E8E93)),
                onPressed: () => _forgetDevice(context),
                child: const Text('Olvidar dispositivo'),
              ),
            ],
          ),
        HrConnectionState.error => _StatusContent(
            icon: const Icon(Icons.error_outline_rounded,
                color: AppColors.rpeMax, size: 32),
            title: 'Error de conexión',
            subtitle: 'Comprueba que el Bluetooth está activado',
          ),
      },
    );
  }

  Widget _buildScanButton(
      BuildContext context, HrConnectionState state) {
    if (state == HrConnectionState.connected) return const SizedBox.shrink();

    if (state == HrConnectionState.scanning) {
      return Center(
        child: TextButton(
          style: TextButton.styleFrom(
              foregroundColor: AppColors.brand),
          onPressed: () => HeartRateService().stopScan(),
          child: const Text('Detener búsqueda'),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: SizedBox(
        width: double.infinity,
        child: FilledButton.icon(
          style: FilledButton.styleFrom(
            backgroundColor: AppColors.brand,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12)),
          ),
          icon:     const Icon(Icons.bluetooth_searching_rounded),
          label:    const Text('Buscar pulsómetros'),
          onPressed: () => _startScan(context),
        ),
      ),
    );
  }

  Widget _buildDeviceList(
      BuildContext context, List<DiscoveredDevice> devices, bool isDark) {
    if (devices.isEmpty) return const SizedBox.shrink();

    final txtColor  = isDark ? Colors.white : const Color(0xFF1C1C1E);
    final cardColor = isDark ? const Color(0xFF1C1C1E) : Colors.white;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Text(
            'DISPOSITIVOS ENCONTRADOS',
            style: TextStyle(
              fontSize:      12,
              fontWeight:    FontWeight.w600,
              letterSpacing: 0.8,
              color:         txtColor.withOpacity(0.5),
            ),
          ),
        ),
        ...devices.map((device) {
          final signalColor = device.rssi > -60
              ? AppColors.rpeLow
              : device.rssi > -80
                  ? AppColors.rpeMid
                  : AppColors.rpeMax;

          return Container(
            margin: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            decoration: BoxDecoration(
              color:        cardColor,
              borderRadius: BorderRadius.circular(12),
            ),
            child: ListTile(
              leading: const Icon(Icons.bluetooth_rounded,
                  color: AppColors.brand),
              title: Text(
                device.name.isNotEmpty ? device.name : 'Dispositivo desconocido',
                style: TextStyle(color: txtColor, fontWeight: FontWeight.w500),
              ),
              subtitle: Text(
                'RSSI: ${device.rssi} dBm',
                style: TextStyle(color: signalColor, fontSize: 12),
              ),
              trailing: FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.brand,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  minimumSize: const Size(0, 32),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8)),
                ),
                onPressed: () => _connectTo(device),
                child: const Text('Conectar', style: TextStyle(fontSize: 13)),
              ),
            ),
          );
        }),
      ],
    );
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final svc    = HeartRateService();

    return Scaffold(
      body: SafeArea(
        top: false,
        bottom: false,
        child: Column(
          children: [
            AppHeader(title: const Text('Pulsómetro')),
            Expanded(
              child: ListenableBuilder(
                listenable: Listenable.merge([
                  svc.connectionState,
                  svc.heartRate,
                  svc.scannedDevices,
                ]),
                builder: (context, _) {
                  final state   = svc.connectionState.value;
                  final hr      = svc.heartRate.value;
                  final devices = svc.scannedDevices.value;

                  return SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildStatusCard(context,
                            state: state, heartRate: hr, isDark: isDark),
                        const SizedBox(height: 8),
                        _buildScanButton(context, state),
                        _buildDeviceList(context, devices, isDark),
                        const SizedBox(height: 32),
                      ],
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Helpers ───────────────────────────────────────────────────────────────────

class _StatusContent extends StatelessWidget {
  final Widget icon;
  final String title;
  final String? subtitle;

  const _StatusContent({
    required this.icon,
    required this.title,
    this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        icon,
        const SizedBox(height: 8),
        Text(
          title,
          style: TextStyle(
            fontSize:   16,
            fontWeight: FontWeight.w600,
            color:      Theme.of(context).colorScheme.onSurface,
          ),
          textAlign: TextAlign.center,
        ),
        if (subtitle != null) ...[
          const SizedBox(height: 4),
          Text(
            subtitle!,
            style: const TextStyle(fontSize: 13, color: Color(0xFF8E8E93)),
            textAlign: TextAlign.center,
          ),
        ],
      ],
    );
  }
}

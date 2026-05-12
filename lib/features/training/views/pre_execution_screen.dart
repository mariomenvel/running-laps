import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../../core/services/heart_rate_service.dart';
import '../../../core/services/settings_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/app_transitions.dart';
import '../../../core/widgets/main_shell.dart';
import '../../athlete/data/athlete_session_model.dart';
import '../../profile/data/zones_repository.dart';
import '../../templates/data/workout_block.dart';
import '../../templates/data/workout_segment.dart';
import '../../templates/data/workout_session.dart';
import 'widgets/countdown_dialog.dart';
import 'workout_execution_screen.dart';

class PreExecutionScreen extends StatefulWidget {
  final WorkoutSession session;
  final AthleteSession? athleteSession;

  const PreExecutionScreen({
    super.key,
    required this.session,
    this.athleteSession,
  });

  @override
  State<PreExecutionScreen> createState() => _PreExecutionScreenState();
}

class _PreExecutionScreenState extends State<PreExecutionScreen> {
  late WorkoutSession _session;
  late WorkoutSession _originalSession;
  bool _warmupEnabled = true;
  bool _cooldownEnabled = true;
  bool _gpsOn = true;
  double? _fcMax;

  @override
  void initState() {
    super.initState();
    _originalSession = widget.session;
    _session = widget.session;
    _warmupEnabled = _originalSession.warmupBlock != null;
    _cooldownEnabled = _originalSession.cooldownBlock != null;
    _loadFcMax();
    _loadGpsDefault();
    HeartRateService()
        .autoReconnect()
        .catchError((e) => debugPrint('[PreExecution] BLE: $e'));
  }

  Future<void> _loadFcMax() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    final profile = await ZonesRepository().getUserProfile(uid);
    if (mounted && profile?.fcMax != null) {
      setState(() => _fcMax = profile!.fcMax!.toDouble());
    }
  }

  Future<void> _loadGpsDefault() async {
    final gps = await SettingsService().getGpsDefault();
    if (mounted) setState(() => _gpsOn = gps);
  }

  Future<void> _onStart() async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => CountdownDialog(
        onComplete: _launchExecution,
      ),
    );
  }

  Future<void> _launchExecution() async {
    if (!mounted) return;
    Navigator.of(context).pop();

    if (mounted) {
      Navigator.of(context).push(
        AppRoute(
          page: WorkoutExecutionScreen(
            session: _session,
            athleteSession: widget.athleteSession,
            gpsActivo: _gpsOn,
            fcMax: _fcMax,
            onCompleted: () {
              if (mounted) {
                MainShell.shellKey.currentState?.navigateBack();
              }
            },
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surfaceOf(context),
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.all(AppSpacing.l),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _session.title,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    _estimatedDuration(),
                    style: TextStyle(
                      fontSize: 14,
                      color: AppColors.textSecondary(context),
                    ),
                  ),
                ],
              ),
            ),
            Divider(color: AppColors.borderOf(context), height: 1),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(AppSpacing.l),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (_originalSession.warmupBlock != null)
                      _buildWarmupRow(),
                    ..._buildMainBlocks(),
                    if (_originalSession.cooldownBlock != null)
                      _buildCooldownRow(),
                    const SizedBox(height: AppSpacing.xl),
                    Divider(color: AppColors.borderOf(context), height: 1),
                    const SizedBox(height: AppSpacing.m),
                    _buildGpsRow(),
                    const SizedBox(height: AppSpacing.s),
                    _buildBleRow(),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(AppSpacing.l),
              child: SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: _onStart,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.brand,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text(
                    'EMPEZAR',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.2,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildWarmupRow() {
    final block = _originalSession.warmupBlock!;
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Icon(
        Icons.waves,
        color: _warmupEnabled
            ? AppColors.brand
            : AppColors.iconMutedOf(context),
      ),
      title: Text(
        'Calentamiento',
        style: TextStyle(
          fontWeight: FontWeight.w600,
          color: _warmupEnabled
              ? AppColors.textPrimary(context)
              : AppColors.textSecondary(context),
        ),
      ),
      subtitle: Text(
        _describeBlock(block),
        style: TextStyle(color: AppColors.textSecondary(context)),
      ),
      trailing: Switch(
        value: _warmupEnabled,
        activeThumbColor: AppColors.brand,
        onChanged: (v) => setState(() {
          _warmupEnabled = v;
          if (!v) {
            _session = _session.copyWith(
              blocks: _session.blocks
                  .where((b) => b.role != BlockRole.warmup)
                  .toList(),
            );
          } else {
            final original = _originalSession.warmupBlock;
            if (original != null && _session.warmupBlock == null) {
              _session = _session.copyWith(
                blocks: [original, ..._session.blocks],
              );
            }
          }
        }),
      ),
    );
  }

  Widget _buildCooldownRow() {
    final block = _originalSession.cooldownBlock!;
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Icon(
        Icons.self_improvement,
        color: _cooldownEnabled
            ? AppColors.brand
            : AppColors.iconMutedOf(context),
      ),
      title: Text(
        'Vuelta a la calma',
        style: TextStyle(
          fontWeight: FontWeight.w600,
          color: _cooldownEnabled
              ? AppColors.textPrimary(context)
              : AppColors.textSecondary(context),
        ),
      ),
      subtitle: Text(
        _describeBlock(block),
        style: TextStyle(color: AppColors.textSecondary(context)),
      ),
      trailing: Switch(
        value: _cooldownEnabled,
        activeThumbColor: AppColors.brand,
        onChanged: (v) => setState(() {
          _cooldownEnabled = v;
          if (!v) {
            _session = _session.copyWith(
              blocks: _session.blocks
                  .where((b) => b.role != BlockRole.cooldown)
                  .toList(),
            );
          } else {
            final original = _originalSession.cooldownBlock;
            if (original != null && _session.cooldownBlock == null) {
              _session = _session.copyWith(
                blocks: [..._session.blocks, original],
              );
            }
          }
        }),
      ),
    );
  }

  List<Widget> _buildMainBlocks() {
    final mainBlocks = _session.blocks
        .where((b) => b.role == BlockRole.main || b.role == BlockRole.custom)
        .toList();

    return mainBlocks.map((block) {
      final idx = mainBlocks.indexOf(block);
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.s),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.bolt, color: AppColors.brand, size: 20),
                const SizedBox(width: AppSpacing.s),
                Text(
                  mainBlocks.length > 1
                      ? 'Bloque ${idx + 1}'
                      : 'Bloque principal',
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 15,
                  ),
                ),
                const Spacer(),
                Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.remove, size: 18),
                      onPressed: block.repetitions > 1
                          ? () => _updateReps(block, block.repetitions - 1)
                          : null,
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.s),
                      child: Text(
                        '${block.repetitions}×',
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 16,
                        ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.add, size: 18),
                      onPressed: block.repetitions < 99
                          ? () => _updateReps(block, block.repetitions + 1)
                          : null,
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              _describeBlock(block),
              style: TextStyle(
                color: AppColors.textSecondary(context),
                fontSize: 13,
              ),
            ),
          ],
        ),
      );
    }).toList();
  }

  void _updateReps(WorkoutBlock block, int newReps) {
    final updatedBlocks = _session.blocks.map((b) {
      return b.id == block.id ? b.copyWith(repetitions: newReps) : b;
    }).toList();
    setState(() {
      _session = _session.copyWith(blocks: updatedBlocks);
    });
  }

  Widget _buildGpsRow() {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Icon(
        _gpsOn ? Icons.gps_fixed : Icons.gps_off,
        color: _gpsOn ? AppColors.brand : AppColors.iconMutedOf(context),
      ),
      title: const Text(
        'GPS',
        style: TextStyle(fontWeight: FontWeight.w600),
      ),
      subtitle: Text(
        _gpsOn ? 'Activado' : 'Desactivado',
        style: TextStyle(color: AppColors.textSecondary(context)),
      ),
      trailing: Switch(
        value: _gpsOn,
        activeThumbColor: AppColors.brand,
        onChanged: (v) => setState(() => _gpsOn = v),
      ),
    );
  }

  Widget _buildBleRow() {
    final hr = HeartRateService();
    return ListenableBuilder(
      listenable: Listenable.merge([
        hr.connectionState,
        hr.heartRate,
        hr.connectedDeviceName,
      ]),
      builder: (context, _) {
        final connected =
            hr.connectionState.value == HrConnectionState.connected;
        final bpm = hr.heartRate.value;
        final name = hr.connectedDeviceName.value;

        return ListTile(
          contentPadding: EdgeInsets.zero,
          leading: Icon(
            Icons.favorite,
            color: connected ? Colors.red : AppColors.iconMutedOf(context),
          ),
          title: const Text(
            'Pulsómetro',
            style: TextStyle(fontWeight: FontWeight.w600),
          ),
          subtitle: Text(
            connected
                ? '${name ?? "Conectado"} · $bpm bpm'
                : 'No conectado',
            style: TextStyle(color: AppColors.textSecondary(context)),
          ),
          trailing: connected
              ? Icon(Icons.bluetooth_connected, color: AppColors.brand)
              : Icon(Icons.bluetooth_disabled,
                  color: AppColors.iconMutedOf(context)),
        );
      },
    );
  }

  String _estimatedDuration() {
    int totalSec = 0;
    for (final block in _session.blocks) {
      for (final seg in block.segments) {
        final dur = seg.durationSec ?? 0;
        final dist = seg.distanceM ?? 0;
        if (dur > 0) {
          totalSec += dur * block.repetitions;
        } else if (dist > 0) {
          totalSec += ((dist / 1000) * 300).round() * block.repetitions;
        }
      }
    }
    if (totalSec == 0) return 'Duración estimada desconocida';
    final min = totalSec ~/ 60;
    if (min < 60) return '~$min min';
    final h = min ~/ 60;
    final m = min % 60;
    return '~${h}h ${m}min';
  }

  String _describeBlock(WorkoutBlock block) {
    final seg = block.segments
        .where((s) => s.type == SegmentType.interval)
        .firstOrNull;
    if (seg == null) return 'Bloque libre';

    final parts = <String>[];

    if (seg.distanceM != null) {
      final d = seg.distanceM!;
      parts.add(d >= 1000
          ? '${(d / 1000).toStringAsFixed(d % 1000 == 0 ? 0 : 1)}km'
          : '${d}m');
    } else if (seg.durationSec != null) {
      parts.add('${seg.durationSec! ~/ 60} min');
    }

    if (seg.target?.paceMinSecPerKm != null) {
      final p = seg.target!.paceMinSecPerKm!;
      parts.add('@ ${p ~/ 60}:${(p % 60).toString().padLeft(2, '0')}/km');
    } else if (seg.target?.zone != null) {
      parts.add('Z${seg.target!.zone!.index + 1}');
    } else if (seg.target?.rpe != null) {
      parts.add('RPE ${seg.target!.rpe}');
    }

    return parts.join(' · ');
  }
}

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../../core/services/heart_rate_service.dart';
import '../../../core/services/settings_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/app_transitions.dart';
import '../../profile/data/zones_repository.dart';
import '../../templates/data/workout_block.dart';
import '../../templates/data/workout_segment.dart';
import '../../templates/data/workout_session.dart';
import '../../athlete/data/athlete_session_model.dart';
import 'training_start_view.dart';
import 'widgets/countdown_dialog.dart';

class PreExecutionScreen extends StatefulWidget {
  final WorkoutSession session;
  final AthleteSession? athleteSession;
  final VoidCallback? onSessionCompleted;

  const PreExecutionScreen({
    super.key,
    required this.session,
    this.athleteSession,
    this.onSessionCompleted,
  });

  @override
  State<PreExecutionScreen> createState() => _PreExecutionScreenState();
}

class _PreExecutionScreenState extends State<PreExecutionScreen> {
  late WorkoutSession _originalSession;
  late WorkoutSession _session;
  bool _gpsOn = true;
  int? _fcMax;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _originalSession = widget.session;
    _session = widget.session;
    _loadFcMax();
    HeartRateService()
        .autoReconnect()
        .catchError((e) => debugPrint('[PreExecutionScreen] HR reconnect: $e'));
    _loadGpsDefault();
  }

  Future<void> _loadGpsDefault() async {
    final v = await SettingsService().getGpsDefault();
    if (mounted) setState(() => _gpsOn = v);
  }

  Future<void> _loadFcMax() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      if (mounted) setState(() => _loading = false);
      return;
    }
    try {
      final profile = await ZonesRepository().getUserProfile(uid);
      if (mounted) {
        setState(() {
          _fcMax = profile?.fcMax;
          _loading = false;
        });
      }
    } catch (e) {
      debugPrint('[PreExecutionScreen] _loadFcMax: $e');
      if (mounted) setState(() => _loading = false);
    }
  }

  // ─── Helpers ────────────────────────────────────────────────────────────────

  String _formatPace(int secPerKm) {
    final m = secPerKm ~/ 60;
    final s = (secPerKm % 60).toString().padLeft(2, '0');
    return '$m:$s/km';
  }

  String _describeSegment(WorkoutSegment seg) {
    final buf = StringBuffer();

    if (seg.distanceM != null) {
      final d = seg.distanceM!;
      buf.write(d >= 1000 ? '${(d / 1000).toStringAsFixed(d % 1000 == 0 ? 0 : 1)}km' : '${d}m');
    } else if (seg.durationSec != null) {
      final s = seg.durationSec!;
      buf.write(s >= 60 ? '${s ~/ 60} min' : '${s}s');
    }

    final t = seg.target;
    if (t != null) {
      if (t.paceMinSecPerKm != null) {
        buf.write(' @ ${_formatPace(t.paceMinSecPerKm!)}');
      }
      if (t.zone != null) {
        buf.write(' · Z${t.zone!.index + 1}');
      }
    }

    return buf.toString();
  }

  String _estimatedDuration() {
    int totalSec = 0;
    for (final block in _session.blocks) {
      int blockSec = 0;
      for (final seg in block.segments) {
        if (seg.durationSec != null) {
          blockSec += seg.durationSec!;
        } else if (seg.distanceM != null) {
          // rough estimate: 3 m/s average pace
          blockSec += (seg.distanceM! / 3).round();
        }
      }
      totalSec += blockSec * block.repetitions;
    }
    final mins = (totalSec / 60).round();
    return '~$mins min';
  }

  // ─── Actions ────────────────────────────────────────────────────────────────

  void _onStart() {
    showDialog(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.black.withValues(alpha: 0.7),
      builder: (_) => CountdownDialog(
        onComplete: () {
          Navigator.of(context).pop();
          _launchExecution();
        },
      ),
    );
  }

  void _launchExecution() {
    debugPrint('[PreExecutionScreen] fcMax=$_fcMax gpsOn=$_gpsOn');
    Navigator.pushReplacement(
      context,
      AppRoute(
        page: TrainingStartView(
          athleteSessionId: widget.athleteSession?.id,
        ),
      ),
    );
  }

  // ─── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildHeader(),
            Divider(color: AppColors.borderOf(context), thickness: 0.5, height: 0.5),
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  children: [
                    if (_session.warmupBlock != null) _buildWarmupRow(),
                    ..._session.mainBlocks.map(_buildMainBlock),
                    if (_session.cooldownBlock != null) _buildCooldownRow(),
                  ],
                ),
              ),
            ),
            Divider(color: AppColors.borderOf(context), thickness: 0.5, height: 0.5),
            Padding(
              padding: const EdgeInsets.all(AppSpacing.l),
              child: Column(
                children: [
                  _buildGpsRow(),
                  const SizedBox(height: AppSpacing.s),
                  _buildBleRow(),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.l,
                vertical: AppSpacing.m,
              ),
              child: SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  onPressed: _loading ? null : _onStart,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.brand,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppDimens.buttonRadius),
                    ),
                  ),
                  child: const Text(
                    'EMPEZAR',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, letterSpacing: 1.2),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s, vertical: AppSpacing.s),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.close),
            onPressed: () => Navigator.pop(context),
          ),
          Expanded(
            child: Text(
              _session.title,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Text(
            _estimatedDuration(),
            style: TextStyle(
              fontSize: 14,
              color: AppColors.textSecondary(context),
            ),
          ),
          const SizedBox(width: AppSpacing.s),
        ],
      ),
    );
  }

  Widget _buildWarmupRow() {
    final warmup = _session.warmupBlock!;
    final hasWarmup = _session.warmupBlock != null;
    return ListTile(
      dense: true,
      leading: const Icon(Icons.waves, color: AppColors.rest, size: 20),
      title: const Text('Calentamiento', style: TextStyle(fontSize: 14)),
      subtitle: warmup.segments.isNotEmpty
          ? Text(
              _describeSegment(warmup.segments.first),
              style: TextStyle(fontSize: 12, color: AppColors.textSecondary(context)),
            )
          : null,
      trailing: Switch(
        value: hasWarmup,
        activeThumbColor: AppColors.brand,
        onChanged: (v) => setState(() {
          if (!v) {
            _session = _session.copyWith(
              blocks: _session.blocks
                  .where((b) => b.role != BlockRole.warmup)
                  .toList(),
            );
          } else {
            final original = _originalSession.warmupBlock;
            if (original != null && _session.warmupBlock == null) {
              _session = _session.copyWith(blocks: [original, ..._session.blocks]);
            }
          }
        }),
      ),
    );
  }

  Widget _buildMainBlock(WorkoutBlock block) {
    final idx = _session.mainBlocks.indexOf(block);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.l, vertical: AppSpacing.s),
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.surfaceOf(context),
          border: Border.all(color: AppColors.borderOf(context), width: 0.5),
          borderRadius: BorderRadius.circular(AppDimens.cardRadiusLarge),
        ),
        padding: const EdgeInsets.all(AppSpacing.l),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.bolt, color: AppColors.effort, size: 20),
                const SizedBox(width: AppSpacing.s),
                Text(
                  'BLOQUE PRINCIPAL',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.2,
                    color: AppColors.textSecondary(context),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.m),
            Row(
              children: [
                Text(
                  'Repeticiones',
                  style: TextStyle(fontSize: 14, color: AppColors.textSecondary(context)),
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.remove, size: 20),
                  color: block.repetitions == 1
                      ? AppColors.iconMutedOf(context)
                      : AppColors.brand,
                  onPressed: block.repetitions == 1
                      ? null
                      : () => _updateRepetitions(idx, block.repetitions - 1),
                ),
                SizedBox(
                  width: 32,
                  child: Text(
                    '${block.repetitions}',
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.add, size: 20),
                  color: block.repetitions == 99
                      ? AppColors.iconMutedOf(context)
                      : AppColors.brand,
                  onPressed: block.repetitions == 99
                      ? null
                      : () => _updateRepetitions(idx, block.repetitions + 1),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.s),
            ...block.segments
                .where((s) => s.type == SegmentType.interval)
                .map(
                  (seg) => Padding(
                    padding: const EdgeInsets.only(bottom: AppSpacing.xs),
                    child: Row(
                      children: [
                        const Icon(Icons.circle, size: 8, color: AppColors.effort),
                        const SizedBox(width: AppSpacing.s),
                        Text(
                          _describeSegment(seg),
                          style: TextStyle(
                            fontSize: 13,
                            color: AppColors.textSecondary(context),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
          ],
        ),
      ),
    );
  }

  void _updateRepetitions(int mainBlockIndex, int newReps) {
    final allBlocks = List<WorkoutBlock>.from(_session.blocks);
    int mainCount = 0;
    for (int i = 0; i < allBlocks.length; i++) {
      if (allBlocks[i].role == BlockRole.main) {
        if (mainCount == mainBlockIndex) {
          allBlocks[i] = allBlocks[i].copyWith(repetitions: newReps);
          break;
        }
        mainCount++;
      }
    }
    setState(() {
      _session = _session.copyWith(blocks: allBlocks);
    });
  }

  Widget _buildCooldownRow() {
    final cooldown = _session.cooldownBlock!;
    final hasCooldown = _session.cooldownBlock != null;
    return ListTile(
      dense: true,
      leading: const Icon(Icons.self_improvement, color: AppColors.rest, size: 20),
      title: const Text('Vuelta a la calma', style: TextStyle(fontSize: 14)),
      subtitle: cooldown.segments.isNotEmpty
          ? Text(
              _describeSegment(cooldown.segments.first),
              style: TextStyle(fontSize: 12, color: AppColors.textSecondary(context)),
            )
          : null,
      trailing: Switch(
        value: hasCooldown,
        activeThumbColor: AppColors.brand,
        onChanged: (v) => setState(() {
          if (!v) {
            _session = _session.copyWith(
              blocks: _session.blocks
                  .where((b) => b.role != BlockRole.cooldown)
                  .toList(),
            );
          } else {
            final original = _originalSession.cooldownBlock;
            if (original != null && _session.cooldownBlock == null) {
              _session = _session.copyWith(blocks: [..._session.blocks, original]);
            }
          }
        }),
      ),
    );
  }

  Widget _buildGpsRow() {
    return Row(
      children: [
        Icon(
          _gpsOn ? Icons.gps_fixed : Icons.gps_off,
          color: _gpsOn ? AppColors.brand : AppColors.iconMutedOf(context),
          size: 20,
        ),
        const SizedBox(width: AppSpacing.s),
        Text('GPS', style: TextStyle(fontSize: 14, color: AppColors.textPrimary(context))),
        const Spacer(),
        Switch(
          value: _gpsOn,
          activeThumbColor: AppColors.brand,
          onChanged: (v) => setState(() => _gpsOn = v),
        ),
      ],
    );
  }

  Widget _buildBleRow() {
    return ListenableBuilder(
      listenable: Listenable.merge([
        HeartRateService().connectionState,
        HeartRateService().connectedDeviceName,
        HeartRateService().heartRate,
      ]),
      builder: (context, _) {
        final state = HeartRateService().connectionState.value;
        final deviceName = HeartRateService().connectedDeviceName.value;
        final hr = HeartRateService().heartRate.value;
        final isConnected = state == HrConnectionState.connected;

        final String subtitle;
        if (isConnected && hr != null) {
          subtitle = '$hr bpm';
        } else if (state == HrConnectionState.connecting) {
          subtitle = 'Conectando...';
        } else {
          subtitle = 'No configurado';
        }

        return Row(
          children: [
            Icon(
              Icons.favorite_border,
              color: isConnected ? AppColors.rpeLow : AppColors.iconMutedOf(context),
              size: 20,
            ),
            const SizedBox(width: AppSpacing.s),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  deviceName ?? 'Pulsómetro',
                  style: TextStyle(fontSize: 14, color: AppColors.textPrimary(context)),
                ),
                Text(
                  subtitle,
                  style: TextStyle(fontSize: 12, color: AppColors.textSecondary(context)),
                ),
              ],
            ),
            const Spacer(),
            Switch(
              value: isConnected,
              activeThumbColor: AppColors.brand,
              onChanged: (val) async {
                if (val) {
                  final lastId = await HeartRateService().getLastDeviceId();
                  if (lastId != null) {
                    HeartRateService().connect(lastId);
                  }
                } else {
                  HeartRateService().disconnect();
                }
              },
            ),
          ],
        );
      },
    );
  }
}

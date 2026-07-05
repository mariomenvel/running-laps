import 'dart:math';

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:running_laps/core/theme/app_colors.dart';
import 'package:running_laps/core/theme/app_theme.dart';
import 'package:running_laps/core/utils/app_transitions.dart';
import 'package:running_laps/core/widgets/main_shell.dart';
import 'package:running_laps/core/services/heart_rate_service.dart';
import 'package:running_laps/core/widgets/modern_snackbar.dart';
import 'package:running_laps/features/auth/viewmodels/auth_controller.dart';
import 'package:running_laps/features/auth/views/auth_page.dart';
import 'package:running_laps/features/onboarding/views/athlete_tutorial_view.dart';
import 'package:running_laps/features/training/views/manual_training_view.dart';
import 'package:running_laps/features/admin/views/admin_panel_screen.dart';
import 'package:running_laps/features/ai_coach/views/ai_coach_settings_view.dart';
import 'package:running_laps/features/ai_coach/data/ai_coach_repository.dart';
import 'package:running_laps/features/ai_coach/data/ai_coach_models.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:running_laps/features/avatar/models/avatar_config.dart';
import 'package:running_laps/features/avatar/services/avatar_generator.dart';

class ProfileView extends StatefulWidget {
  const ProfileView({super.key});

  @override
  State<ProfileView> createState() => _ProfileViewState();
}

class _ProfileViewState extends State<ProfileView> {
  late final AuthController _authCtrl;

  String _userName = '';
  String? _photoUrl;
  bool _isAdmin = false;
  bool _isAthleteMode = false;
  AvatarConfig? _avatarConfig;

  @override
  void initState() {
    super.initState();
    _authCtrl = AuthController();
    _loadUserData();
  }

  @override
  void dispose() {
    _authCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadUserData() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    final doc = await FirebaseFirestore.instance.collection('users').doc(uid).get();
    if (!mounted) return;
    final data = doc.data() ?? {};
    AvatarConfig? parsed;
    final rawConfig = data['generativeAvatarConfig'];
    if (rawConfig is Map<String, dynamic>) {
      parsed = AvatarConfig.fromMap(rawConfig);
    }
    setState(() {
      _userName      = data['nombre'] ?? 'Usuario';
      _photoUrl      = data['profileImageUrl'];
      _isAdmin       = data['isAdmin'] ?? false;
      _isAthleteMode = data['isAthleteMode'] ?? false;
      _avatarConfig  = parsed ?? AvatarConfig.random();
    });
  }

  void _showGenerateTestDataDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Theme.of(context).colorScheme.surface,
        title: Text('Generar datos de prueba',
            style: AppTypography.h3.copyWith(color: AppColors.textPrimary(context))),
        content: Text(
          'Esto borrará TODOS tus entrenamientos actuales y creará ~55 sesiones realistas distribuidas en los últimos 90 días.\n\n¿Continuar?',
          style: AppTypography.body.copyWith(color: AppColors.iconMutedOf(context)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              _generateTestData();
            },
            style: TextButton.styleFrom(foregroundColor: AppColors.rpeMax),
            child: const Text('Borrar y generar'),
          ),
        ],
      ),
    );
  }

  Future<void> _generateTestData() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null || !mounted) return;

    ModernSnackBar.showWarning(context, 'Generando datos de prueba...');

    try {
      final firestore = FirebaseFirestore.instance;
      final col = firestore.collection('users').doc(uid).collection('trainings');

      // Borrar entrenamientos existentes
      final existing = await col.limit(500).get();
      final deleteBatch = firestore.batch();
      for (final doc in existing.docs) {
        deleteBatch.delete(doc.reference);
      }
      await deleteBatch.commit();

      // Generar nuevos (misma lógica que el script)
      final random = Random();
      final now = DateTime.now();
      const types = ['rodaje', 'series', 'tempo', 'largo'];

      final trainings = <Map<String, dynamic>>[];
      double totalKm = 0;
      int totalSec = 0;

      for (int dayBack = 90; dayBack >= 0; dayBack--) {
        final date = now.subtract(Duration(days: dayBack));
        final restChance = date.weekday == DateTime.sunday ? 0.60 : 0.38;
        if (random.nextDouble() < restChance) continue;

        final type = (date.weekday == DateTime.saturday)
            ? 'largo'
            : (date.weekday == DateTime.tuesday || date.weekday == DateTime.thursday)
                ? (random.nextBool() ? 'series' : 'tempo')
                : types[random.nextInt(types.length)];

        final (distM, durMin, rpe, serieCount) = switch (type) {
          'series' => (6000 + random.nextInt(3000), 35 + random.nextInt(15),
              7.5 + random.nextDouble() * 1.5, 5 + random.nextInt(4)),
          'tempo'  => (8000 + random.nextInt(4000), 45 + random.nextInt(20),
              6.5 + random.nextDouble() * 1.5, 2),
          'largo'  => (16000 + random.nextInt(9000), 90 + random.nextInt(40),
              5.0 + random.nextDouble(), 1),
          _        => (6000 + random.nextInt(7000), 35 + random.nextInt(25),
              4.0 + random.nextDouble() * 1.5, 1 + random.nextInt(2)),
        };

        final v = 0.85 + random.nextDouble() * 0.30;
        final finalDistM = (distM * v).toInt();
        final finalDurSec = ((durMin * v) * 60).toInt().clamp(300, 18000);
        final distPerSerie = finalDistM ~/ serieCount;
        final secPerSerie = finalDurSec / serieCount;

        final series = List.generate(serieCount, (_) => {
          'distanciaM':  distPerSerie,
          'tiempoSec':   double.parse(secPerSerie.toStringAsFixed(1)),
          'descansoSec': serieCount > 2 ? 60 + random.nextInt(60) : 0,
          'rpe':         double.parse((rpe + (random.nextDouble() - 0.5)).clamp(1.0, 10.0).toStringAsFixed(1)),
          'fcMedia':     138.0 + random.nextInt(30),
          'usedGps':     random.nextBool(),
        });

        final loadScore = (finalDistM / 1000.0) * rpe * 10;
        totalKm += finalDistM / 1000.0;
        totalSec += finalDurSec;

        trainings.add({
          'titulo':          '${type[0].toUpperCase()}${type.substring(1)}',
          'fecha':           date.toIso8601String(),
          'gps':             random.nextDouble() > 0.25,
          'series':          series,
          'distanciaTotalM': finalDistM,
          'tiempoTotalSec':  finalDurSec.toDouble(),
          'rpePromedio':     double.parse(rpe.toStringAsFixed(1)),
          'ritmoMedioSecKm': finalDistM > 0 ? (finalDurSec / (finalDistM / 1000.0)).toInt() : null,
          'loadScore':       double.parse(loadScore.toStringAsFixed(1)),
          'fcMediaSesion':   138.0 + random.nextInt(25),
          'isManual':        random.nextDouble() > 0.75,
          'tags':            _tagsForType(type, random),
          'createdAt':       date.toIso8601String(),
          'updatedAt':       date.toIso8601String(),
        });
      }

      // Guardar en batches de 400
      for (int i = 0; i < trainings.length; i += 400) {
        final chunk = trainings.sublist(i, (i + 400).clamp(0, trainings.length));
        final batch = firestore.batch();
        for (final t in chunk) {
          batch.set(col.doc(), t);
        }
        await batch.commit();
      }

      // Generar sesiones planificadas (próximas 4 semanas)
      await _generatePlannedSessions(firestore, uid, random);

      // Actualizar stats
      await firestore.collection('users').doc(uid).update({
        'totalSessions':    trainings.length,
        'totalKm':          double.parse(totalKm.toStringAsFixed(2)),
        'totalTimeMinutes': totalSec ~/ 60,
        'lastTrainingDate': now.toIso8601String(),
      });

      if (!mounted) return;
      ModernSnackBar.showSuccess(context,
          '${trainings.length} entrenamientos + sesiones planificadas generadas · ${totalKm.toStringAsFixed(0)} km');
    } catch (e) {
      if (!mounted) return;
      ModernSnackBar.showError(context, 'Error: $e');
    }
  }

  List<String> _tagsForType(String type, Random random) {
    const customExtras = ['pista', 'montaña', 'lluvia'];
    final tags = switch (type) {
      'series' => ['series'],
      'tempo'  => ['tempo'],
      'largo'  => ['largo', 'rodaje'],
      _        => ['rodaje'],
    };
    if (random.nextDouble() < 0.30) {
      tags.add(customExtras[random.nextInt(customExtras.length)]);
    }
    return tags;
  }

  Future<void> _generatePlannedSessions(
    FirebaseFirestore firestore, String uid, Random random,
  ) async {
    // Borrar sesiones planificadas existentes
    final col = firestore.collection('users').doc(uid).collection('athleteSessions');
    final existing = await col.limit(500).get();
    if (existing.docs.isNotEmpty) {
      final deleteBatch = firestore.batch();
      for (final doc in existing.docs) {
        deleteBatch.delete(doc.reference);
      }
      await deleteBatch.commit();
    }

    final now = DateTime.now();
    const categories = ['rodaje_base', 'series_medias', 'tempo', 'rodaje_largo'];
    final sessions = <Map<String, dynamic>>[];

    // -14 días (pasadas, completadas) hasta +28 días (futuras, planificadas)
    for (int i = -14; i <= 28; i++) {
      final date = now.add(Duration(days: i));
      if (date.weekday == DateTime.sunday) continue;
      if (random.nextDouble() > 0.70) continue;

      final isPast   = i < 0;
      final status   = isPast ? 'completed' : 'planned';
      final category = categories[random.nextInt(categories.length)];
      final dateStr  = '${date.year}-'
          '${date.month.toString().padLeft(2, '0')}-'
          '${date.day.toString().padLeft(2, '0')}';

      sessions.add({
        'date':     dateStr,
        'time':     '${6 + random.nextInt(12)}:00',
        'category': category,
        'status':   status,
        if (isPast) 'completedTrainingId': null,
        'blocks': [
          {
            'type':            'continuousDistance',
            'distanceM':       3000 + random.nextInt(5000),
            'targetPaceMinMin': 5,
            'targetPaceMaxMin': 6,
            'targetRpe':       5.0,
          }
        ],
        'planningNotes': null,
        'createdAt':     FieldValue.serverTimestamp(),
        'updatedAt':     FieldValue.serverTimestamp(),
      });
    }

    for (int i = 0; i < sessions.length; i += 400) {
      final chunk = sessions.sublist(i, (i + 400).clamp(0, sessions.length));
      final batch = firestore.batch();
      for (final s in chunk) {
        batch.set(col.doc(), s);
      }
      await batch.commit();
    }
  }

  void _openAvatarCustomizer() {
    MainShell.shellKey.currentState?.navigateTo(14, params: _avatarConfig);
  }

  Future<void> _logout() async {
    try {
      await _authCtrl.signOut();
      if (!mounted) return;
      Navigator.of(context).pushAndRemoveUntil(
        AppRoute(page: const AuthPage()),
        (_) => false,
      );
    } catch (e) {
      if (!mounted) return;
      ModernSnackBar.showError(context, e.toString());
    }
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: AppSpacing.xl),

          // ── Cabecera ──────────────────────────────────────────────
          Center(
            child: Column(
              children: [
                GestureDetector(
                  onTap: _openAvatarCustomizer,
                  child: _avatarConfig != null
                      ? ClipOval(
                          child: SvgPicture.string(
                            AvatarGenerator.generateSVG(_avatarConfig!),
                            width: 80,
                            height: 80,
                            fit: BoxFit.cover,
                          ),
                        )
                      : CircleAvatar(
                          radius: 40,
                          backgroundColor: AppColors.surfaceOf(context),
                          child: Icon(Icons.person, color: AppColors.iconMutedOf(context), size: 40),
                        ),
                ),
                const SizedBox(height: AppSpacing.m),
                Text(_userName, style: AppTypography.h2.copyWith(color: AppColors.textPrimary(context))),
                const SizedBox(height: AppSpacing.xs),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  decoration: BoxDecoration(
                    color: _isAthleteMode
                        ? AppColors.brand.withOpacity(0.15)
                        : AppColors.surfaceOf(context),
                    border: Border.all(
                      color: _isAthleteMode ? AppColors.brand : AppColors.borderOf(context),
                    ),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    _isAthleteMode ? 'Modo Atleta' : 'Modo Libre',
                    style: AppTypography.small.copyWith(
                      color: _isAthleteMode ? AppColors.brand : AppColors.iconMuted,
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: AppSpacing.xxl),

          // ── Entrenamiento ─────────────────────────────────────────
          const _SectionTitle('ENTRENAMIENTO'),
          const SizedBox(height: AppSpacing.s),
          _MenuCard(children: [
            _MenuItem(
              icon: Icons.favorite_outline,
              label: 'Zonas de entrenamiento',
              subtitle: 'FC máx, zonas personalizadas',
              onTap: () => MainShell.shellKey.currentState?.navigateTo(9),
            ),
            const _MenuDivider(),
            _MenuItem(
              icon: Icons.history_outlined,
              label: 'Historial completo',
              onTap: () => MainShell.shellKey.currentState?.navigateTo(4),
            ),
            const _MenuDivider(),
            _MenuItem(
              icon: Icons.auto_awesome_outlined,
              label: 'Entrenador IA',
              subtitle: 'Sugerencias semanales',
              onTap: () => MainShell.shellKey.currentState?.navigateTo(16),
            ),
            const _MenuDivider(),
            _MenuItem(
              icon: Icons.edit_note_outlined,
              label: 'Registrar entrenamiento',
              subtitle: 'Sesión pasada sin móvil',
              onTap: () => Navigator.push(context, AppRoute(page: const ManualTrainingView())),
            ),
          ]),

          const SizedBox(height: AppSpacing.xl),

          // ── Configuración ─────────────────────────────────────────
          const _SectionTitle('CONFIGURACIÓN'),
          const SizedBox(height: AppSpacing.s),
          _MenuCard(children: [
            ListenableBuilder(
              listenable: Listenable.merge([
                HeartRateService().connectionState,
                HeartRateService().connectedDeviceName,
              ]),
              builder: (context, _) {
                final isConnected = HeartRateService().connectionState.value
                    == HrConnectionState.connected;
                final name = HeartRateService().connectedDeviceName.value;
                return _MenuItem(
                  icon: Icons.bluetooth_outlined,
                  label: 'Pulsómetro BLE',
                  subtitle: isConnected
                      ? 'Conectado${name != null ? ' · $name' : ''}'
                      : 'Sin conectar',
                  subtitleColor: isConnected ? AppColors.rpeLow : null,
                  onTap: () => MainShell.shellKey.currentState?.navigateTo(10),
                );
              },
            ),
            const _MenuDivider(),
            _MenuItem(
              icon: Icons.settings_outlined,
              label: 'Cuenta y ajustes',
              onTap: () => MainShell.shellKey.currentState?.navigateTo(8,
                  params: {'name': _userName, 'onUpdated': _loadUserData}),
            ),
            const _MenuDivider(),
            _MenuItem(
              icon: Icons.brush_outlined,
              label: 'Editar avatar',
              onTap: () => MainShell.shellKey.currentState?.navigateTo(14,
                  params: _avatarConfig),
            ),
          ]),

          // ── Admin (condicional) ───────────────────────────────────
          if (_isAdmin) ...[
            const SizedBox(height: AppSpacing.xl),
            const _SectionTitle('ADMINISTRACIÓN'),
            const SizedBox(height: AppSpacing.s),
            _MenuCard(children: [
              _MenuItem(
                icon: Icons.admin_panel_settings_outlined,
                label: 'Panel de administrador',
                onTap: () => Navigator.push(context, AppRoute(page: const AdminPanelScreen())),
              ),
              const _MenuDivider(),
              _MenuItem(
                icon: Icons.refresh_outlined,
                label: 'Generar datos de prueba',
                subtitle: 'Borrará todos tus entrenamientos y creará ~55 realistas',
                onTap: _showGenerateTestDataDialog,
              ),
              const _MenuDivider(),
              _MenuItem(
                icon: Icons.restart_alt_rounded,
                label: 'Reset cuotas IA',
                subtitle: 'Reinicia messagesUsed y previewsGenerated a 0',
                onTap: () async {
                  final uid = FirebaseAuth.instance.currentUser?.uid;
                  if (uid == null) return;
                  final now = DateTime.now();
                  final monday = now.subtract(Duration(days: now.weekday - 1));
                  final sunday = now.add(Duration(days: 7 - now.weekday));
                  await AiCoachRepository().saveUsage(
                    AiCoachUsage(
                      plan: 'athlete_chat_weekly',
                      messagesUsed: 0,
                      previewsGenerated: 0,
                      messagesLimit: 3,
                      periodStart: DateTime(monday.year, monday.month, monday.day),
                      periodEnd: DateTime(
                          sunday.year, sunday.month, sunday.day, 23, 59, 59),
                    ),
                    uid: uid,
                  );
                  if (context.mounted) {
                    ModernSnackBar.showSuccess(context, 'Cuotas reseteadas');
                  }
                },
              ),
              const _MenuDivider(),
              _MenuItem(
                icon: Icons.feedback_outlined,
                label: 'Reset feedback semanal',
                subtitle: 'Elimina el feedback de la semana actual',
                onTap: () async {
                  final uid = FirebaseAuth.instance.currentUser?.uid;
                  if (uid == null) return;

                  final now = DateTime.now();

                  final thisMonday = now.subtract(Duration(days: now.weekday - 1));
                  final thisWeekStart = '${thisMonday.year}-'
                      '${thisMonday.month.toString().padLeft(2, '0')}-'
                      '${thisMonday.day.toString().padLeft(2, '0')}';

                  final lastMonday = thisMonday.subtract(const Duration(days: 7));
                  final lastWeekStart = '${lastMonday.year}-'
                      '${lastMonday.month.toString().padLeft(2, '0')}-'
                      '${lastMonday.day.toString().padLeft(2, '0')}';

                  final col = FirebaseFirestore.instance
                      .collection('users')
                      .doc(uid)
                      .collection('aiCoachFeedback');

                  await Future.wait([
                    col.doc(thisWeekStart).delete(),
                    col.doc(lastWeekStart).delete(),
                  ]);

                  if (context.mounted) {
                    ModernSnackBar.showSuccess(context, 'Feedback reseteado');
                  }
                },
              ),
            ]),
          ],

          const SizedBox(height: AppSpacing.xl),
          const _SectionTitle('AYUDA'),
          const SizedBox(height: AppSpacing.s),
          _MenuCard(children: [
            _MenuItem(
              icon: Icons.school_rounded,
              label: 'Cómo funciona Running Laps',
              subtitle: 'Tutorial del modo atleta',
              onTap: () => Navigator.push(
                context,
                AppRoute(
                  page: const AthleteTutorialView(
                    dismissible: true,
                  ),
                ),
              ),
            ),
          ]),

          const SizedBox(height: AppSpacing.xxl),

          // ── Cerrar sesión ─────────────────────────────────────────
          Center(
            child: ValueListenableBuilder<bool>(
              valueListenable: _authCtrl.isLoading,
              builder: (context, isLoading, _) => TextButton.icon(
                icon: const Icon(Icons.logout_rounded, size: 18),
                label: Text(isLoading ? 'Cerrando sesión...' : 'Cerrar sesión'),
                style: TextButton.styleFrom(foregroundColor: AppColors.rpeMax),
                onPressed: isLoading ? null : _logout,
              ),
            ),
          ),

          const SizedBox(height: 100),
        ],
      ),
    );
  }
}

// ─── Widgets privados ─────────────────────────────────────────────────────────

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.title);
  final String title;

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: AppTypography.small.copyWith(
        color: AppColors.iconMutedOf(context),
        letterSpacing: 1.2,
        fontWeight: FontWeight.w600,
      ),
    );
  }
}

class _MenuCard extends StatelessWidget {
  const _MenuCard({required this.children});
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surfaceOf(context),
        border: Border.all(color: AppColors.borderOf(context)),
        borderRadius: BorderRadius.circular(AppDimens.cardRadius),
      ),
      child: Column(children: children),
    );
  }
}

class _MenuItem extends StatelessWidget {
  const _MenuItem({
    required this.icon,
    required this.label,
    required this.onTap,
    this.subtitle,
    this.subtitleColor,
  });

  final IconData icon;
  final String label;
  final String? subtitle;
  final Color? subtitleColor;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppDimens.cardRadius),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.l,
          vertical: AppSpacing.m,
        ),
        child: Row(
          children: [
            Icon(icon, color: AppColors.iconMutedOf(context), size: AppDimens.iconSizeSmall),
            const SizedBox(width: AppSpacing.m),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(label, style: AppTypography.body.copyWith(color: AppColors.textPrimary(context))),
                  if (subtitle != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      subtitle!,
                      style: AppTypography.small.copyWith(
                        color: subtitleColor ?? AppColors.iconMutedOf(context),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            Icon(Icons.chevron_right, color: AppColors.iconMutedOf(context), size: 18),
          ],
        ),
      ),
    );
  }
}

class _MenuDivider extends StatelessWidget {
  const _MenuDivider();

  @override
  Widget build(BuildContext context) {
    // indent = AppSpacing.l (16) + iconSizeSmall (20) + AppSpacing.m (12) = 48
    return Divider(color: AppColors.borderOf(context), height: 1, indent: 48);
  }
}


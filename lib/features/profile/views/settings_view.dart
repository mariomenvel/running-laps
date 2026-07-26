import 'package:flutter/material.dart';

import 'package:running_laps/core/services/settings_service.dart';
import 'package:running_laps/core/theme/app_colors.dart';
import 'package:running_laps/core/theme/app_theme.dart';
import 'package:running_laps/core/utils/app_transitions.dart';
import 'package:running_laps/core/widgets/app_bottom_sheet.dart';
import 'package:running_laps/core/widgets/app_header.dart';
import 'package:running_laps/core/widgets/back_pill.dart';
import 'package:running_laps/core/widgets/main_shell.dart';
import 'package:running_laps/core/widgets/shell_embedding_scope.dart';
import 'package:running_laps/core/widgets/modern_snackbar.dart';
import 'package:running_laps/features/auth/viewmodels/auth_controller.dart';
import 'package:running_laps/features/auth/views/auth_page.dart';

/// Ajustes de la cuenta.
///
/// Sustituye a la antigua `AccountSettingsView`, de la que solo se conservan
/// las tres funciones que van a producto: **cambiar nombre**, **borrar
/// cuenta** y **GPS por defecto**. Lo demás que vivía allí (estilo de
/// tarjetas, alarmas por defecto, distancia de marca destacada, cambiar
/// contraseña) se retiró por decisión de producto — ver CLAUDE.md, deuda #5.
///
/// Es también el sitio donde vivirá la gestión de la suscripción
/// (`docs/MONETIZATION_ARCHITECTURE.md`); por eso la pantalla existe como tal
/// y no se disolvió entera dentro del menú de Perfil.
class SettingsView extends StatefulWidget {
  const SettingsView({
    super.key,
    required this.currentName,
    required this.onNameUpdated,
  });

  final String currentName;
  final VoidCallback onNameUpdated;

  @override
  State<SettingsView> createState() => _SettingsViewState();
}

class _SettingsViewState extends State<SettingsView> {
  final AuthController _authCtrl = AuthController();

  late String _displayName = widget.currentName;
  bool _gpsDefault = false;
  bool _loadingPrefs = true;

  @override
  void initState() {
    super.initState();
    _loadPrefs();
  }

  @override
  void dispose() {
    _authCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadPrefs() async {
    final gps = await SettingsService().getGpsDefault();
    if (!mounted) return;
    setState(() {
      _gpsDefault = gps;
      _loadingPrefs = false;
    });
  }

  // ── Cambiar nombre ────────────────────────────────────────────────────────

  Future<void> _showChangeNameSheet() async {
    final nameCtrl = TextEditingController(text: _displayName);
    final passCtrl = TextEditingController();
    // Con Google/Apple no hay contraseña que pedir: la reautenticación la
    // resuelve el proveedor.
    final needsPassword = !_authCtrl.isGoogleUser() && !_authCtrl.isAppleUser();

    await showAppBottomSheet<void>(
      context: context,
      builder: (sheetCtx) => Padding(
        padding: EdgeInsets.only(
          left: AppSpacing.xl,
          right: AppSpacing.xl,
          top: AppSpacing.m,
          bottom: MediaQuery.of(sheetCtx).viewInsets.bottom + AppSpacing.xl,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Cambiar nombre',
                style: AppTypography.h2
                    .copyWith(color: AppColors.textPrimary(sheetCtx))),
            const SizedBox(height: AppSpacing.s),
            Text(
              needsPassword
                  ? 'Introduce tu contraseña para confirmar el cambio.'
                  : 'Deberás identificarte de nuevo con tu proveedor para '
                      'confirmar el cambio.',
              style: AppTypography.small
                  .copyWith(color: AppColors.textSecondary(sheetCtx)),
            ),
            const SizedBox(height: AppSpacing.l),
            TextField(
              controller: nameCtrl,
              textCapitalization: TextCapitalization.words,
              decoration: _fieldDecoration(sheetCtx, 'Tu nombre'),
            ),
            if (needsPassword) ...[
              const SizedBox(height: AppSpacing.m),
              TextField(
                controller: passCtrl,
                obscureText: true,
                decoration: _fieldDecoration(sheetCtx, 'Contraseña'),
              ),
            ],
            const SizedBox(height: AppSpacing.xl),
            ValueListenableBuilder<bool>(
              valueListenable: _authCtrl.isLoading,
              builder: (_, isLoading, __) => FilledButton(
                onPressed: isLoading
                    ? null
                    : () => _submitNameChange(
                          sheetCtx,
                          name: nameCtrl.text,
                          password: passCtrl.text,
                          needsPassword: needsPassword,
                        ),
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.brand,
                  minimumSize: const Size(double.infinity, 52),
                ),
                child: isLoading
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white),
                      )
                    : const Text('Guardar'),
              ),
            ),
          ],
        ),
      ),
    );

    nameCtrl.dispose();
    passCtrl.dispose();
  }

  Future<void> _submitNameChange(
    BuildContext sheetCtx, {
    required String name,
    required String password,
    required bool needsPassword,
  }) async {
    final trimmed = name.trim();
    if (trimmed.isEmpty) {
      ModernSnackBar.showError(sheetCtx, 'El nombre no puede estar vacío');
      return;
    }
    if (needsPassword && password.isEmpty) {
      ModernSnackBar.showError(sheetCtx, 'Introduce tu contraseña');
      return;
    }

    try {
      await _authCtrl.reauthenticate(password);
      await _authCtrl.updateName(trimmed);
      if (!mounted || !sheetCtx.mounted) return;
      setState(() => _displayName = trimmed);
      widget.onNameUpdated();
      Navigator.pop(sheetCtx);
      ModernSnackBar.showSuccess(context, 'Nombre actualizado');
    } catch (e) {
      if (sheetCtx.mounted) ModernSnackBar.showError(sheetCtx, e.toString());
    }
  }

  // ── Borrar cuenta ─────────────────────────────────────────────────────────

  Future<void> _showDeleteAccountSheet() async {
    final passCtrl = TextEditingController();
    final needsPassword = !_authCtrl.isGoogleUser() && !_authCtrl.isAppleUser();

    await showAppBottomSheet<void>(
      context: context,
      builder: (sheetCtx) => Padding(
        padding: EdgeInsets.only(
          left: AppSpacing.xl,
          right: AppSpacing.xl,
          top: AppSpacing.m,
          bottom: MediaQuery.of(sheetCtx).viewInsets.bottom + AppSpacing.xl,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Borrar cuenta',
                style: AppTypography.h2
                    .copyWith(color: AppColors.textPrimary(sheetCtx))),
            const SizedBox(height: AppSpacing.s),
            Text(
              'Se eliminan tu cuenta y todos tus entrenamientos, de forma '
              'permanente. No se puede deshacer.',
              style: AppTypography.body
                  .copyWith(color: AppColors.textSecondary(sheetCtx)),
            ),
            const SizedBox(height: AppSpacing.l),
            if (needsPassword)
              TextField(
                controller: passCtrl,
                obscureText: true,
                decoration: _fieldDecoration(sheetCtx, 'Contraseña'),
              )
            else
              Text(
                'Deberás identificarte de nuevo con tu proveedor para '
                'confirmar.',
                style: AppTypography.small
                    .copyWith(color: AppColors.textSecondary(sheetCtx)),
              ),
            const SizedBox(height: AppSpacing.xl),
            ValueListenableBuilder<bool>(
              valueListenable: _authCtrl.isLoading,
              builder: (_, isLoading, __) => FilledButton(
                onPressed: isLoading
                    ? null
                    : () => _submitDeleteAccount(
                          sheetCtx,
                          password: passCtrl.text,
                          needsPassword: needsPassword,
                        ),
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.rpeMax,
                  minimumSize: const Size(double.infinity, 52),
                ),
                child: isLoading
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white),
                      )
                    : const Text('Borrar mi cuenta'),
              ),
            ),
            const SizedBox(height: AppSpacing.s),
            TextButton(
              onPressed: () => Navigator.pop(sheetCtx),
              child: Text('Cancelar',
                  style: TextStyle(color: AppColors.textSecondary(sheetCtx))),
            ),
          ],
        ),
      ),
    );

    passCtrl.dispose();
  }

  Future<void> _submitDeleteAccount(
    BuildContext sheetCtx, {
    required String password,
    required bool needsPassword,
  }) async {
    if (needsPassword && password.isEmpty) {
      ModernSnackBar.showError(sheetCtx, 'Introduce tu contraseña');
      return;
    }
    try {
      // La Cloud Function exige sesión reciente (auth_time < 10 min), así que
      // la reautenticación no es solo una confirmación de la UI.
      await _authCtrl.reauthenticate(password);
      await _authCtrl.deleteAccount();
      if (!mounted) return;
      Navigator.of(context).pushAndRemoveUntil(
        AppRoute(page: const AuthPage()),
        (_) => false,
      );
      ModernSnackBar.showSuccess(context, 'Cuenta eliminada');
    } catch (e) {
      if (sheetCtx.mounted) ModernSnackBar.showError(sheetCtx, e.toString());
    }
  }

  // ── UI ────────────────────────────────────────────────────────────────────

  /// Embebida en el shell se cambia de pestaña; pusheada como ruta propia se
  /// hace pop (mismo criterio que ProfileView).
  void _goBack() {
    if (ShellEmbeddingScope.isEmbedded(context)) {
      MainShell.shellKey.currentState?.navigateBack();
    } else {
      Navigator.of(context).pop();
    }
  }

  InputDecoration _fieldDecoration(BuildContext context, String hint) {
    OutlineInputBorder border(Color color, double width) => OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: color, width: width),
        );
    return InputDecoration(
      hintText: hint,
      hintStyle: AppTypography.body.copyWith(color: AppColors.textSecondary(context)),
      filled: true,
      fillColor: AppColors.surface2Of(context),
      contentPadding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.m,
        vertical: AppSpacing.m,
      ),
      border: border(AppColors.borderOf(context), 0.5),
      enabledBorder: border(AppColors.borderOf(context), 0.5),
      focusedBorder: border(AppColors.brand, 1.5),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background(context),
      body: Column(
        children: [
          const AppHeader(showBottomDivider: false),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.l),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: AppSpacing.m),
                  BackPill(onTap: _goBack),
                  const SizedBox(height: AppSpacing.l),

                  Text('Ajustes',
                      style: AppTypography.h1
                          .copyWith(color: AppColors.textPrimary(context))),
                  const SizedBox(height: AppSpacing.xl),

                  _SectionLabel('CUENTA'),
                  const SizedBox(height: AppSpacing.s),
                  _Card(children: [
                    _Tile(
                      icon: Icons.person_outline_rounded,
                      label: 'Nombre',
                      value: _displayName,
                      onTap: _showChangeNameSheet,
                    ),
                  ]),

                  const SizedBox(height: AppSpacing.xl),

                  _SectionLabel('ENTRENAMIENTO'),
                  const SizedBox(height: AppSpacing.s),
                  _Card(children: [
                    _SwitchTile(
                      icon: Icons.location_on_outlined,
                      label: 'GPS activado por defecto',
                      subtitle: 'Al empezar un entrenamiento',
                      value: _gpsDefault,
                      enabled: !_loadingPrefs,
                      onChanged: (value) {
                        setState(() => _gpsDefault = value);
                        SettingsService().setGpsDefault(value);
                      },
                    ),
                  ]),

                  const SizedBox(height: AppSpacing.xxl),

                  Center(
                    child: TextButton(
                      onPressed: _showDeleteAccountSheet,
                      style: TextButton.styleFrom(
                        foregroundColor: AppColors.rpeMax,
                      ),
                      child: const Text('Borrar cuenta'),
                    ),
                  ),

                  const SizedBox(height: 100),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Widgets privados ─────────────────────────────────────────────────────────

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => Text(
        text,
        style: AppTypography.small.copyWith(
          color: AppColors.iconMutedOf(context),
          letterSpacing: 1.2,
          fontWeight: FontWeight.w600,
        ),
      );
}

class _Card extends StatelessWidget {
  const _Card({required this.children});
  final List<Widget> children;

  @override
  Widget build(BuildContext context) => Container(
        decoration: BoxDecoration(
          color: AppColors.surfaceOf(context),
          border: Border.all(color: AppColors.borderOf(context)),
          borderRadius: BorderRadius.circular(AppDimens.cardRadius),
        ),
        child: Column(children: children),
      );
}

class _Tile extends StatelessWidget {
  const _Tile({
    required this.icon,
    required this.label,
    required this.onTap,
    this.value,
  });

  final IconData icon;
  final String label;
  final String? value;
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
            Icon(icon,
                color: AppColors.iconMutedOf(context),
                size: AppDimens.iconSizeSmall),
            const SizedBox(width: AppSpacing.m),
            Expanded(
              child: Text(label,
                  style: AppTypography.body
                      .copyWith(color: AppColors.textPrimary(context))),
            ),
            if (value != null)
              Text(value!,
                  style: AppTypography.body
                      .copyWith(color: AppColors.textSecondary(context))),
            const SizedBox(width: AppSpacing.s),
            Icon(Icons.chevron_right,
                color: AppColors.iconMutedOf(context), size: 18),
          ],
        ),
      ),
    );
  }
}

class _SwitchTile extends StatelessWidget {
  const _SwitchTile({
    required this.icon,
    required this.label,
    required this.value,
    required this.onChanged,
    this.subtitle,
    this.enabled = true,
  });

  final IconData icon;
  final String label;
  final String? subtitle;
  final bool value;
  final bool enabled;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.l,
        vertical: AppSpacing.s,
      ),
      child: Row(
        children: [
          Icon(icon,
              color: value ? AppColors.brand : AppColors.iconMutedOf(context),
              size: AppDimens.iconSizeSmall),
          const SizedBox(width: AppSpacing.m),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(label,
                    style: AppTypography.body
                        .copyWith(color: AppColors.textPrimary(context))),
                if (subtitle != null) ...[
                  const SizedBox(height: 2),
                  Text(subtitle!,
                      style: AppTypography.small
                          .copyWith(color: AppColors.textSecondary(context))),
                ],
              ],
            ),
          ),
          Switch.adaptive(
            value: value,
            onChanged: enabled ? onChanged : null,
            activeTrackColor: AppColors.brand,
          ),
        ],
      ),
    );
  }
}

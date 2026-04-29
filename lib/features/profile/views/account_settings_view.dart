import 'package:flutter/material.dart';
import 'package:running_laps/core/utils/app_transitions.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:running_laps/config/app_theme.dart';
import 'package:running_laps/core/theme/app_colors.dart';
import 'package:running_laps/core/theme/theme_service.dart';
import '../../auth/viewmodels/auth_controller.dart';
import '../../auth/views/auth_page.dart';
import '../../../core/widgets/modern_snackbar.dart';
import '../../../core/widgets/app_header.dart';
import '../../../core/widgets/gradient_banner.dart';
import '../../../core/services/settings_service.dart';
import '../../../core/services/wear_auth_service.dart';

import '../../templates/data/template_models.dart';
import '../../templates/widgets/alarm_config_sheet.dart';

class AccountSettingsView extends StatefulWidget {
  final String currentName;
  final VoidCallback onNameUpdated;

  const AccountSettingsView({
    Key? key, 
    required this.currentName,
    required this.onNameUpdated,
  }) : super(key: key);

  @override
  State<AccountSettingsView> createState() => _AccountSettingsViewState();
}

class _AccountSettingsViewState extends State<AccountSettingsView> {
  final AuthController _authCtrl = AuthController();
  late String _displayName;
  
  // Settings state
  bool _useWhiteCards = true;
  bool _alarmDefault = false;
  bool _gpsDefault = false;
  bool _watchConnected = false;
  int _bestMarkDistanceM = 400;

  @override
  void initState() {
    super.initState();
    _displayName = widget.currentName;
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final settings = SettingsService();
    final cardStyle = await settings.getCardStyle();
    final alarm = await settings.getAlarmEnabled();
    final gps = await settings.getGpsDefault();
    final prefs = await SharedPreferences.getInstance();

    int bestDist = 400;
    try {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid != null) {
        final doc = await FirebaseFirestore.instance
            .collection('users')
            .doc(uid)
            .collection('settings')
            .doc('bestMarkDistance')
            .get();
        if (doc.exists && doc.data()?['distanceM'] != null) {
          bestDist = (doc.data()!['distanceM'] as num).toInt();
        }
      }
    } catch (_) {}

    if (mounted) {
      setState(() {
        _useWhiteCards = cardStyle;
        _alarmDefault = alarm;
        _gpsDefault = gps;
        _watchConnected = prefs.getBool('watch_connected') ?? false;
        _bestMarkDistanceM = bestDist;
      });
    }
  }

  // =====================================================
  // DIÁLOGOS (Migrados de ProfileMenuView)
  // =====================================================

  void _showChangeNameDialog() {
    final TextEditingController nameEditCtrl = TextEditingController(text: _displayName);
    final TextEditingController passCtrl = TextEditingController();
    final bool isGoogle = _authCtrl.isGoogleUser();
    
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(32),
            topRight: Radius.circular(32),
          ),
        ),
        padding: EdgeInsets.only(
          left: 24,
          right: 24,
          top: 12,
          bottom: MediaQuery.of(context).viewInsets.bottom + 32,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.onSurface.withOpacity(0.2),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 24),
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppColors.brand.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.person_outline_rounded, size: 40, color: Theme.of(context).brightness == Brightness.dark ? AppColors.brandLight : AppColors.brand),
            ),
            const SizedBox(height: 24),
            Text(
              'Cambiar nombre',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w900,
                color: Theme.of(context).colorScheme.onSurface,
                letterSpacing: -0.5,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              isGoogle
                ? 'Deberás identificarte con Google para confirmar el cambio.'
                : 'Introduce tu contraseña para confirmar el cambio.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6), fontSize: 14),
            ),
            const SizedBox(height: 24),
            TextField(
              controller: nameEditCtrl,
              autofocus: true,
              style: const TextStyle(fontWeight: FontWeight.w600),
              decoration: InputDecoration(
                labelText: 'Nuevo nombre',
                filled: true,
                fillColor: Theme.of(context).colorScheme.onSurface.withOpacity(0.04),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide.none,
                ),
                prefixIcon: Icon(Icons.edit_rounded, color: Theme.of(context).brightness == Brightness.dark ? AppColors.brandLight : AppColors.brand),
              ),
            ),
            if (!isGoogle) ...[
              const SizedBox(height: 12),
              TextField(
                controller: passCtrl,
                obscureText: true,
                style: const TextStyle(fontWeight: FontWeight.w600),
                decoration: InputDecoration(
                  labelText: 'Contraseña de confirmación',
                  filled: true,
                  fillColor: Theme.of(context).colorScheme.onSurface.withOpacity(0.04),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide.none,
                  ),
                  prefixIcon: Icon(Icons.lock_outline, color: Theme.of(context).brightness == Brightness.dark ? AppColors.brandLight : AppColors.brand),
                ),
              ),
            ],
            const SizedBox(height: 32),
            Row(
              children: [
                Expanded(
                  child: TextButton(
                    onPressed: () => Navigator.pop(context),
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    ),
                    child: Text(
                      'Cancelar',
                      style: TextStyle(color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6), fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: ValueListenableBuilder<bool>(
                    valueListenable: _authCtrl.isLoading,
                    builder: (context, isLoading, _) {
                      return Container(
                        decoration: BoxDecoration(
                          color: AppColors.brand,
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [
                            BoxShadow(
                              color: AppColors.brand.withOpacity(0.3),
                              blurRadius: 10,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: ElevatedButton(
                          onPressed: isLoading ? null : () async {
                            if (nameEditCtrl.text.trim().isEmpty) return;
                            if (!isGoogle && passCtrl.text.isEmpty) {
                              ModernSnackBar.showError(context, 'Introduce tu contraseña para confirmar');
                              return;
                            }
                            try {
                              // 1. Reautenticar primero
                              await _authCtrl.reauthenticate(passCtrl.text);
                              
                              // 2. Actualizar nombre
                              await _authCtrl.updateName(nameEditCtrl.text);
                              
                              if (mounted) {
                                setState(() {
                                  _displayName = nameEditCtrl.text;
                                });
                                widget.onNameUpdated();
                                Navigator.pop(context);
                                ModernSnackBar.showSuccess(context, 'Nombre actualizado');
                              }
                            } catch (e) {
                              if (mounted) ModernSnackBar.showError(context, e.toString());
                            }
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.transparent,
                            foregroundColor: Colors.white,
                            shadowColor: Colors.transparent,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                          ),
                          child: isLoading
                            ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                            : const Text('GUARDAR', style: TextStyle(fontWeight: FontWeight.bold)),
                        ),
                      );
                    }
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _showChangePasswordDialog() {
    if (_authCtrl.isGoogleUser()) {
      ModernSnackBar.showWarning(context, 'Los usuarios de Google gestionan su contraseña en Google Account.');
      return;
    }

    final TextEditingController currentPassCtrl = TextEditingController();
    final TextEditingController newPassCtrl = TextEditingController();
    final TextEditingController confirmNewPassCtrl = TextEditingController();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(32),
            topRight: Radius.circular(32),
          ),
        ),
        padding: EdgeInsets.only(
          left: 24,
          right: 24,
          top: 12,
          bottom: MediaQuery.of(context).viewInsets.bottom + 32,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.onSurface.withOpacity(0.2),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 24),
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppColors.rpeMid.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.key_rounded, size: 40, color: AppColors.rpeMid),
            ),
            const SizedBox(height: 24),
            Text(
              'Cambiar contraseña',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w900,
                color: Theme.of(context).colorScheme.onSurface,
                letterSpacing: -0.5,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Introduce tu contraseña actual y la nueva dos veces.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6), fontSize: 14),
            ),
            const SizedBox(height: 24),
            TextField(
              controller: currentPassCtrl,
              obscureText: true,
              style: const TextStyle(fontWeight: FontWeight.w600),
              decoration: InputDecoration(
                labelText: 'Contraseña actual',
                filled: true,
                fillColor: Theme.of(context).colorScheme.onSurface.withOpacity(0.04),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide.none,
                ),
                prefixIcon: const Icon(Icons.lock_outline, color: AppColors.rpeMid),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: newPassCtrl,
              obscureText: true,
              style: const TextStyle(fontWeight: FontWeight.w600),
              decoration: InputDecoration(
                labelText: 'Contraseña nueva',
                filled: true,
                fillColor: Theme.of(context).colorScheme.onSurface.withOpacity(0.04),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide.none,
                ),
                prefixIcon: const Icon(Icons.lock_reset_rounded, color: AppColors.rpeMid),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: confirmNewPassCtrl,
              obscureText: true,
              style: const TextStyle(fontWeight: FontWeight.w600),
              decoration: InputDecoration(
                labelText: 'Confirmar contraseña nueva',
                filled: true,
                fillColor: Theme.of(context).colorScheme.onSurface.withOpacity(0.04),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide.none,
                ),
                prefixIcon: const Icon(Icons.check_circle_outline_rounded, color: AppColors.rpeMid),
              ),
            ),
            const SizedBox(height: 16),
            
            // Requisitos en tiempo real
            AnimatedBuilder(
              animation: Listenable.merge([newPassCtrl, confirmNewPassCtrl]),
              builder: (context, _) {
                final pass = newPassCtrl.text;
                final confirm = confirmNewPassCtrl.text;
                final hasMinLength = pass.length >= 8;
                final hasUppercase = pass.contains(RegExp(r'[A-Z]'));
                final hasDigits = pass.contains(RegExp(r'[0-9]'));
                final passwordsMatch = pass.isNotEmpty && pass == confirm;
                final allMet = hasMinLength && hasUppercase && hasDigits && passwordsMatch;

                return Column(
                  children: [
                    _buildRequirementRow("Mínimo 8 caracteres", hasMinLength),
                    const SizedBox(height: 4),
                    _buildRequirementRow("Al menos 1 mayúscula", hasUppercase),
                    const SizedBox(height: 4),
                    _buildRequirementRow("Al menos 1 número", hasDigits),
                    const SizedBox(height: 4),
                    _buildRequirementRow("Las contraseñas coinciden", passwordsMatch),
                    const SizedBox(height: 24),
                    Row(
                      children: [
                        Expanded(
                          child: TextButton(
                            onPressed: () => Navigator.pop(context),
                            style: TextButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                            ),
                            child: Text(
                              'Cancelar',
                              style: TextStyle(color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6), fontWeight: FontWeight.bold),
                            ),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: ValueListenableBuilder<bool>(
                            valueListenable: _authCtrl.isLoading,
                            builder: (context, isLoading, _) {
                              return Container(
                                decoration: BoxDecoration(
                                  color: allMet ? AppColors.rpeMid : AppColors.iconMuted,
                                  borderRadius: BorderRadius.circular(16),
                                  boxShadow: allMet ? [
                                    BoxShadow(
                                      color: AppColors.rpeMid.withOpacity(0.3),
                                      blurRadius: 10,
                                      offset: const Offset(0, 4),
                                    ),
                                  ] : [],
                                ),
                                child: ElevatedButton(
                                  onPressed: (isLoading || !allMet) ? null : () async {
                                    if (currentPassCtrl.text.isEmpty) {
                                      ModernSnackBar.showError(context, "Introduce tu contraseña actual");
                                      return;
                                    }
                                    try {
                                      // Reautenticar con la ACTUAL
                                      await _authCtrl.reauthenticate(currentPassCtrl.text);
                                      // Actualizar con la NUEVA
                                      await _authCtrl.updatePassword(newPassCtrl.text);
                                      if (mounted) {
                                        Navigator.pop(context);
                                        ModernSnackBar.showSuccess(context, 'Contraseña actualizada correctamente');
                                      }
                                    } catch (e) {
                                      if (mounted) ModernSnackBar.showError(context, e.toString());
                                    }
                                  },
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.transparent,
                                    foregroundColor: Colors.white,
                                    shadowColor: Colors.transparent,
                                    padding: const EdgeInsets.symmetric(vertical: 16),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                    disabledBackgroundColor: Colors.transparent,
                                    disabledForegroundColor: Colors.white.withOpacity(0.7),
                                  ),
                                  child: isLoading
                                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                                    : const Text('CAMBIAR', style: TextStyle(fontWeight: FontWeight.bold)),
                                ),
                              );
                            }
                          ),
                        ),
                      ],
                    ),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRequirementRow(String text, bool isMet) {
    return Row(
      children: [
        AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          width: 20,
          height: 20,
          decoration: BoxDecoration(
            color: isMet ? AppColors.rpeLow : Colors.transparent,
            border: Border.all(
              color: isMet ? AppColors.rpeLow : Theme.of(context).colorScheme.onSurface.withOpacity(0.35),
            ),
            shape: BoxShape.circle,
          ),
          child: Center(
            child: Icon(
              Icons.check,
              size: 14,
              color: isMet ? Colors.white : Colors.transparent,
            ),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          text,
          style: TextStyle(
            color: isMet ? AppColors.rpeLow : Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
            fontSize: 13,
            fontWeight: isMet ? FontWeight.w600 : FontWeight.normal,
          ),
        ),
      ],
    );
  }

  void _showDeleteAccountDialog() {
    final TextEditingController passCtrl = TextEditingController();
    final bool isGoogle = _authCtrl.isGoogleUser();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(32),
            topRight: Radius.circular(32),
          ),
        ),
        padding: EdgeInsets.only(
          left: 24,
          right: 24,
          top: 12,
          bottom: MediaQuery.of(context).viewInsets.bottom + 32,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.onSurface.withOpacity(0.2),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 24),
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppColors.rpeMax,
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.delete_sweep_rounded, size: 40, color: AppColors.rpeMax),
            ),
            const SizedBox(height: 24),
            Text(
              '¿Borrar cuenta?',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w900,
                color: Theme.of(context).colorScheme.onSurface,
                letterSpacing: -0.5,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Esta acción es IRREVERSIBLE. Se borrarán todos tus datos y entrenamientos permanentemente.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6), fontSize: 16),
            ),
            const SizedBox(height: 24),
            if (!isGoogle) ...[
              TextField(
                controller: passCtrl,
                obscureText: true,
                style: const TextStyle(fontWeight: FontWeight.w600),
                decoration: InputDecoration(
                  labelText: 'Introduce tu contraseña',
                  filled: true,
                  fillColor: Theme.of(context).colorScheme.onSurface.withOpacity(0.04),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide.none,
                  ),
                  prefixIcon: const Icon(Icons.lock_outline, color: AppColors.rpeMax),
                ),
              ),
            ] else ...[
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.rest,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Row(
                  children: [
                    Icon(Icons.login_rounded, color: AppColors.rest),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Text(
                        'Deberás identificarte de nuevo con Google para confirmar.',
                        style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 32),
            Row(
              children: [
                Expanded(
                  child: TextButton(
                    onPressed: () => Navigator.pop(context),
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    ),
                    child: Text(
                      'Cancelar',
                      style: TextStyle(color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6), fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: ValueListenableBuilder<bool>(
                    valueListenable: _authCtrl.isLoading,
                    builder: (context, isLoading, _) {
                      return Container(
                        decoration: BoxDecoration(
                          color: AppColors.rpeMax,
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [
                            BoxShadow(
                              color: AppColors.rpeMax.withOpacity(0.3),
                              blurRadius: 10,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: ElevatedButton(
                          onPressed: isLoading ? null : () async {
                            try {
                              if (isGoogle) {
                                await _authCtrl.reauthenticate(""); 
                              } else {
                                if (passCtrl.text.isEmpty) throw Exception('Introduce tu contraseña para confirmar');
                                await _authCtrl.reauthenticate(passCtrl.text);
                              }
                              await _authCtrl.deleteAccount();
                              if (mounted) {
                                Navigator.pop(context);
                                Navigator.pushAndRemoveUntil(
                                  context, 
                                  AppRoute(page: const AuthPage()),
                                  (r) => false
                                );
                                ModernSnackBar.showSuccess(context, 'Cuenta eliminada con éxito.');
                              }
                            } catch (e) {
                              if (mounted) ModernSnackBar.showError(context, e.toString());
                            }
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.transparent,
                            foregroundColor: Colors.white,
                            shadowColor: Colors.transparent,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                          ),
                          child: isLoading
                            ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                            : const Text('BORRAR', style: TextStyle(fontWeight: FontWeight.bold)),
                        ),
                      );
                    }
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // =====================================================
  // UI COMPONENTS
  // =====================================================

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 8, top: 24),
      child: Text(
        title.toUpperCase(),
        style: TextStyle(
          color: Theme.of(context).colorScheme.onSurface.withOpacity(0.5),
          fontSize: 12,
          fontWeight: FontWeight.bold,
          letterSpacing: 1.2,
        ),
      ),
    );
  }

  Widget _buildMenuTile({
    required String title,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
    bool isDestructive = false,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Theme.of(context).brightness == Brightness.dark
                ? Colors.transparent
                : Colors.black.withOpacity(0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(icon, color: color, size: 22),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Text(
                    title,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: isDestructive ? AppColors.rpeMax : Theme.of(context).colorScheme.onSurface,
                    ),
                  ),
                ),
                Icon(
                  Icons.arrow_forward_ios_rounded,
                  size: 16,
                  color: Theme.of(context).colorScheme.onSurface.withOpacity(0.35),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSwitchTile({
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
    required bool value,
    required ValueChanged<bool> onChanged,
    VoidCallback? onSettingsTap,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Theme.of(context).brightness == Brightness.dark
                ? Colors.transparent
                : Colors.black.withOpacity(0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: color, size: 22),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                  ),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 12,
                      color: Theme.of(context).colorScheme.onSurface.withOpacity(0.5),
                    ),
                  ),
                ],
              ),
            ),
            if (onSettingsTap != null && value)
              IconButton(
                icon: Icon(Icons.settings_suggest_rounded, color: Theme.of(context).colorScheme.onSurface.withOpacity(0.35), size: 20),
                onPressed: onSettingsTap,
              ),
            Transform.scale(
              scale: 0.9,
              child: Switch(
                value: value,
                onChanged: onChanged,
                activeColor: AppColors.brand,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCardStyleSetting() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: isDark ? Colors.transparent : Colors.black.withOpacity(0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
        border: Border.all(color: Theme.of(context).colorScheme.outline.withOpacity(0.5)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppColors.brand.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(Icons.style_rounded, color: isDark ? AppColors.brandLight : AppColors.brand, size: 22),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Text(
                'Estilo de tarjetas',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
              ),
            ),
            // Segmented control
            Container(
              padding: const EdgeInsets.all(3),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.onSurface.withOpacity(0.06),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                children: [
                  _buildStyleOption('Clásico', !_useWhiteCards),
                  _buildStyleOption('Moderno', _useWhiteCards),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStyleOption(String label, bool isSelected) {
    return GestureDetector(
      onTap: () async {
        final newValue = label == 'Moderno';
        await SettingsService().setCardStyle(newValue);
        if (mounted) setState(() => _useWhiteCards = newValue);
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.brand : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: isSelected ? Colors.white : Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
          ),
        ),
      ),
    );
  }

  Widget _buildBestMarkTile() {
    final distLabel = _bestMarkDistanceM >= 1000
        ? '${_bestMarkDistanceM ~/ 1000}k'
        : '${_bestMarkDistanceM}m';
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Theme.of(context).brightness == Brightness.dark
                ? Colors.transparent
                : Colors.black.withOpacity(0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: _showBestMarkPicker,
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFF7B1FA2).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.emoji_events_outlined, color: Color(0xFF7B1FA2), size: 22),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Mejor marca en',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: Theme.of(context).colorScheme.onSurface,
                        ),
                      ),
                      Text(
                        distLabel,
                        style: TextStyle(
                          fontSize: 12,
                          color: Theme.of(context).colorScheme.onSurface.withOpacity(0.5),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  Icons.arrow_forward_ios_rounded,
                  size: 16,
                  color: Theme.of(context).colorScheme.onSurface.withOpacity(0.35),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildThemeSelector() {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: ThemeService.themeMode,
      builder: (context, current, _) {
        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Theme.of(context).brightness == Brightness.dark
                    ? Colors.transparent
                    : Colors.black.withOpacity(0.03),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: AppColors.brand.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(Icons.brightness_4_rounded,
                          color: AppColors.brand, size: 22),
                    ),
                    const SizedBox(width: 16),
                    Text(
                      'Tema de la app',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: Theme.of(context).colorScheme.onSurface,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    _buildThemeOption(ThemeMode.system,
                        Icons.phone_android_rounded, 'Sistema', current),
                    const SizedBox(width: 8),
                    _buildThemeOption(ThemeMode.light,
                        Icons.light_mode_rounded, 'Claro', current),
                    const SizedBox(width: 8),
                    _buildThemeOption(ThemeMode.dark,
                        Icons.dark_mode_rounded, 'Oscuro', current),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildThemeOption(
      ThemeMode mode, IconData icon, String label, ThemeMode current) {
    final bool selected = current == mode;
    return Expanded(
      child: GestureDetector(
        onTap: () => ThemeService.setTheme(mode),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: selected ? AppColors.brand : Theme.of(context).colorScheme.onSurface.withOpacity(0.08),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            children: [
              Icon(icon,
                  size: 20,
                  color: selected ? Colors.white : Theme.of(context).colorScheme.onSurface.withOpacity(0.6)),
              const SizedBox(height: 4),
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight:
                      selected ? FontWeight.bold : FontWeight.normal,
                  color: selected ? Colors.white : Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _saveBestMarkDistance(int distanceM) async {
    try {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid == null) return;
      await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .collection('settings')
          .doc('bestMarkDistance')
          .set({'distanceM': distanceM}, SetOptions(merge: true));
      if (mounted) setState(() => _bestMarkDistanceM = distanceM);
    } catch (e) {
      if (mounted) ModernSnackBar.showError(context, 'No se pudo guardar');
    }
  }

  void _showBestMarkPicker() {
    const distances = [100, 200, 400, 800, 1000, 1500, 5000, 10000];
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(32),
            topRight: Radius.circular(32),
          ),
        ),
        padding: const EdgeInsets.fromLTRB(24, 12, 24, 36),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.onSurface.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'Distancia para mejor marca',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w800,
                color: Theme.of(context).colorScheme.onSurface,
                letterSpacing: -0.5,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Se usará para calcular tu mejor ritmo en esa distancia.',
              style: TextStyle(
                fontSize: 13,
                color: Theme.of(context).colorScheme.onSurface.withOpacity(0.5),
              ),
            ),
            const SizedBox(height: 20),
            StatefulBuilder(
              builder: (ctx, setSheet) => Wrap(
                spacing: 10,
                runSpacing: 10,
                children: distances.map((d) {
                  final isSel = d == _bestMarkDistanceM;
                  final label = d >= 1000 ? '${d ~/ 1000}k' : '${d}m';
                  return GestureDetector(
                    onTap: () {
                      setSheet(() {});
                      _saveBestMarkDistance(d);
                      Navigator.pop(ctx);
                    },
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 150),
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                      decoration: BoxDecoration(
                        color: isSel
                            ? AppColors.brand
                            : Theme.of(context).colorScheme.onSurface.withOpacity(0.07),
                        borderRadius: BorderRadius.circular(24),
                      ),
                      child: Text(
                        label,
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: isSel
                              ? Colors.white
                              : Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showAlarmSettings() async {
    final settings = SettingsService();
    final config = await settings.getAlarmConfig();
    
    if (!mounted) return;

    final initialAlerts = TemplateAlerts(
      enabled: true,
      mode: config['mode'],
      timeMin: config['timeMin'],
      timeSec: config['timeSec'],
      paceMin: config['paceMin'],
      paceSec: config['paceSec'],
      segmentDistance: config['segment'],
    );

    final TemplateAlerts? result = await showModalBottomSheet<TemplateAlerts>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => AlarmConfigSheet(initialAlerts: initialAlerts),
    );

    if (result != null && mounted) {
      await settings.saveAlarmConfig(
        mode: result.mode,
        timeMin: result.timeMin,
        timeSec: result.timeSec,
        paceMin: result.paceMin,
        paceSec: result.paceSec,
        segment: result.segmentDistance,
      );
      
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Ajustes de alarma guardados"),
          behavior: SnackBarBehavior.floating,
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  Future<void> _connectWatch() async {
    try {
      final connected = await WearAuthService().scanAndAuthenticateWatch(context);
      if (!mounted) return;
      if (connected) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setBool('watch_connected', true);
        setState(() => _watchConnected = true);
        ModernSnackBar.showSuccess(context, 'Reloj conectado correctamente');
      }
    } catch (e) {
      if (!mounted) return;
      ModernSnackBar.showError(context, e.toString());
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        top: false,
        bottom: false,
        child: Column(
          children: [
            AppHeader(
              onTapRight: () {},
            ),
            GradientBanner(
              title: 'Configuración de cuenta',
              subtitle: 'Gestiona tu perfil y seguridad',
              icon: Icons.manage_accounts_rounded,
              accentColor: AppColors.surface,
              height: 90,
            ),
            
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 24.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 12),
                    
                    _buildSectionHeader("Preferencias de entrenamiento"),
                    _buildSwitchTile(
                      title: "Alarmas de ritmo",
                      subtitle: "Activar avisos por defecto al iniciar",
                      icon: Icons.notifications_active_rounded,
                      color: AppColors.rpeMid,
                      value: _alarmDefault,
                      onChanged: (val) {
                        setState(() => _alarmDefault = val);
                        SettingsService().setAlarmEnabled(val);
                      },
                      onSettingsTap: _showAlarmSettings,
                    ),
                    _buildSwitchTile(
                      title: "GPS siempre activo",
                      subtitle: "Pre-configurar registro GPS al iniciar",
                      icon: Icons.location_on_rounded,
                      color: AppColors.rpeLow,
                      value: _gpsDefault,
                      onChanged: (val) {
                        setState(() => _gpsDefault = val);
                        SettingsService().setGpsDefault(val);
                      },
                    ),
                    
                    _buildSectionHeader("Apariencia"),
                    _buildSectionHeader("Apariencia"),
                    _buildThemeSelector(),
                    _buildCardStyleSetting(),

                    _buildSectionHeader("Estadísticas"),
                    _buildBestMarkTile(),

                    _buildSectionHeader("Perfil"),
                    _buildMenuTile(
                      title: "Cambiar mi nombre",
                      icon: Icons.edit_rounded,
                      color: AppColors.rest,
                      onTap: _showChangeNameDialog,
                    ),
                    
                    if (!_authCtrl.isGoogleUser()) ...[
                      _buildSectionHeader("Seguridad"),
                      _buildMenuTile(
                        title: "Cambiar mi contraseña",
                        icon: Icons.key_rounded,
                        color: AppColors.rpeMid,
                        onTap: _showChangePasswordDialog,
                      ),
                    ],

                    _buildSectionHeader("Dispositivos"),
                    _buildMenuTile(
                      title: _watchConnected ? "Reloj conectado ✓" : "Conectar reloj",
                      icon: _watchConnected ? Icons.check_circle_rounded : Icons.watch_rounded,
                      color: _watchConnected ? AppColors.rpeLow : AppColors.brand,
                      onTap: _connectWatch,
                    ),

                    _buildSectionHeader("Zona peligrosa"),
                    _buildMenuTile(
                      title: "Borrar cuenta permanentemente",
                      icon: Icons.delete_forever_rounded,
                      color: AppColors.rpeMax,
                      isDestructive: true,
                      onTap: _showDeleteAccountDialog,
                    ),
                    
                    const SizedBox(height: 40),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

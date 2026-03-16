import 'package:flutter/material.dart';
import 'package:running_laps/core/utils/app_transitions.dart';
import 'package:running_laps/config/app_theme.dart';
import 'package:running_laps/core/theme/theme_service.dart';
import '../../auth/viewmodels/auth_controller.dart';
import '../../auth/views/auth_page.dart';
import '../../../core/widgets/modern_snackbar.dart';
import '../../../core/widgets/app_header.dart';
import '../../../core/widgets/gradient_banner.dart';
import '../../../core/services/settings_service.dart';
import '../../home/views/home_view.dart';
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
  bool _alarmDefault = false;
  bool _gpsDefault = false;

  @override
  void initState() {
    super.initState();
    _displayName = widget.currentName;
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final settings = SettingsService();
    final alarm = await settings.getAlarmEnabled();
    final gps = await settings.getGpsDefault();
    if (mounted) {
      setState(() {
        _alarmDefault = alarm;
        _gpsDefault = gps;
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
                color: Tema.brandPurple.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.person_outline_rounded, size: 40, color: Tema.brandPurple),
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
                prefixIcon: const Icon(Icons.edit_rounded, color: Tema.brandPurple),
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
                  prefixIcon: const Icon(Icons.lock_outline, color: Tema.brandPurple),
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
                          gradient: LinearGradient(
                            colors: [Tema.brandPurple.withOpacity(0.8), Tema.brandPurple],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [
                            BoxShadow(
                              color: Tema.brandPurple.withOpacity(0.3),
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
                color: Colors.amber.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.key_rounded, size: 40, color: Colors.amber),
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
                prefixIcon: const Icon(Icons.lock_outline, color: Colors.amber),
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
                prefixIcon: const Icon(Icons.lock_reset_rounded, color: Colors.amber),
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
                prefixIcon: const Icon(Icons.check_circle_outline_rounded, color: Colors.amber),
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
                                  gradient: LinearGradient(
                                    colors: allMet 
                                        ? [Colors.amber.shade400, Colors.amber.shade700]
                                        : [Colors.grey.shade300, Colors.grey.shade500],
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                  ),
                                  borderRadius: BorderRadius.circular(16),
                                  boxShadow: allMet ? [
                                    BoxShadow(
                                      color: Colors.amber.withOpacity(0.3),
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
            color: isMet ? Colors.green : Colors.transparent,
            border: Border.all(
              color: isMet ? Colors.green : Theme.of(context).colorScheme.onSurface.withOpacity(0.35),
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
            color: isMet ? Colors.green : Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
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
                color: Colors.red.shade50,
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.delete_sweep_rounded, size: 40, color: Colors.red.shade400),
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
                  prefixIcon: const Icon(Icons.lock_outline, color: Colors.red),
                ),
              ),
            ] else ...[
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Row(
                  children: [
                    Icon(Icons.login_rounded, color: Colors.blue.shade600),
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
                          gradient: LinearGradient(
                            colors: [Colors.red.shade400, Colors.red.shade700],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.red.shade400.withOpacity(0.3),
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
                      color: isDestructive ? Colors.red : Theme.of(context).colorScheme.onSurface,
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
                activeColor: Tema.brandPurple,
              ),
            ),
          ],
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
                        color: Tema.brandPurple.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(Icons.brightness_4_rounded,
                          color: Tema.brandPurple, size: 22),
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
            color: selected ? Tema.brandPurple : Theme.of(context).colorScheme.onSurface.withOpacity(0.08),
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            AppHeader(
              onTapRight: () {},
            ),
            GradientBanner(
              title: 'Configuración de cuenta',
              subtitle: 'Gestiona tu perfil y seguridad',
              icon: Icons.manage_accounts_rounded,
              gradientColors: [
                Colors.blueGrey.shade800,
                Colors.blueGrey.shade400,
              ],
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
                      color: Colors.orange,
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
                      color: Colors.green,
                      value: _gpsDefault,
                      onChanged: (val) {
                        setState(() => _gpsDefault = val);
                        SettingsService().setGpsDefault(val);
                      },
                    ),
                    
                    _buildSectionHeader("Apariencia"),
                    _buildThemeSelector(),

                    _buildSectionHeader("Perfil"),
                    _buildMenuTile(
                      title: "Cambiar mi nombre",
                      icon: Icons.edit_rounded,
                      color: Colors.blue,
                      onTap: _showChangeNameDialog,
                    ),
                    
                    if (!_authCtrl.isGoogleUser()) ...[
                      _buildSectionHeader("Seguridad"),
                      _buildMenuTile(
                        title: "Cambiar mi contraseña",
                        icon: Icons.key_rounded,
                        color: Colors.amber,
                        onTap: _showChangePasswordDialog,
                      ),
                    ],

                    _buildSectionHeader("Zona peligrosa"),
                    _buildMenuTile(
                      title: "Borrar cuenta permanentemente",
                      icon: Icons.delete_forever_rounded,
                      color: Colors.red,
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

import 'dart:async';

import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:running_laps/core/theme/app_colors.dart';
import 'package:running_laps/core/widgets/modern_snackbar.dart';

class EmailVerificationPendingView extends StatefulWidget {
  final VoidCallback onVerified;

  const EmailVerificationPendingView({super.key, required this.onVerified});

  @override
  State<EmailVerificationPendingView> createState() =>
      _EmailVerificationPendingViewState();
}

class _EmailVerificationPendingViewState
    extends State<EmailVerificationPendingView> {
  bool _checking = false;
  bool _resendCooldown = false;
  int _cooldownSeconds = 0;
  Timer? _cooldownTimer;

  @override
  void dispose() {
    _cooldownTimer?.cancel();
    super.dispose();
  }

  Future<void> _checkVerified() async {
    setState(() => _checking = true);
    final user = FirebaseAuth.instance.currentUser;
    await user?.reload();
    final refreshedUser = FirebaseAuth.instance.currentUser;

    if (refreshedUser?.emailVerified == true) {
      try {
        await FirebaseFunctions.instance
            .httpsCallable('syncEmailVerified')
            .call();
        await refreshedUser?.getIdToken(true);
      } catch (e) {
        debugPrint('[EmailVerification] syncEmailVerified error: $e');
        // no bloqueante: el usuario ya está verificado en Auth,
        // el custom claim es defensa adicional, no requisito
      }
      widget.onVerified();
    } else {
      if (mounted) setState(() => _checking = false);
      if (mounted) {
        ModernSnackBar.showWarning(
          context,
          'Aún no hemos detectado la verificación. '
          'Intenta de nuevo en unos segundos.',
        );
      }
    }
  }

  Future<void> _resendEmail() async {
    await FirebaseAuth.instance.currentUser?.sendEmailVerification();
    if (!mounted) return;
    ModernSnackBar.showSuccess(context, 'Email reenviado');
    setState(() {
      _resendCooldown = true;
      _cooldownSeconds = 30;
    });
    _cooldownTimer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) {
        t.cancel();
        return;
      }
      setState(() => _cooldownSeconds--);
      if (_cooldownSeconds <= 0) {
        t.cancel();
        setState(() => _resendCooldown = false);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final email =
        FirebaseAuth.instance.currentUser?.email ?? '';

    return Scaffold(
      body: Container(
        decoration: isDark
            ? const BoxDecoration(color: AppColors.backgroundDark)
            : const BoxDecoration(
                color: Colors.white,
                image: DecorationImage(
                  image: AssetImage('assets/images/fondo.png'),
                  fit: BoxFit.cover,
                  opacity: 0.6,
                ),
              ),
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
            child: ConstrainedBox(
              constraints: BoxConstraints(
                minHeight: MediaQuery.of(context).size.height -
                    MediaQuery.of(context).padding.top -
                    MediaQuery.of(context).padding.bottom -
                    48,
              ),
              child: IntrinsicHeight(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(18),
                  child: Image.asset(
                    'assets/images/icono_launcher.png',
                    height: 80,
                    fit: BoxFit.contain,
                  ),
                ),
                const SizedBox(height: 40),
                Icon(
                  Icons.mark_email_unread_outlined,
                  size: 64,
                  color: isDark ? AppColors.brandLight : AppColors.brand,
                ),
                const SizedBox(height: 24),
                Text(
                  'Verifica tu email',
                  style: TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : const Color(0xFF1C1C1E),
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                Text(
                  'Hemos enviado un enlace de verificación a $email.\nRevisa tu correo y vuelve aquí.',
                  style: TextStyle(
                    fontSize: 15,
                    height: 1.5,
                    color: AppColors.textSecondary(context),
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 48),
                SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: FilledButton(
                    onPressed: _checking ? null : _checkVerified,
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.brand,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    child: _checking
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Text(
                            'Ya verifiqué mi email',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                  ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: OutlinedButton(
                    onPressed: _resendCooldown ? null : _resendEmail,
                    style: OutlinedButton.styleFrom(
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      side: BorderSide(
                        color: _resendCooldown
                            ? AppColors.brand.withValues(alpha: 0.3)
                            : AppColors.brand,
                      ),
                    ),
                    child: Text(
                      _resendCooldown
                          ? 'Reenviar email (${_cooldownSeconds}s)'
                          : 'Reenviar email',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: _resendCooldown
                            ? AppColors.brand.withValues(alpha: 0.4)
                            : AppColors.brand,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                TextButton(
                  onPressed: () => FirebaseAuth.instance.signOut(),
                  child: Text(
                    'Cerrar sesión',
                    style: TextStyle(
                      fontSize: 13,
                      color: AppColors.textSecondary(context),
                    ),
                  ),
                ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

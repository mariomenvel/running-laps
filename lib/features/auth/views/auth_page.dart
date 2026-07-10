import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:running_laps/features/auth/viewmodels/auth_controller.dart';
import 'package:running_laps/features/auth/views/auth_wrapper.dart';
import 'package:running_laps/features/auth/views/email_verification_pending_view.dart';
import 'package:running_laps/core/widgets/modern_snackbar.dart';
import 'package:running_laps/config/app_theme.dart';
import 'package:running_laps/core/theme/app_colors.dart';

// CAMBIO: La vista ahora usa el Controller
class AuthPage extends StatefulWidget {
  const AuthPage({super.key});

  @override
  State<AuthPage> createState() => _AuthPageState();
}

class _AuthPageState extends State<AuthPage> {
  // --- Controller ---
  final _authCtrl = AuthController();

  // --- Estado para ver/ocultar contraseñas ---
  bool _showLoginPassword = false;
  bool _showRegisterPassword = false;
  bool _showRegisterConfirmPassword = false;

  @override
  void dispose() {
    _authCtrl.dispose();
    super.dispose();
  }

  // ===================================================================
  // Lógica de Interacción con el Controller
  // ===================================================================

  void _showError(Object e) {
    final msg = _extractErrorMessage(e);
    if (!mounted) return;
    
    // SnackBar "Bonito"
    // SnackBar "Bonito"
    ModernSnackBar.showError(context, msg);
  }

  String _extractErrorMessage(Object e) {
    if (e is String) return e;

    final s = e.toString();

    final regex = RegExp(r'^(?:.*?:\s*)(.*)$');
    final match = regex.firstMatch(s);
    if (match != null && match.groupCount >= 1) {
      final extracted = match.group(1);
      if (extracted != null && extracted.isNotEmpty) return extracted;
    }

    return s;
  }

  Future<void> _signIn() async {
    try {
      await _authCtrl.signIn();
      if (!mounted) return;
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const AuthWrapper()),
        (route) => false,
      );
    } catch (e) {
      if (!mounted) return;
      _showError(e);
    }
  }

  Future<void> _signUp() async {
    try {
      await _authCtrl.signUp();
      if (!mounted) return;
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(
          builder: (_) => EmailVerificationPendingView(
            onVerified: () => Navigator.of(context).pushAndRemoveUntil(
              MaterialPageRoute(builder: (_) => const AuthWrapper()),
              (route) => false,
            ),
          ),
        ),
        (route) => false,
      );
    } catch (e) {
      if (!mounted) return;
      _showError(e);
    }
  }

  Future<void> _signInWithGoogle() async {
    try {
      await _authCtrl.signInWithGoogle();
      if (!mounted) return;
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const AuthWrapper()),
        (route) => false,
      );
    } catch (e) {
      if (!mounted) return;
      _showError(e);
    }
  }

  Future<void> _recoverPassword(String email) async {
    try {
      await _authCtrl.recoverPassword(email);
      if (!mounted) return;
      Navigator.of(context).pop(); // Cerrar el diálogo
      ModernSnackBar.showSuccess(
        context,
        'Correo de recuperación enviado. Revisa tu bandeja.',
      );
    } catch (e) {
      _showError(e);
    }
  }

  void _showForgotPasswordDialog() {
    final TextEditingController _resetEmailCtrl = TextEditingController();
    // Variable local para el error dentro del BottomSheet
    String? _localError;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            
            // Función interna para manejar el envío y actualizar el estado LOCAL del modal
            Future<void> _submitRecovery() async {
              setModalState(() {
                _localError = null; // Limpiar error previo
              });

              try {
                await _authCtrl.recoverPassword(_resetEmailCtrl.text);

                // `context` aquí es el del modal (sombreado por el builder):
                // el guard correcto es context.mounted, no el mounted del State.
                if (!context.mounted) return;
                Navigator.of(context).pop(); // Cerrar modal si éxito

                // Mostrar éxito en SnackBar (ya no hay modal tapándolo)
                ModernSnackBar.showSuccess(
                  context,
                  'Correo enviado. Revisa tu bandeja.',
                );
              } catch (e) {
                // Si el modal se cerró durante el await, no tocar su estado
                if (!context.mounted) return;
                // Si falla, actualizamos el estado DEL MODAL para mostrar el error
                setModalState(() {
                   _localError = _extractErrorMessage(e);
                });
              }
            }

            return Container(
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surface,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(25),
                  topRight: Radius.circular(25),
                ),
              ),
              padding: EdgeInsets.only(
                left: 24,
                right: 24,
                top: 24,
                bottom: MediaQuery.of(context).viewInsets.bottom + 24,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
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
                    'Recuperar contraseña',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).brightness == Brightness.dark ? AppColors.brandLight : AppColors.brand,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Introduce tu correo electrónico y te enviaremos un enlace para restablecer tu contraseña.',
                    style: TextStyle(
                      fontSize: 14,
                      color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 32),
                  _buildTextField(
                    controller: _resetEmailCtrl,
                    hintText: 'Correo electrónico',
                    prefixIcon: Icon(Icons.email_outlined, color: AppColors.iconMutedOf(context)),
                  ),
                  
                  // ZONA DE ERROR INLINE
                  if (_localError != null) ...[
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.rpeMax.withOpacity(0.12), // Fondo rojo suave
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppColors.rpeMax.withOpacity(0.3)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.error_outline, color: AppColors.rpeMax),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              _localError!,
                              style: const TextStyle(
                                color: AppColors.rpeMax,
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],

                  const SizedBox(height: 24),
                  ValueListenableBuilder<bool>(
                    valueListenable: _authCtrl.isLoading,
                    builder: (context, isLoading, child) {
                      return SizedBox(
                        height: 55,
                        child: ElevatedButton(
                          onPressed: isLoading
                              ? null
                              : _submitRecovery, // Llamamos a la función interna
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.brand,
                            foregroundColor: Colors.white,
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                            textStyle: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          child: isLoading
                              ? const SizedBox(
                                  width: 24,
                                  height: 24,
                                  child: CircularProgressIndicator(
                                    color: Colors.white,
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Text('ENVIAR ENLACE'),
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 16),
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: Text(
                      'Cancelar',
                      style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
                      fontWeight: FontWeight.bold,
                    ),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }


  Widget _buildPasswordRequirements() {
    // Escuchamos ambos controladores para actualizar si cambia cualquiera
    return AnimatedBuilder(
      animation: Listenable.merge([_authCtrl.passCtrl, _authCtrl.confirmPassCtrl]),
      builder: (context, child) {
        final pass = _authCtrl.passCtrl.text;
        final confirm = _authCtrl.confirmPassCtrl.text;

        final hasMinLength = pass.length >= 8;
        final hasUppercase = pass.contains(RegExp(r'[A-Z]'));
        final hasDigits = pass.contains(RegExp(r'[0-9]')); 
        // Coinciden si no están vacías y son iguales
        final passwordsMatch = pass.isNotEmpty && pass == confirm;

        return Column(
          children: [
            _buildRequirementRow("Mínimo 8 caracteres", hasMinLength),
            const SizedBox(height: 4),
            _buildRequirementRow("Al menos 1 mayúscula", hasUppercase),
            const SizedBox(height: 4),
            _buildRequirementRow("Al menos 1 número", hasDigits),
            const SizedBox(height: 4),
            _buildRequirementRow("Las contraseñas coinciden", passwordsMatch),
          ],
        );
      },
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
              color: isMet ? AppColors.rpeLow : AppColors.iconMutedOf(context),
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
            color: isMet ? AppColors.rpeLow : AppColors.iconMutedOf(context),
            fontSize: 13,
            fontWeight: isMet ? FontWeight.w600 : FontWeight.normal,
          ),
        ),
      ],
    );
  }

  // ===================================================================
  // Helpers de UI
  // ===================================================================

  Widget _buildTextField({
    required TextEditingController controller,
    required String hintText,
    bool obscureText = false,
    Widget? suffixIcon,
    Widget? prefixIcon,
    TextInputAction? textInputAction,
    ValueChanged<String>? onSubmitted,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      height: 60,
      decoration: BoxDecoration(
        color: AppColors.surfaceOf(context),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark
              ? Colors.white.withOpacity(0.08)
              : Colors.black.withOpacity(0.06),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDark ? 0 : 0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: TextField(
        controller: controller,
        obscureText: obscureText,
        obscuringCharacter: '•',
        keyboardType: hintText.contains('Correo')
            ? TextInputType.emailAddress
            : TextInputType.text,
        textInputAction: textInputAction,
        onSubmitted: onSubmitted,
        style: TextStyle(
          color: Theme.of(context).colorScheme.onSurface,
          fontSize: 16,
          fontWeight: FontWeight.w500,
        ),
        decoration: InputDecoration(
          hintText: hintText,
          hintStyle: TextStyle(
            color: AppColors.textSecondary(context),
            letterSpacing: 0.0,
          ),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
          prefixIcon: prefixIcon,
          suffixIcon: suffixIcon,
        ),
      ),
    );
  }

  // CAMBIO: Ahora el botón permite decidir si muestra el loading o no.
  Widget _buildButton({
    required String text,
    required VoidCallback? onPressed,
    bool showLoading = true,
  }) {
    return ValueListenableBuilder<bool>(
      valueListenable: _authCtrl.isLoading,
      builder: (context, isLoading, child) {
        final bool disabled = isLoading && showLoading;

        return Container(
          height: 60,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: AppColors.brand.withOpacity(0.3), // Sombra con color de marca
                blurRadius: 15,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              onPressed: disabled ? null : onPressed,
              style: OutlinedButton.styleFrom(
                backgroundColor: AppColors.brand,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                elevation: 0,
                textStyle: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.1,
                ),
              ),
              child: isLoading && showLoading
                  ? const SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 3,
                      ),
                    )
                  : Text(text),
            ),
          ),
        );
      },
    );
  }

  Widget _buildGoogleButton() {
    return ValueListenableBuilder<bool>(
      valueListenable: _authCtrl.isLoading,
      builder: (context, isLoading, child) {
        return _PremiumGoogleButton(
          onTap: isLoading ? null : _signInWithGoogle,
          isLoading: isLoading,
        );
      },
    );
  }

  Widget _buildGoogleDivider() {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 24),
      child: Row(
        children: [
          Expanded(child: Divider(color: Theme.of(context).colorScheme.outline, thickness: 1)),
          Container(
            width: 28,
            height: 28,
            margin: const EdgeInsets.symmetric(horizontal: 16),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.surfaceOf(context),
              border: Border.all(
                color: Theme.of(context).colorScheme.outline.withOpacity(0.3),
              ),
            ),
            alignment: Alignment.center,
            child: Text(
              'o',
              style: TextStyle(
                color: AppColors.textSecondary(context),
                fontWeight: FontWeight.w600,
                fontSize: 13,
              ),
            ),
          ),
          Expanded(child: Divider(color: Theme.of(context).colorScheme.outline, thickness: 1)),
        ],
      ),
    );
  }

  // ===================================================================
  // Vistas de Formulario (Login / Registro)
  // ===================================================================

  /// Formulario de Login
  // ===================================================================
  // Vistas de Formulario (Campos)
  // ===================================================================

  Widget _buildLoginFields() {
    return Column(
      children: [
        _buildTextField(
          controller: _authCtrl.emailCtrl,
          hintText: 'Correo electrónico',
          prefixIcon: Icon(Icons.email_outlined, color: AppColors.textSecondary(context)),
          textInputAction: TextInputAction.next,
          onSubmitted: (_) => FocusScope.of(context).nextFocus(),
        ),
        const SizedBox(height: 16),
        _buildTextField(
          controller: _authCtrl.passCtrl,
          hintText: 'Contraseña',
          obscureText: !_showLoginPassword,
          prefixIcon: Icon(Icons.lock_outline, color: AppColors.textSecondary(context)),
          textInputAction: TextInputAction.done,
          onSubmitted: (_) => FocusScope.of(context).unfocus(),
          suffixIcon: IconButton(
            icon: Icon(
              _showLoginPassword ? Icons.visibility_off : Icons.visibility,
              color: AppColors.textSecondary(context),
            ),
            onPressed: () {
              setState(() {
                _showLoginPassword = !_showLoginPassword;
              });
            },
          ),
        ),
        Align(
          alignment: Alignment.centerRight,
          child: TextButton(
            onPressed: _showForgotPasswordDialog,
            child: Builder(builder: (context) => Text(
              '¿Olvidaste tu contraseña?',
              style: TextStyle(
                color: Theme.of(context).brightness == Brightness.dark ? AppColors.brandLight : AppColors.brand,
                fontWeight: FontWeight.bold,
                decoration: TextDecoration.underline,
                decorationColor: Theme.of(context).brightness == Brightness.dark ? AppColors.brandLight : AppColors.brand,
              ),
            )),
          ),
        ),
      ],
    );
  }

  // ===================================================================
  // Vistas de Botones (Footer)
  // ===================================================================

  Widget _buildLoginButtons() {
    return Column(
      children: [
        _buildGoogleButton(),
        _buildGoogleDivider(),
        _buildButton(
          text: 'INICIAR SESIÓN',
          onPressed: _signIn,
          showLoading: true,
        ),
        const SizedBox(height: 16),
        _buildButton(
          text: 'REGISTRARSE',
          onPressed: () {
            _authCtrl.isLoginView.value = false;
            _authCtrl.emailCtrl.clear();
            _authCtrl.passCtrl.clear();
            _authCtrl.usernameCtrl.clear();
            _authCtrl.confirmPassCtrl.clear();
          },
          showLoading: false,
        ),
      ],
    );
  }

  /// Formulario de Registro
  Widget _buildRegisterFields() {
    return Column(
      children: [
        _buildTextField(
          controller: _authCtrl.usernameCtrl,
          hintText: 'Nombre de usuario',
          prefixIcon: Icon(Icons.person_outline, color: AppColors.textSecondary(context)),
          textInputAction: TextInputAction.next,
          onSubmitted: (_) => FocusScope.of(context).nextFocus(),
        ),
        const SizedBox(height: 16),
        _buildTextField(
          controller: _authCtrl.emailCtrl,
          hintText: 'Correo electrónico',
          prefixIcon: Icon(Icons.email_outlined, color: AppColors.textSecondary(context)),
          textInputAction: TextInputAction.next,
          onSubmitted: (_) => FocusScope.of(context).nextFocus(),
        ),
        const SizedBox(height: 16),
        _buildTextField(
          controller: _authCtrl.passCtrl,
          hintText: 'Contraseña',
          obscureText: !_showRegisterPassword,
          prefixIcon: Icon(Icons.lock_outline, color: AppColors.textSecondary(context)),
          textInputAction: TextInputAction.next,
          onSubmitted: (_) => FocusScope.of(context).nextFocus(),
          suffixIcon: IconButton(
            icon: Icon(
              _showRegisterPassword ? Icons.visibility_off : Icons.visibility,
              color: AppColors.textSecondary(context),
            ),
            onPressed: () {
              setState(() {
                _showRegisterPassword = !_showRegisterPassword;
              });
            },
          ),
        ),
        const SizedBox(height: 12),
        _buildTextField(
          controller: _authCtrl.confirmPassCtrl,
          hintText: 'Confirmar contraseña',
          obscureText: !_showRegisterConfirmPassword,
          prefixIcon: Icon(Icons.lock_outline, color: AppColors.textSecondary(context)),
          textInputAction: TextInputAction.done,
          onSubmitted: (_) => FocusScope.of(context).unfocus(),
          suffixIcon: IconButton(
            icon: Icon(
              _showRegisterConfirmPassword
                  ? Icons.visibility_off
                  : Icons.visibility,
              color: AppColors.textSecondary(context),
            ),
            onPressed: () {
              setState(() {
                _showRegisterConfirmPassword = !_showRegisterConfirmPassword;
              });
            },
          ),
        ),
        const SizedBox(height: 12),
        // Checklist de Requisitos en tiempo real (MOVIDO AQUÍ)
        _buildPasswordRequirements(),
      ],
    );
  }

  Widget _buildRegisterButtons() {
    return Column(
      children: [
        _buildGoogleButton(),
        _buildGoogleDivider(),
        _buildButton(
          text: 'REGISTRARSE',
          onPressed: _signUp,
          showLoading: true,
        ),
        const SizedBox(height: 16),
        ValueListenableBuilder<bool>(
          valueListenable: _authCtrl.isLoading,
          builder: (context, isLoading, child) {
            return TextButton(
              onPressed: isLoading ? null : () {
                _authCtrl.isLoginView.value = true;
                _authCtrl.emailCtrl.clear();
                _authCtrl.passCtrl.clear();
                _authCtrl.usernameCtrl.clear();
              },
              child: Text(
                '¿Ya tienes cuenta? Iniciar sesión',
                style: TextStyle(
                  color: Theme.of(context).brightness == Brightness.dark ? AppColors.brandLight : AppColors.brand,
                  fontWeight: FontWeight.bold,
                ),
              ),
            );
          },
        ),
      ],
    );
  }

  // ===================================================================
  // Build Principal
  // ===================================================================

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final double logoHeight = size.height * 0.18;

    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      resizeToAvoidBottomInset: true, // Crucial para que el teclado desplace el contenido
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
          // Usamos un solo SingleChildScrollView para TODO
          child: SingleChildScrollView(
            physics: const ClampingScrollPhysics(), // Evita rebote excesivo
            padding: const EdgeInsets.symmetric(horizontal: 42.0),
            child: ConstrainedBox(
              // Aseguramos que el contenido ocupe al menos toda la pantalla si es posible
              constraints: BoxConstraints(
                minHeight: size.height - MediaQuery.of(context).padding.top - MediaQuery.of(context).padding.bottom,
                maxWidth: 400,
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // ================= HEADER (Logo) =================
                  SizedBox(
                    height: logoHeight > 140 ? 140 : logoHeight,
                    child: Center(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(20),
                        child: Image.asset(
                          'assets/images/Icon.png',
                          fit: BoxFit.contain,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 32),

                  // ================= BODY (Campos) =================
                  ValueListenableBuilder<bool>(
                    valueListenable: _authCtrl.isLoginView,
                    builder: (context, isLoginView, child) {
                      return AnimatedSwitcher(
                        duration: const Duration(milliseconds: 300),
                        key: ValueKey<bool>(isLoginView),
                        child: isLoginView
                            ? _buildLoginFields()
                            : _buildRegisterFields(),
                      );
                    },
                  ),
                  const SizedBox(height: 28),

                  // ================= FOOTER (Botones) =================
                  ValueListenableBuilder<bool>(
                    valueListenable: _authCtrl.isLoginView,
                    builder: (context, isLoginView, child) {
                      return AnimatedSwitcher(
                        duration: const Duration(milliseconds: 300),
                        child: isLoginView
                            ? _buildLoginButtons()
                            : _buildRegisterButtons(),
                      );
                    },
                  ),
                  const SizedBox(height: 24),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Widget interno para el botón de Google con diseño Premium y micro-animaciones
class _PremiumGoogleButton extends StatefulWidget {
  final VoidCallback? onTap;
  final bool isLoading;

  const _PremiumGoogleButton({this.onTap, this.isLoading = false});

  @override
  State<_PremiumGoogleButton> createState() => _PremiumGoogleButtonState();
}

class _PremiumGoogleButtonState extends State<_PremiumGoogleButton> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 100),
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.96).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _handleTapDown(TapDownDetails details) {
    if (widget.onTap != null) _controller.forward();
  }

  void _handleTapUp(TapUpDetails details) {
    if (widget.onTap != null) _controller.reverse();
  }

  void _handleTapCancel() {
    if (widget.onTap != null) _controller.reverse();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: _handleTapDown,
      onTapUp: _handleTapUp,
      onTapCancel: _handleTapCancel,
      onTap: widget.onTap,
      child: ScaleTransition(
        scale: _scaleAnimation,
        child: Container(
          height: 60,
          margin: const EdgeInsets.only(top: 8),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: Theme.of(context).colorScheme.outline,
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.06),
                blurRadius: 20,
                offset: const Offset(0, 10),
              ),
              BoxShadow(
                color: AppColors.brand.withOpacity(0.03),
                blurRadius: 30,
                offset: const Offset(0, 15),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: Stack(
              children: [
                Center(
                  child: widget.isLoading
                      ? const SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(AppColors.brand),
                          ),
                        )
                      : Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            // Icono de Google estilizado
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                shape: BoxShape.circle,
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.05),
                                    blurRadius: 5,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: SvgPicture.asset(
                                'assets/images/google_logo.svg',
                                width: 20,
                                height: 20,
                              ),
                            ),
                            const SizedBox(width: 16),
                            Text(
                              'CONTINUAR CON GOOGLE',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w800,
                                color: Theme.of(context).colorScheme.onSurface,
                                letterSpacing: 1.2,
                              ),
                            ),
                          ],
                        ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}



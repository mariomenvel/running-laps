import 'package:flutter/material.dart';
// RUTA CORREGIDA:
import 'package:running_laps/features/auth/viewmodels/auth_controller.dart'; // CAMBIO: Usamos el Controller
import 'package:running_laps/features/home/views/home_view.dart';
import 'package:running_laps/core/widgets/modern_snackbar.dart';
import 'package:running_laps/config/app_theme.dart';

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

      ModernSnackBar.showSuccess(context, 'Sesión iniciada');

      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (context) => const HomeView()),
        (Route<dynamic> route) => false,
      );
    } catch (e) {
      final msg = _extractErrorMessage(e);
      if (!mounted) return;

      if (msg.contains("verificar tu correo")) {
        // Mostrar opción de reenviar
        // Mostrar opción de reenviar
        ModernSnackBar.showWarning(
          context,
          msg,
          duration: const Duration(seconds: 6),
          action: SnackBarAction(
            label: 'REENVIAR',
            textColor: Colors.white,
            onPressed: () async {
               // Reenviar correo
               try {
                 await _authCtrl.resendVerificationEmail(
                   _authCtrl.emailCtrl.text, 
                   _authCtrl.passCtrl.text
                 );
                 if(!mounted) return;
                 ModernSnackBar.showSuccess(context, 'Correo enviado. Revisa tu bandeja.');
               } catch (resendError) {
                 _showError(resendError);
               }
            },
          ),
        );
      } else {
         _showError(e);
      }
    }
  }

  Future<void> _signUp() async {
    try {
      await _authCtrl.signUp();
      if (!mounted) return;

      ModernSnackBar.showSuccess(
        context, 
        'Cuenta creada. Revisa tu correo para verificarla antes de entrar.',
        duration: const Duration(seconds: 5),
      );
    } catch (e) {
      _showError(e);
    }
  }

  void _toggleView() {
    _authCtrl.toggleView();
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
                
                if (!mounted) return;
                Navigator.of(context).pop(); // Cerrar modal si éxito
                
                // Mostrar éxito en SnackBar (ya no hay modal tapándolo)
                // Mostrar éxito en SnackBar (ya no hay modal tapándolo)
                ModernSnackBar.showSuccess(
                  context,
                  'Correo enviado. Revisa tu bandeja.',
                );
              } catch (e) {
                // Si falla, actualizamos el estado DEL MODAL para mostrar el error
                setModalState(() {
                   // Usamos la misma lógica de extracción de mensaje
                   // pero sin mostrar SnackBar, sino texto rojo.
                   _localError = _extractErrorMessage(e);
                });
              }
            }

            return Container(
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.only(
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
                        color: Colors.grey[300],
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  const Text(
                    'Recuperar contraseña',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: Tema.brandPurple,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Introduce tu correo electrónico y te enviaremos un enlace para restablecer tu contraseña.',
                    style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 32),
                  _buildTextField(
                    controller: _resetEmailCtrl,
                    hintText: 'Correo electrónico',
                    prefixIcon: const Icon(Icons.email_outlined, color: Colors.grey),
                  ),
                  
                  // ZONA DE ERROR INLINE
                  if (_localError != null) ...[
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.red[50], // Fondo rojo suave
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.red.withOpacity(0.3)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.error_outline, color: Colors.red),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              _localError!,
                              style: const TextStyle(
                                color: Colors.red,
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
                            backgroundColor: Tema.brandPurple,
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
                      style: TextStyle(color: Colors.grey[600], fontWeight: FontWeight.bold),
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
            color: isMet ? Colors.green : Colors.transparent,
            border: Border.all(
              color: isMet ? Colors.green : Colors.grey.shade400,
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
            color: isMet ? Colors.green : Colors.grey.shade600,
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
  }) {
    return Container(
      height: 60,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 20,
            offset: const Offset(0, 10),
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
        style: const TextStyle(color: Colors.black87, fontSize: 16, fontWeight: FontWeight.w500),
        decoration: InputDecoration(
          hintText: hintText,
          hintStyle: TextStyle(color: Colors.grey[400], letterSpacing: 0.0),
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
                color: Tema.brandPurple.withOpacity(0.3), // Sombra con color de marca
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
                backgroundColor: Tema.brandPurple,
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
          prefixIcon: Icon(Icons.email_outlined, color: Colors.grey[400]),
        ),
        const SizedBox(height: 16),
        _buildTextField(
          controller: _authCtrl.passCtrl,
          hintText: 'Contraseña',
          obscureText: !_showLoginPassword,
          prefixIcon: Icon(Icons.lock_outline, color: Colors.grey[400]),
          suffixIcon: IconButton(
            icon: Icon(
              _showLoginPassword ? Icons.visibility_off : Icons.visibility,
              color: Colors.grey,
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
            child: const Text(
              '¿Olvidaste tu contraseña?',
              style: TextStyle(
                color: Tema.brandPurple,
                fontWeight: FontWeight.bold,
                decoration: TextDecoration.underline,
                decorationColor: Tema.brandPurple,
              ),
            ),
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
        _buildButton(
          text: 'INICIAR SESIÓN',
          onPressed: _signIn,
          showLoading: true,
        ),
        const SizedBox(height: 16),
        _buildButton(
          text: 'REGISTRARSE',
          onPressed: _toggleView,
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
          prefixIcon: Icon(Icons.person_outline, color: Colors.grey[400]),
        ),
        const SizedBox(height: 16),
        _buildTextField(
          controller: _authCtrl.emailCtrl,
          hintText: 'Correo electrónico',
          prefixIcon: Icon(Icons.email_outlined, color: Colors.grey[400]),
        ),
        const SizedBox(height: 16),
        _buildTextField(
          controller: _authCtrl.passCtrl,
          hintText: 'Contraseña',
          obscureText: !_showRegisterPassword,
          prefixIcon: Icon(Icons.lock_outline, color: Colors.grey[400]),
          suffixIcon: IconButton(
            icon: Icon(
              _showRegisterPassword ? Icons.visibility_off : Icons.visibility,
              color: Colors.grey,
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
          prefixIcon: Icon(Icons.lock_outline, color: Colors.grey[400]),
          suffixIcon: IconButton(
            icon: Icon(
              _showRegisterConfirmPassword
                  ? Icons.visibility_off
                  : Icons.visibility,
              color: Colors.grey,
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
              onPressed: isLoading ? null : _toggleView,
              child: const Text(
                '¿Ya tienes cuenta? Iniciar sesión',
                style: TextStyle(
                  color: Tema.brandPurple,
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
    final double logoHeight = size.height * 0.30; // Un poco menos para dar espacio

    // Color de fondo para el gradiente (coincide con HomeView)
    const Color _bgGradientColor = Color(0xFFF9F5FB);

    return Scaffold(
      resizeToAvoidBottomInset: true, // Crucial para que el teclado desplace el contenido
      body: Container(
        decoration: const BoxDecoration(
          gradient: RadialGradient(
            center: Alignment.center,
            radius: 1.5,
            colors: [_bgGradientColor, Colors.white],
            stops: [0.0, 1.0],
          ),
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
            padding: const EdgeInsets.symmetric(horizontal: 24.0),
            child: ConstrainedBox(
              // Aseguramos que el contenido ocupe al menos toda la pantalla si es posible
              constraints: BoxConstraints(
                minHeight: size.height - MediaQuery.of(context).padding.top - MediaQuery.of(context).padding.bottom,
                maxWidth: 400,
              ),
              child: IntrinsicHeight( // Permite que el Column use MainAxisAlignment.spaceBetween
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // ================= HEADER (Logo) =================
                    SizedBox(
                      height: logoHeight > 250 ? 250 : logoHeight,
                      child: Center(
                        child: Image.asset(
                          'assets/images/Icon.png',
                          fit: BoxFit.contain,
                        ),
                      ),
                    ),
                    
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
                    
                    const Spacer(), // Empuja los botones al final si hay espacio
                    const SizedBox(height: 24),
                    
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
                    const SizedBox(height: 24), // Margen inferior final
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



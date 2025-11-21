import 'package:flutter/material.dart';
// RUTA CORREGIDA:
import 'package:running_laps/features/auth/viewmodels/auth_controller.dart'; // CAMBIO: Usamos el Controller
import 'package:running_laps/features/home/views/home_view.dart';
import '../../../app/tema.dart';

// CAMBIO: La vista ahora usa el Controller
class AuthPage extends StatefulWidget {
  const AuthPage({super.key});

  @override
  State<AuthPage> createState() => _AuthPageState();
}

class _AuthPageState extends State<AuthPage> {
  // --- Controller ---
  final _authCtrl = AuthController();

  // --- Constantes de Estilo ---
  static const double _fieldWidth = 300;

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
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(msg), backgroundColor: Colors.red));
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

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Sesión iniciada')));

      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (context) => const HomeView()),
        (Route<dynamic> route) => false,
      );
    } catch (e) {
      _showError(e);
    }
  }

  Future<void> _signUp() async {
    try {
      await _authCtrl.signUp();
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Cuenta creada con éxito. Inicia sesión.'),
        ),
      );
    } catch (e) {
      _showError(e);
    }
  }

  void _toggleView() {
    _authCtrl.toggleView();
  }

  // ===================================================================
  // Helpers de UI
  // ===================================================================

  Widget _buildTextField({
    required TextEditingController controller,
    required String hintText,
    bool obscureText = false,
    Widget? suffixIcon,
  }) {
    return SizedBox(
      width: _fieldWidth,
      height: 60,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.7),
          borderRadius: BorderRadius.circular(8),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.25),
              blurRadius: 2,
              spreadRadius: 2,
              offset: const Offset(0, 0),
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
          style: const TextStyle(color: Colors.black, fontSize: 16),
          decoration: InputDecoration(
            hintText: hintText,
            hintStyle: const TextStyle(color: Colors.grey, letterSpacing: 0.0),
            border: InputBorder.none,
            contentPadding: const EdgeInsets.fromLTRB(20, 20, 12, 7),
            suffixIcon: suffixIcon,
          ),
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
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.3),
                blurRadius: 10,
                spreadRadius: 2,
                offset: const Offset(0, 0),
              ),
            ],
          ),
          child: SizedBox(
            width: _fieldWidth,
            height: 60,
            child: OutlinedButton(
              onPressed: disabled ? null : onPressed,
              style: OutlinedButton.styleFrom(
                backgroundColor: Tema.brandPurple,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
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
  Widget _buildLoginForm() {
    return Column(
      children: [
        _buildTextField(
          controller: _authCtrl.emailCtrl,
          hintText: 'Correo electrónico',
        ),
        const SizedBox(height: 16),
        _buildTextField(
          controller: _authCtrl.passCtrl,
          hintText: 'Contraseña',
          obscureText: !_showLoginPassword,
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
        const SizedBox(height: 20),
        // SOLO este botón muestra el loading
        _buildButton(
          text: 'INICIAR SESIÓN',
          onPressed: _signIn,
          showLoading: true,
        ),
        const SizedBox(height: 16),
        // Este botón NO muestra loading, solo se deshabilita si quisieras
        _buildButton(
          text: 'REGISTRARSE',
          onPressed: _toggleView,
          showLoading: false,
        ),
      ],
    );
  }

  /// Formulario de Registro
  Widget _buildRegisterForm() {
    return Column(
      children: [
        _buildTextField(
          controller: _authCtrl.usernameCtrl,
          hintText: 'Nombre de usuario',
        ),
        const SizedBox(height: 16),
        _buildTextField(
          controller: _authCtrl.emailCtrl,
          hintText: 'Correo electrónico',
        ),
        const SizedBox(height: 16),
        _buildTextField(
          controller: _authCtrl.passCtrl,
          hintText: 'Contraseña',
          obscureText: !_showRegisterPassword,
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
        const SizedBox(height: 16),
        _buildTextField(
          controller: _authCtrl.confirmPassCtrl,
          hintText: 'Confirmar contraseña',
          obscureText: !_showRegisterConfirmPassword,
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
        const SizedBox(height: 32),
        // Aquí sí queremos ver el loading al registrar
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
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          image: DecorationImage(
            image: AssetImage('assets/images/fondo.png'),
            fit: BoxFit.cover,
          ),
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.only(
            top: 80.0,
            left: 24.0,
            right: 24.0,
            bottom: 24.0,
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.start,
            children: [
              Image.asset(
                'assets/images/Icon.png',
                height: 400,
                fit: BoxFit.contain,
              ),
              const SizedBox(height: 0),
              ValueListenableBuilder<bool>(
                valueListenable: _authCtrl.isLoginView,
                builder: (context, isLoginView, child) {
                  return AnimatedSwitcher(
                    duration: const Duration(milliseconds: 300),
                    key: ValueKey<bool>(isLoginView),
                    child: isLoginView
                        ? _buildLoginForm()
                        : _buildRegisterForm(),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

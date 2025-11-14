import 'package:flutter/material.dart';
// RUTA CORREGIDA:
import 'package:running_laps/features/auth/viewmodels/auth_controller.dart'; // CAMBIO: Usamos el Controller
import 'package:running_laps/features/home/views/home_view.dart';

// CAMBIO: La vista ahora usa el Controller
class AuthPage extends StatefulWidget {
  const AuthPage({super.key});

  @override
  State<AuthPage> createState() => _AuthPageState();
}

class _AuthPageState extends State<AuthPage> {
  // --- Controller ---
  // CAMBIO: El estado se gestiona en el Controller
  final _authCtrl = AuthController();

  // --- Constantes de Estilo ---
  static const double _fieldWidth = 300;
  static const Color _brandColor = Color(0xFFA349A4);

  @override
  void dispose() {
    // CAMBIO: Limpiamos el Controller (que a su vez limpia sus controladores de texto)
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
    // Si ya es un string, devolver tal cual
    if (e is String) return e;

    final s = e.toString();

    // Intentar extraer el texto después de un prefijo tipo "Exception: " o "Error: "
    final regex = RegExp(r'^(?:.*?:\s*)(.*)$');
    final match = regex.firstMatch(s);
    if (match != null && match.groupCount >= 1) {
      final extracted = match.group(1);
      if (extracted != null && extracted.isNotEmpty) return extracted;
    }

    // Si no se pudo extraer, devolver el toString() original
    return s;
  }

  Future<void> _signIn() async {
    try {
      // CAMBIO: Llamamos al método del Controller.
      await _authCtrl.signIn();
      if (!mounted) return;

      // 1. Muestra la SnackBar PRIMERO
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Sesión iniciada')));

      // 2. Navega a la nueva pantalla DESPUÉS
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
      // CAMBIO: Llamamos al método del Controller. El Controller se encarga de:
      // 1. Comprobar contraseñas
      // 2. Llamar al Repository
      // 3. Llamar a _authCtrl.toggleView()
      await _authCtrl.signUp();
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Cuenta creada con éxito. Inicia sesión.'),
        ),
      );

      // No es necesario llamar a _toggleView() aquí, el Controller ya lo hace.
    } catch (e) {
      _showError(e);
    }
  }

  // El método de cambio de vista también llama al Controller
  void _toggleView() {
    _authCtrl.toggleView();
  }

  // ===================================================================
  // Helpers de UI (Sin cambios, pero usando los controladores del Controller)
  // ===================================================================

  Widget _buildTextField({
    required TextEditingController controller,
    required String hintText,
    bool obscureText = false,
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
          ),
        ),
      ),
    );
  }

  // CAMBIO: Envuelve el botón en un ValueListenableBuilder para reaccionar a _authCtrl.isLoading
  Widget _buildButton({
    required String text,
    required VoidCallback? onPressed,
  }) {
    // CAMBIO: Reconstruye el botón solo cuando el estado de carga cambia
    return ValueListenableBuilder<bool>(
      valueListenable: _authCtrl.isLoading,
      builder: (context, isLoading, child) {
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
              onPressed: isLoading
                  ? null
                  : onPressed, // Deshabilita si está cargando
              style: OutlinedButton.styleFrom(
                backgroundColor: _brandColor,
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
              child: isLoading
                  ? const SizedBox(
                      // Indicador de carga
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

  /// Devuelve el formulario de Login (basado en View1)
  Widget _buildLoginForm() {
    return Column(
      children: [
        // CAMBIO: Usando los controladores del Controller
        _buildTextField(
          controller: _authCtrl.emailCtrl,
          hintText: 'Correo electrónico',
        ),
        const SizedBox(height: 16),
        _buildTextField(
          controller: _authCtrl.passCtrl,
          hintText: 'Contraseña',
          obscureText: true,
        ),
        const SizedBox(height: 20),
        _buildButton(text: 'INICIAR SESIÓN', onPressed: _signIn),
        const SizedBox(height: 16),
        // CAMBIO: El botón de registro usa el mismo widget que ya gestiona la carga.
        _buildButton(text: 'REGISTRARSE', onPressed: _toggleView),
      ],
    );
  }

  /// Devuelve el formulario de Registro (basado en View2)
  Widget _buildRegisterForm() {
    return Column(
      children: [
        // CAMBIO: Usando los controladores del Controller
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
          obscureText: true,
        ),
        const SizedBox(height: 16),
        _buildTextField(
          controller: _authCtrl.confirmPassCtrl,
          hintText: 'Confirmar contraseña',
          obscureText: true,
        ),
        const SizedBox(height: 32),
        _buildButton(text: 'REGISTRARSE', onPressed: _signUp),
        const SizedBox(height: 16),
        // CAMBIO: Este TextButton solo usa la carga para deshabilitarse (si está cargando, el onPressed es null)
        ValueListenableBuilder<bool>(
          valueListenable: _authCtrl.isLoading,
          builder: (context, isLoading, child) {
            return TextButton(
              onPressed: isLoading ? null : _toggleView,
              child: const Text(
                '¿Ya tienes cuenta? Iniciar sesión',
                style: TextStyle(
                  color: _brandColor,
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
              // 1. El Logo
              Image.asset(
                'assets/images/Icon.png',
                height: 400,
                fit: BoxFit.contain,
              ),
              const SizedBox(height: 0),

              // 2. El formulario (Login o Registro)
              // CAMBIO: ValueListenableBuilder para reconstruir solo el formulario
              // cuando cambia la vista (_authCtrl.isLoginView)
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

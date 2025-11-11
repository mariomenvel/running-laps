import 'package:flutter/material.dart';
// RUTA CORREGIDA:
import 'package:running_laps/features/auth/data/auth_repository.dart';

class AuthPage extends StatefulWidget {
  const AuthPage({super.key});

  @override
  State<AuthPage> createState() => _AuthPageState();
}

class _AuthPageState extends State<AuthPage> {
  // --- Estado de la UI ---
  bool _isLoginView = true; // true = Vista Login (View1), false = Vista Registro (View2)
  bool _loading = false;

  // --- Lógica de Auth (de LoginPage) ---
  final _auth = AuthRepository();

  // --- Controladores (para todos los campos) ---
  final _emailCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  final _usernameCtrl = TextEditingController();
  final _confirmPassCtrl = TextEditingController();

  // --- Constantes de Estilo (de View1/View2) ---
  static const double _fieldWidth = 300; // 'ancho' de tu View1
  static const Color _brandColor = Color(0xFFA349A4);

  @override
  void dispose() {
    // Limpiamos todos los controladores
    _emailCtrl.dispose();
    _passCtrl.dispose();
    _usernameCtrl.dispose();
    _confirmPassCtrl.dispose();
    super.dispose();
  }

  // ===================================================================
  // Lógica de Autenticación (de LoginPage)
  // ===================================================================

  void _showError(Object e) {
    final msg = e.toString();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: Colors.red,
    ));
  }

  Future<void> _signIn() async {
    setState(() => _loading = true);
    try {
      // Usamos los controladores de email y pass
      await _auth.signIn(_emailCtrl.text, _passCtrl.text);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Sesión iniciada')),
      );
    } catch (e) {
      _showError(e);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _signUp() async {
    // 1. Comprobar si las contraseñas coinciden
    if (_passCtrl.text != _confirmPassCtrl.text) {
      _showError("Las contraseñas no coinciden");
      return;
    }

    setState(() => _loading = true);
    try {
      // 2. CORREGIDO: Llamada con argumentos posicionales
      await _auth.signUp(
        _emailCtrl.text,
        _passCtrl.text,
        _usernameCtrl.text, // <-- Pasa como 'nombre'
      );
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Cuenta creada con éxito')),
      );

      // 3. Después de registrarse, volvemos al Login
      _toggleView();
    } catch (e) {
      _showError(e);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  // ===================================================================
  // Helpers de UI
  // ===================================================================

  /// Cambia entre la vista de Login y la de Registro
  void _toggleView() {
    // Limpiar todos los campos al cambiar de vista
    _emailCtrl.clear();
    _passCtrl.clear();
    _usernameCtrl.clear();
    _confirmPassCtrl.clear();

    // Invertir la vista
    setState(() {
      _isLoginView = !_isLoginView;
    });
  }

  /// [NUEVO] - Este es el estilo EXACTO de tu View1
  Widget _buildTextField({
    required TextEditingController controller,
    required String hintText,
    bool obscureText = false,
  }) {
    return SizedBox(
      width: _fieldWidth, // 'ancho' de tu View1
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
          style: const TextStyle(
            color: Colors.black, // input text color
            fontSize: 16,
          ),
          decoration: InputDecoration(
            hintText: hintText,
            hintStyle: const TextStyle(
              color: Colors.grey, // phantom text color
              letterSpacing: 0.0,
            ),
            border: InputBorder.none,
            contentPadding: const EdgeInsets.fromLTRB(
              20, // left
              20, // top
              12, // right
              7, // bottom
            ),
          ),
        ),
      ),
    );
  }

  /// [NUEVO] - Este es el estilo EXACTO de tu View1
  Widget _buildButton({
    required String text,
    required VoidCallback? onPressed,
  }) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.3), // Sombra de tu View1
            blurRadius: 10,
            spreadRadius: 2,
            offset: const Offset(0, 0),
          ),
        ],
      ),
      child: SizedBox(
        width: _fieldWidth, // 'ancho' de tu View1
        height: 60,
        child: OutlinedButton(
          onPressed: onPressed,
          style: OutlinedButton.styleFrom(
            backgroundColor: _brandColor,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12), // Tu style
            ),
            elevation: 0,
            textStyle: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.1,
            ),
          ),
          child: _loading
              ? const SizedBox( // Indicador de carga
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
  }

  // ===================================================================
  // Vistas de Formulario (Login / Registro)
  // ===================================================================

  /// Devuelve el formulario de Login (basado en View1)
  Widget _buildLoginForm() {
    return Column(
      children: [
        // NOTA: Tu View1 dice 'Nombre de usuario' pero la lógica _signIn
        // usa email. Lo dejo como 'Correo electrónico' para que funcione.
        _buildTextField(
          controller: _emailCtrl,
          hintText: 'Correo electrónico',
        ),
        const SizedBox(height: 16),
        _buildTextField(
          controller: _passCtrl,
          hintText: 'Contraseña',
          obscureText: true,
        ),
        const SizedBox(height: 20),
        _buildButton(
          text: 'INICIAR SESIÓN',
          onPressed: _loading ? null : _signIn,
        ),
        const SizedBox(height: 16),
        _buildButton(
          text: 'REGISTRARSE',
          onPressed: _loading ? null : _toggleView, // <-- Llama a _toggleView
        ),
      ],
    );
  }

  /// Devuelve el formulario de Registro (basado en View2)
  Widget _buildRegisterForm() {
    return Column(
      children: [
        _buildTextField(
          controller: _usernameCtrl,
          hintText: 'Nombre de usuario',
        ),
        const SizedBox(height: 16),
        _buildTextField(
          controller: _emailCtrl,
          hintText: 'Correo electrónico',
        ),
        const SizedBox(height: 16),
        _buildTextField(
          controller: _passCtrl,
          hintText: 'Contraseña',
          obscureText: true,
        ),
        const SizedBox(height: 16),
        _buildTextField(
          controller: _confirmPassCtrl,
          hintText: 'Confirmar contraseña',
          obscureText: true,
        ),
        const SizedBox(height: 32),
        _buildButton(
          text: 'REGISTRARSE',
          onPressed: _loading ? null : _signUp, // <-- Llama a _signUp
        ),
        const SizedBox(height: 16),
        TextButton(
          onPressed: _loading ? null : _toggleView, // <-- Llama a _toggleView
          child: const Text(
            '¿Ya tienes cuenta? Iniciar sesión',
            style: TextStyle(
              color: _brandColor,
              fontWeight: FontWeight.bold,
            ),
          ),
        )
      ],
    );
  }

  // ===================================================================
  // Build Principal
  // ===================================================================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // NOTA: El fondo será blanco (o el default del Scaffold),
      // ya que tu código de View1/View2 tiene el gradiente comentado.
      // Si SÍ querías un gradiente, avísame y descomento la
      // decoración del 'Container'.
      body: Container(
        // [CAMBIO] - Añadida la imagen de fondo según tu solicitud.
        decoration: const BoxDecoration(
          image: DecorationImage(
            image: AssetImage('assets/images/fondo.png'), // Ruta de tu imagen
            fit: BoxFit.cover, // Para que cubra toda la pantalla
          ),
        ),
        // [CAMBIO DE LAYOUT] - Eliminado el 'Center'
        child: SingleChildScrollView(
          // [CAMBIO DE LAYOUT] - Padding superior de 80 para "subirlo"
          padding: const EdgeInsets.only(
            top: 80.0,
            left: 24.0,
            right: 24.0,
            bottom: 24.0,
          ),
          child: Column(
            // [CAMBIO DE LAYOUT] - Alinear al inicio (arriba)
            mainAxisAlignment: MainAxisAlignment.start,
            children: [
              // 1. El Logo (de View1/View2)
              Image.asset(
                // ASEGÚRATE de que la ruta es correcta en tu pubspec.yaml
                'assets/images/Icon.png',
                height: 400,
                fit: BoxFit.contain,
              ),
              const SizedBox(height: 0),

              // 2. El formulario (Login o Registro)
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 300),
                key: ValueKey<bool>(_isLoginView),
                child: _isLoginView
                    ? _buildLoginForm()
                    : _buildRegisterForm(),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
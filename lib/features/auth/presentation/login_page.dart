import 'package:flutter/material.dart';
import '../../auth/data/auth_repository.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() {
    return _LoginPageState();
  }
}

class _LoginPageState extends State<LoginPage> {
  final TextEditingController _nombreCtrl = TextEditingController();
  final TextEditingController _emailCtrl = TextEditingController();
  final TextEditingController _passCtrl  = TextEditingController();
  final TextEditingController _pass2Ctrl = TextEditingController();

  final AuthRepository _auth = AuthRepository();

  bool _loading = false;
  bool _isRegisterMode = false; // false: login, true: registro

  @override
  void dispose() {
    _nombreCtrl.dispose();
    _emailCtrl.dispose();
    _passCtrl.dispose();
    _pass2Ctrl.dispose();
    super.dispose();
  }

  void _showSnack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  bool _validateForm(bool isRegister) { 
    String nombre = _nombreCtrl.text.trim();
    String email = _emailCtrl.text.trim();
    String pass  = _passCtrl.text;
    String pass2 = _pass2Ctrl.text;

    if(isRegister){
      if (nombre.isEmpty) {
        _showSnack('El nombre es obligatorio.');
        return false;
      }
    }
    if (email.isEmpty) {
      _showSnack('El email es obligatorio.');
      return false;
    }
    if (pass.isEmpty) {
      _showSnack('La contraseña es obligatoria.');
      return false;
    }
    if (pass.length < 6) {
      _showSnack('La contraseña debe tener al menos 6 caracteres.');
      return false;
    }
    if (isRegister) {
      if (pass2.isEmpty) {
        _showSnack('Confirma la contraseña.');
        return false;
      }
      if (pass != pass2) {
        _showSnack('Las contraseñas no coinciden.');
        return false;
      }
    }
    return true;
  }

  Future<void> _doLogin() async {
    if (!_validateForm(false)) {
      return;
    }
    setState(() {
      _loading = true;
    });
    try {
      await _auth.signIn(_emailCtrl.text, _passCtrl.text);
      _showSnack('Sesión iniciada');
    } on AuthFailure catch (e) {
      _showSnack(e.message);
    } catch (e) {
      _showSnack('Error inesperado al iniciar sesión.');
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
    }
  }

  Future<void> _doRegister() async {
    if (!_validateForm(true)) {
      return;
    }
    setState(() {
      _loading = true;
    });
    try {
      await _auth.signUp(_emailCtrl.text, _passCtrl.text , _nombreCtrl.text);
      _showSnack('Cuenta creada. Ya puedes iniciar sesión.');
      if (mounted) {
        setState(() {
          _isRegisterMode = false; // volver a modo login
        });
      }
    } on AuthFailure catch (e) {
      _showSnack(e.message);
    } catch (e) {
      _showSnack('Error inesperado al registrar.');
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
    }
  }

  Future<void> _doLogout() async {
    try {
      await _auth.signOut();
      _showSnack('Sesión cerrada');
    } catch (_) {
      _showSnack('No se pudo cerrar sesión.');
    }
  }

  @override
  Widget build(BuildContext context) {
    // Preparar handlers sin usar ternarios
    VoidCallback? primaryAction;
    String primaryText = '';
    if (_loading) {
      primaryAction = null;
      if (_isRegisterMode) {
        primaryText = 'Creando cuenta...';
      } else {
        primaryText = 'Entrando...';
      }
    } else {
      if (_isRegisterMode) {
        primaryAction = _doRegister;
        primaryText = 'Crear cuenta';
      } else {
        primaryAction = _doLogin;
        primaryText = 'Entrar';
      }
    }

    VoidCallback? toggleModeAction;
    String toggleText = '';
    if (_loading) {
      toggleModeAction = null;
      if (_isRegisterMode) {
        toggleText = 'Ya tengo cuenta';
      } else {
        toggleText = 'Crear cuenta nueva';
      }
    } else {
      toggleModeAction = () {
        setState(() {
          _isRegisterMode = !_isRegisterMode;
        });
      };
      if (_isRegisterMode) {
        toggleText = 'Ya tengo cuenta';
      } else {
        toggleText = 'Crear cuenta nueva';
      }
    }

    VoidCallback? logoutAction;
    if (_loading) {
      logoutAction = null;
    } else {
      logoutAction = _doLogout;
    }

    List<Widget> passwordConfirmRow = <Widget>[];
    if (_isRegisterMode) {
      passwordConfirmRow.add(const SizedBox(height: 12));
      passwordConfirmRow.add(
        TextField(
          controller: _pass2Ctrl,
          obscureText: true,
          decoration: const InputDecoration(
            labelText: 'Confirmar contraseña',
            border: OutlineInputBorder(),
          ),
        ),
      );
    }

    List<Widget> aniadirNombreRow = <Widget>[];
    if (_isRegisterMode) {
      aniadirNombreRow.add(const SizedBox(height: 12));
      aniadirNombreRow.add(
        TextField(
          controller: _nombreCtrl,
          obscureText: false,
          decoration: const InputDecoration(
            labelText: 'Nombre',
            border: OutlineInputBorder(),
          ),
        ),
      );
    }

    return Scaffold(
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: <Widget>[
                const Text(
                  'Running Laps',
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                ),
                ...aniadirNombreRow,

                const SizedBox(height: 16),
                TextField(
                  controller: _emailCtrl,
                  keyboardType: TextInputType.emailAddress,
                  decoration: const InputDecoration(
                    labelText: 'Email',
                    border: OutlineInputBorder(),
                  ),
                ),
                  
                

                const SizedBox(height: 12),
                TextField(
                  controller: _passCtrl,
                  obscureText: true,
                  decoration: const InputDecoration(
                    labelText: 'Contraseña',
                    border: OutlineInputBorder(),
                  ),
                ),
                // Confirmación solo si está en modo registro
                ...passwordConfirmRow,
                const SizedBox(height: 16),
                Row(
                  children: <Widget>[
                    Expanded(
                      child: FilledButton(
                        onPressed: primaryAction,
                        child: Text(primaryText),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: <Widget>[
                    Expanded(
                      child: OutlinedButton(
                        onPressed: toggleModeAction,
                        child: Text(toggleText),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                TextButton(
                  onPressed: logoutAction,
                  child: const Text('Cerrar sesión'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

/// Handles phone-side QR scanning to authenticate the Wear OS watch.
///
/// Flow:
/// 1. Watch creates wear_sessions/{code} with status='pending'
/// 2. Watch displays a QR encoding runninglaps://wear-auth?code=XXXXXX
/// 3. Phone scans the QR via [scanAndAuthenticateWatch], extracts the code
/// 4. Phone writes the user's ID token to wear_sessions/{code}
/// 5. Watch reads the document, signs in with signInWithCustomToken()
///
/// NOTE: In production, step 4 should call a Cloud Function that uses the
/// Firebase Admin SDK to generate a real Custom Token from the ID token,
/// and write it as the 'customToken' field. A client-side ID token cannot
/// be used directly with signInWithCustomToken().
class WearAuthService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  /// Opens the camera scanner, extracts the session code from the QR URL,
  /// and writes auth data to Firestore so the watch can complete sign-in.
  ///
  /// Returns true on success, false if the user cancelled.
  /// Throws on Firestore/auth errors.
  Future<bool> scanAndAuthenticateWatch(BuildContext context) async {
    final String? code = await Navigator.push<String>(
      context,
      MaterialPageRoute(builder: (_) => const _WearQRScannerPage()),
    );

    if (code == null) return false; // user cancelled

    final user = _auth.currentUser;
    if (user == null) throw Exception('No hay sesión activa');

    // Validate the session document exists before writing auth data
    final sessionDoc =
        await _firestore.collection('wear_sessions').doc(code).get();
    if (!sessionDoc.exists) {
      throw Exception('Código no válido o expirado');
    }
    if (sessionDoc.data()?['status'] != 'pending') {
      throw Exception('Esta sesión ya fue utilizada');
    }

    final idToken = await user.getIdToken();

    final payload = {
      'status': 'authenticated',
      'uid': user.uid,
      // The watch reads 'idToken' and tries signInWithCustomToken(idToken).
      // In development this call fails (ID token ≠ custom token) and the watch
      // falls back to storing the uid in SharedPreferences for Firestore queries.
      // TODO: Production — call a Cloud Function here that uses the Admin SDK to
      // generate a real Custom Token from idToken, then write it as 'customToken'.
      // Requires Firebase Blaze plan. The watch reads 'idToken' field below.
      'idToken': idToken,
      'authenticatedAt': FieldValue.serverTimestamp(),
    };
    debugPrint('[WearAuth] Writing to wear_sessions/$code: status=authenticated uid=${user.uid}');
    await _firestore.collection('wear_sessions').doc(code).update(payload);
    debugPrint('[WearAuth] Firestore update complete for code=$code');

    return true;
  }
}

class _WearQRScannerPage extends StatefulWidget {
  const _WearQRScannerPage();

  @override
  State<_WearQRScannerPage> createState() => _WearQRScannerPageState();
}

class _WearQRScannerPageState extends State<_WearQRScannerPage> {
  late final MobileScannerController _controller;
  bool _scanned = false;

  @override
  void initState() {
    super.initState();
    _controller = MobileScannerController();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onDetect(BarcodeCapture capture) {
    if (_scanned) return;

    final rawValue = capture.barcodes.firstOrNull?.rawValue;
    if (rawValue == null) return;

    // Expected format: runninglaps://wear-auth?code=XXXXXX
    final uri = Uri.tryParse(rawValue);
    if (uri == null || uri.scheme != 'runninglaps' || uri.host != 'wear-auth') {
      return;
    }

    final code = uri.queryParameters['code'];
    if (code == null || code.length != 6) return;

    _scanned = true;
    Navigator.pop(context, code);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Conectar reloj'),
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
      ),
      body: Stack(
        children: [
          MobileScanner(
            controller: _controller,
            onDetect: _onDetect,
          ),
          Align(
            alignment: Alignment.bottomCenter,
            child: Container(
              margin: const EdgeInsets.only(bottom: 48),
              padding:
                  const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.6),
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Text(
                'Apunta la cámara al QR del reloj',
                style: TextStyle(color: Colors.white, fontSize: 14),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

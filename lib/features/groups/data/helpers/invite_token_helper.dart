import 'dart:math';
import 'dart:convert';
import 'package:crypto/crypto.dart';

/// Helpers for generating and hashing invite tokens and short codes.
class InviteTokenHelper {
  // Omits 0/O and 1/I to avoid visual confusion when typing.
  static const String _chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
  static const int _shortCodeLength = 6;

  /// Returns a 6-char uppercase alphanumeric code, e.g. "X7K2PQ".
  static String generateShortCode() {
    final random = Random.secure();
    return List.generate(
      _shortCodeLength,
      (_) => _chars[random.nextInt(_chars.length)],
    ).join();
  }

  /// Returns a 32-byte cryptographically random token as a URL-safe base64
  /// string (no padding). Used as the raw token embedded in links.
  static String generateToken() {
    final random = Random.secure();
    final bytes = List<int>.generate(32, (_) => random.nextInt(256));
    return base64Url.encode(bytes).replaceAll('=', '');
  }

  /// SHA-256 hash of [token]. Only the hash is stored in Firestore;
  /// the raw token lives in the invite link / QR code.
  static String hashToken(String token) {
    final bytes = utf8.encode(token);
    return sha256.convert(bytes).toString();
  }

  /// Builds the deep-link URL for a short code.
  static String buildInviteUrl(String shortCode) =>
      'runninglaps://join?code=$shortCode';
}

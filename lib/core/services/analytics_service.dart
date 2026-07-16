import 'package:firebase_analytics/firebase_analytics.dart';

/// Wrapper fino sobre FirebaseAnalytics. Como la navegación principal es un
/// IndexedStack (MainShell) y no rutas de Navigator, las screen views se
/// registran manualmente en los puntos de cambio de tab/pantalla.
class AnalyticsService {
  static final FirebaseAnalytics instance = FirebaseAnalytics.instance;

  static Future<void> logScreenView(String screenName) {
    return instance.logScreenView(screenName: screenName);
  }
}

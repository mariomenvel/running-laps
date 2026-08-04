/// Números que tienen que coincidir con lo que dicen los textos legales
/// publicados en runninglaps.com.
///
/// Viven aquí y no sueltos en cada pantalla porque no son una decisión de UI:
/// cambiarlos sin cambiar `hosting/terms.html` y `hosting/privacy.html` deja a
/// la app prometiendo una cosa y haciendo otra.
class LegalPolicy {
  const LegalPolicy._();

  /// Edad mínima para tener cuenta.
  ///
  /// `terms.html` § 2 ("Tu cuenta") y `privacy.html` § menores. En España el
  /// consentimiento digital del menor se puede dar desde los 14 (art. 7
  /// LOPDGDD), pero los términos fijan 16 y es lo que la app debe respetar.
  static const int minimumAgeYears = 16;

  /// Fecha de nacimiento más reciente que se puede declarar cumpliendo
  /// [minimumAgeYears]. Los selectores de fecha de nacimiento la usan como
  /// `maximumDate`, de modo que la rueda no llega a una edad no permitida en
  /// vez de aceptarla y rechazarla después.
  static DateTime latestAllowedBirthDate([DateTime? now]) {
    final ref = now ?? DateTime.now();
    return DateTime(ref.year - minimumAgeYears, ref.month, ref.day);
  }
}

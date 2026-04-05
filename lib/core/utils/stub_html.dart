// Stub for non-web platforms — provides a no-op html.window.location.reload()
// so that conditional imports in web-only code compile on mobile/desktop.
// ignore: avoid_web_libraries_in_flutter
final window = _WindowStub();

class _WindowStub {
  final location = _LocationStub();
}

class _LocationStub {
  void reload() {}
}

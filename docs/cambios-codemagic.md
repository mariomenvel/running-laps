# Configuracion Codemagic

Fecha: 2026-06-14

## Resumen

Se anade `codemagic.yaml` en la raiz del repositorio para que Codemagic pueda detectar configuracion declarativa por rama.

## Workflows incluidos

- `android-workflow`
  - ejecuta `flutter pub get`
  - ejecuta `flutter analyze`
  - genera `.aab` y `.apk` release

- `ios-workflow`
  - ejecuta `flutter pub get`
  - ejecuta `pod install`
  - genera `Runner.app` para simulador sin firma con `flutter build ios --simulator`
  - empaqueta esa app en `.zip`

## Archivo creado

- `codemagic.yaml`

## Requisitos pendientes en Codemagic

Para que el workflow de iOS funcione de forma fiable en Codemagic, sigue pendiente configurar en la plataforma:

- certificado de firma iOS
- provisioning profiles
- cuenta App Store Connect si se quiere distribuir

El workflow actual evita ese fallo compilando para `iOS Simulator` con el flujo Flutter documentado: `flutter build ios --simulator`.
El artefacto final publicado por Codemagic es un `.zip` que contiene `Runner.app`.
Si se quiere una `.ipa` distribuible desde Codemagic, hay que crear un workflow firmado adicional para dispositivo real.

## Ajuste adicional para CI iOS

Se ha ampliado `SUPPORTED_PLATFORMS` en las configuraciones `Release` y `Profile` del proyecto iOS para admitir tambien `iphonesimulator`.

Motivo:

- el proyecto estaba limitado a `iphoneos`
- eso provocaba fallo `xcodebuild` con codigo `65` al compilar el workflow unsigned de simulador en Codemagic

El workflow deja de llamar a `xcodebuild` directamente porque Codemagic documenta `flutter build ios --simulator` como ruta especifica para Flutter. Esto evita que Xcode entre en una ruta de build de dispositivo o archive que requiere equipo de desarrollo.

## Ajuste adicional por fallo real de build Dart

Tras revisar el log completo de Codemagic, el fallo ya no era de firma. La compilacion de simulador llegaba hasta Dart y fallaba por:

- `Method not found: 'CupertinoPageTransitionsBuilder'`

Se corrige eliminando la referencia explicita a `CupertinoPageTransitionsBuilder` en `lib/core/theme/app_theme.dart`.
La app vuelve a usar las transiciones por defecto de Flutter, evitando depender de una API que cambia de libreria segun la version del SDK.

## Como usarlo

1. Subir este archivo a la rama deseada.
2. En Codemagic, seleccionar esa rama.
3. Pulsar `Check for configuration file`.
4. Elegir el workflow `android-workflow` o `ios-workflow`.

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
  - genera `.ipa` release

## Archivo creado

- `codemagic.yaml`

## Requisitos pendientes en Codemagic

Para que el workflow de iOS funcione de forma fiable en Codemagic, sigue pendiente configurar en la plataforma:

- certificado de firma iOS
- provisioning profiles
- cuenta App Store Connect si se quiere distribuir

Si no se configura firma iOS en Codemagic, el paso `flutter build ipa --release` puede fallar.

## Como usarlo

1. Subir este archivo a la rama deseada.
2. En Codemagic, seleccionar esa rama.
3. Pulsar `Check for configuration file`.
4. Elegir el workflow `android-workflow` o `ios-workflow`.

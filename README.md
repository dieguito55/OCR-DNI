# OCR DNI

Aplicacion movil Flutter para escaneo offline de DNI, revision de datos extraidos y exportacion local de padrones en formato Excel.

## Funcionalidades

- Captura de DNI con camara o seleccion desde galeria.
- OCR offline con integracion nativa Android.
- Revision y correccion de datos antes de guardar.
- Gestion local de registros por sede.
- Exportacion a plantilla Excel incluida en `assets/templates/`.

## Estructura

```text
android/       Integracion nativa Android y OCR offline
assets/        Imagenes, fuente, modelos OCR y plantilla Excel
lib/           Codigo principal Flutter
test/          Pruebas unitarias y de widgets
pubspec.yaml   Configuracion del proyecto
```

## Requisitos

- Flutter SDK compatible con Dart `^3.11.5`.
- Android SDK.
- Dispositivo o emulador Android.

## Ejecucion

```bash
flutter pub get
flutter run
```

## Compilacion APK

```bash
flutter build apk --release
```

El APK generado queda en:

```text
build/app/outputs/flutter-apk/app-release.apk
```

## Notas

Los archivos de depuracion, capturas, XML de automatizacion, bases locales, prompts y plantillas externas de trabajo no forman parte del repositorio.

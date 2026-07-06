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
docs/          Manual tecnico, manual de usuario y registro
lib/           Codigo principal Flutter
release/       Indicaciones para adjuntar el APK generado
test/          Pruebas unitarias y de widgets
pubspec.yaml   Configuracion del proyecto
```

Documentacion principal:

- [Manual tecnico](docs/MANUAL_TECNICO.md)
- [Manual de usuario](docs/MANUAL_USUARIO.md)
- [Registro de software](docs/REGISTRO_SOFTWARE.md)

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

En esta maquina el APK release actual esta en:

```text
D:\00.proyectos\xioo\agraria\build\app\outputs\flutter-apk\app-release.apk
```

El APK no se sube como archivo dentro del repositorio porque es un binario generado. Para entrega formal debe adjuntarse como asset de release o anexo.

## Notas

Los archivos de depuracion, capturas, XML de automatizacion, bases locales, prompts y plantillas externas de trabajo no forman parte del repositorio.

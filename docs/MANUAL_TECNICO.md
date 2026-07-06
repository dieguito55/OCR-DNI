# Manual tecnico

## 1. Descripcion

OCR DNI es una aplicacion movil Android construida con Flutter. Permite capturar o seleccionar imagenes de DNI, procesarlas localmente con OCR offline, revisar los datos extraidos y exportar padrones en formato Excel.

La aplicacion no requiere conexion a internet para ejecutar el OCR.

## 2. Arquitectura

```text
Flutter UI
  -> lib/screens/
  -> lib/services/ocr_service.dart
  -> MethodChannel xiomi/ocr
  -> android/app/src/main/kotlin/.../NativeOcr.kt
  -> JNI/C++ OCR pipeline
  -> assets/ocr_models/
```

## 3. Componentes

- `lib/`: interfaz, modelos, servicios, persistencia local y exportacion.
- `android/app/src/main/kotlin/`: puente Flutter-Android y servicio OCR nativo.
- `android/app/src/main/cpp/`: pipeline C++ para OCR offline.
- `assets/ocr_models/`: modelos OCR empaquetados como assets locales.
- `assets/templates/padron_template.xlsx`: plantilla de exportacion.
- `test/`: pruebas del parser y widget base.

## 4. Requisitos de desarrollo

- Flutter SDK compatible con Dart `^3.11.5`.
- Android SDK.
- JDK 17 o superior.
- NDK `28.2.13676358`.
- CMake `3.22.1`.

## 5. Instalacion de dependencias

```bash
flutter pub get
```

## 6. Analisis estatico

```bash
flutter analyze
```

Resultado esperado:

```text
No issues found!
```

## 7. Compilacion APK

```bash
flutter build apk --release
```

Salida esperada:

```text
build/app/outputs/flutter-apk/app-release.apk
```

## 8. APK generado para entrega

En esta maquina el APK release generado queda en:

```text
D:\00.proyectos\xioo\agraria\build\app\outputs\flutter-apk\app-release.apk
```

El APK no se versiona dentro del repositorio porque es un binario generado. Para entrega formal se debe adjuntar como archivo de release o anexo.

## 9. Consideraciones

- El build actual usa firma debug para facilitar ejecucion local de release.
- Para publicacion externa se recomienda configurar firma propia en Android.
- Las librerias nativas de OCR incrementan el peso del repositorio y del APK.
- Los archivos temporales, capturas, logs, bases locales y prompts fueron excluidos del repositorio.


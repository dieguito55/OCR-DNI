# Artefactos de release

El APK se genera localmente con:

```bash
flutter build apk --release
```

Ruta de salida:

```text
build/app/outputs/flutter-apk/app-release.apk
```

El APK no se guarda en Git porque es un binario generado y pesa mas de 100 MB. Para una entrega formal, adjuntarlo como asset de GitHub Release o como anexo externo.


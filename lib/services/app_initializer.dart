import 'dart:io';

import 'package:path_provider/path_provider.dart';

import '../database/database_service.dart';
import 'ocr_service.dart';

class AppInitializer {
  AppInitializer({DatabaseService? databaseService, OcrService? ocrService})
    : _databaseService = databaseService ?? DatabaseService.instance,
      _ocrService = ocrService ?? OcrService.instance;

  final DatabaseService _databaseService;
  final OcrService _ocrService;

  Future<InitializationReport> initialize() async {
    await _databaseService.initialize();
    final imagesDirectory = await dniImagesDirectory();
    final ocrReady = await _ocrService.verifyLocalModels();
    return InitializationReport(
      databaseReady: true,
      imagesDirectory: imagesDirectory.path,
      ocrAssetsDetected: ocrReady,
    );
  }

  static Future<Directory> dniImagesDirectory() async {
    final base = await getApplicationDocumentsDirectory();
    final directory = Directory(
      '${base.path}${Platform.pathSeparator}dni_images',
    );
    if (!await directory.exists()) {
      await directory.create(recursive: true);
    }
    return directory;
  }
}

class InitializationReport {
  const InitializationReport({
    required this.databaseReady,
    required this.imagesDirectory,
    required this.ocrAssetsDetected,
  });

  final bool databaseReady;
  final String imagesDirectory;
  final bool ocrAssetsDetected;
}

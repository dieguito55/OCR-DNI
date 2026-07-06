import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../models/ocr_result.dart';
import '../models/persona.dart';
import 'dni_text_parser.dart';

class OcrService {
  OcrService._();

  static final OcrService instance = OcrService._();
  static const MethodChannel _channel = MethodChannel('xiomi/ocr');

  Future<bool> verifyLocalModels() async {
    const requiredAssets = [
      'assets/ocr_models/config.txt',
      'assets/ocr_models/models/ch_PP-OCRv2_det_slim_opt.nb',
      'assets/ocr_models/models/ch_PP-OCRv2_rec_slim_opt.nb',
      'assets/ocr_models/labels/ppocr_keys_v1.txt',
    ];

    for (final asset in requiredAssets) {
      try {
        await rootBundle.load(asset);
      } catch (_) {
        return false;
      }
    }
    return true;
  }

  Future<OcrResult> processImage(String imagePath) async {
    try {
      final response = await _channel.invokeMapMethod<String, dynamic>(
        'processDniImage',
        {'imagePath': imagePath},
      );
      final fullText = response?['text']?.toString() ?? '';
      final raw = response?['raw']?.toString() ?? '';
      final boxPoints = _parseBoxPoints(
        response?['boxPointsJson']?.toString() ?? raw,
      );
      debugPrint(
        'XIOMI_OCR boxes=${response?['boxes']} points=${boxPoints.length} rawHasBoxPoints=${raw.contains('boxPoints')}',
      );
      final extracted = DniTextParser.parse(fullText, imagePath);
      return OcrResult(
        imagePath: imagePath,
        fullText: fullText,
        persona: extracted,
        engineStatus: response?['engine']?.toString() ?? 'nativo',
        raw: raw,
        visualizedPath: response?['visualizedPath']?.toString() ?? '',
        boxes: int.tryParse(response?['boxes']?.toString() ?? '') ?? 0,
        boxPoints: boxPoints,
        elapsedMs:
            double.tryParse(response?['elapsedMs']?.toString() ?? '') ?? 0,
      );
    } on MissingPluginException {
      return _pendingNativeResult(imagePath);
    } on PlatformException catch (error) {
      return OcrResult(
        imagePath: imagePath,
        fullText: 'OCR no disponible: ${error.message ?? error.code}',
        persona: Persona(
          imagenDniPath: imagePath,
          textoOcr: error.message ?? error.code,
        ),
        engineStatus: 'error',
        raw: error.details?.toString() ?? '',
      );
    }
  }

  OcrResult _pendingNativeResult(String imagePath) {
    const text =
        'OCR nativo pendiente. Coloca los modelos PP-OCRv2 en assets/ocr_models '
        'e implementa processDniImage en Android para devolver el texto detectado.';
    return OcrResult(
      imagePath: imagePath,
      fullText: text,
      persona: Persona(imagenDniPath: imagePath, textoOcr: text),
      engineStatus: 'pendiente',
    );
  }

  List<OcrBox> _parseBoxPoints(String raw) {
    if (raw.isEmpty) return const [];
    try {
      final decoded = jsonDecode(raw);
      final boxes = decoded is Map<String, dynamic>
          ? decoded['boxPoints']
          : decoded;
      if (boxes is! List) return const [];
      return boxes
          .map((box) {
            if (box is! List) return null;
            final points = box
                .map((point) {
                  if (point is! List || point.length < 2) return null;
                  return OcrPoint(
                    x: double.tryParse(point[0].toString()) ?? 0,
                    y: double.tryParse(point[1].toString()) ?? 0,
                  );
                })
                .whereType<OcrPoint>()
                .toList();
            return points.length >= 4 ? OcrBox(points: points) : null;
          })
          .whereType<OcrBox>()
          .toList();
    } catch (_) {
      return const [];
    }
  }
}

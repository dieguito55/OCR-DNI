import 'persona.dart';

class OcrResult {
  const OcrResult({
    required this.imagePath,
    required this.fullText,
    required this.persona,
    this.engineStatus = 'pendiente',
    this.raw = '',
    this.visualizedPath = '',
    this.boxes = 0,
    this.boxPoints = const [],
    this.elapsedMs = 0,
  });

  final String imagePath;
  final String fullText;
  final Persona persona;
  final String engineStatus;
  final String raw;
  final String visualizedPath;
  final int boxes;
  final List<OcrBox> boxPoints;
  final double elapsedMs;
}

class OcrBox {
  const OcrBox({required this.points});

  final List<OcrPoint> points;
}

class OcrPoint {
  const OcrPoint({required this.x, required this.y});

  final double x;
  final double y;
}

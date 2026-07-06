import 'dart:async';
import 'dart:io';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as p;
import 'package:permission_handler/permission_handler.dart';

import '../core/theme/app_theme.dart';
import '../models/sede.dart';
import '../models/ocr_result.dart';
import '../services/app_initializer.dart';
import '../services/ocr_service.dart';
import '../widgets/sede_switcher_button.dart';
import 'review_screen.dart';

const _navy = Color(0xFF07142D);
const _ink = Color(0xFF111827);
const _muted = Color(0xFF64748B);
const _line = Color(0xFFE2E8F0);
const _cyan = Color(0xFF208EAD);

class DetectionScreen extends StatefulWidget {
  const DetectionScreen({
    super.key,
    required this.sede,
    required this.onChangeSede,
  });

  final Sede sede;
  final VoidCallback onChangeSede;

  @override
  State<DetectionScreen> createState() => _DetectionScreenState();
}

class _DetectionScreenState extends State<DetectionScreen> {
  CameraController? _controller;
  String? _imagePath;
  bool _loadingCamera = true;
  bool _processing = false;
  bool _flashOn = false;
  Offset? _focusPoint;
  Timer? _focusPointTimer;
  String? _message;

  double _minZoom = 1.0;
  double _maxZoom = 1.0;
  double _currentZoom = 1.0;
  double _baseZoom = 1.0;

  @override
  void initState() {
    super.initState();
    _initCamera();
  }

  @override
  void dispose() {
    _focusPointTimer?.cancel();
    _controller?.pausePreview();
    _controller?.dispose();
    super.dispose();
  }

  Future<void> _initCamera() async {
    setState(() {
      _loadingCamera = true;
      _message = null;
    });

    final status = await Permission.camera.request();
    if (!status.isGranted) {
      setState(() {
        _loadingCamera = false;
        _message = 'Activa el permiso de camara para escanear DNI.';
      });
      return;
    }

    try {
      final cameras = await availableCameras();
      if (cameras.isEmpty) {
        setState(() {
          _loadingCamera = false;
          _message = 'No se encontro una camara disponible.';
        });
        return;
      }

      final selectedCamera = _selectBestCamera(cameras);
      final controller = CameraController(
        selectedCamera,
        ResolutionPreset.veryHigh,
        enableAudio: false,
        imageFormatGroup: ImageFormatGroup.jpeg,
      );
      await controller.initialize();
      await _configureCameraForDni(controller);

      final minZoom = await controller.getMinZoomLevel();
      final maxZoom = await controller.getMaxZoomLevel();

      if (!mounted) return;
      setState(() {
        _controller = controller;
        _loadingCamera = false;
        _flashOn = false;
        _minZoom = minZoom;
        _maxZoom = maxZoom;
        _currentZoom = minZoom;
        _baseZoom = minZoom;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loadingCamera = false;
        _message = 'No se pudo iniciar la camara: $error';
      });
    }
  }

  CameraDescription _selectBestCamera(List<CameraDescription> cameras) {
    final sorted = [...cameras]
      ..sort((a, b) => _cameraScore(b).compareTo(_cameraScore(a)));
    return sorted.first;
  }

  int _cameraScore(CameraDescription camera) {
    var score = 0;
    if (camera.lensDirection == CameraLensDirection.back) score += 100;
    if (camera.lensDirection == CameraLensDirection.front) score -= 100;
    if (camera.lensDirection == CameraLensDirection.external) score -= 20;

    final name = camera.name.toLowerCase();
    final numericId = int.tryParse(
      RegExp(r'\d+').firstMatch(name)?.group(0) ?? '',
    );
    if (numericId == 0) score += 30;
    if (numericId == 1) score += 10;
    if (name.contains('back') || name.contains('rear')) score += 12;
    if (name.contains('wide')) score += 8;
    if (name.contains('ultra') ||
        name.contains('macro') ||
        name.contains('depth')) {
      score -= 25;
    }
    return score;
  }

  Future<void> _configureCameraForDni(CameraController controller) async {
    await controller.setFlashMode(FlashMode.off);
    await _tryCameraAction(() => controller.setFocusMode(FocusMode.auto));
    await _tryCameraAction(() => controller.setExposureMode(ExposureMode.auto));
    await _tryCameraAction(
      () => controller.setFocusPoint(const Offset(0.5, 0.5)),
    );
    await _tryCameraAction(
      () => controller.setExposurePoint(const Offset(0.5, 0.5)),
    );
  }

  Future<void> _tryCameraAction(Future<void> Function() action) async {
    try {
      await action();
    } on CameraException {
      // Some devices do not expose every camera2 control through the plugin.
    }
  }

  Future<void> _takePhoto() async {
    final controller = _controller;
    if (controller == null ||
        !controller.value.isInitialized ||
        controller.value.isTakingPicture) {
      return;
    }
    await HapticFeedback.mediumImpact();
    final shot = await controller.takePicture();
    await _setTorch(false);
    final storedPath = await _copyToPrivateFolder(shot.path);
    if (!mounted) return;
    setState(() => _imagePath = storedPath);
  }

  Future<void> _focusAt(Offset localPosition, Size size) async {
    final controller = _controller;
    if (controller == null || !controller.value.isInitialized) return;

    final normalized = Offset(
      (localPosition.dx / size.width).clamp(0.0, 1.0),
      (localPosition.dy / size.height).clamp(0.0, 1.0),
    );
    await HapticFeedback.selectionClick();
    await _tryCameraAction(() => controller.setFocusPoint(normalized));
    await _tryCameraAction(() => controller.setExposurePoint(normalized));

    if (!mounted) return;
    setState(() => _focusPoint = localPosition);
    _focusPointTimer?.cancel();
    _focusPointTimer = Timer(const Duration(milliseconds: 900), () {
      if (mounted) setState(() => _focusPoint = null);
    });
  }

  void _handleScaleStart(ScaleStartDetails details) {
    _baseZoom = _currentZoom;
  }

  void _handleScaleUpdate(ScaleUpdateDetails details) {
    final controller = _controller;
    if (controller == null || !controller.value.isInitialized) return;

    var zoom = _baseZoom * details.scale;
    zoom = zoom.clamp(_minZoom, _maxZoom);

    if (zoom != _currentZoom) {
      setState(() => _currentZoom = zoom);
      controller.setZoomLevel(zoom);
    }
  }

  Future<void> _pickImage() async {
    final picked = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      imageQuality: 96,
    );
    if (picked == null) return;
    final storedPath = await _copyToPrivateFolder(picked.path);
    if (!mounted) return;
    setState(() => _imagePath = storedPath);
  }

  Future<String> _copyToPrivateFolder(String sourcePath) async {
    final directory = await AppInitializer.dniImagesDirectory();
    final extension = p.extension(sourcePath).isEmpty
        ? '.jpg'
        : p.extension(sourcePath);
    final fileName = 'dni_${DateTime.now().millisecondsSinceEpoch}$extension';
    final target = p.join(directory.path, fileName);
    await File(sourcePath).copy(target);
    return target;
  }

  Future<void> _process() async {
    final imagePath = _imagePath;
    if (imagePath == null) return;
    setState(() => _processing = true);
    final OcrResult result = await OcrService.instance.processImage(imagePath);
    if (!mounted) return;
    setState(() => _processing = false);
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ReviewScreen(result: result, sede: widget.sede),
      ),
    );
  }

  Future<void> _toggleTorch() async {
    await HapticFeedback.selectionClick();
    await _setTorch(!_flashOn);
  }

  Future<void> _setTorch(bool enabled) async {
    final controller = _controller;
    if (controller == null || !controller.value.isInitialized) return;
    try {
      await controller.setFlashMode(enabled ? FlashMode.torch : FlashMode.off);
      if (!mounted) return;
      setState(() {
        _flashOn = enabled;
        if (_message == 'Linterna no disponible en esta camara.') {
          _message = null;
        }
      });
    } on CameraException {
      if (!mounted) return;
      setState(() {
        _flashOn = false;
        _message = 'Linterna no disponible en esta camara.';
      });
    }
  }

  void _clearPhoto() {
    setState(() => _imagePath = null);
  }

  @override
  Widget build(BuildContext context) {
    final hasPhoto = _imagePath != null;
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 28),
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: const Color(0xFFEAF7FB),
                          borderRadius: BorderRadius.circular(13),
                        ),
                        child: const Icon(
                          Icons.document_scanner_rounded,
                          color: _cyan,
                          size: 18,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Text(
                        'Deteccion',
                        style: Theme.of(context).textTheme.headlineMedium
                            ?.copyWith(
                              fontWeight: FontWeight.w800,
                              color: _ink,
                              letterSpacing: -0.5,
                            ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    hasPhoto
                        ? 'Imagen lista para extraer datos'
                        : 'Alinea el documento y evita reflejos',
                    style: const TextStyle(
                      fontFamily: 'Inter',
                      color: _muted,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
            SedeSwitcherButton(
              sede: widget.sede,
              onPressed: widget.onChangeSede,
            ),
          ],
        ),
        const SizedBox(height: 16),
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: _line),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF0F172A).withValues(alpha: 0.10),
                blurRadius: 28,
                offset: const Offset(0, 14),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.all(8),
            child: AspectRatio(
              aspectRatio: 0.72,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(17),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    _Preview(
                      controller: _controller,
                      loading: _loadingCamera,
                      imagePath: _imagePath,
                      message: _message,
                    ),
                    if (!hasPhoto && !_loadingCamera)
                      _FocusTapLayer(
                        focusPoint: _focusPoint,
                        onFocus: _focusAt,
                        onScaleStart: _handleScaleStart,
                        onScaleUpdate: _handleScaleUpdate,
                      ),
                    const _DniGuide(),
                    _TorchControl(
                      enabled: _flashOn,
                      visible: !hasPhoto && !_loadingCamera,
                      onPressed: _processing ? null : _toggleTorch,
                    ),
                    _CameraHud(
                      hasPhoto: hasPhoto,
                      processing: _processing,
                      torchOn: _flashOn,
                    ),
                    if (_processing)
                      Container(
                        color: const Color(0x7707142D),
                        child: Center(
                          child: Container(
                            width: 62,
                            height: 62,
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(18),
                            ),
                            child: const Padding(
                              padding: EdgeInsets.all(14),
                              child: CircularProgressIndicator(
                                color: _cyan,
                                strokeWidth: 2.5,
                              ),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 14),
        _CaptureStatus(hasPhoto: hasPhoto, processing: _processing),
        const SizedBox(height: 14),
        Row(
          children: [
            Expanded(
              child: FilledButton.icon(
                style: FilledButton.styleFrom(
                  backgroundColor: _navy,
                  foregroundColor: Colors.white,
                  minimumSize: const Size(48, 52),
                ),
                onPressed: _processing
                    ? null
                    : _imagePath == null
                    ? _takePhoto
                    : _clearPhoto,
                icon: Icon(
                  _imagePath == null
                      ? Icons.camera_alt_rounded
                      : Icons.refresh_rounded,
                ),
                label: Text(_imagePath == null ? 'Tomar foto' : 'Repetir'),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: _navy,
                  side: const BorderSide(color: _line),
                  minimumSize: const Size(48, 52),
                ),
                onPressed: _processing ? null : _pickImage,
                icon: const Icon(Icons.photo_library_rounded),
                label: const Text('Galeria'),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Container(
          decoration: BoxDecoration(
            gradient: null,
            color: (_imagePath == null || _processing)
                ? XiomiColors.border
                : _navy,
            borderRadius: BorderRadius.circular(16),
            boxShadow: (_imagePath != null && !_processing)
                ? [
                    BoxShadow(
                      color: _navy.withValues(alpha: 0.18),
                      blurRadius: 20,
                      offset: const Offset(0, 10),
                    ),
                  ]
                : null,
          ),
          child: Material(
            color: Colors.transparent,
            borderRadius: BorderRadius.circular(16),
            child: InkWell(
              onTap: _imagePath == null || _processing ? null : _process,
              borderRadius: BorderRadius.circular(16),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 15),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    if (_processing)
                      const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    else
                      Icon(
                        Icons.auto_awesome_rounded,
                        color: (_imagePath != null) ? Colors.white : _muted,
                        size: 20,
                      ),
                    const SizedBox(width: 10),
                    Text(
                      _processing ? 'Procesando...' : 'Procesar OCR',
                      style: TextStyle(
                        fontFamily: 'Inter',
                        color: (_imagePath != null && !_processing)
                            ? Colors.white
                            : _muted,
                        fontWeight: FontWeight.w600,
                        fontSize: 15,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _Preview extends StatelessWidget {
  const _Preview({
    required this.controller,
    required this.loading,
    required this.imagePath,
    required this.message,
  });

  final CameraController? controller;
  final bool loading;
  final String? imagePath;
  final String? message;

  @override
  Widget build(BuildContext context) {
    if (imagePath != null) {
      return Image.file(File(imagePath!), fit: BoxFit.cover);
    }
    if (loading) {
      return const ColoredBox(
        color: XiomiColors.ink,
        child: Center(
          child: CircularProgressIndicator(color: XiomiColors.lightCyan),
        ),
      );
    }
    final camera = controller;
    if (camera != null && camera.value.isInitialized) {
      final size = camera.value.previewSize;
      if (size == null) return CameraPreview(camera);
      return ClipRect(
        child: FittedBox(
          fit: BoxFit.cover,
          child: SizedBox(
            width: size.height,
            height: size.width,
            child: CameraPreview(camera),
          ),
        ),
      );
    }
    return ColoredBox(
      color: XiomiColors.ink,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(22),
          child: Text(
            message ?? 'Camara no disponible',
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.white),
          ),
        ),
      ),
    );
  }
}

class _DniGuide extends StatefulWidget {
  const _DniGuide();

  @override
  State<_DniGuide> createState() => _DniGuideState();
}

class _DniGuideState extends State<_DniGuide>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final guideWidth = MediaQuery.sizeOf(context).width * 0.78;
    final guideHeight = guideWidth * 0.63;
    return IgnorePointer(
      child: Stack(
        children: [
          ColorFiltered(
            colorFilter: ColorFilter.mode(
              Colors.black.withValues(alpha: 0.6), // Darker for better contrast
              BlendMode.srcOut,
            ),
            child: Stack(
              fit: StackFit.expand,
              children: [
                const DecoratedBox(
                  decoration: BoxDecoration(color: Colors.black),
                ),
                Center(
                  child: Container(
                    width: guideWidth,
                    height: guideHeight,
                    decoration: BoxDecoration(
                      color: Colors.transparent,
                      borderRadius: BorderRadius.circular(12), // Smoother edges
                    ),
                  ),
                ),
              ],
            ),
          ),
          Center(
            child: Container(
              width: guideWidth,
              height: guideHeight,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFF7DD3EA), width: 2),
              ),
              child: Stack(
                children: [
                  const _Corner(alignment: Alignment.topLeft),
                  const _Corner(alignment: Alignment.topRight),
                  const _Corner(alignment: Alignment.bottomLeft),
                  const _Corner(alignment: Alignment.bottomRight),
                  AnimatedBuilder(
                    animation: _controller,
                    builder: (context, child) {
                      return Positioned(
                        top: _controller.value * (guideHeight - 4),
                        left: 0,
                        right: 0,
                        child: Container(
                          height: 4,
                          decoration: BoxDecoration(
                            boxShadow: [
                              BoxShadow(
                                color: const Color(
                                  0xFF7DD3EA,
                                ).withValues(alpha: 0.45),
                                blurRadius: 8,
                                spreadRadius: 4,
                              ),
                            ],
                            gradient: LinearGradient(
                              colors: [
                                const Color(0xFF7DD3EA).withValues(alpha: 0.0),
                                const Color(0xFF7DD3EA),
                                const Color(0xFF7DD3EA).withValues(alpha: 0.0),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                  const Positioned(
                    left: 14,
                    top: 14,
                    child: _GuideChip(icon: Icons.badge_rounded, text: 'DNI'),
                  ),
                  const Positioned(
                    right: 14,
                    bottom: 14,
                    child: _GuideChip(
                      icon: Icons.center_focus_strong_rounded,
                      text: 'Texto nitido',
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _FocusTapLayer extends StatelessWidget {
  const _FocusTapLayer({
    required this.focusPoint,
    required this.onFocus,
    required this.onScaleStart,
    required this.onScaleUpdate,
  });

  final Offset? focusPoint;
  final Future<void> Function(Offset localPosition, Size size) onFocus;
  final void Function(ScaleStartDetails) onScaleStart;
  final void Function(ScaleUpdateDetails) onScaleUpdate;

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: LayoutBuilder(
        builder: (context, constraints) {
          final size = Size(constraints.maxWidth, constraints.maxHeight);
          return GestureDetector(
            behavior: HitTestBehavior.translucent,
            onTapDown: (details) => onFocus(details.localPosition, size),
            onScaleStart: onScaleStart,
            onScaleUpdate: onScaleUpdate,
            child: CustomPaint(painter: _FocusReticlePainter(focusPoint)),
          );
        },
      ),
    );
  }
}

class _FocusReticlePainter extends CustomPainter {
  const _FocusReticlePainter(this.point);

  final Offset? point;

  @override
  void paint(Canvas canvas, Size size) {
    final focus = point;
    if (focus == null) return;

    final paint = Paint()
      ..color = const Color(0xFF7DD3EA)
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;
    final rect = Rect.fromCenter(center: focus, width: 54, height: 54);
    canvas.drawRRect(
      RRect.fromRectAndRadius(rect, const Radius.circular(8)),
      paint,
    );

    final linePaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.85)
      ..strokeWidth = 1.4;
    canvas.drawLine(focus.translate(-8, 0), focus.translate(8, 0), linePaint);
    canvas.drawLine(focus.translate(0, -8), focus.translate(0, 8), linePaint);
  }

  @override
  bool shouldRepaint(covariant _FocusReticlePainter oldDelegate) {
    return oldDelegate.point != point;
  }
}

class _CameraHud extends StatelessWidget {
  const _CameraHud({
    required this.hasPhoto,
    required this.processing,
    required this.torchOn,
  });

  final bool hasPhoto;
  final bool processing;
  final bool torchOn;

  @override
  Widget build(BuildContext context) {
    return Positioned(
      left: 12,
      right: 12,
      bottom: 12,
      child: Row(
        children: [
          _GuideChip(
            icon: hasPhoto
                ? Icons.check_circle_rounded
                : torchOn
                ? Icons.flash_on_rounded
                : Icons.wb_sunny_rounded,
            text: hasPhoto
                ? 'Captura lista'
                : torchOn
                ? 'Linterna activa'
                : 'Buena luz',
          ),
          const SizedBox(width: 8),
          _GuideChip(
            icon: processing
                ? Icons.hourglass_top_rounded
                : Icons.stay_current_landscape_rounded,
            text: processing ? 'Procesando' : 'Horizontal',
          ),
        ],
      ),
    );
  }
}

class _CaptureStatus extends StatelessWidget {
  const _CaptureStatus({required this.hasPhoto, required this.processing});

  final bool hasPhoto;
  final bool processing;

  @override
  Widget build(BuildContext context) {
    final icon = processing
        ? Icons.hourglass_top_rounded
        : hasPhoto
        ? Icons.check_circle_rounded
        : Icons.document_scanner_rounded;
    final text = processing
        ? 'Extrayendo texto del DNI'
        : hasPhoto
        ? 'Revisa la imagen o procesa el OCR'
        : 'Lista para capturar el anverso del DNI';
    final statusColor = processing
        ? XiomiColors.warning
        : hasPhoto
        ? XiomiColors.success
        : _cyan;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _line),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0F172A).withValues(alpha: 0.05),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: statusColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(XiomiRadius.sm),
            ),
            child: Icon(icon, color: statusColor, size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                fontFamily: 'Inter',
                color: _ink,
                fontWeight: FontWeight.w600,
                fontSize: 13,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TorchControl extends StatelessWidget {
  const _TorchControl({
    required this.enabled,
    required this.visible,
    required this.onPressed,
  });

  final bool enabled;
  final bool visible;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    if (!visible) return const SizedBox.shrink();

    return Positioned(
      top: 12,
      right: 12,
      child: Tooltip(
        message: enabled ? 'Apagar linterna' : 'Encender linterna',
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onPressed,
            borderRadius: BorderRadius.circular(8),
            child: Ink(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: enabled ? _navy : Colors.black.withValues(alpha: 0.62),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: enabled
                      ? const Color(0xFF7DD3EA)
                      : Colors.white.withValues(alpha: 0.2),
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    enabled
                        ? Icons.flashlight_on_rounded
                        : Icons.flashlight_off_rounded,
                    color: Colors.white,
                    size: 18,
                  ),
                  const SizedBox(width: 7),
                  Text(
                    enabled ? 'Linterna ON' : 'Linterna',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _GuideChip extends StatelessWidget {
  const _GuideChip({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: const Color(0xFF07142D).withValues(alpha: 0.78),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: Colors.white.withValues(alpha: 0.85)),
            const SizedBox(width: 5),
            Text(
              text,
              style: const TextStyle(
                fontFamily: 'Inter',
                color: Colors.white,
                fontSize: 11,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.2,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Corner extends StatelessWidget {
  const _Corner({required this.alignment});

  final Alignment alignment;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: alignment,
      child: Container(
        width: 28,
        height: 28,
        decoration: BoxDecoration(
          border: Border(
            top: alignment.y < 0
                ? const BorderSide(color: Color(0xFF7DD3EA), width: 5)
                : BorderSide.none,
            bottom: alignment.y > 0
                ? const BorderSide(color: Color(0xFF7DD3EA), width: 5)
                : BorderSide.none,
            left: alignment.x < 0
                ? const BorderSide(color: Color(0xFF7DD3EA), width: 5)
                : BorderSide.none,
            right: alignment.x > 0
                ? const BorderSide(color: Color(0xFF7DD3EA), width: 5)
                : BorderSide.none,
          ),
        ),
      ),
    );
  }
}

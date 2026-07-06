import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/theme/app_theme.dart';
import '../database/database_service.dart';
import '../models/ocr_result.dart';
import '../models/persona.dart';
import '../models/sede.dart';

class ReviewScreen extends StatefulWidget {
  const ReviewScreen({
    super.key,
    required this.sede,
    this.result,
    this.persona,
  });

  final Sede sede;
  final OcrResult? result;
  final Persona? persona;

  @override
  State<ReviewScreen> createState() => _ReviewScreenState();
}

class _ReviewScreenState extends State<ReviewScreen> {
  final _formKey = GlobalKey<FormState>();
  late Persona _base;
  late final Map<String, TextEditingController> _controllers;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final source = widget.persona ?? widget.result?.persona ?? const Persona();
    _base = source.copyWith(sedeId: widget.sede.id);
    _controllers = {
      'apellidoPaterno': TextEditingController(text: _base.apellidoPaterno),
      'apellidoMaterno': TextEditingController(text: _base.apellidoMaterno),
      'nombres': TextEditingController(text: _base.nombres),
      'dni': TextEditingController(text: _base.dni),
      'sexo': TextEditingController(text: _base.sexo),
      'fechaNacimiento': TextEditingController(text: _base.fechaNacimiento),
      'textoOcr': TextEditingController(
        text: _base.textoOcr.isEmpty
            ? widget.result?.fullText ?? ''
            : _base.textoOcr,
      ),
    };
  }

  @override
  void dispose() {
    for (final controller in _controllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    final persona = _buildPersona();
    try {
      await DatabaseService.instance.savePersona(persona);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Registro guardado localmente.')),
      );
      Navigator.of(context).pop(true);
    } on DuplicateDniException catch (error) {
      if (!mounted) return;
      setState(() => _saving = false);
      await showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('DNI duplicado'),
          content: Text(
            'El DNI ${error.existing.dni} ya está registrado como ${error.existing.nombreCompleto}.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cerrar'),
            ),
          ],
        ),
      );
    } catch (error) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('No se pudo guardar: $error')));
    }
  }

  Future<void> _delete() async {
    final id = _base.id;
    if (id == null) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Eliminar registro'),
        content: const Text(
          'Se eliminará el registro local. La imagen asociada se conserva para evitar borrar evidencia por accidente.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await DatabaseService.instance.deletePersona(id);
    if (!mounted) return;
    Navigator.of(context).pop(true);
  }

  Persona _buildPersona() {
    String text(String key) => _controllers[key]!.text.trim();
    return _base.copyWith(
      sedeId: widget.sede.id,
      apellidoPaterno: text('apellidoPaterno'),
      apellidoMaterno: text('apellidoMaterno'),
      nombres: text('nombres'),
      dni: text('dni'),
      sexo: text('sexo'),
      fechaNacimiento: text('fechaNacimiento'),
      textoOcr: text('textoOcr'),
    );
  }

  @override
  Widget build(BuildContext context) {
    final imagePath = _base.imagenDniPath;
    final visualizedPath = widget.result?.visualizedPath ?? '';
    return Scaffold(
      appBar: AppBar(
        title: Text(
          _base.id == null ? 'Revisión de datos' : 'Editar registro',
          style: const TextStyle(
            fontFamily: 'Inter',
            fontWeight: FontWeight.w700,
            fontSize: 18,
          ),
        ),
        actions: [
          if (_base.id != null)
            IconButton(
              tooltip: 'Eliminar',
              onPressed: _delete,
              icon: const Icon(
                Icons.delete_outline_rounded,
                color: XiomiColors.error,
              ),
            ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
          children: [
            if (imagePath.isNotEmpty && File(imagePath).existsSync())
              Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(XiomiRadius.lg),
                  boxShadow: XiomiColors.cardShadow,
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(XiomiRadius.lg),
                  child: Image.file(
                    File(imagePath),
                    height: 210,
                    fit: BoxFit.cover,
                  ),
                ),
              ),
            if (imagePath.isNotEmpty &&
                File(imagePath).existsSync() &&
                (widget.result?.boxPoints.isNotEmpty ?? false))
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: _OcrBoxImage(
                  imagePath: imagePath,
                  boxes: widget.result!.boxPoints,
                  elapsedMs: widget.result!.elapsedMs,
                ),
              ),
            if (visualizedPath.isNotEmpty && File(visualizedPath).existsSync())
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: _OcrVisualizedImage(
                  path: visualizedPath,
                  boxes: widget.result?.boxes ?? 0,
                  elapsedMs: widget.result?.elapsedMs ?? 0,
                ),
              ),
            const SizedBox(height: 16),
            if (widget.result != null)
              _OcrStatusCard(
                result: widget.result!,
                completed: _base.estaCompleto,
              ),
            if (widget.result != null)
              _ExtractedSummary(values: _summaryValues),
            _field(
              'dni',
              'DNI',
              keyboardType: TextInputType.number,
              validator: _dniValidator,
            ),
            _field('apellidoPaterno', 'Apellido paterno'),
            _field('apellidoMaterno', 'Apellido materno'),
            _field('nombres', 'Nombres'),
            _field('fechaNacimiento', 'Fecha de nacimiento'),
            _field('sexo', 'Sexo'),
            _Section(
              title: 'Texto OCR',
              children: [_field('textoOcr', 'Texto detectado', maxLines: 5)],
            ),
            const SizedBox(height: 12),
            Container(
              decoration: BoxDecoration(
                gradient: XiomiColors.heroGradient,
                borderRadius: BorderRadius.circular(XiomiRadius.md),
                boxShadow: XiomiColors.buttonShadow,
              ),
              child: Material(
                color: Colors.transparent,
                borderRadius: BorderRadius.circular(XiomiRadius.md),
                child: InkWell(
                  onTap: _saving ? null : _save,
                  borderRadius: BorderRadius.circular(XiomiRadius.md),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 15),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        if (_saving)
                          const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        else
                          const Icon(
                            Icons.save_rounded,
                            color: Colors.white,
                            size: 20,
                          ),
                        const SizedBox(width: 10),
                        Text(
                          _saving ? 'Guardando...' : 'Guardar registro',
                          style: const TextStyle(
                            fontFamily: 'Inter',
                            color: Colors.white,
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
        ),
      ),
    );
  }

  Widget _field(
    String key,
    String label, {
    int maxLines = 1,
    TextInputType? keyboardType,
    String? Function(String?)? validator,
  }) {
    final controller = _controllers[key]!;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: TextFormField(
        controller: controller,
        maxLines: maxLines,
        keyboardType: keyboardType,
        textCapitalization: TextCapitalization.characters,
        inputFormatters: [
          TextInputFormatter.withFunction(
            (oldValue, newValue) => TextEditingValue(
              text: newValue.text.toUpperCase(),
              selection: newValue.selection,
            ),
          ),
        ],
        validator: validator,
        decoration: InputDecoration(
          labelText: label,
          suffixIcon: IconButton(
            tooltip: 'Borrar texto',
            icon: const Icon(
              Icons.clear_rounded,
              size: 20,
              color: XiomiColors.muted,
            ),
            onPressed: () => controller.clear(),
          ),
        ),
      ),
    );
  }

  Map<String, String> get _summaryValues {
    return {
      'DNI': _controllers['dni']!.text.trim(),
      'Nacimiento': _controllers['fechaNacimiento']!.text.trim(),
      'Sexo': _controllers['sexo']!.text.trim(),
      'Paterno': _controllers['apellidoPaterno']!.text.trim(),
      'Materno': _controllers['apellidoMaterno']!.text.trim(),
      'Nombres': _controllers['nombres']!.text.trim(),
    };
  }

  String? _dniValidator(String? value) {
    final dni = value?.trim() ?? '';
    if (dni.isEmpty) return null;
    if (!RegExp(r'^\d{8}$').hasMatch(dni)) {
      return 'El DNI debe tener 8 dígitos.';
    }
    return null;
  }
}

class _ExtractedSummary extends StatelessWidget {
  const _ExtractedSummary({required this.values});

  final Map<String, String> values;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: values.entries.map((entry) {
          final hasValue = entry.value.isNotEmpty;
          return Container(
            width: (MediaQuery.sizeOf(context).width - 56) / 2,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: hasValue ? XiomiColors.successLight : Colors.white,
              borderRadius: BorderRadius.circular(XiomiRadius.md),
              border: Border.all(
                color: hasValue
                    ? XiomiColors.success.withValues(alpha: 0.25)
                    : XiomiColors.warning.withValues(alpha: 0.30),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  entry.key,
                  style: const TextStyle(
                    fontFamily: 'Inter',
                    color: XiomiColors.muted,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.3,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  hasValue ? entry.value : 'Pendiente',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontFamily: 'Inter',
                    color: hasValue ? XiomiColors.ink : XiomiColors.warning,
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }
}

class _OcrVisualizedImage extends StatelessWidget {
  const _OcrVisualizedImage({
    required this.path,
    required this.boxes,
    required this.elapsedMs,
  });

  final String path;
  final int boxes;
  final double elapsedMs;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: XiomiColors.lightCyan),
      ),
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(
                  Icons.center_focus_strong_rounded,
                  color: XiomiColors.primaryPurple,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Zonas detectadas: $boxes',
                    style: const TextStyle(
                      color: XiomiColors.ink,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                Text(
                  '${elapsedMs.toStringAsFixed(0)} ms',
                  style: const TextStyle(color: XiomiColors.muted),
                ),
              ],
            ),
            const SizedBox(height: 10),
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: Image.file(File(path), fit: BoxFit.contain),
            ),
          ],
        ),
      ),
    );
  }
}

class _OcrBoxImage extends StatelessWidget {
  const _OcrBoxImage({
    required this.imagePath,
    required this.boxes,
    required this.elapsedMs,
  });

  final String imagePath;
  final List<OcrBox> boxes;
  final double elapsedMs;

  Future<ui.Image> _loadImage() async {
    final bytes = await File(imagePath).readAsBytes();
    final codec = await ui.instantiateImageCodec(bytes);
    final frame = await codec.getNextFrame();
    return frame.image;
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<ui.Image>(
      future: _loadImage(),
      builder: (context, snapshot) {
        final image = snapshot.data;
        return DecoratedBox(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: XiomiColors.lightCyan),
          ),
          child: Padding(
            padding: const EdgeInsets.all(10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(
                      Icons.center_focus_strong_rounded,
                      color: XiomiColors.primaryPurple,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Cuadros OCR: ${boxes.length}',
                        style: const TextStyle(
                          color: XiomiColors.ink,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    Text(
                      '${elapsedMs.toStringAsFixed(0)} ms',
                      style: const TextStyle(color: XiomiColors.muted),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                if (image == null)
                  const SizedBox(
                    height: 180,
                    child: Center(child: CircularProgressIndicator()),
                  )
                else
                  ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: AspectRatio(
                      aspectRatio: image.width / image.height,
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          Image.file(File(imagePath), fit: BoxFit.fill),
                          CustomPaint(
                            painter: _OcrBoxesPainter(
                              boxes: boxes,
                              imageSize: Size(
                                image.width.toDouble(),
                                image.height.toDouble(),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _OcrBoxesPainter extends CustomPainter {
  const _OcrBoxesPainter({required this.boxes, required this.imageSize});

  final List<OcrBox> boxes;
  final Size imageSize;

  @override
  void paint(Canvas canvas, Size size) {
    final scaleX = size.width / imageSize.width;
    final scaleY = size.height / imageSize.height;
    final paint = Paint()
      ..color = XiomiColors.success
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3;
    final fill = Paint()
      ..color = XiomiColors.success.withValues(alpha: 0.10)
      ..style = PaintingStyle.fill;

    for (final box in boxes) {
      final path = Path();
      for (var i = 0; i < box.points.length; i++) {
        final point = box.points[i];
        final offset = Offset(point.x * scaleX, point.y * scaleY);
        if (i == 0) {
          path.moveTo(offset.dx, offset.dy);
        } else {
          path.lineTo(offset.dx, offset.dy);
        }
      }
      path.close();
      canvas.drawPath(path, fill);
      canvas.drawPath(path, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _OcrBoxesPainter oldDelegate) {
    return oldDelegate.boxes != boxes || oldDelegate.imageSize != imageSize;
  }
}

class _OcrStatusCard extends StatelessWidget {
  const _OcrStatusCard({required this.result, required this.completed});

  final OcrResult result;
  final bool completed;

  @override
  Widget build(BuildContext context) {
    final hasText = result.fullText.trim().isNotEmpty;
    final statusColor = completed
        ? XiomiColors.success
        : hasText
        ? XiomiColors.info
        : XiomiColors.warning;
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: statusColor.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(XiomiRadius.lg),
        border: Border.all(color: statusColor.withValues(alpha: 0.18)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: statusColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(XiomiRadius.sm),
            ),
            child: Icon(
              completed
                  ? Icons.verified_rounded
                  : hasText
                  ? Icons.fact_check_rounded
                  : Icons.warning_amber_rounded,
              color: statusColor,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              completed
                  ? 'OCR completó los campos principales.'
                  : hasText
                  ? 'OCR detectó texto, revisa o corrige los campos.'
                  : 'OCR no devolvió texto. Prueba con más luz o una imagen menos inclinada.',
              style: const TextStyle(
                fontFamily: 'Inter',
                color: XiomiColors.ink,
                fontWeight: FontWeight.w600,
                fontSize: 13,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({required this.title, required this.children});

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(XiomiRadius.lg),
        border: Border.all(color: XiomiColors.border.withValues(alpha: 0.5)),
        boxShadow: XiomiColors.cardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontFamily: 'Inter',
              color: XiomiColors.ink,
              fontWeight: FontWeight.w700,
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 12),
          ...children,
        ],
      ),
    );
  }
}

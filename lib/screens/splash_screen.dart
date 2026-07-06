import 'package:flutter/material.dart';

import '../core/theme/app_theme.dart';
import '../services/app_initializer.dart';
import 'main_shell.dart';
import 'sede_selection_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin {
  String _status = 'Preparando escaner local';
  late final AnimationController _fadeController;
  late final AnimationController _pulseController;
  late final Animation<double> _fadeIn;
  late final Animation<double> _pulse;

  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 750),
    );
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat(reverse: true);

    _fadeIn = CurvedAnimation(parent: _fadeController, curve: Curves.easeOut);
    _pulse = Tween<double>(begin: 0.985, end: 1.01).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    _fadeController.forward();
    _boot();
  }

  @override
  void dispose() {
    _fadeController.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  Future<void> _boot() async {
    try {
      setState(() => _status = 'Inicializando base de datos local');
      final report = await AppInitializer().initialize();
      await Future<void>.delayed(const Duration(milliseconds: 550));
      if (!mounted) return;
      setState(() {
        _status = report.ocrAssetsDetected
            ? 'Modelos OCR locales verificados'
            : 'OCR listo para modelos locales';
      });
      await Future<void>.delayed(const Duration(milliseconds: 650));
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => SedeSelectionScreen(
            onSelected: (selectionContext, sede) {
              Navigator.of(selectionContext).pushReplacement(
                MaterialPageRoute(builder: (_) => MainShell(initialSede: sede)),
              );
            },
          ),
        ),
      );
    } catch (error) {
      if (!mounted) return;
      setState(() => _status = 'No se pudo iniciar: $error');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F7FB),
      body: Stack(
        fit: StackFit.expand,
        children: [
          const _InstitutionalBackdrop(),
          SafeArea(
            child: FadeTransition(
              opacity: _fadeIn,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(24, 28, 24, 28),
                child: Column(
                  children: [
                    const Spacer(flex: 3),
                    ScaleTransition(scale: _pulse, child: const _LogoPanel()),
                    const SizedBox(height: 24),
                    const Text(
                      'Xiomi',
                      style: TextStyle(
                        fontFamily: 'Inter',
                        color: Color(0xFF111827),
                        fontSize: 38,
                        fontWeight: FontWeight.w900,
                        height: 1,
                      ),
                    ),
                    const SizedBox(height: 9),
                    const Text(
                      'GESTION LOCAL DE PADRONES',
                      style: TextStyle(
                        fontFamily: 'Inter',
                        color: Color(0xFF536070),
                        fontSize: 11,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 2.6,
                      ),
                    ),
                    const SizedBox(height: 34),
                    _StatusPanel(status: _status),
                    const Spacer(flex: 4),
                    const _SecurityBadge(),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _InstitutionalBackdrop extends StatelessWidget {
  const _InstitutionalBackdrop();

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _InstitutionalBackdropPainter(),
      child: const SizedBox.expand(),
    );
  }
}

class _LogoPanel extends StatelessWidget {
  const _LogoPanel();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 168,
      height: 168,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(34),
        border: Border.all(color: const Color(0xFFE4E9F2)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF101B3D).withValues(alpha: 0.14),
            blurRadius: 34,
            offset: const Offset(0, 18),
          ),
        ],
      ),
      child: Image.asset(
        'assets/images/xiomi_icon.png',
        fit: BoxFit.contain,
        filterQuality: FilterQuality.high,
      ),
    );
  }
}

class _StatusPanel extends StatelessWidget {
  const _StatusPanel({required this.status});

  final String status;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(maxWidth: 340),
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE4E9F2)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 22,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: const Color(0xFFEAF7FB),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Padding(
              padding: EdgeInsets.all(8),
              child: CircularProgressIndicator(
                strokeWidth: 2.2,
                color: Color(0xFF208EAD),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 220),
              child: Text(
                status,
                key: ValueKey(status),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontFamily: 'Inter',
                  color: Color(0xFF1F2937),
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  height: 1.35,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SecurityBadge extends StatelessWidget {
  const _SecurityBadge();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFF0E1A35),
        borderRadius: BorderRadius.circular(XiomiRadius.pill),
      ),
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.wifi_off_rounded, size: 14, color: Color(0xFF7DD3EA)),
          SizedBox(width: 7),
          Text(
            'Operacion local sin internet',
            style: TextStyle(
              fontFamily: 'Inter',
              color: Colors.white,
              fontSize: 11,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.2,
            ),
          ),
        ],
      ),
    );
  }
}

class _InstitutionalBackdropPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final header = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Color(0xFF07142D), Color(0xFF172554)],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height * 0.38));
    canvas.drawRect(
      Rect.fromLTWH(0, 0, size.width, size.height * 0.38),
      header,
    );

    final accent = Paint()
      ..color = const Color(0xFF8B24FF).withValues(alpha: 0.16);
    canvas.drawCircle(
      Offset(-size.width * 0.18, size.height * 0.18),
      size.width * 0.58,
      accent,
    );

    final cyan = Paint()
      ..color = const Color(0xFF39E7FF).withValues(alpha: 0.12);
    canvas.drawCircle(
      Offset(size.width * 1.02, size.height * 0.16),
      size.width * 0.42,
      cyan,
    );

    final lower = Paint()..color = const Color(0xFFF4F7FB);
    final path = Path()
      ..moveTo(0, size.height * 0.31)
      ..quadraticBezierTo(
        size.width * 0.48,
        size.height * 0.39,
        size.width,
        size.height * 0.30,
      )
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();
    canvas.drawPath(path, lower);

    final line = Paint()
      ..color = const Color(0xFFDDE5F0)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    canvas.drawLine(
      Offset(24, size.height * 0.38),
      Offset(size.width - 24, size.height * 0.38),
      line,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

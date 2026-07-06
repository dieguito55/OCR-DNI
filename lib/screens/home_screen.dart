import 'package:flutter/material.dart';

import '../database/database_service.dart';
import '../models/app_stats.dart';
import '../models/persona.dart';
import '../models/sede.dart';
import '../services/excel_export_service.dart';
import '../widgets/metric_card.dart';
import '../widgets/sede_switcher_button.dart';

const _navy = Color(0xFF07142D);
const _navy2 = Color(0xFF172554);
const _ink = Color(0xFF111827);
const _muted = Color(0xFF64748B);
const _line = Color(0xFFE2E8F0);
const _cyan = Color(0xFF208EAD);

class HomeScreen extends StatefulWidget {
  const HomeScreen({
    super.key,
    required this.sede,
    required this.onChangeSede,
    required this.onScanPressed,
  });

  final Sede sede;
  final VoidCallback onChangeSede;
  final VoidCallback onScanPressed;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late Future<_HomeData> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  @override
  void didUpdateWidget(covariant HomeScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.sede.id != widget.sede.id) {
      _future = _load();
    }
  }

  Future<_HomeData> _load() async {
    final db = DatabaseService.instance;
    return _HomeData(
      stats: await db.stats(sedeId: widget.sede.id!),
      last: await db.lastPersona(sedeId: widget.sede.id!),
    );
  }

  Future<void> _export() async {
    final personas = await DatabaseService.instance.allPersonas(
      sedeId: widget.sede.id!,
    );
    if (!mounted) return;
    if (personas.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Todavia no hay registros para exportar.'),
        ),
      );
      return;
    }
    final file = await ExcelExportService.instance.exportPadron(
      personas,
      sede: widget.sede,
    );
    await ExcelExportService.instance.share(file);
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<_HomeData>(
      future: _future,
      builder: (context, snapshot) {
        final data =
            snapshot.data ??
            const _HomeData(
              stats: AppStats(
                total: 0,
                completos: 0,
                pendientes: 0,
                duplicados: 0,
                listosExportar: 0,
              ),
            );
        return RefreshIndicator(
          color: _cyan,
          onRefresh: () async {
            setState(() => _future = _load());
          },
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 28),
            children: [
              _HomeHeader(sede: widget.sede, onChangeSede: widget.onChangeSede),
              const SizedBox(height: 18),
              _OperationalBanner(
                sede: widget.sede,
                total: data.stats.total,
                completos: data.stats.completos,
              ),
              const SizedBox(height: 20),
              const _SectionTitle(
                title: 'Resumen operativo',
                icon: Icons.analytics_outlined,
              ),
              const SizedBox(height: 12),
              GridView.count(
                crossAxisCount: 2,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
                childAspectRatio: 1.08,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                children: [
                  MetricCard(
                    title: 'Registros guardados',
                    value: data.stats.total,
                    icon: Icons.people_alt_rounded,
                    accent: _navy,
                  ),
                  MetricCard(
                    title: 'Completos',
                    value: data.stats.completos,
                    icon: Icons.verified_rounded,
                    accent: const Color(0xFF12805C),
                  ),
                  MetricCard(
                    title: 'Pendientes',
                    value: data.stats.pendientes,
                    icon: Icons.pending_actions_rounded,
                    accent: const Color(0xFFB45309),
                  ),
                  MetricCard(
                    title: 'DNIs duplicados',
                    value: data.stats.duplicados,
                    icon: Icons.content_copy_rounded,
                    accent: const Color(0xFFB42318),
                  ),
                  MetricCard(
                    title: 'Listos para exportar',
                    value: data.stats.listosExportar,
                    icon: Icons.table_chart_rounded,
                    accent: _cyan,
                  ),
                ],
              ),
              const SizedBox(height: 22),
              const _SectionTitle(
                title: 'Acciones principales',
                icon: Icons.task_alt_rounded,
              ),
              const SizedBox(height: 12),
              _PrimaryAction(
                onPressed: widget.onScanPressed,
                icon: Icons.document_scanner_rounded,
                label: 'Escanear nuevo DNI',
                subtitle:
                    'Captura el documento y envia la imagen a revision OCR.',
              ),
              const SizedBox(height: 10),
              _SecondaryAction(
                onPressed: _export,
                icon: Icons.ios_share_rounded,
                label: 'Exportar padron de la sede',
              ),
              if (data.last != null) ...[
                const SizedBox(height: 22),
                const _SectionTitle(
                  title: 'Ultimo registro',
                  icon: Icons.history_rounded,
                ),
                const SizedBox(height: 12),
                _LastRecord(persona: data.last!),
              ],
            ],
          ),
        );
      },
    );
  }
}

class _HomeHeader extends StatelessWidget {
  const _HomeHeader({required this.sede, required this.onChangeSede});

  final Sede sede;
  final VoidCallback onChangeSede;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Image.asset(
                'assets/images/logo.png',
                height: 46,
                alignment: Alignment.centerLeft,
                fit: BoxFit.contain,
                filterQuality: FilterQuality.high,
              ),
              const SizedBox(height: 8),
              const Text(
                'Panel de control de padrones',
                style: TextStyle(
                  fontFamily: 'Inter',
                  color: _muted,
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
        SedeSwitcherButton(sede: sede, onPressed: onChangeSede),
      ],
    );
  }
}

class _OperationalBanner extends StatelessWidget {
  const _OperationalBanner({
    required this.sede,
    required this.total,
    required this.completos,
  });

  final Sede sede;
  final int total;
  final int completos;

  @override
  Widget build(BuildContext context) {
    final progress = total == 0 ? 0.0 : (completos / total).clamp(0.0, 1.0);
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [_navy, _navy2],
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: _navy.withValues(alpha: 0.18),
            blurRadius: 24,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(
                  Icons.location_on_rounded,
                  color: Colors.white,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      sede.displayName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontFamily: 'Inter',
                        color: Colors.white,
                        fontWeight: FontWeight.w900,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      'Sede activa para captura y exportacion local',
                      style: TextStyle(
                        fontFamily: 'Inter',
                        color: Colors.white.withValues(alpha: 0.72),
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              const _StatusPill(),
            ],
          ),
          const SizedBox(height: 16),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              minHeight: 7,
              value: progress,
              backgroundColor: Colors.white.withValues(alpha: 0.15),
              valueColor: const AlwaysStoppedAnimation<Color>(
                Color(0xFF7DD3EA),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '$completos de $total registros completos',
            style: TextStyle(
              fontFamily: 'Inter',
              color: Colors.white.withValues(alpha: 0.76),
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white.withValues(alpha: 0.16)),
      ),
      child: const Text(
        'Activa',
        style: TextStyle(
          fontFamily: 'Inter',
          color: Colors.white,
          fontSize: 11,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.title, required this.icon});

  final String title;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: const Color(0xFFEAF7FB),
            borderRadius: BorderRadius.circular(11),
          ),
          child: Icon(icon, size: 17, color: _cyan),
        ),
        const SizedBox(width: 9),
        Text(
          title,
          style: const TextStyle(
            fontFamily: 'Inter',
            color: _ink,
            fontWeight: FontWeight.w900,
            fontSize: 15,
          ),
        ),
      ],
    );
  }
}

class _PrimaryAction extends StatelessWidget {
  const _PrimaryAction({
    required this.onPressed,
    required this.icon,
    required this.label,
    required this.subtitle,
  });

  final VoidCallback onPressed;
  final IconData icon;
  final String label;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: _navy,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: _navy.withValues(alpha: 0.18),
            blurRadius: 22,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(18),
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(18),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 17),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.10),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(icon, color: Colors.white, size: 22),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        label,
                        style: const TextStyle(
                          fontFamily: 'Inter',
                          color: Colors.white,
                          fontWeight: FontWeight.w900,
                          fontSize: 15,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        subtitle,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontFamily: 'Inter',
                          color: Colors.white.withValues(alpha: 0.70),
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
                const Icon(Icons.arrow_forward_rounded, color: Colors.white),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SecondaryAction extends StatelessWidget {
  const _SecondaryAction({
    required this.onPressed,
    required this.icon,
    required this.label,
  });

  final VoidCallback onPressed;
  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      onPressed: onPressed,
      icon: Icon(icon),
      label: Text(label),
      style: OutlinedButton.styleFrom(
        backgroundColor: Colors.white,
        foregroundColor: _navy,
        side: const BorderSide(color: _line),
        minimumSize: const Size(48, 52),
      ),
    );
  }
}

class _LastRecord extends StatelessWidget {
  const _LastRecord({required this.persona});

  final Persona persona;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _line),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0F172A).withValues(alpha: 0.06),
            blurRadius: 22,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: const Color(0xFFEAF7FB),
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(Icons.person_outline_rounded, color: _cyan),
          ),
          const SizedBox(width: 13),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '#${persona.numero ?? '-'}  ${persona.nombreCompleto}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontFamily: 'Inter',
                    color: _ink,
                    fontWeight: FontWeight.w900,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  persona.dni.isEmpty ? 'DNI pendiente' : 'DNI ${persona.dni}',
                  style: const TextStyle(
                    fontFamily: 'Inter',
                    color: _muted,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
          const Icon(Icons.chevron_right_rounded, color: _muted),
        ],
      ),
    );
  }
}

class _HomeData {
  const _HomeData({required this.stats, this.last});

  final AppStats stats;
  final Persona? last;
}

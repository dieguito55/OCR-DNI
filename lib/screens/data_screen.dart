import 'package:flutter/material.dart';

import '../database/database_service.dart';
import '../models/persona.dart';
import '../models/sede.dart';
import '../services/excel_export_service.dart';
import '../widgets/persona_card.dart';
import '../widgets/sede_switcher_button.dart';
import 'review_screen.dart';

const _navy = Color(0xFF07142D);
const _bg = Color(0xFFF4F7FB);
const _ink = Color(0xFF111827);
const _muted = Color(0xFF64748B);
const _line = Color(0xFFE2E8F0);
const _cyan = Color(0xFF208EAD);

class DataScreen extends StatefulWidget {
  const DataScreen({super.key, required this.sede, required this.onChangeSede});

  final Sede sede;
  final VoidCallback onChangeSede;

  @override
  State<DataScreen> createState() => _DataScreenState();
}

class _DataScreenState extends State<DataScreen> {
  final _searchController = TextEditingController();
  late Future<List<Persona>> _future;
  bool _exporting = false;

  @override
  void initState() {
    super.initState();
    _future = _searchFuture();
    _searchController.addListener(_search);
  }

  @override
  void didUpdateWidget(covariant DataScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.sede.id != widget.sede.id) _search();
  }

  @override
  void dispose() {
    _searchController
      ..removeListener(_search)
      ..dispose();
    super.dispose();
  }

  Future<List<Persona>> _searchFuture() {
    return DatabaseService.instance.searchPersonas(
      _searchController.text,
      sedeId: widget.sede.id!,
    );
  }

  void _search() {
    setState(() => _future = _searchFuture());
  }

  Future<void> _open(Persona persona) async {
    final changed = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => ReviewScreen(persona: persona, sede: widget.sede),
      ),
    );
    if (changed == true) _search();
  }

  Future<void> _export() async {
    setState(() => _exporting = true);
    try {
      final personas = await DatabaseService.instance.allPersonas(
        sedeId: widget.sede.id!,
      );
      if (!mounted) return;
      if (personas.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No hay registros para exportar.')),
        );
        return;
      }
      final file = await ExcelExportService.instance.exportPadron(
        personas,
        sede: widget.sede,
      );
      await ExcelExportService.instance.share(file);
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('No se pudo exportar: $error')));
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: _bg,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _Header(sede: widget.sede, onChangeSede: widget.onChangeSede),
                const SizedBox(height: 16),
                _SearchField(controller: _searchController),
                const SizedBox(height: 12),
                _ExportButton(
                  exporting: _exporting,
                  onPressed: _exporting ? null : _export,
                ),
                const SizedBox(height: 12),
              ],
            ),
          ),
          Expanded(
            child: FutureBuilder<List<Persona>>(
              future: _future,
              builder: (context, snapshot) {
                final personas = snapshot.data ?? const <Persona>[];
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(
                    child: CircularProgressIndicator(color: _cyan),
                  );
                }
                if (personas.isEmpty) {
                  return _EmptyData(query: _searchController.text.trim());
                }
                return RefreshIndicator(
                  color: _cyan,
                  onRefresh: () async => _search(),
                  child: ListView.separated(
                    padding: const EdgeInsets.fromLTRB(20, 4, 20, 28),
                    itemCount: personas.length,
                    separatorBuilder: (context, index) =>
                        const SizedBox(height: 10),
                    itemBuilder: (context, index) {
                      final persona = personas[index];
                      return PersonaCard(
                        persona: persona,
                        onTap: () => _open(persona),
                      );
                    },
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.sede, required this.onChangeSede});

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
              Row(
                children: [
                  Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: const Color(0xFFEAF7FB),
                      borderRadius: BorderRadius.circular(13),
                    ),
                    child: const Icon(
                      Icons.folder_rounded,
                      color: _cyan,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    'Datos',
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.w900,
                      color: _ink,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 5),
              Text(
                'Registros de ${sede.displayName}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
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

class _SearchField extends StatelessWidget {
  const _SearchField({required this.controller});

  final TextEditingController controller;

  @override
  Widget build(BuildContext context) {
    return Container(
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
      child: TextField(
        controller: controller,
        style: const TextStyle(
          fontFamily: 'Inter',
          fontSize: 14,
          fontWeight: FontWeight.w700,
          color: _ink,
        ),
        decoration: InputDecoration(
          prefixIcon: const Icon(Icons.search_rounded, color: _cyan),
          suffixIcon: controller.text.isEmpty
              ? null
              : IconButton(
                  tooltip: 'Limpiar busqueda',
                  onPressed: controller.clear,
                  icon: const Icon(
                    Icons.close_rounded,
                    color: _muted,
                    size: 19,
                  ),
                ),
          hintText: 'Buscar por DNI, nombres o apellidos',
          hintStyle: const TextStyle(
            fontFamily: 'Inter',
            color: Color(0xFF94A3B8),
            fontWeight: FontWeight.w600,
          ),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(18),
            borderSide: BorderSide.none,
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(18),
            borderSide: const BorderSide(color: _cyan, width: 1.2),
          ),
          filled: true,
          fillColor: Colors.white,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 14,
          ),
        ),
      ),
    );
  }
}

class _ExportButton extends StatelessWidget {
  const _ExportButton({required this.exporting, required this.onPressed});

  final bool exporting;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      onPressed: onPressed,
      icon: exporting
          ? const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(strokeWidth: 2, color: _cyan),
            )
          : const Icon(Icons.table_chart_rounded),
      label: Text(exporting ? 'Exportando...' : 'Exportar esta sede'),
      style: OutlinedButton.styleFrom(
        backgroundColor: Colors.white,
        foregroundColor: _navy,
        side: const BorderSide(color: _line),
        minimumSize: const Size(48, 52),
      ),
    );
  }
}

class _EmptyData extends StatelessWidget {
  const _EmptyData({required this.query});

  final String query;

  @override
  Widget build(BuildContext context) {
    final searching = query.isNotEmpty;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: _line),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 66,
                height: 66,
                decoration: BoxDecoration(
                  color: const Color(0xFFEAF7FB),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Icon(
                  searching ? Icons.manage_search_rounded : Icons.inbox_rounded,
                  color: _cyan,
                  size: 30,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                searching ? 'Sin coincidencias' : 'Sin registros',
                style: const TextStyle(
                  fontFamily: 'Inter',
                  color: _ink,
                  fontWeight: FontWeight.w900,
                  fontSize: 16,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                searching
                    ? 'No se encontraron registros con ese criterio.'
                    : 'No hay registros guardados en esta sede.',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontFamily: 'Inter',
                  color: _muted,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

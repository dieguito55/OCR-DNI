import 'package:flutter/material.dart';

import '../core/theme/app_theme.dart';
import '../database/database_service.dart';
import '../models/sede.dart';

const _navy = Color(0xFF07142D);
const _navy2 = Color(0xFF172554);
const _bg = Color(0xFFF4F7FB);
const _card = Colors.white;
const _ink = Color(0xFF111827);
const _muted = Color(0xFF64748B);
const _line = Color(0xFFE2E8F0);
const _cyan = Color(0xFF208EAD);
const _purple = Color(0xFF6B3FA0);

class SedeSelectionScreen extends StatefulWidget {
  const SedeSelectionScreen({
    super.key,
    this.pickMode = false,
    this.currentSedeId,
    this.onSelected,
  });

  final bool pickMode;
  final int? currentSedeId;
  final void Function(BuildContext context, Sede sede)? onSelected;

  @override
  State<SedeSelectionScreen> createState() => _SedeSelectionScreenState();
}

class _SedeSelectionScreenState extends State<SedeSelectionScreen>
    with SingleTickerProviderStateMixin {
  final _queryController = TextEditingController();
  late final AnimationController _introController;
  List<Sede> _sedes = const [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _introController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    )..forward();
    _queryController.addListener(() => setState(() {}));
    _loadSedes();
  }

  @override
  void dispose() {
    _queryController.dispose();
    _introController.dispose();
    super.dispose();
  }

  List<Sede> get _visibleSedes {
    final query = _queryController.text.trim().toLowerCase();
    if (query.isEmpty) return _sedes;
    return _sedes.where((sede) {
      final haystack = [
        sede.nombre,
        sede.codigo,
        sede.descripcion,
        sede.displayName,
      ].join(' ').toLowerCase();
      return haystack.contains(query);
    }).toList();
  }

  Future<void> _loadSedes() async {
    setState(() => _loading = true);
    final sedes = await DatabaseService.instance.allSedes();
    if (!mounted) return;
    setState(() {
      _sedes = sedes;
      _loading = false;
    });
  }

  void _enter(Sede sede) {
    if (widget.pickMode) {
      Navigator.of(context).pop(sede);
      return;
    }
    widget.onSelected?.call(context, sede);
  }

  Future<void> _saveSede([Sede? sede]) async {
    try {
      final result = await Navigator.of(context).push<Sede>(
        MaterialPageRoute(builder: (_) => _SedeFormPage(sede: sede)),
      );
      if (result == null) return;
      final saved = await DatabaseService.instance.saveSede(result);
      if (!mounted) return;
      final fresh = await DatabaseService.instance.allSedes();
      if (!mounted) return;
      setState(() {
        _sedes = fresh;
        _loading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            sede == null ? 'Sede creada correctamente.' : 'Sede actualizada.',
          ),
        ),
      );
      if (sede == null) _enter(saved);
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('No se pudo guardar: $error')));
    }
  }

  Future<void> _deleteSede(Sede sede) async {
    if (sede.id == null) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Eliminar sede'),
        content: Text(
          'Se eliminara "${sede.displayName}" y todos sus registros locales. Esta accion no se puede deshacer.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancelar'),
          ),
          FilledButton.icon(
            onPressed: () => Navigator.of(context).pop(true),
            icon: const Icon(Icons.delete_outline_rounded),
            label: const Text('Eliminar'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await DatabaseService.instance.deleteSede(sede.id!);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Sede eliminada correctamente.')),
      );
      if (widget.pickMode && sede.id == widget.currentSedeId) {
        Navigator.of(context).pop();
        return;
      }
      final fresh = await DatabaseService.instance.allSedes();
      if (!mounted) return;
      setState(() {
        _sedes = fresh;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('No se pudo eliminar: $error')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final visibleSedes = _visibleSedes;
    final hasQuery = _queryController.text.trim().isNotEmpty;
    return Scaffold(
      backgroundColor: _bg,
      body: Stack(
        children: [
          const _HeaderBackground(),
          SafeArea(
            child: RefreshIndicator(
              color: _cyan,
              onRefresh: _loadSedes,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 18, 20, 28),
                children: [
                  _AnimatedEntry(
                    controller: _introController,
                    begin: 0,
                    child: _TopBar(
                      pickMode: widget.pickMode,
                      onBack: () => Navigator.of(context).pop(),
                      onCreate: () => _saveSede(),
                    ),
                  ),
                  const SizedBox(height: 18),
                  _AnimatedEntry(
                    controller: _introController,
                    begin: 0.10,
                    child: _InstitutionPanel(
                      count: _sedes.length,
                      pickMode: widget.pickMode,
                    ),
                  ),
                  const SizedBox(height: 14),
                  _AnimatedEntry(
                    controller: _introController,
                    begin: 0.18,
                    child: _SearchField(
                      controller: _queryController,
                      enabled: _sedes.isNotEmpty,
                    ),
                  ),
                  const SizedBox(height: 18),
                  _AnimatedEntry(
                    controller: _introController,
                    begin: 0.26,
                    child: _SectionHeader(
                      count: visibleSedes.length,
                      total: _sedes.length,
                      hasQuery: hasQuery,
                      onCreate: () => _saveSede(),
                    ),
                  ),
                  const SizedBox(height: 10),
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 240),
                    child: _loading
                        ? const _LoadingSedes(key: ValueKey('loading'))
                        : _sedes.isEmpty
                        ? _EmptySedes(
                            key: const ValueKey('empty'),
                            onCreate: () => _saveSede(),
                          )
                        : visibleSedes.isEmpty
                        ? _NoResults(
                            key: const ValueKey('no-results'),
                            onClear: _queryController.clear,
                          )
                        : Column(
                            key: ValueKey(
                              'list-${visibleSedes.length}-$hasQuery',
                            ),
                            children: [
                              for (
                                var index = 0;
                                index < visibleSedes.length;
                                index++
                              )
                                _AnimatedEntry(
                                  controller: _introController,
                                  begin: 0.30 + (index * 0.035).clamp(0, 0.24),
                                  child: Padding(
                                    padding: const EdgeInsets.only(bottom: 10),
                                    child: _SedeCard(
                                      sede: visibleSedes[index],
                                      selected:
                                          visibleSedes[index].id ==
                                          widget.currentSedeId,
                                      onEnter: () =>
                                          _enter(visibleSedes[index]),
                                      onEdit: () =>
                                          _saveSede(visibleSedes[index]),
                                      onDelete: () =>
                                          _deleteSede(visibleSedes[index]),
                                    ),
                                  ),
                                ),
                            ],
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

class _HeaderBackground extends StatelessWidget {
  const _HeaderBackground();

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _InstitutionalHeaderPainter(),
      child: const SizedBox.expand(),
    );
  }
}

class _AnimatedEntry extends StatelessWidget {
  const _AnimatedEntry({
    required this.controller,
    required this.begin,
    required this.child,
  });

  final AnimationController controller;
  final double begin;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final curved = CurvedAnimation(
      parent: controller,
      curve: Interval(begin.clamp(0.0, 0.88), 1, curve: Curves.easeOutCubic),
    );
    return FadeTransition(
      opacity: curved,
      child: SlideTransition(
        position: Tween<Offset>(
          begin: const Offset(0, 0.06),
          end: Offset.zero,
        ).animate(curved),
        child: child,
      ),
    );
  }
}

class _TopBar extends StatelessWidget {
  const _TopBar({
    required this.pickMode,
    required this.onBack,
    required this.onCreate,
  });

  final bool pickMode;
  final VoidCallback onBack;
  final VoidCallback onCreate;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (pickMode) ...[
          _HeaderIconButton(
            tooltip: 'Volver',
            icon: Icons.arrow_back_rounded,
            onPressed: onBack,
          ),
          const SizedBox(width: 12),
        ],
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (pickMode)
                const Text(
                  'Cambiar sede',
                  style: TextStyle(
                    fontFamily: 'Inter',
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                    fontSize: 25,
                  ),
                )
              else
                Image.asset(
                  'assets/images/logo.png',
                  height: 54,
                  alignment: Alignment.centerLeft,
                  fit: BoxFit.contain,
                  filterQuality: FilterQuality.high,
                ),
              const SizedBox(height: 8),
              Text(
                pickMode
                    ? 'Seleccione el sector operativo activo.'
                    : 'Seleccione la sede donde se guardaran los escaneos.',
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontFamily: 'Inter',
                  color: Colors.white.withValues(alpha: 0.78),
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  height: 1.35,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 12),
        _PrimaryIconButton(
          tooltip: 'Agregar sede',
          icon: Icons.add_rounded,
          onPressed: onCreate,
        ),
      ],
    );
  }
}

class _InstitutionPanel extends StatelessWidget {
  const _InstitutionPanel({required this.count, required this.pickMode});

  final int count;
  final bool pickMode;

  @override
  Widget build(BuildContext context) {
    return _Card(
      padding: const EdgeInsets.all(18),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 58,
                height: 58,
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: _line),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(7),
                  child: Image.asset(
                    'assets/images/xiomi_icon.png',
                    fit: BoxFit.contain,
                    filterQuality: FilterQuality.high,
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      pickMode ? 'Sede operativa' : 'Control de captura',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontFamily: 'Inter',
                        color: _ink,
                        fontWeight: FontWeight.w900,
                        fontSize: 20,
                        height: 1.1,
                      ),
                    ),
                    const SizedBox(height: 5),
                    const Text(
                      'Registro local, numeracion independiente y exportacion por sede.',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontFamily: 'Inter',
                        color: _muted,
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
                        height: 1.35,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              _MetricTile(
                icon: Icons.apartment_rounded,
                value: '$count',
                label: count == 1 ? 'sede' : 'sedes',
              ),
              const SizedBox(width: 10),
              const _MetricTile(
                icon: Icons.security_rounded,
                value: 'Local',
                label: 'datos',
              ),
              const SizedBox(width: 10),
              const _MetricTile(
                icon: Icons.table_chart_rounded,
                value: 'XLSX',
                label: 'salida',
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _MetricTile extends StatelessWidget {
  const _MetricTile({
    required this.icon,
    required this.value,
    required this.label,
  });

  final IconData icon;
  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        height: 64,
        padding: const EdgeInsets.symmetric(horizontal: 10),
        decoration: BoxDecoration(
          color: const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: _line),
        ),
        child: Row(
          children: [
            Icon(icon, color: _cyan, size: 18),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    value,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontFamily: 'Inter',
                      color: _ink,
                      fontSize: 14,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontFamily: 'Inter',
                      color: _muted,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SearchField extends StatelessWidget {
  const _SearchField({required this.controller, required this.enabled});

  final TextEditingController controller;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return _Card(
      padding: EdgeInsets.zero,
      child: TextField(
        controller: controller,
        enabled: enabled,
        textInputAction: TextInputAction.search,
        cursorColor: _cyan,
        style: const TextStyle(
          fontFamily: 'Inter',
          color: _ink,
          fontWeight: FontWeight.w700,
          fontSize: 14,
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
                    size: 19,
                    color: _muted,
                  ),
                ),
          hintText: 'Buscar sede, codigo o descripcion',
          hintStyle: const TextStyle(
            color: Color(0xFF94A3B8),
            fontWeight: FontWeight.w600,
          ),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(18),
            borderSide: BorderSide.none,
          ),
          enabledBorder: OutlineInputBorder(
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
            vertical: 15,
          ),
        ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({
    required this.count,
    required this.total,
    required this.hasQuery,
    required this.onCreate,
  });

  final int count;
  final int total;
  final bool hasQuery;
  final VoidCallback onCreate;

  @override
  Widget build(BuildContext context) {
    final label = hasQuery ? '$count de $total sedes' : '$total sedes';
    return Row(
      children: [
        Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(
            color: const Color(0xFFEAF7FB),
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Icon(Icons.location_on_rounded, size: 18, color: _cyan),
        ),
        const SizedBox(width: 10),
        const Expanded(
          child: Text(
            'Sedes disponibles',
            style: TextStyle(
              fontFamily: 'Inter',
              color: _ink,
              fontWeight: FontWeight.w900,
              fontSize: 16,
            ),
          ),
        ),
        Text(
          label,
          style: const TextStyle(
            fontFamily: 'Inter',
            color: _muted,
            fontWeight: FontWeight.w800,
            fontSize: 12,
          ),
        ),
        const SizedBox(width: 8),
        _SecondaryIconButton(
          tooltip: 'Nueva sede',
          icon: Icons.add_business_rounded,
          onPressed: onCreate,
        ),
      ],
    );
  }
}

class _LoadingSedes extends StatelessWidget {
  const _LoadingSedes({super.key});

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: 42),
      child: Center(child: CircularProgressIndicator(color: _cyan)),
    );
  }
}

class _EmptySedes extends StatelessWidget {
  const _EmptySedes({super.key, required this.onCreate});

  final VoidCallback onCreate;

  @override
  Widget build(BuildContext context) {
    return _Card(
      padding: const EdgeInsets.all(22),
      child: Column(
        children: [
          Container(
            width: 70,
            height: 70,
            decoration: BoxDecoration(
              color: const Color(0xFFEAF7FB),
              borderRadius: BorderRadius.circular(22),
              border: Border.all(color: const Color(0xFFD2EEF6)),
            ),
            child: const Icon(
              Icons.add_location_alt_rounded,
              size: 32,
              color: _cyan,
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'Crea tu primera sede',
            style: TextStyle(
              fontFamily: 'Inter',
              color: _ink,
              fontWeight: FontWeight.w900,
              fontSize: 18,
            ),
          ),
          const SizedBox(height: 7),
          const Text(
            'Antes de escanear, define el sector donde se guardaran los registros.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: 'Inter',
              color: _muted,
              fontSize: 13,
              fontWeight: FontWeight.w600,
              height: 1.45,
            ),
          ),
          const SizedBox(height: 20),
          _WideButton(
            label: 'Agregar sede',
            icon: Icons.add_rounded,
            onPressed: onCreate,
          ),
        ],
      ),
    );
  }
}

class _NoResults extends StatelessWidget {
  const _NoResults({super.key, required this.onClear});

  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    return _Card(
      padding: const EdgeInsets.all(22),
      child: Column(
        children: [
          const Icon(Icons.manage_search_rounded, color: _muted, size: 38),
          const SizedBox(height: 12),
          const Text(
            'Sin coincidencias',
            style: TextStyle(
              fontFamily: 'Inter',
              color: _ink,
              fontWeight: FontWeight.w900,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'Revisa el texto de busqueda o vuelve a ver todas las sedes.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: 'Inter',
              color: _muted,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 14),
          OutlinedButton.icon(
            onPressed: onClear,
            icon: const Icon(Icons.close_rounded),
            label: const Text('Limpiar busqueda'),
          ),
        ],
      ),
    );
  }
}

enum _SedeAction { edit, delete }

class _SedeCard extends StatelessWidget {
  const _SedeCard({
    required this.sede,
    required this.selected,
    required this.onEnter,
    required this.onEdit,
    required this.onDelete,
  });

  final Sede sede;
  final bool selected;
  final VoidCallback onEnter;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final code = sede.codigo.trim();
    return _Card(
      borderColor: selected ? _cyan : _line,
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(18),
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: onEnter,
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    color: selected ? _navy : const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Icon(
                    selected
                        ? Icons.check_circle_rounded
                        : Icons.location_city_rounded,
                    color: selected ? Colors.white : _cyan,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              sede.nombre.trim().isEmpty
                                  ? 'Sede sin nombre'
                                  : sede.nombre.trim(),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontFamily: 'Inter',
                                color: _ink,
                                fontWeight: FontWeight.w900,
                                fontSize: 15.5,
                              ),
                            ),
                          ),
                          if (selected) ...[
                            const SizedBox(width: 6),
                            const Icon(
                              Icons.verified_rounded,
                              color: _cyan,
                              size: 17,
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 7),
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: [
                          if (code.isNotEmpty)
                            _InfoChip(
                              icon: Icons.tag_rounded,
                              label: code,
                              strong: true,
                            ),
                          _InfoChip(
                            icon: Icons.folder_copy_rounded,
                            label: selected ? 'Activa' : 'Disponible',
                          ),
                        ],
                      ),
                      if (sede.descripcion.trim().isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Text(
                          sede.descripcion.trim(),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontFamily: 'Inter',
                            color: _muted,
                            fontSize: 12.5,
                            fontWeight: FontWeight.w600,
                            height: 1.35,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _PrimaryIconButton(
                      tooltip: 'Entrar a sede',
                      icon: Icons.arrow_forward_rounded,
                      onPressed: onEnter,
                      compact: true,
                    ),
                    const SizedBox(height: 5),
                    PopupMenuButton<_SedeAction>(
                      tooltip: 'Opciones',
                      color: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                      icon: const Icon(Icons.more_horiz_rounded, color: _muted),
                      onSelected: (action) {
                        switch (action) {
                          case _SedeAction.edit:
                            onEdit();
                          case _SedeAction.delete:
                            onDelete();
                        }
                      },
                      itemBuilder: (context) => const [
                        PopupMenuItem(
                          value: _SedeAction.edit,
                          child: _MenuItem(
                            icon: Icons.edit_location_alt_rounded,
                            label: 'Editar',
                          ),
                        ),
                        PopupMenuItem(
                          value: _SedeAction.delete,
                          child: _MenuItem(
                            icon: Icons.delete_outline_rounded,
                            label: 'Eliminar',
                            danger: true,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _MenuItem extends StatelessWidget {
  const _MenuItem({
    required this.icon,
    required this.label,
    this.danger = false,
  });

  final IconData icon;
  final String label;
  final bool danger;

  @override
  Widget build(BuildContext context) {
    final color = danger ? XiomiColors.error : _ink;
    return Row(
      children: [
        Icon(icon, size: 18, color: color),
        const SizedBox(width: 10),
        Text(
          label,
          style: TextStyle(
            fontFamily: 'Inter',
            color: color,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}

class _InfoChip extends StatelessWidget {
  const _InfoChip({
    required this.icon,
    required this.label,
    this.strong = false,
  });

  final IconData icon;
  final String label;
  final bool strong;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: strong ? const Color(0xFFEAF7FB) : const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(XiomiRadius.pill),
        border: Border.all(color: strong ? const Color(0xFFD2EEF6) : _line),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: strong ? _cyan : _muted),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontFamily: 'Inter',
              color: strong ? _cyan : _muted,
              fontSize: 11,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _Card extends StatelessWidget {
  const _Card({
    required this.child,
    this.padding = EdgeInsets.zero,
    this.borderColor = _line,
  });

  final Widget child;
  final EdgeInsets padding;
  final Color borderColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: _card,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: borderColor),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0F172A).withValues(alpha: 0.07),
            blurRadius: 24,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: child,
    );
  }
}

class _PrimaryIconButton extends StatelessWidget {
  const _PrimaryIconButton({
    required this.tooltip,
    required this.icon,
    required this.onPressed,
    this.compact = false,
  });

  final String tooltip;
  final IconData icon;
  final VoidCallback onPressed;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final size = compact ? 40.0 : 46.0;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: _navy,
        borderRadius: BorderRadius.circular(compact ? 12 : 15),
        boxShadow: [
          BoxShadow(
            color: _navy.withValues(alpha: 0.20),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: IconButton(
        tooltip: tooltip,
        onPressed: onPressed,
        padding: EdgeInsets.zero,
        icon: Icon(icon, color: Colors.white, size: compact ? 19 : 24),
      ),
    );
  }
}

class _SecondaryIconButton extends StatelessWidget {
  const _SecondaryIconButton({
    required this.tooltip,
    required this.icon,
    required this.onPressed,
  });

  final String tooltip;
  final IconData icon;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 38,
      height: 38,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(13),
        border: Border.all(color: _line),
      ),
      child: IconButton(
        tooltip: tooltip,
        onPressed: onPressed,
        padding: EdgeInsets.zero,
        icon: Icon(icon, color: _cyan, size: 18),
      ),
    );
  }
}

class _HeaderIconButton extends StatelessWidget {
  const _HeaderIconButton({
    required this.tooltip,
    required this.icon,
    required this.onPressed,
  });

  final String tooltip;
  final IconData icon;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: Colors.white.withValues(alpha: 0.18)),
      ),
      child: IconButton(
        tooltip: tooltip,
        onPressed: onPressed,
        padding: EdgeInsets.zero,
        icon: Icon(icon, color: Colors.white, size: 21),
      ),
    );
  }
}

class _WideButton extends StatelessWidget {
  const _WideButton({
    required this.label,
    required this.icon,
    required this.onPressed,
  });

  final String label;
  final IconData icon;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: FilledButton.icon(
        onPressed: onPressed,
        icon: Icon(icon),
        label: Text(label),
        style: FilledButton.styleFrom(
          backgroundColor: _navy,
          foregroundColor: Colors.white,
          minimumSize: const Size(48, 52),
        ),
      ),
    );
  }
}

class _SedeFormPage extends StatefulWidget {
  const _SedeFormPage({this.sede});

  final Sede? sede;

  @override
  State<_SedeFormPage> createState() => _SedeFormPageState();
}

class _SedeFormPageState extends State<_SedeFormPage> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nombre;
  late final TextEditingController _codigo;
  late final TextEditingController _descripcion;

  @override
  void initState() {
    super.initState();
    final sede = widget.sede;
    _nombre = TextEditingController(text: sede?.nombre ?? '');
    _codigo = TextEditingController(text: sede?.codigo ?? '');
    _descripcion = TextEditingController(text: sede?.descripcion ?? '');
  }

  @override
  void dispose() {
    _nombre.dispose();
    _codigo.dispose();
    _descripcion.dispose();
    super.dispose();
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    final base = widget.sede;
    Navigator.of(context).pop(
      Sede(
        id: base?.id,
        nombre: _nombre.text.trim(),
        codigo: _codigo.text.trim(),
        descripcion: _descripcion.text.trim(),
        fechaCreacion: base?.fechaCreacion ?? '',
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final editing = widget.sede != null;
    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        backgroundColor: _bg,
        foregroundColor: _ink,
        title: Text(editing ? 'Editar sede' : 'Nueva sede'),
      ),
      body: SafeArea(
        top: false,
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
            children: [
              _Card(
                padding: const EdgeInsets.all(18),
                child: Row(
                  children: [
                    Container(
                      width: 56,
                      height: 56,
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(color: _line),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(7),
                        child: Image.asset(
                          'assets/images/xiomi_icon.png',
                          fit: BoxFit.contain,
                        ),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            editing
                                ? 'Actualiza la sede'
                                : 'Configura el punto de trabajo',
                            style: const TextStyle(
                              fontFamily: 'Inter',
                              color: _ink,
                              fontWeight: FontWeight.w900,
                              fontSize: 18,
                            ),
                          ),
                          const SizedBox(height: 5),
                          const Text(
                            'Los escaneos, imagenes y exportaciones quedaran asociados a esta sede.',
                            style: TextStyle(
                              fontFamily: 'Inter',
                              color: _muted,
                              fontWeight: FontWeight.w600,
                              fontSize: 12.5,
                              height: 1.35,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              const Text(
                'Datos de sede',
                style: TextStyle(
                  fontFamily: 'Inter',
                  color: _ink,
                  fontWeight: FontWeight.w900,
                  fontSize: 16,
                ),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _nombre,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(
                  prefixIcon: Icon(Icons.location_city_rounded),
                  labelText: 'Nombre de sede o sector',
                ),
                validator: (value) {
                  if ((value ?? '').trim().isEmpty) {
                    return 'Escribe el nombre de la sede.';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _codigo,
                textCapitalization: TextCapitalization.characters,
                decoration: const InputDecoration(
                  prefixIcon: Icon(Icons.tag_rounded),
                  labelText: 'Codigo corto',
                  hintText: 'Ej. SECTOR-01',
                ),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _descripcion,
                maxLines: 3,
                decoration: const InputDecoration(
                  prefixIcon: Padding(
                    padding: EdgeInsets.only(bottom: 48),
                    child: Icon(Icons.notes_rounded),
                  ),
                  labelText: 'Descripcion',
                ),
              ),
              const SizedBox(height: 24),
              _WideButton(
                label: 'Guardar sede',
                icon: Icons.save_rounded,
                onPressed: _submit,
              ),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: () => Navigator.of(context).pop(),
                icon: const Icon(Icons.close_rounded),
                label: const Text('Cancelar'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _InstitutionalHeaderPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final header = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [_navy, _navy2],
      ).createShader(Rect.fromLTWH(0, 0, size.width, 260));
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, 250), header);

    final purple = Paint()..color = _purple.withValues(alpha: 0.18);
    canvas.drawCircle(
      Offset(-size.width * 0.12, 95),
      size.width * 0.55,
      purple,
    );

    final cyan = Paint()..color = _cyan.withValues(alpha: 0.16);
    canvas.drawCircle(Offset(size.width * 0.95, 88), size.width * 0.38, cyan);

    final lower = Paint()..color = _bg;
    final path = Path()
      ..moveTo(0, 210)
      ..quadraticBezierTo(size.width * 0.48, 255, size.width, 212)
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();
    canvas.drawPath(path, lower);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

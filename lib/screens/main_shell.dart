import 'package:flutter/material.dart';

import '../core/theme/app_theme.dart';
import '../database/database_service.dart';
import '../models/sede.dart';
import 'data_screen.dart';
import 'detection_screen.dart';
import 'home_screen.dart';
import 'sede_selection_screen.dart';

class MainShell extends StatefulWidget {
  const MainShell({super.key, required this.initialSede});

  final Sede initialSede;

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _index = 1;
  late Sede _sede;

  @override
  void initState() {
    super.initState();
    _sede = widget.initialSede;
  }

  Future<void> _changeSede() async {
    final selected = await Navigator.of(context).push<Sede>(
      MaterialPageRoute(
        builder: (_) =>
            SedeSelectionScreen(pickMode: true, currentSedeId: _sede.id),
      ),
    );
    if (!mounted) return;
    if (selected == null) {
      final activeSede = await DatabaseService.instance.findSede(_sede.id!);
      if (!mounted || activeSede != null) return;
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
      return;
    }
    setState(() => _sede = selected);
  }

  @override
  Widget build(BuildContext context) {
    final screens = [
      DetectionScreen(sede: _sede, onChangeSede: _changeSede),
      HomeScreen(
        sede: _sede,
        onChangeSede: _changeSede,
        onScanPressed: () => setState(() => _index = 0),
      ),
      DataScreen(sede: _sede, onChangeSede: _changeSede),
    ];

    return Scaffold(
      backgroundColor: const Color(0xFFF4F7FB),
      body: SafeArea(
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 250),
          switchInCurve: Curves.easeOut,
          switchOutCurve: Curves.easeIn,
          child: KeyedSubtree(key: ValueKey(_index), child: screens[_index]),
        ),
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          border: const Border(top: BorderSide(color: Color(0xFFE2E8F0))),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF0F172A).withValues(alpha: 0.07),
              blurRadius: 18,
              offset: const Offset(0, -8),
            ),
          ],
        ),
        child: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(8, 4, 8, 4),
            child: Row(
              children: [
                _NavItem(
                  index: 0,
                  currentIndex: _index,
                  icon: Icons.document_scanner_outlined,
                  activeIcon: Icons.document_scanner,
                  label: 'Deteccion',
                  onTap: () => setState(() => _index = 0),
                ),
                _NavItem(
                  index: 1,
                  currentIndex: _index,
                  icon: Icons.space_dashboard_outlined,
                  activeIcon: Icons.space_dashboard_rounded,
                  label: 'Inicio',
                  onTap: () => setState(() => _index = 1),
                ),
                _NavItem(
                  index: 2,
                  currentIndex: _index,
                  icon: Icons.folder_outlined,
                  activeIcon: Icons.folder_rounded,
                  label: 'Datos',
                  onTap: () => setState(() => _index = 2),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.index,
    required this.currentIndex,
    required this.icon,
    required this.activeIcon,
    required this.label,
    required this.onTap,
  });

  final int index;
  final int currentIndex;
  final IconData icon;
  final IconData activeIcon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final selected = index == currentIndex;
    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(XiomiRadius.md),
        splashColor: const Color(0xFF208EAD).withValues(alpha: 0.08),
        highlightColor: Colors.transparent,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOut,
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 220),
                curve: Curves.easeOut,
                padding: EdgeInsets.symmetric(
                  horizontal: selected ? 20 : 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: selected
                      ? const Color(0xFFEAF7FB)
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(XiomiRadius.pill),
                ),
                child: Icon(
                  selected ? activeIcon : icon,
                  size: 22,
                  color: selected
                      ? const Color(0xFF208EAD)
                      : const Color(0xFF94A3B8),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                label,
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 11,
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                  letterSpacing: 0.1,
                  color: selected
                      ? const Color(0xFF07142D)
                      : const Color(0xFF64748B),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

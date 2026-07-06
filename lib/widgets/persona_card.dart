import 'package:flutter/material.dart';

import '../core/theme/app_theme.dart';
import '../models/persona.dart';

const _cyan = Color(0xFF208EAD);
const _ink = Color(0xFF111827);
const _muted = Color(0xFF64748B);
const _line = Color(0xFFE2E8F0);

class PersonaCard extends StatelessWidget {
  const PersonaCard({super.key, required this.persona, required this.onTap});

  final Persona persona;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final complete = persona.estaCompleto;
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: complete ? XiomiColors.success.withValues(alpha: 0.30) : _line,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0F172A).withValues(alpha: 0.06),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(18),
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: onTap,
          splashColor: _cyan.withValues(alpha: 0.08),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: complete
                        ? XiomiColors.successLight
                        : const Color(0xFFEAF7FB),
                    borderRadius: BorderRadius.circular(15),
                  ),
                  child: Icon(
                    complete
                        ? Icons.check_circle_outline_rounded
                        : Icons.assignment_ind_rounded,
                    color: complete ? XiomiColors.success : _cyan,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 13),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        persona.nombreCompleto,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontFamily: 'Inter',
                          color: _ink,
                          fontWeight: FontWeight.w900,
                          fontSize: 14.5,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Wrap(
                        spacing: 7,
                        runSpacing: 6,
                        children: [
                          if (persona.numero != null)
                            _MiniChip(
                              text: '#${persona.numero}',
                              icon: Icons.format_list_numbered_rounded,
                              strong: true,
                            ),
                          _MiniChip(
                            text: persona.dni.isEmpty
                                ? 'DNI pendiente'
                                : 'DNI ${persona.dni}',
                            icon: Icons.badge_rounded,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                _StatusBadge(
                  text: complete ? 'Completo' : 'Pendiente',
                  complete: complete,
                ),
                const SizedBox(width: 4),
                const Icon(
                  Icons.chevron_right_rounded,
                  color: _muted,
                  size: 20,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _MiniChip extends StatelessWidget {
  const _MiniChip({
    required this.text,
    required this.icon,
    this.strong = false,
  });

  final String text;
  final IconData icon;
  final bool strong;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
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
            text,
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

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.text, required this.complete});

  final String text;
  final bool complete;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
      decoration: BoxDecoration(
        color: complete ? XiomiColors.successLight : XiomiColors.warningLight,
        borderRadius: BorderRadius.circular(XiomiRadius.pill),
        border: Border.all(
          color: complete
              ? XiomiColors.success.withValues(alpha: 0.25)
              : XiomiColors.warning.withValues(alpha: 0.25),
        ),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontFamily: 'Inter',
          color: complete ? XiomiColors.success : XiomiColors.warning,
          fontSize: 10.5,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';

import '../models/sede.dart';

const _navy = Color(0xFF07142D);
const _cyan = Color(0xFF208EAD);
const _ink = Color(0xFF111827);
const _line = Color(0xFFE2E8F0);

class SedeSwitcherButton extends StatelessWidget {
  const SedeSwitcherButton({
    super.key,
    required this.sede,
    required this.onPressed,
  });

  final Sede sede;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: 'Cambiar sede',
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onPressed,
          splashColor: _cyan.withValues(alpha: 0.08),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: _line),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF0F172A).withValues(alpha: 0.06),
                  blurRadius: 16,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 27,
                  height: 27,
                  decoration: BoxDecoration(
                    color: const Color(0xFFEAF7FB),
                    borderRadius: BorderRadius.circular(9),
                  ),
                  child: const Icon(
                    Icons.location_city_rounded,
                    size: 15,
                    color: _cyan,
                  ),
                ),
                const SizedBox(width: 8),
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 118),
                  child: Text(
                    sede.displayName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontFamily: 'Inter',
                      color: _ink,
                      fontWeight: FontWeight.w800,
                      fontSize: 12.5,
                    ),
                  ),
                ),
                const SizedBox(width: 5),
                const Icon(
                  Icons.keyboard_arrow_down_rounded,
                  size: 18,
                  color: _navy,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

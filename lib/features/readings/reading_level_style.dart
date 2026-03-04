import 'package:flutter/material.dart';

class ReadingLevelStyle {
  const ReadingLevelStyle._();

  static Color background(BuildContext context, String? levelRaw) {
    final Color base = _base(levelRaw);
    return Color.alphaBlend(
      base.withValues(alpha: 0.18),
      Theme.of(context).colorScheme.surface,
    );
  }

  static Color foreground(String? levelRaw) {
    return _base(levelRaw);
  }

  static Color _base(String? levelRaw) {
    final String level = (levelRaw ?? '').trim().toUpperCase();
    switch (level) {
      case 'A1':
        return const Color(0xFF2E7D32);
      case 'A2':
        return const Color(0xFF00695C);
      case 'B1':
        return const Color(0xFF1565C0);
      case 'B2':
        return const Color(0xFF283593);
      case 'C1':
        return const Color(0xFFEF6C00);
      case 'C2':
        return const Color(0xFFC62828);
      default:
        return const Color(0xFF546E7A);
    }
  }
}

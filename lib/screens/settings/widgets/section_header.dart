import 'package:flutter/material.dart';

/// iOS-style section header with a tinted icon + small all-caps title.
/// Used at the top of each grouped Card in the settings page so readers can
/// scan section boundaries without relying on whitespace alone.
class SectionHeader extends StatelessWidget {
  final IconData icon;
  final String title;

  const SectionHeader({
    super.key,
    required this.icon,
    required this.title,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 0, 4, 10),
      child: Row(
        children: [
          Icon(icon, size: 16, color: cs.primary),
          const SizedBox(width: 8),
          Text(
            title.toUpperCase(),
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.2,
              color: cs.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

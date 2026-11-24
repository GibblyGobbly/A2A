// SPDX-License-Identifier: GPL-3.0-or-later

import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import 'brutal.dart';

/// A flat outlined button with an icon above a short label, for rows of
/// related actions such as rotate left and rotate right.
class IconLabelButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback? onPressed;
  final bool selected;

  const IconLabelButton({
    super.key,
    required this.icon,
    required this.label,
    required this.onPressed,
    this.selected = false,
  });

  @override
  Widget build(BuildContext context) {
    final foreground = selected ? AppTheme.surface : AppTheme.ink;
    return Pressable(
      onTap: onPressed,
      color: selected ? AppTheme.ink : null,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
      semanticLabel: label,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 24, color: foreground),
          const SizedBox(height: 4),
          Text(
            label.toUpperCase(),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: AppTheme.label.copyWith(
              fontSize: 11,
              letterSpacing: 0.6,
              color: foreground,
            ),
          ),
        ],
      ),
    );
  }
}

// SPDX-License-Identifier: GPL-3.0-or-later

import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// A label on the left and its value on the right, for detail lists.
class InfoRow extends StatelessWidget {
  final String label;
  final String value;

  const InfoRow({super.key, required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 112,
            child: Text(label.toUpperCase(), style: AppTheme.label),
          ),
          const SizedBox(width: 12),
          Expanded(child: SelectableText(value, style: AppTheme.body)),
        ],
      ),
    );
  }
}

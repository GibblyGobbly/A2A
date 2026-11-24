// SPDX-License-Identifier: GPL-3.0-or-later

import 'package:flutter/material.dart';
import '../../models/tool_info.dart';
import '../../theme/app_theme.dart';
import '../../widgets/brutal.dart';
import 'tool_launcher.dart';

/// One tool in the workspace list: icon, name, one line on what it does.
/// When [blockedReason] is set the tile is disabled and shows the reason.
class ToolTile extends StatelessWidget {
  final ToolInfo tool;
  final String? blockedReason;
  final VoidCallback onTap;

  const ToolTile({
    super.key,
    required this.tool,
    required this.onTap,
    this.blockedReason,
  });

  @override
  Widget build(BuildContext context) {
    final enabled = blockedReason == null;
    return Pressable(
      onTap: enabled ? onTap : null,
      padding: const EdgeInsets.all(12),
      semanticLabel: tool.label,
      child: Row(
        children: [
          CategoryTile(
            color: enabled ? AppTheme.muted : AppTheme.paper,
            icon: ToolLauncher.icon(tool.id),
            size: 44,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  tool.label,
                  style: AppTheme.body.copyWith(fontWeight: FontWeight.w700),
                ),
                Text(
                  blockedReason ?? tool.description,
                  style: AppTheme.caption,
                ),
              ],
            ),
          ),
          if (enabled) Icon(Icons.chevron_right, color: AppTheme.ink),
        ],
      ),
    );
  }
}

// SPDX-License-Identifier: GPL-3.0-or-later

import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import 'brutal.dart';

/// Layout shared by every tool screen: a back button and title at the top,
/// scrolling content, and one primary action pinned above the system bar.
class ToolScaffold extends StatelessWidget {
  final String title;
  final String? subtitle;
  final List<Widget> children;

  /// Primary action label. No button is shown when null.
  final String? actionLabel;
  final IconData actionIcon;
  final VoidCallback? onAction;

  /// When false the content does not scroll, for screens whose content fills
  /// the space itself, such as an image with a crop frame.
  final bool scrollable;

  const ToolScaffold({
    super.key,
    required this.title,
    required this.children,
    this.subtitle,
    this.actionLabel,
    this.actionIcon = Icons.check,
    this.onAction,
    this.scrollable = true,
  });

  @override
  Widget build(BuildContext context) {
    AppTheme.watch(context);
    const padding = EdgeInsets.fromLTRB(16, 8, 16, 16);
    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _header(context),
            Expanded(
              child: scrollable
                  ? ListView(padding: padding, children: children)
                  : Padding(
                      padding: padding,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: children,
                      ),
                    ),
            ),
            if (actionLabel != null)
              DecoratedBox(
                decoration: BoxDecoration(
                  color: AppTheme.paper,
                  border: Border(
                    top: BorderSide(
                      color: AppTheme.ink,
                      width: AppTheme.stroke,
                    ),
                  ),
                ),
                child: SafeArea(
                  top: false,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                    child: BrutalButton(
                      label: actionLabel!,
                      icon: actionIcon,
                      onPressed: onAction,
                    ),
                  ),
                ),
              )
            else
              SizedBox(height: MediaQuery.paddingOf(context).bottom),
          ],
        ),
      ),
    );
  }

  Widget _header(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      child: Row(
        children: [
          BrutalIconButton(
            icon: Icons.arrow_back,
            tooltip: 'Back',
            onPressed: () => Navigator.of(context).maybePop(),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title.toUpperCase(),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTheme.title,
                ),
                if (subtitle != null)
                  Text(
                    subtitle!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTheme.caption,
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

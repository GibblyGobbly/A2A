// SPDX-License-Identifier: GPL-3.0-or-later

import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import 'brutal.dart';

class BottomTab {
  final String label;
  final IconData icon;

  const BottomTab(this.label, this.icon);
}

/// Bottom navigation bar: the selected tab's icon sits in a yellow pill.
class BottomTabs extends StatelessWidget {
  final List<BottomTab> tabs;
  final int index;
  final ValueChanged<int> onSelected;

  const BottomTabs({
    super.key,
    required this.tabs,
    required this.index,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    final duration = motion(context, 160);
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.surface,
        border: Border(
          top: BorderSide(color: AppTheme.ink, width: AppTheme.stroke),
        ),
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 64,
          child: Row(
            children: [
              for (var i = 0; i < tabs.length; i++)
                Expanded(
                  child: Semantics(
                    selected: i == index,
                    button: true,
                    label: tabs[i].label,
                    child: InkWell(
                      onTap: () => onSelected(i),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          AnimatedContainer(
                            duration: duration,
                            curve: Curves.easeOut,
                            width: 56,
                            height: 32,
                            decoration: BoxDecoration(
                              color: i == index
                                  ? AppTheme.accent
                                  : AppTheme.surface,
                              borderRadius: const BorderRadius.all(
                                Radius.circular(16),
                              ),
                              border: Border.all(
                                color: i == index
                                    ? AppTheme.ink
                                    : AppTheme.surface,
                                width: AppTheme.stroke,
                              ),
                            ),
                            child: Icon(
                              tabs[i].icon,
                              color: i == index
                                  ? AppTheme.onAccent
                                  : AppTheme.ink,
                              size: 20,
                            ),
                          ),
                          const SizedBox(height: 4),
                          ExcludeSemantics(
                            child: Text(
                              tabs[i].label,
                              maxLines: 1,
                              style: AppTheme.label.copyWith(
                                fontSize: 11,
                                letterSpacing: 0.6,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

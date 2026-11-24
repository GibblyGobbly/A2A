// SPDX-License-Identifier: GPL-3.0-or-later

import 'package:flutter/material.dart';
import '../../services/file_pick_service.dart';
import '../../services/share_intake_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/bottom_tabs.dart';
import '../../widgets/brutal.dart';
import '../history_screen.dart';
import '../workspace/workspace_screen.dart';
import 'start_page.dart';

/// Top level: the start page and the saved files, switched by a bottom bar.
/// Files shared from other apps open straight in the workspace.
class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  static const _tabs = [
    BottomTab('HOME', Icons.home_outlined),
    BottomTab('FILES', Icons.folder_outlined),
  ];

  int _index = 0;

  @override
  void initState() {
    super.initState();
    ShareIntakeService.pending.addListener(_openShared);
    WidgetsBinding.instance.addPostFrameCallback((_) => _openShared());
  }

  @override
  void dispose() {
    ShareIntakeService.pending.removeListener(_openShared);
    super.dispose();
  }

  void _openShared() {
    if (!mounted) return;
    final shared = ShareIntakeService.takeAll();
    if (shared.isEmpty) return;
    final outcome = FilePickService.sortByCategory(shared, null);
    if (outcome.skipped > 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Skipped ${outcome.skipped} of the shared files.'),
        ),
      );
    }
    if (outcome.files.isEmpty) return;
    setState(() => _index = 0);
    WorkspaceScreen.open(context, outcome.files);
  }

  void _select(int i) {
    if (i == _index) return;
    Haptics.select();
    setState(() => _index = i);
  }

  @override
  Widget build(BuildContext context) {
    AppTheme.watch(context);
    return PopScope(
      // Back returns to the start page before leaving the app.
      canPop: _index == 0,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _select(0);
      },
      child: Scaffold(
        body: SafeArea(
          bottom: false,
          child: IndexedStack(
            index: _index,
            children: [
              StartPage(onSeeAllFiles: () => _select(1)),
              const HistoryScreen(),
            ],
          ),
        ),
        bottomNavigationBar: BottomTabs(
          tabs: _tabs,
          index: _index,
          onSelected: _select,
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import '../models/file_item.dart';
import '../services/share_intake_service.dart';
import '../theme/app_theme.dart';
import '../widgets/brutal.dart';
import 'history_screen.dart';
import 'tool_screen.dart';

class _Page {
  final String label;
  final IconData icon;
  final FileCategory? category;

  const _Page(this.label, this.icon, this.category);
}

/// Swipeable pages, one per tool plus the file history, with a bottom bar.
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  static const _pages = [
    _Page('IMAGE', Icons.image_outlined, FileCategory.image),
    _Page('VIDEO', Icons.movie_outlined, FileCategory.video),
    _Page('AUDIO', Icons.graphic_eq, FileCategory.audio),
    _Page('DOCS', Icons.description_outlined, FileCategory.document),
    _Page('FILES', Icons.history, null),
  ];

  final PageController _controller = PageController();
  int _index = 0;

  @override
  void initState() {
    super.initState();
    ShareIntakeService.pending.addListener(_jumpToShared);
    WidgetsBinding.instance.addPostFrameCallback((_) => _jumpToShared());
  }

  @override
  void dispose() {
    ShareIntakeService.pending.removeListener(_jumpToShared);
    _controller.dispose();
    super.dispose();
  }

  /// Shows the tool that matches files shared from another app.
  void _jumpToShared() {
    final shared = ShareIntakeService.pending.value;
    if (shared.isEmpty) return;
    final page = _pages.indexWhere((p) => p.category == shared.first.category);
    if (page >= 0) _go(page, animate: false);
  }

  void _go(int index, {bool animate = true}) {
    setState(() => _index = index);
    if (!_controller.hasClients) return;
    final duration = motion(context, 280);
    if (animate && duration > Duration.zero) {
      _controller.animateToPage(
        index,
        duration: duration,
        curve: Curves.easeOutCubic,
      );
    } else {
      _controller.jumpToPage(index);
    }
  }

  @override
  Widget build(BuildContext context) {
    AppTheme.watch(context);
    return PopScope(
      // Back returns to the first page before leaving the app.
      canPop: _index == 0,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _go(0);
      },
      child: Scaffold(
        body: SafeArea(
          bottom: false,
          child: PageView(
            controller: _controller,
            onPageChanged: (i) {
              Haptics.select();
              setState(() => _index = i);
            },
            children: [
              for (final page in _pages)
                page.category == null
                    ? const HistoryScreen()
                    : ToolScreen(category: page.category!),
            ],
          ),
        ),
        bottomNavigationBar: _bottomBar(),
      ),
    );
  }

  Widget _bottomBar() {
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
              for (var i = 0; i < _pages.length; i++)
                Expanded(
                  child: Semantics(
                    selected: i == _index,
                    button: true,
                    label: _pages[i].label,
                    child: InkWell(
                      onTap: () {
                        Haptics.select();
                        _go(i);
                      },
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          AnimatedContainer(
                            duration: duration,
                            curve: Curves.easeOut,
                            width: 52,
                            height: 30,
                            decoration: BoxDecoration(
                              color: i == _index
                                  ? AppTheme.accent
                                  : AppTheme.surface,
                              borderRadius: const BorderRadius.all(
                                Radius.circular(15),
                              ),
                              border: Border.all(
                                color: i == _index
                                    ? AppTheme.ink
                                    : AppTheme.surface,
                                width: AppTheme.stroke,
                              ),
                            ),
                            child: Icon(
                              _pages[i].icon,
                              color: i == _index
                                  ? AppTheme.onAccent
                                  : AppTheme.ink,
                              size: 20,
                            ),
                          ),
                          const SizedBox(height: 4),
                          ExcludeSemantics(
                            child: Text(
                              _pages[i].label,
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

import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import 'document_studio_screen.dart';
import 'history_screen.dart';
import 'image_studio_screen.dart';
import 'media_studio_screen.dart';
import 'universal_convert_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _currentIndex = 0;
  late final PageController _pageController;

  final List<Widget> _screens = const [
    ImageStudioScreen(),
    MediaStudioScreen(),
    UniversalConvertScreen(),
    DocumentStudioScreen(),
    HistoryScreen(),
  ];

  @override
  void initState() {
    super.initState();
    _pageController = PageController(initialPage: _currentIndex);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _onPageChanged(int index) {
    setState(() => _currentIndex = index);
  }

  void _onBottomNavTapped(int index) {
    setState(() => _currentIndex = index);
    _pageController.animateToPage(
      index,
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeInOut,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: PageView(
        controller: _pageController,
        onPageChanged: _onPageChanged,
        physics: const BouncingScrollPhysics(),
        children: _screens,
      ),
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          color: AppTheme.surfaceWhite,
          border: Border(top: BorderSide(color: Color(0xFFE2E8F0))),
        ),
        child: NavigationBar(
          selectedIndex: _currentIndex,
          onDestinationSelected: _onBottomNavTapped,
          backgroundColor: AppTheme.surfaceWhite,
          indicatorColor: AppTheme.lightBlue,
          elevation: 0,
          destinations: const [
            NavigationDestination(
              icon: Icon(Icons.image_outlined, color: AppTheme.textMuted),
              selectedIcon: Icon(Icons.image, color: AppTheme.primaryBlue),
              label: 'Images',
            ),
            NavigationDestination(
              icon: Icon(Icons.videocam_outlined, color: AppTheme.textMuted),
              selectedIcon: Icon(Icons.videocam, color: AppTheme.primaryBlue),
              label: 'Media',
            ),
            NavigationDestination(
              icon: Icon(Icons.swap_horiz, color: AppTheme.textMuted),
              selectedIcon: Icon(Icons.swap_horiz, color: AppTheme.primaryBlue),
              label: 'Universal',
            ),
            NavigationDestination(
              icon: Icon(Icons.description_outlined, color: AppTheme.textMuted),
              selectedIcon: Icon(Icons.description, color: AppTheme.primaryBlue),
              label: 'Document',
            ),
            NavigationDestination(
              icon: Icon(Icons.history_outlined, color: AppTheme.textMuted),
              selectedIcon: Icon(Icons.history, color: AppTheme.primaryBlue),
              label: 'History',
            ),
          ],
        ),
      ),
    );
  }
}

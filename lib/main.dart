import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'services/history_service.dart';
import 'theme/app_theme.dart';
import 'views/home_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await HistoryService.init();

  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
      systemNavigationBarColor: AppTheme.surfaceWhite,
      systemNavigationBarIconBrightness: Brightness.dark,
    ),
  );

  runApp(const OmniConvertApp());
}

class OmniConvertApp extends StatelessWidget {
  const OmniConvertApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'A2A',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      home: const HomeScreen(),
    );
  }
}

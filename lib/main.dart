import 'package:flutter/material.dart';
import 'services/theme_service.dart';
import 'services/app_language.dart';
import 'screens/auth_screen.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([themeService, appLang]),
      builder: (context, child) {
        return MaterialApp(
          title: 'WorkSpot',
          debugShowCheckedModeBanner: false,
          
          // DİL PARÇASY (Tətbiqiň dilini göni dolandyrýar)
          locale: Locale(appLang.currentLanguage),
          
          themeMode: themeService.value,
          theme: ThemeData(
            brightness: Brightness.light,
            primaryColor: const Color(0xFF2563EB),
            scaffoldBackgroundColor: const Color(0xFFF8FAFC),
          ),
          darkTheme: ThemeData(
            brightness: Brightness.dark,
            primaryColor: const Color(0xFF2563EB),
            scaffoldBackgroundColor: const Color(0xFF0F172A),
          ),
          home: const AuthScreen(),
        );
      },
    );
  }
}
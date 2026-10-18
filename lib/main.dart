import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_web_plugins/url_strategy.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:google_fonts/google_fonts.dart';
import 'services/theme_service.dart';
import 'services/app_language.dart';
import 'services/presence_service.dart';
import 'screens/auth_screen.dart';
import 'screens/admin_dashboard_screen.dart';
import 'screens/admin_login_screen.dart';
import 'widgets/legal_footer.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  if (kIsWeb) {
    usePathUrlStrategy();
  }
  if (!kIsWeb) {
    await MobileAds.instance.initialize();
  }
  await Supabase.initialize(
    url: 'https://erlguuogmrgyhuhbecny.supabase.co',
    publishableKey: 'sb_publishable_r7vI6rcDqvnn5B8W259y9g_xGNjtcTQ',
    authOptions: const FlutterAuthClientOptions(
      authFlowType: AuthFlowType.pkce,
      detectSessionInUri: true,
    ),
  );

  await appLang.load();
  runApp(const MyApp());
  try {
    PresenceService.instance.start();
  } catch (error) {
    debugPrint('Presence unavailable: $error');
  }
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
            textTheme: GoogleFonts.interTextTheme(),
          ),
          darkTheme: ThemeData(
            brightness: Brightness.dark,
            primaryColor: const Color(0xFF2563EB),
            scaffoldBackgroundColor: const Color(0xFF0F172A),
            textTheme: GoogleFonts.interTextTheme(ThemeData.dark().textTheme),
          ),
          home: const AuthScreen(),
          onGenerateRoute: (settings) {
            switch (settings.name) {
              case '/admin':
                final arguments = settings.arguments;
                final hasPasscodeOverride =
                    arguments is Map && arguments['passcodeOverride'] == true;
                return MaterialPageRoute(
                  settings: settings,
                  builder: (_) => hasPasscodeOverride
                      ? const AdminDashboardScreen(allowPasscodeOverride: true)
                      : const AdminLoginScreen(),
                );
              case '/admin-login':
                return MaterialPageRoute(
                  settings: settings,
                  builder: (_) => const AdminLoginScreen(),
                );
              case '/about':
                return _legalRoute(settings, LegalPageType.about);
              case '/contact':
                return _legalRoute(settings, LegalPageType.contact);
              case '/privacy':
                return _legalRoute(settings, LegalPageType.privacy);
              case '/terms':
                return _legalRoute(settings, LegalPageType.terms);
              default:
                return null;
            }
          },
        );
      },
    );
  }

  static Route<dynamic> _legalRoute(RouteSettings settings, LegalPageType type) {
    return MaterialPageRoute(
      settings: settings,
      builder: (_) => LegalPage(type: type),
    );
  }
}

import 'package:flutter/foundation.dart' show kDebugMode, kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_web_plugins/url_strategy.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:google_fonts/google_fonts.dart';
import 'services/theme_service.dart';
import 'services/app_language.dart';
import 'services/presence_service.dart';
import 'screens/home_map_screen.dart';
import 'widgets/legal_footer.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  if (kIsWeb) {
    usePathUrlStrategy();
  }

  Object? startupError;
  if (!kIsWeb) {
    try {
      await MobileAds.instance.initialize();
    } catch (error, stackTrace) {
      // Ads are non-critical: log and continue without them.
      debugPrint('MobileAds initialization failed: $error');
      debugPrintStack(stackTrace: stackTrace);
    }
  }
  try {
    await Supabase.initialize(
      url: 'https://erlguuogmrgyhuhbecny.supabase.co',
      publishableKey: 'sb_publishable_r7vI6rcDqvnn5B8W259y9g_xGNjtcTQ',
      authOptions: const FlutterAuthClientOptions(
        authFlowType: AuthFlowType.pkce,
        detectSessionInUri: true,
      ),
    );
  } catch (error, stackTrace) {
    debugPrint('Supabase initialization failed: $error');
    debugPrintStack(stackTrace: stackTrace);
    startupError = error;
  }

  await appLang.load();
  if (startupError != null) {
    runApp(StartupErrorApp(error: startupError));
    return;
  }
  runApp(const MyApp());
  try {
    PresenceService.instance.start();
  } catch (error) {
    debugPrint('Presence unavailable: $error');
  }
}

/// Shown when a critical service failed to initialize, so the app renders an
/// error screen instead of crashing before the first frame.
class StartupErrorApp extends StatelessWidget {
  const StartupErrorApp({super.key, required this.error});

  final Object? error;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'WorkSpot',
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.cloud_off, size: 64, color: Colors.grey),
                const SizedBox(height: 16),
                const Text(
                  'Could not connect to the service.\nPlease check your internet connection and try again.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 16),
                ),
                if (kDebugMode && error != null) ...[
                  const SizedBox(height: 16),
                  Text(
                    '$error',
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
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
          // Guests and logged-in users both land on the map (Guideline 5.1.1(v)).
          home: const HomeMapScreen(),
          onGenerateRoute: (settings) {
            switch (settings.name) {
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

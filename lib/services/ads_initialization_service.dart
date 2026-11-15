import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

class AdsInitializationService {
  AdsInitializationService._();

  static Future<bool>? _initialization;

  static Future<bool> initialize() => _initialization ??= _initialize();

  static Future<bool> _initialize() async {
    await WidgetsBinding.instance.endOfFrame;
    try {
      await MobileAds.instance.initialize();
      return true;
    } catch (error, stackTrace) {
      debugPrint('MobileAds initialization failed: $error');
      debugPrintStack(stackTrace: stackTrace);
      return false;
    }
  }
}

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../screens/admin_dashboard_screen.dart';
import '../services/admin_auth_service.dart';

enum AdminAccess { disabled, pinRequired, allowedWithoutPin }

/// Single entry point for every admin entrance (long press on the login screen
/// and the Admin button in the profile). The PIN only gates the UI: it is
/// compiled into the binary via --dart-define, so real protection is the
/// `app_metadata.role = 'admin'` claim enforced by the database (is_admin()).
class AdminGate {
  static const String _pin = String.fromEnvironment('WORKSPOT_ADMIN_PIN');
  static const int minPinLength = 8;
  static const int _maxAttempts = 5;
  static const Duration _lockDuration = Duration(seconds: 30);

  static int _failedAttempts = 0;
  static DateTime? _lockedUntil;

  static bool get isConfigured =>
      _pin.length >= minPinLength && RegExp(r'^\d+$').hasMatch(_pin);

  /// Without a configured PIN only web builds can be opened, and only by a
  /// user whose token carries the admin claim; mobile stays disabled.
  @visibleForTesting
  static Future<AdminAccess> decide({
    required bool isWeb,
    required bool pinConfigured,
    required Future<bool> Function() isAdmin,
  }) async {
    if (pinConfigured) return AdminAccess.pinRequired;
    if (isWeb && await isAdmin()) return AdminAccess.allowedWithoutPin;
    return AdminAccess.disabled;
  }

  static Future<void> open(BuildContext context) async {
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);

    void notify(String message) {
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(message)));
    }

    final access = await decide(
      isWeb: kIsWeb,
      pinConfigured: isConfigured,
      isAdmin: () => AdminAuthService.isAdminUser(
        Supabase.instance.client,
        refresh: true,
      ),
    );
    if (access == AdminAccess.disabled) {
      notify('Admin girişi söndürülüb.');
      return;
    }
    if (access == AdminAccess.allowedWithoutPin) {
      await navigator.push(
        MaterialPageRoute(builder: (_) => const AdminDashboardScreen()),
      );
      return;
    }

    final lockedUntil = _lockedUntil;
    if (lockedUntil != null && DateTime.now().isBefore(lockedUntil)) {
      final seconds = lockedUntil.difference(DateTime.now()).inSeconds + 1;
      notify('Çox sayda səhv cəhd. $seconds saniyə sonra yenidən cəhd edin.');
      return;
    }

    if (!context.mounted) return;
    final entered = await _askPin(context);
    if (entered == null) return;

    if (entered != _pin) {
      _failedAttempts++;
      if (_failedAttempts >= _maxAttempts) {
        _failedAttempts = 0;
        _lockedUntil = DateTime.now().add(_lockDuration);
        notify('Çox sayda səhv cəhd. ${_lockDuration.inSeconds} saniyə sonra yenidən cəhd edin.');
      } else {
        notify('PIN yanlışdır.');
      }
      return;
    }
    _failedAttempts = 0;
    _lockedUntil = null;

    final client = Supabase.instance.client;
    if (client.auth.currentSession == null) {
      notify('Əvvəl telefonla daxil olun.');
      return;
    }
    if (!await AdminAuthService.isAdminUser(client, refresh: true)) {
      notify('Bu hesabın admin icazəsi yoxdur. Admin hesabı ilə daxil olun.');
      return;
    }

    await navigator.push(
      MaterialPageRoute(builder: (_) => const AdminDashboardScreen()),
    );
  }

  static Future<String?> _askPin(BuildContext context) {
    final controller = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (dialogContext) {
        var obscure = true;
        return StatefulBuilder(
          builder: (context, setState) => AlertDialog(
            backgroundColor: const Color(0xFF111827),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            title: const Text(
              'Admin',
              style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800),
            ),
            content: TextField(
              controller: controller,
              autofocus: true,
              keyboardType: TextInputType.number,
              obscureText: obscure,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                labelText: 'PIN',
                labelStyle: const TextStyle(color: Colors.white70),
                filled: true,
                fillColor: const Color(0xFF0F172A),
                suffixIcon: IconButton(
                  onPressed: () => setState(() => obscure = !obscure),
                  icon: Icon(
                    obscure ? Icons.visibility_off_rounded : Icons.visibility_rounded,
                    color: Colors.white70,
                  ),
                ),
              ),
              onSubmitted: (value) => Navigator.of(dialogContext).pop(value.trim()),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(),
                child: const Text('Ləğv et'),
              ),
              ElevatedButton(
                onPressed: () =>
                    Navigator.of(dialogContext).pop(controller.text.trim()),
                child: const Text('Daxil ol'),
              ),
            ],
          ),
        );
      },
    ).whenComplete(controller.dispose);
  }
}

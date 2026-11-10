import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../screens/admin_dashboard_screen.dart';
import '../services/admin_auth_service.dart';

enum AdminPinResult { ok, wrong, locked, notAdmin, error }

/// Single entry point for every admin entrance (long press on the login screen
/// and the Admin button in the profile). Access needs the signed
/// `app_metadata.role = 'admin'` claim AND a PIN verified by the database
/// (verify_admin_pin). The PIN is never part of any client bundle.
class AdminGate {
  /// Admin claim first (the PIN is never requested or sent for other users),
  /// then the server-side PIN check. [verifyPin] throws [PostgrestException]
  /// with code P0423 when the server has locked the PIN out.
  @visibleForTesting
  static Future<AdminPinResult> verify({
    required Future<bool> Function() isAdmin,
    required Future<bool> Function(String pin) verifyPin,
    required String pin,
  }) async {
    if (!await isAdmin()) return AdminPinResult.notAdmin;
    try {
      return await verifyPin(pin) ? AdminPinResult.ok : AdminPinResult.wrong;
    } on PostgrestException catch (e) {
      if (e.code == 'P0423') return AdminPinResult.locked;
      if (e.code == '42501') return AdminPinResult.notAdmin;
      return AdminPinResult.error;
    } catch (_) {
      return AdminPinResult.error;
    }
  }

  static Future<void> open(BuildContext context) async {
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);

    void notify(String message) {
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(message)));
    }

    final client = Supabase.instance.client;
    if (client.auth.currentSession == null) {
      notify('Əvvəl telefonla daxil olun.');
      return;
    }
    if (!await AdminAuthService.isAdminUser(client, refresh: true)) {
      notify('Bu hesabın admin icazəsi yoxdur. Admin hesabı ilə daxil olun.');
      return;
    }

    if (!context.mounted) return;
    final entered = await _askPin(context);
    if (entered == null || entered.isEmpty) return;

    final result = await verify(
      isAdmin: () => AdminAuthService.isAdminUser(client),
      verifyPin: (pin) async {
        final ok = await client.rpc('verify_admin_pin', params: {'p_pin': pin});
        return ok == true;
      },
      pin: entered,
    );

    switch (result) {
      case AdminPinResult.ok:
        await navigator.push(
          MaterialPageRoute(builder: (_) => const AdminDashboardScreen()),
        );
      case AdminPinResult.wrong:
        notify('PIN yanlışdır.');
      case AdminPinResult.locked:
        notify('Çox sayda səhv cəhd. 15 dəqiqə sonra yenidən cəhd edin.');
      case AdminPinResult.notAdmin:
        notify('Bu hesabın admin icazəsi yoxdur. Admin hesabı ilə daxil olun.');
      case AdminPinResult.error:
        notify('PIN yoxlanıla bilmədi. Bir az sonra yenidən cəhd edin.');
    }
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

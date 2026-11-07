import 'dart:convert';

import 'package:supabase_flutter/supabase_flutter.dart';

/// Client-side mirror of the server's `public.is_admin()`: the only source of
/// truth is the `app_metadata.role` claim inside the signed access token.
/// Emails, `user_metadata` and `profiles` are intentionally not used.
/// This only controls the UI; the database enforces the real permission.
class AdminAuthService {
  static bool hasAdminClaim(Session? session) {
    final token = session?.accessToken;
    if (token == null || token.isEmpty) return false;
    final parts = token.split('.');
    if (parts.length != 3) return false;
    try {
      final payload = utf8.decode(base64Url.decode(base64Url.normalize(parts[1])));
      final claims = jsonDecode(payload);
      if (claims is! Map) return false;
      final appMetadata = claims['app_metadata'];
      return appMetadata is Map && appMetadata['role'] == 'admin';
    } catch (_) {
      return false;
    }
  }

  /// With [refresh] the session is renewed first so a recently granted claim is picked up.
  static Future<bool> isAdminUser(
    SupabaseClient client, {
    bool refresh = false,
  }) async {
    if (client.auth.currentSession == null) return false;
    if (refresh) {
      try {
        await client.auth.refreshSession();
      } catch (_) {
        // Keep the current session; the claim check below decides.
      }
    }
    return hasAdminClaim(client.auth.currentSession);
  }
}

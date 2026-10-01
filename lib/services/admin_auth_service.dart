import 'package:supabase_flutter/supabase_flutter.dart';

class AdminAuthService {
  static const Set<String> adminEmails = {
    'admin@workspot.az',
    'kazimzade1977@icloud.com',
  };

  static bool _hasAdminFlag(Map<String, dynamic>? data) {
    if (data == null) return false;
    final role = data['role']?.toString().toLowerCase().trim();
    final isAdmin = data['is_admin'] == true;
    return role == 'admin' || role == 'superadmin' || isAdmin;
  }

  static bool _hasAdminEmail(User? user) {
    final email = user?.email?.toLowerCase().trim() ?? '';
    return email.isNotEmpty && adminEmails.contains(email);
  }

  static Future<bool> isAdminUser(SupabaseClient client) async {
    final user = client.auth.currentUser;
    if (user == null) return false;

    if (_hasAdminEmail(user)) return true;

    if (_hasAdminFlag(user.appMetadata)) return true;
    if (_hasAdminFlag(user.userMetadata)) return true;

    try {
      final profile = await client
          .from('profiles')
          .select('role, is_admin')
          .eq('id', user.id)
          .maybeSingle();
      if (profile is Map<String, dynamic> && _hasAdminFlag(profile)) {
        return true;
      }
    } catch (_) {
      // Fall back to metadata/email checks if profiles is not available.
    }

    return false;
  }
}
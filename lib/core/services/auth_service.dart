import 'package:supabase_flutter/supabase_flutter.dart';

class AuthService {
  final SupabaseClient _supabase = Supabase.instance.client;

  Future<void> sendOtpCode(String phoneNumber) async {
    final formattedPhone = phoneNumber.startsWith('+') ? phoneNumber : '+$phoneNumber';
    await _supabase.auth.signInWithOtp(phone: formattedPhone);
  }

  Future<AuthResponse> verifyOtpCode(String phoneNumber, String token) async {
    final formattedPhone = phoneNumber.startsWith('+') ? phoneNumber : '+$phoneNumber';
    return await _supabase.auth.verifyOTP(
      phone: formattedPhone,
      token: token,
      type: OtpType.sms,
    );
  }

  String? get currentUserId => _supabase.auth.currentUser?.id;

  Future<void> signOut() async {
    await _supabase.auth.signOut();
  }
}
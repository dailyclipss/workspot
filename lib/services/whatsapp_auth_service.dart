import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class WhatsAppAuthService {
  WhatsAppAuthService({SupabaseClient? client})
      : _client = client ?? Supabase.instance.client;

  static final RegExp _azerbaijanPhonePattern = RegExp(
    r'^\+994(?:10|50|51|55|60|70|77|99)\d{7}$',
  );

  final SupabaseClient _client;

  static String normalizePhoneNumber(String phoneNumber) {
    final digits = phoneNumber.replaceAll(RegExp(r'[^0-9]'), '');
    return digits.length == 9 ? '+994$digits' : '+$digits';
  }

  static bool isValidAzerbaijanPhoneNumber(String phoneNumber) {
    return _azerbaijanPhonePattern.hasMatch(normalizePhoneNumber(phoneNumber));
  }

  Future<void> sendOTP(String phoneNumber) async {
    final normalizedPhoneNumber = normalizePhoneNumber(phoneNumber);
    if (!isValidAzerbaijanPhoneNumber(normalizedPhoneNumber)) {
      throw const FormatException('A valid +994 phone number is required.');
    }

    // The server generates, stores (hashed) and sends the code.
    final response = await _client.functions.invoke(
      'send-whatsapp-otp',
      body: {
        'v': 2,
        'phone': normalizedPhoneNumber.substring(1),
      },
    );
    if (response.status >= 300) {
      throw StateError('OTP could not be sent (${response.status}).');
    }
  }

  Future<WhatsAppAuthSession> verifyOTP(
    String phoneNumber,
    String code,
  ) async {
    final normalizedPhoneNumber = normalizePhoneNumber(phoneNumber);

    // The server checks the code and returns a one-time token for a real
    // session bound to this phone number.
    final response = await _client.functions.invoke(
      'verify-whatsapp-otp',
      body: {
        'phone': normalizedPhoneNumber.substring(1),
        'code': code.trim(),
      },
    );
    final data = response.data;
    final tokenHash = data is Map ? data['token_hash'] : null;
    if (response.status >= 300 || tokenHash is! String || tokenHash.isEmpty) {
      throw StateError('Invalid or expired OTP code.');
    }

    await _client.auth.verifyOTP(
      tokenHash: tokenHash,
      type: OtpType.magiclink,
    );

    final session = WhatsAppAuthSession(
      phoneNumber: normalizedPhoneNumber,
      signedInAt: DateTime.now(),
    );
    WhatsAppAuthState.instance.signIn(session);
    return session;
  }
}

class WhatsAppAuthSession {
  const WhatsAppAuthSession({
    required this.phoneNumber,
    required this.signedInAt,
  });

  final String phoneNumber;
  final DateTime signedInAt;
}

class WhatsAppAuthState extends ValueNotifier<WhatsAppAuthSession?> {
  WhatsAppAuthState._() : super(null);

  static final instance = WhatsAppAuthState._();

  bool get isSignedIn => value != null;

  void signIn(WhatsAppAuthSession session) {
    value = session;
  }

  void signOut() {
    value = null;
  }
}

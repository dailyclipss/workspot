import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class WhatsAppAuthService {
  WhatsAppAuthService({SupabaseClient? client})
      : _client = client ?? Supabase.instance.client;

  static const _otpLifetime = Duration(minutes: 2);
  // App Store review demo account: no WhatsApp message is sent for this number.
  static const _reviewPhoneNumber = '+994501234567';
  static const _reviewOtpCode = '123456';
  static final RegExp _azerbaijanPhonePattern = RegExp(
    r'^\+994(?:10|50|51|55|60|70|77|99)\d{7}$',
  );

  final SupabaseClient _client;
  String? _phoneNumber;
  String? _otpCode;
  DateTime? _expiresAt;

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

    final otpCode = normalizedPhoneNumber == _reviewPhoneNumber
        ? _reviewOtpCode
        : _generateOtpCode();
    if (normalizedPhoneNumber != _reviewPhoneNumber) {
      await _client.functions.invoke(
        'send-whatsapp-otp',
        body: {
          'phone': normalizedPhoneNumber.substring(1),
          'otpCode': otpCode,
        },
      );
    }

    _phoneNumber = normalizedPhoneNumber;
    _otpCode = otpCode;
    _expiresAt = DateTime.now().add(_otpLifetime);
  }

  Future<WhatsAppAuthSession> verifyOTP(
    String phoneNumber,
    String code,
  ) async {
    final normalizedPhoneNumber = normalizePhoneNumber(phoneNumber);
    final expiresAt = _expiresAt;
    if (_phoneNumber != normalizedPhoneNumber ||
        _otpCode == null ||
        expiresAt == null ||
        DateTime.now().isAfter(expiresAt) ||
        code.trim() != _otpCode) {
      throw StateError('Invalid or expired OTP code.');
    }

    if (normalizedPhoneNumber == _reviewPhoneNumber) {
      await _ensureReviewSupabaseSession();
    }

    final session = WhatsAppAuthSession(
      phoneNumber: normalizedPhoneNumber,
      signedInAt: DateTime.now(),
    );
    WhatsAppAuthState.instance.signIn(session);
    _otpCode = null;
    _expiresAt = null;
    return session;
  }

  // Supabase-dependent actions (posting jobs, payments) need an authenticated
  // user, so the review account gets an anonymous Supabase session.
  Future<void> _ensureReviewSupabaseSession() async {
    if (_client.auth.currentSession != null) return;
    try {
      await _client.auth.signInAnonymously();
    } catch (error) {
      debugPrint('Review account anonymous Supabase sign-in failed: $error');
    }
  }

  String _generateOtpCode() {
    return (Random.secure().nextInt(1000000)).toString().padLeft(6, '0');
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

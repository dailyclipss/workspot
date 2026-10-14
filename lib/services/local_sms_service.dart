import 'package:flutter/foundation.dart';

abstract class PhoneOtpService {
  Future<void> sendOtpSms(String phoneNumber);

  Future<MockPhoneSession> verifyOtp(String phoneNumber, String code);
}

class LocalSmsService implements PhoneOtpService {
  LocalSmsService();

  static const useMockSms =
      bool.fromEnvironment('USE_MOCK_SMS', defaultValue: true);
  static const mockVerificationCode = '123456';
  static final RegExp _azerbaijanPhonePattern = RegExp(
    r'^\+994(?:10|50|51|55|60|70|77|99)\d{7}$',
  );

  String? _mockPhoneNumber;
  DateTime? _mockExpiresAt;

  static String normalizePhoneNumber(String phoneNumber) {
    final normalized = phoneNumber.replaceAll(RegExp(r'[^\d+]'), '');
    return normalized.startsWith('+') ? normalized : '+$normalized';
  }

  static bool isValidAzerbaijanPhoneNumber(String phoneNumber) {
    return _azerbaijanPhonePattern.hasMatch(normalizePhoneNumber(phoneNumber));
  }

  @override
  Future<void> sendOtpSms(String phoneNumber) async {
    final normalizedPhoneNumber = normalizePhoneNumber(phoneNumber);
    if (!isValidAzerbaijanPhoneNumber(normalizedPhoneNumber)) {
      throw const FormatException('Etibarlı +994 telefon nömrəsi daxil edin.');
    }

    if (!useMockSms) {
      throw UnsupportedError(
        'The local SMS provider has not been configured. '
        'Set USE_MOCK_SMS=true until its API contract is available.',
      );
    }

    _mockPhoneNumber = normalizedPhoneNumber;
    _mockExpiresAt = DateTime.now().add(const Duration(minutes: 2));
    debugPrint(
      'Mock OTP generated for $normalizedPhoneNumber: '
      '$mockVerificationCode (expires: $_mockExpiresAt)',
    );
  }

  @override
  Future<MockPhoneSession> verifyOtp(String phoneNumber, String code) async {
    final normalizedPhoneNumber = normalizePhoneNumber(phoneNumber);
    final expiresAt = _mockExpiresAt;
    if (_mockPhoneNumber != normalizedPhoneNumber ||
        expiresAt == null ||
        DateTime.now().isAfter(expiresAt)) {
      throw StateError('Təsdiq kodunun vaxtı bitib. Yeni kod göndərin.');
    }
    if (code.trim() != mockVerificationCode) {
      throw StateError('Təsdiq kodu yanlışdır.');
    }

    final session = MockPhoneSession(
      phoneNumber: normalizedPhoneNumber,
      signedInAt: DateTime.now(),
    );
    MockPhoneAuthState.instance.signIn(session);
    return session;
  }
}

class MockPhoneSession {
  const MockPhoneSession({
    required this.phoneNumber,
    required this.signedInAt,
  });

  final String phoneNumber;
  final DateTime signedInAt;
}

class MockPhoneAuthState extends ValueNotifier<MockPhoneSession?> {
  MockPhoneAuthState._() : super(null);

  static final instance = MockPhoneAuthState._();

  bool get isSignedIn => value != null;

  void signIn(MockPhoneSession session) {
    value = session;
  }

  void signOut() {
    value = null;
  }
}

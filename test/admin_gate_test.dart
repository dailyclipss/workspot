import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:workspot/config/admin_gate.dart';
import 'package:workspot/services/admin_auth_service.dart';

String _jwt(Map<String, dynamic> claims) {
  String enc(Object o) =>
      base64Url.encode(utf8.encode(jsonEncode(o))).replaceAll('=', '');
  return '${enc({'alg': 'HS256'})}.${enc(claims)}.sig';
}

Session? _session(Map<String, dynamic> claims) => Session(
      accessToken: _jwt(claims),
      tokenType: 'bearer',
      user: const User(
        id: 'u1',
        appMetadata: {},
        userMetadata: {},
        aud: 'authenticated',
        createdAt: '2026-01-01T00:00:00Z',
      ),
    );

void main() {
  final adminSession = _session({
    'app_metadata': {'role': 'admin'}
  });
  final userSession = _session({'app_metadata': {}, 'role': 'authenticated'});
  final anonSession =
      _session({'is_anonymous': true, 'role': 'authenticated', 'app_metadata': {}});

  Future<bool> check(Session? s) async => AdminAuthService.hasAdminClaim(s);

  Future<AdminAccess> run(bool web, bool pin, Session? s) =>
      AdminGate.decide(isWeb: web, pinConfigured: pin, isAdmin: () => check(s));

  group('web, no PIN configured', () {
    test('admin role is allowed', () async {
      expect(await run(true, false, adminSession),
          AdminAccess.allowedWithoutPin);
    });
    test('normal user is denied', () async {
      expect(await run(true, false, userSession), AdminAccess.disabled);
    });
    test('anonymous user is denied', () async {
      expect(await run(true, false, anonSession), AdminAccess.disabled);
    });
    test('no session is denied', () async {
      expect(await run(true, false, null), AdminAccess.disabled);
    });
    test('role in user_metadata or top level does not count', () async {
      final fake = _session({
        'role': 'admin',
        'user_metadata': {'role': 'admin'},
        'app_metadata': {}
      });
      expect(await run(true, false, fake), AdminAccess.disabled);
    });
  });

  group('mobile unchanged', () {
    test('no PIN: disabled even for admin, admin check never consulted',
        () async {
      var asked = false;
      final r = await AdminGate.decide(
        isWeb: false,
        pinConfigured: false,
        isAdmin: () async {
          asked = true;
          return true;
        },
      );
      expect(r, AdminAccess.disabled);
      expect(asked, isFalse);
    });
    test('PIN configured: PIN required', () async {
      expect(await run(false, true, adminSession), AdminAccess.pinRequired);
      expect(await run(false, true, null), AdminAccess.pinRequired);
    });
  });

  test('web with PIN configured still requires the PIN', () async {
    expect(await run(true, true, userSession), AdminAccess.pinRequired);
  });
}

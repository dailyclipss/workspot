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

Session _session(Map<String, dynamic> claims) => Session(
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
  final anonSession = _session(
      {'is_anonymous': true, 'role': 'authenticated', 'app_metadata': {}});
  final fakeAdmin = _session({
    'role': 'admin',
    'user_metadata': {'role': 'admin'},
    'app_metadata': {}
  });

  Future<AdminPinResult> run(
    Session? session,
    Future<bool> Function(String) rpc, {
    List<String>? calls,
  }) =>
      AdminGate.verify(
        isAdmin: () async => AdminAuthService.hasAdminClaim(session),
        verifyPin: (p) {
          calls?.add(p);
          return rpc(p);
        },
        pin: 'entered-pin',
      );

  test('admin role + correct PIN opens', () async {
    expect(await run(adminSession, (_) async => true), AdminPinResult.ok);
  });

  test('admin role + wrong PIN is rejected', () async {
    expect(await run(adminSession, (_) async => false), AdminPinResult.wrong);
  });

  test('server lockout (P0423) is reported as locked', () async {
    final r = await run(
      adminSession,
      (_) async => throw const PostgrestException(
          message: 'admin_pin_locked', code: 'P0423'),
    );
    expect(r, AdminPinResult.locked);
  });

  test('server 42501 is reported as notAdmin', () async {
    final r = await run(
      adminSession,
      (_) async =>
          throw const PostgrestException(message: 'x', code: '42501'),
    );
    expect(r, AdminPinResult.notAdmin);
  });

  test('network or unknown failure is an error, never access', () async {
    expect(await run(adminSession, (_) async => throw Exception('offline')),
        AdminPinResult.error);
    expect(
        await run(
            adminSession,
            (_) async =>
                throw const PostgrestException(message: 'x', code: '500')),
        AdminPinResult.error);
  });

  for (final entry in {
    'normal user': userSession,
    'anonymous user': anonSession,
    'no session': null,
    'role only in user_metadata/top level': fakeAdmin,
  }.entries) {
    test('${entry.key}: denied and the RPC is never called', () async {
      final calls = <String>[];
      final r = await run(entry.value, (_) async => true, calls: calls);
      expect(r, AdminPinResult.notAdmin);
      expect(calls, isEmpty);
    });
  }
}

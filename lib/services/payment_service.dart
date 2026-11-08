import 'dart:convert';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import 'app_language.dart';

/// Which record in Supabase should be marked VIP after a successful payment.
enum PaymentTargetType { job, company, proSubscription }

class PaymentPackage {
  final String id;
  final String nameKey;
  final double amount;
  final String currency;
  final int vipDurationDays;

  const PaymentPackage({
    required this.id,
    required this.nameKey,
    required this.amount,
    this.currency = PaymentCatalog.defaultCurrency,
    required this.vipDurationDays,
  });
}

/// Predefined catalog: B2B AZN packages (local POS) + B2C Pro subscription (IAP).
class PaymentCatalog {
  static const String defaultCurrency = 'AZN';

  static const List<PaymentPackage> b2bPackages = [
    PaymentPackage(
      id: 'single_vip_pin',
      nameKey: 'pkg_single_vip_pin',
      amount: 15,
      vipDurationDays: 7,
    ),
    PaymentPackage(
      id: 'pro_business',
      nameKey: 'pkg_pro_business',
      amount: 45,
      vipDurationDays: 30,
    ),
    PaymentPackage(
      id: 'enterprise',
      nameKey: 'pkg_enterprise',
      amount: 99,
      vipDurationDays: 30,
    ),
  ];

  static const PaymentPackage proSubscription = PaymentPackage(
    id: 'pro_subscription_monthly',
    nameKey: 'pkg_pro_subscription',
    amount: 3.99,
    currency: defaultCurrency,
    vipDurationDays: 30,
  );
}

/// Server-side result of an order, as written by the Epoint callback.
enum OrderOutcome { paid, failed, pending }

/// Starts Epoint checkouts and reads their server-side results.
class PaymentService {
  PaymentService._();
  static final PaymentService instance = PaymentService._();
  static final RegExp _uuidPattern = RegExp(
    r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[1-5][0-9a-fA-F]{3}-[89abAB][0-9a-fA-F]{3}-[0-9a-fA-F]{12}$',
  );

  SupabaseClient get _client => Supabase.instance.client;

  static bool isValidUuid(String? value) =>
      value != null && _uuidPattern.hasMatch(value.trim());

  /// Epoint public key (safe to ship in the app). The private key must live
  /// only on the backend (see supabase/functions/epoint-create).
  static const String epointPublicKey = 'i000201987';

  static const String _epointFunctionUrl =
      'https://erlguuogmrgyhuhbecny.supabase.co/functions/v1/epoint-create';

  /// Asks the backend (Supabase Edge Function `epoint-create`) to
  /// create an Epoint checkout and opens the returned payment page.
  /// Returns null on success, or an error message.
  Future<String?> createPayment({
    required PaymentPackage package,
    required String targetId,
    required PaymentTargetType targetType,
    String? orderId,
    bool sameTabOnWeb = false,
  }) async {
    try {
      final session = _client.auth.currentSession;
      final userId = _client.auth.currentUser?.id;
      if (session == null || !isValidUuid(userId)) {
        return 'An authenticated user is required to make a payment.';
      }
      if (!isValidUuid(targetId)) {
        return 'A valid job, company, or subscription UUID is required.';
      }

      final response = await http
          .post(
            Uri.parse(_epointFunctionUrl),
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer ${session.accessToken}',
            },
            body: jsonEncode({
              'public_key': epointPublicKey,
              'amount': package.amount,
              'currency': package.currency,
              'package_id': package.id,
              'target_id': targetId,
              'target_type': targetType.name,
              'user_id': userId,
              'description': appLang.translate(package.nameKey),
              if (orderId != null) 'orderId': orderId,
            }),
          )
          .timeout(const Duration(seconds: 30));

      Map<String, dynamic> body = {};
      try {
        body = jsonDecode(response.body) as Map<String, dynamic>;
      } catch (_) {}

      if (response.statusCode < 200 || response.statusCode >= 300) {
        final detail = body['error'] ?? body['message'];
        return 'Payment server error (${response.statusCode})'
            '${detail != null ? ': $detail' : '.'}';
      }
      final redirectUrl = (body['redirect_url'] ?? body['url']) as String?;
      if (redirectUrl == null || redirectUrl.isEmpty) {
        return 'Payment page URL was not returned.';
      }
      final uri = Uri.parse(redirectUrl);
      if (uri.scheme != 'https') return 'Invalid payment page URL.';

      final opened = sameTabOnWeb && kIsWeb
          ? await launchUrl(uri, webOnlyWindowName: '_self')
          : await launchUrl(uri, mode: LaunchMode.externalApplication);
      return opened ? null : 'Could not open the payment page.';
    } catch (error) {
      return '${appLang.translate('payment_failed_prefix')} $error';
    }
  }

  /// Reads the order's server-side status (RLS limits this to the caller's
  /// own orders). The client never marks an order paid; only the Epoint
  /// callback does.
  Future<OrderOutcome> fetchOrderOutcome(String orderId) async {
    final row = await _client
        .from('orders')
        .select('status')
        .eq('order_id', orderId)
        .maybeSingle();
    switch (row?['status']?.toString().toLowerCase().trim()) {
      case 'paid':
        return OrderOutcome.paid;
      case 'failed':
        return OrderOutcome.failed;
      default:
        return OrderOutcome.pending;
    }
  }

  /// Polls the order until it leaves `pending` or [timeout] elapses.
  Future<OrderOutcome> waitForOrderOutcome(
    String orderId, {
    Duration interval = const Duration(seconds: 4),
    Duration timeout = const Duration(seconds: 30),
  }) async {
    final deadline = DateTime.now().add(timeout);
    while (true) {
      final outcome = await fetchOrderOutcome(orderId);
      if (outcome != OrderOutcome.pending) return outcome;
      if (DateTime.now().add(interval).isAfter(deadline)) return outcome;
      await Future<void>.delayed(interval);
    }
  }
}

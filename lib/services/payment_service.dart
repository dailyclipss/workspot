import 'package:supabase_flutter/supabase_flutter.dart';

import 'app_language.dart';

/// How the payment was collected.
enum PaymentMethod { localPos, appleIap, googleIap }

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

/// Predefined catalog: B2B USD packages (local POS) + B2C Pro subscription (IAP).
class PaymentCatalog {
  static const String defaultCurrency = 'USD';

  static const List<PaymentPackage> b2bPackages = [
    PaymentPackage(
      id: 'single_vip_pin',
      nameKey: 'pkg_single_vip_pin',
      amount: 8.99,
      vipDurationDays: 7,
    ),
    PaymentPackage(
      id: 'pro_business',
      nameKey: 'pkg_pro_business',
      amount: 22.99,
      vipDurationDays: 30,
    ),
    PaymentPackage(
      id: 'enterprise',
      nameKey: 'pkg_enterprise',
      amount: 49.99,
      vipDurationDays: 30,
    ),
  ];

  static const PaymentPackage proSubscription = PaymentPackage(
    id: 'pro_subscription_monthly',
    nameKey: 'pkg_pro_subscription',
    amount: 3.99,
    vipDurationDays: 30,
  );
}

class PaymentResult {
  final bool success;
  final String? transactionId;
  final String message;
  final PaymentPackage package;
  final PaymentMethod method;
  final DateTime? vipExpiresAt;

  const PaymentResult({
    required this.success,
    required this.message,
    required this.package,
    required this.method,
    this.transactionId,
    this.vipExpiresAt,
  });
}

/// Unified payment handler for local merchant POS (B2B, AZN) and
/// Apple/Google in-app purchases (B2C Pro subscription, USD).
///
/// The actual POS SDK / `in_app_purchase` package integration is not wired up
/// yet; the `_charge*` methods are the single place to plug in the real
/// payment gateway calls once credentials/SDKs are available.
class PaymentService {
  PaymentService._();
  static final PaymentService instance = PaymentService._();

  SupabaseClient get _client => Supabase.instance.client;

  Future<PaymentResult> payWithLocalPos({
    required PaymentPackage package,
    required String targetId,
    required PaymentTargetType targetType,
  }) async {
    return _processPayment(
      package: package,
      method: PaymentMethod.localPos,
      targetId: targetId,
      targetType: targetType,
      charge: () => _chargeLocalPos(package),
    );
  }

  Future<PaymentResult> payWithInAppPurchase({
    required PaymentPackage package,
    required String targetId,
    required PaymentTargetType targetType,
    required bool isIOS,
  }) async {
    return _processPayment(
      package: package,
      method: isIOS ? PaymentMethod.appleIap : PaymentMethod.googleIap,
      targetId: targetId,
      targetType: targetType,
      charge: () => isIOS ? _chargeAppleIap(package) : _chargeGoogleIap(package),
    );
  }

  Future<PaymentResult> _processPayment({
    required PaymentPackage package,
    required PaymentMethod method,
    required String targetId,
    required PaymentTargetType targetType,
    required Future<String> Function() charge,
  }) async {
    try {
      final transactionId = await charge();
      final vipExpiresAt =
          DateTime.now().add(Duration(days: package.vipDurationDays));

      await _recordSuccessfulPayment(
        transactionId: transactionId,
        package: package,
        method: method,
        targetId: targetId,
        targetType: targetType,
        vipExpiresAt: vipExpiresAt,
      );

      return PaymentResult(
        success: true,
        transactionId: transactionId,
        message: appLang.translate('payment_success_message'),
        package: package,
        method: method,
        vipExpiresAt: vipExpiresAt,
      );
    } catch (error) {
      return PaymentResult(
        success: false,
        message: '${appLang.translate('payment_failed_prefix')} $error',
        package: package,
        method: method,
      );
    }
  }

  // Placeholder POS charge — replace with the real merchant POS SDK call.
  Future<String> _chargeLocalPos(PaymentPackage package) async {
    await Future<void>.delayed(const Duration(milliseconds: 900));
    return 'pos_${DateTime.now().millisecondsSinceEpoch}';
  }

  // Placeholder Apple IAP charge — replace with `in_app_purchase` StoreKit flow.
  Future<String> _chargeAppleIap(PaymentPackage package) async {
    await Future<void>.delayed(const Duration(milliseconds: 900));
    return 'apple_iap_${DateTime.now().millisecondsSinceEpoch}';
  }

  // Placeholder Google IAP charge — replace with `in_app_purchase` Play Billing flow.
  Future<String> _chargeGoogleIap(PaymentPackage package) async {
    await Future<void>.delayed(const Duration(milliseconds: 900));
    return 'google_iap_${DateTime.now().millisecondsSinceEpoch}';
  }

  Future<void> _recordSuccessfulPayment({
    required String transactionId,
    required PaymentPackage package,
    required PaymentMethod method,
    required String targetId,
    required PaymentTargetType targetType,
    required DateTime vipExpiresAt,
  }) async {
    await _client.from('transactions').insert({
      'reference': transactionId,
      'target_id': targetId,
      'target_type': targetType.name,
      'package_id': package.id,
      'package_name': appLang.translate(package.nameKey),
      'amount': package.amount,
      'currency': package.currency,
      'payment_method': method.name,
      'status': 'completed',
      'created_at': DateTime.now().toIso8601String(),
    });

    final table = targetType == PaymentTargetType.company ? 'companies' : 'jobs';
    await _client.from(table).update({
      'is_vip': true,
      'vip_expires_at': vipExpiresAt.toIso8601String(),
    }).eq('id', targetId);
  }
}

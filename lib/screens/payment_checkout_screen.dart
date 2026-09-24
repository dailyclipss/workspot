import 'dart:io' show Platform;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';

import '../services/app_language.dart';
import '../services/payment_service.dart';

/// Checkout flow for B2B VIP packages (local POS, USD) and the B2C Pro
/// subscription (Apple/Google in-app purchase, USD).
class PaymentCheckoutScreen extends StatefulWidget {
  final String targetId;
  final PaymentTargetType targetType;

  const PaymentCheckoutScreen({
    super.key,
    required this.targetId,
    this.targetType = PaymentTargetType.job,
  });

  @override
  State<PaymentCheckoutScreen> createState() => _PaymentCheckoutScreenState();
}

class _PaymentCheckoutScreenState extends State<PaymentCheckoutScreen> {
  static const _background = Color(0xFF0F172A);
  static const _surface = Color(0xFF1E293B);
  static const _muted = Color(0xFF94A3B8);
  static const _blue = Color(0xFF2563EB);

  PaymentPackage? _selectedPackage;
  bool _isProcessing = false;

  bool get _isIOS => !kIsWeb && Platform.isIOS;

  bool get _isProPackage =>
      _selectedPackage?.id == PaymentCatalog.proSubscription.id;

  Future<void> _pay() async {
    final package = _selectedPackage;
    if (package == null) return;

    setState(() => _isProcessing = true);
    final result = _isProPackage
        ? await PaymentService.instance.payWithInAppPurchase(
            package: package,
            targetId: widget.targetId,
            targetType: widget.targetType,
            isIOS: _isIOS,
          )
        : await PaymentService.instance.payWithLocalPos(
            package: package,
            targetId: widget.targetId,
            targetType: widget.targetType,
          );

    if (!mounted) return;
    setState(() => _isProcessing = false);

    if (result.success) {
      _showReceiptModal(result);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(result.message), backgroundColor: Colors.red),
      );
    }
  }

  String _formatPrice(PaymentPackage package) {
    return package.currency == 'USD'
        ? '\$${package.amount.toStringAsFixed(2)}'
        : '${package.amount.toStringAsFixed(2)} ${package.currency}';
  }

  void _showReceiptModal(PaymentResult result) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        return Container(
          padding: const EdgeInsets.fromLTRB(20, 24, 20, 24),
          decoration: const BoxDecoration(
            color: _background,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.check_circle_rounded,
                      color: Color(0xFF22C55E), size: 32),
                  const SizedBox(width: 10),
                  Text(appLang.translate('payment_confirmed_title'),
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold)),
                ],
              ),
              const SizedBox(height: 18),
              _receiptRow(appLang.translate('receipt_package_label'),
                  appLang.translate(result.package.nameKey)),
              _receiptRow(appLang.translate('receipt_amount_label'),
                  _formatPrice(result.package)),
              _receiptRow(appLang.translate('receipt_method_label'),
                  _methodLabel(result.method)),
              _receiptRow(appLang.translate('receipt_transaction_label'),
                  result.transactionId ?? '-'),
              if (result.vipExpiresAt != null)
                _receiptRow(appLang.translate('receipt_vip_expiry_label'),
                    '${result.vipExpiresAt!.day}.${result.vipExpiresAt!.month}.${result.vipExpiresAt!.year}'),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => _showPlaceholderMessage(
                          appLang.translate('receipt_download_placeholder')),
                      icon: const Icon(Icons.download_rounded,
                          color: Colors.white),
                      label: Text(appLang.translate('download_receipt'),
                          style: const TextStyle(color: Colors.white)),
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: Colors.white24),
                        minimumSize: const Size(0, 48),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () => _showPlaceholderMessage(
                          appLang.translate('e_invoice_placeholder')),
                      icon: const Icon(Icons.receipt_long_rounded,
                          color: Colors.white),
                      label: Text(appLang.translate('request_e_invoice'),
                          style: const TextStyle(color: Colors.white)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _blue,
                        minimumSize: const Size(0, 48),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                child: TextButton(
                  onPressed: () {
                    Navigator.pop(sheetContext);
                    Navigator.pop(context, true);
                  },
                  child: Text(appLang.translate('close_label'),
                      style: const TextStyle(color: _muted)),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _showPlaceholderMessage(String message) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  String _methodLabel(PaymentMethod method) {
    return switch (method) {
      PaymentMethod.localPos => appLang.translate('payment_method_local_pos'),
      PaymentMethod.appleIap => appLang.translate('payment_method_apple_iap'),
      PaymentMethod.googleIap =>
        appLang.translate('payment_method_google_iap'),
    };
  }

  Widget _receiptRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: _muted, fontSize: 13)),
          Text(value,
              style: const TextStyle(
                  color: Colors.white, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _background,
      appBar: AppBar(
        backgroundColor: _background,
        foregroundColor: Colors.white,
        elevation: 0,
        title: Text(appLang.translate('checkout_title'),
            style: const TextStyle(fontWeight: FontWeight.bold)),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
          children: [
            Text(appLang.translate('checkout_b2b_section'),
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),
            ...PaymentCatalog.b2bPackages.map(_packageCard),
            const SizedBox(height: 22),
            Text(appLang.translate('checkout_pro_section'),
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),
            _packageCard(PaymentCatalog.proSubscription),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton(
                onPressed:
                    (_selectedPackage == null || _isProcessing) ? null : _pay,
                style: ElevatedButton.styleFrom(
                    backgroundColor: _blue,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14))),
                child: _isProcessing
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white))
                    : Text(
                        _selectedPackage == null
                            ? appLang.translate('select_package')
                            : '${_isProPackage ? appLang.translate('subscribe_now') : appLang.translate('pay_with_pos')} (${_formatPrice(_selectedPackage!)})',
                        style: const TextStyle(
                            color: Colors.white, fontWeight: FontWeight.bold),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _packageCard(PaymentPackage package) {
    final isSelected = _selectedPackage?.id == package.id;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => setState(() => _selectedPackage = package),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: _surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
                color: isSelected ? _blue : Colors.white10,
                width: isSelected ? 1.6 : 1),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(appLang.translate(package.nameKey),
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 15,
                            fontWeight: FontWeight.bold)),
                    const SizedBox(height: 4),
                    Text(
                        '${package.vipDurationDays} ${appLang.translate('vip_days_suffix')}',
                        style: const TextStyle(color: _muted, fontSize: 12)),
                  ],
                ),
              ),
              Text(_formatPrice(package),
                  style: const TextStyle(
                      color: Color(0xFF60A5FA),
                      fontSize: 16,
                      fontWeight: FontWeight.bold)),
              const SizedBox(width: 8),
              Icon(
                isSelected
                    ? Icons.radio_button_checked_rounded
                    : Icons.radio_button_off_rounded,
                color: isSelected ? _blue : _muted,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

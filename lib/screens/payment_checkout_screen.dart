import 'dart:io' show Platform;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';

import '../services/app_language.dart';
import '../services/payment_service.dart';

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
  static const _backgroundTop = Color(0xFF18181B);
  static const _backgroundBottom = Color(0xFF09090B);
  static const _surface = Color(0xFF111113);
  static const _surfaceAlt = Color(0xFF16161A);
  static const _muted = Color(0xFF9CA3AF);
  static const _accent = Color(0xFF38BDF8);
  static const _success = Color(0xFF22C55E);

  PaymentPackage? _selectedPackage;
  bool _isProcessing = false;

  bool get _isIOS => !kIsWeb && Platform.isIOS;

  bool get _isProPackage =>
      _selectedPackage?.id == PaymentCatalog.proSubscription.id;

  List<_PricingTier> get _tiers => [
        _PricingTier(
          package: PaymentCatalog.b2bPackages[0],
          eyebrow: 'TEK VIP',
          badge: '7 gün',
          accent: const Color(0xFF38BDF8),
          shortSummary:
              'Karta daxil olan vakansiyanı dərhal diqqət mərkəzinə çıxarır.',
          details: const [
            '7 gün xəritədə fərqlənən qızılı VIP kapsul',
            'Axtarış və siyahıda yuxarı sıralarda görünmə',
            'Birbaşa WhatsApp və Zəng düyməsi üstünlüyü',
          ],
          terms:
              'Bu paket aktivləşdirildiyi andan 7 təqvim günü etibarlıdır. Ad statusu aktiv olduqda xəritə pininiz göstərilir. Status dayandırıldıqda görünmə də dayana bilər.',
          refundPolicy:
              'Aktivləşdirilməmiş sifarişlər üçün dəstək sorğusu ilə yoxlanılır. Aktiv olduqdan sonra geri ödəniş edilmir.',
        ),
        _PricingTier(
          package: PaymentCatalog.b2bPackages[1],
          eyebrow: 'PRO BİZNES',
          badge: 'ƏN ÇOX SEÇİLƏN',
          featured: true,
          accent: const Color(0xFFF59E0B),
          shortSummary:
              'Ən balanslı seçim. Görünürlük, müraciət və analitika bir yerdə.',
          details: const [
            '30 gün aktiv VIP qızılı pin görünüşü',
            'Axtarışlarda VIP prioritet sıralama',
            'Xüsusi "Təcili Vakansiya" vizual etiketi',
            'Birbaşa Instagram səhifə yönləndirməsi',
          ],
          terms:
              'Paket 30 gün aktiv qalır. Elan aktiv statusda olduğu müddətdə üstün görünürlük saxlanılır. Təqdim olunan hekayə paylaşımı yalnız aktiv elan üçün istifadə olunur.',
          refundPolicy:
              'Paylaşım və aktivləşdirmədən sonra geri ödəniş verilmir. Texniki xəta halında komandaya müraciət edilə bilər.',
        ),
        _PricingTier(
          package: PaymentCatalog.b2bPackages[2],
          eyebrow: 'ENTERPRISE',
          badge: '30 gün',
          accent: const Color(0xFFA78BFA),
          shortSummary:
              'Miqyaslı işə qəbul və premium brend təqdimatı üçün hazırlanıb.',
          details: const [
            'Aylıq 10 ədəd VIP vakansiya yerləşdirilməsi',
            'Siyahı və xəritədə brend adı/logosu vurğusu',
            'B2B dəstək xidməti və sürətli təsdiq',
          ],
          terms:
              'Enterprise paketində aktivləşmə 30 gün davam edir. Logo ilə pin yalnız təsdiqlənmiş hesablar üçün görünür və paket statusu bitdikdə standart görünüşə qayıdır.',
          refundPolicy:
              'Xüsusi brend qurulumu tamamlandıqdan sonra geri ödəniş edilmir. Aktivləşdirmə öncəsi dəstək ilə əlaqə saxlaya bilərsiniz.',
        ),
      ];

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
    final amount = package.amount;
    final amountText = amount % 1 == 0
        ? amount.toStringAsFixed(0)
        : amount
            .toStringAsFixed(2)
            .replaceFirst(RegExp(r'0+$'), '')
            .replaceFirst(RegExp(r'\.$'), '');
    return '$amountText ₼';
  }

  void _showReceiptModal(PaymentResult result) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        return Container(
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 24),
          decoration: const BoxDecoration(
            color: _backgroundTop,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.check_circle_rounded,
                      color: _success, size: 32),
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
                        backgroundColor: _accent,
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
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
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
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.end,
              style: const TextStyle(
                  color: Colors.white, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }

  void _showPackageDetails(_PricingTier tier) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        return DraggableScrollableSheet(
          initialChildSize: 0.78,
          minChildSize: 0.52,
          maxChildSize: 0.94,
          builder: (context, controller) {
            return Container(
              decoration: const BoxDecoration(
                color: _backgroundTop,
                borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
              ),
              child: SingleChildScrollView(
                controller: controller,
                padding: const EdgeInsets.fromLTRB(20, 10, 20, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: Container(
                        width: 42,
                        height: 5,
                        decoration: BoxDecoration(
                          color: Colors.white24,
                          borderRadius: BorderRadius.circular(999),
                        ),
                      ),
                    ),
                    const SizedBox(height: 18),
                    Text(
                      appLang.translate(tier.package.nameKey),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '${_formatPrice(tier.package)} • ${tier.package.vipDurationDays} gün aktivlik',
                      style: const TextStyle(color: _muted, fontSize: 13),
                    ),
                    const SizedBox(height: 18),
                    _detailSection('Paketin üstünlükləri', tier.details),
                    const SizedBox(height: 14),
                    _detailSection('Aktiv status şərtləri', [tier.terms]),
                    const SizedBox(height: 14),
                    _detailSection('Geri ödəniş qaydası', [tier.refundPolicy]),
                    const SizedBox(height: 18),
                    SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: ElevatedButton(
                        onPressed: () {
                          setState(() => _selectedPackage = tier.package);
                          Navigator.pop(sheetContext);
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: tier.accent,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        child: const Text(
                          'Bu paketi seç',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _detailSection(String title, List<String> points) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 14.5,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 12),
          ...points.map(
            (point) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.check_circle_rounded,
                      color: _success, size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      point,
                      style: const TextStyle(
                        color: Color(0xFFE5E7EB),
                        height: 1.35,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTierCard(_PricingTier tier) {
    final isSelected = _selectedPackage?.id == tier.package.id;
    final borderColor = isSelected ? tier.accent : Colors.white12;
    final glowColor = tier.featured
      ? tier.accent.withValues(alpha: 0.25)
      : tier.accent.withValues(alpha: 0.14);

    return AnimatedContainer(
      duration: const Duration(milliseconds: 240),
      curve: Curves.easeOutCubic,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: glowColor,
            blurRadius: isSelected ? 28 : 18,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () => setState(() => _selectedPackage = tier.package),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [_surface, _surfaceAlt, _backgroundBottom],
              ),
              border: Border.all(
                color: borderColor,
                width: isSelected ? 1.8 : 1.0,
              ),
            ),
            child: Stack(
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Expanded(
                                    child: Text(
                                      tier.eyebrow,
                                      style: TextStyle(
                                        color: tier.accent,
                                        fontSize: 11,
                                        fontWeight: FontWeight.w800,
                                        letterSpacing: 1.0,
                                      ),
                                    ),
                                  ),
                                  if (tier.featured)
                                    Container(
                                      margin: const EdgeInsets.only(left: 10),
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 10, vertical: 6),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFF1E1B12),
                                        borderRadius:
                                            BorderRadius.circular(999),
                                        border: Border.all(
                                          color: tier.accent.withValues(alpha: 0.82),
                                        ),
                                        boxShadow: [
                                          BoxShadow(
                                            color: tier.accent.withValues(
                                                alpha: 0.28),
                                            blurRadius: 14,
                                            spreadRadius: 0.5,
                                          ),
                                        ],
                                      ),
                                      child: Text(
                                        tier.badge,
                                        style: TextStyle(
                                          color: tier.accent,
                                          fontSize: 10.2,
                                          fontWeight: FontWeight.w800,
                                          letterSpacing: 0.35,
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                              const SizedBox(height: 6),
                              Text(
                                appLang.translate(tier.package.nameKey),
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 18,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                tier.shortSummary,
                                style: const TextStyle(
                                  color: _muted,
                                  height: 1.35,
                                  fontSize: 12.5,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 10),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  visualDensity: VisualDensity.compact,
                                  onPressed: () => _showPackageDetails(tier),
                                  icon: const Icon(Icons.info_outline),
                                  color: Colors.white70,
                                  tooltip: 'Ətraflı məlumat',
                                ),
                                Icon(
                                  isSelected
                                      ? Icons.radio_button_checked_rounded
                                      : Icons.radio_button_off_rounded,
                                  color: isSelected ? tier.accent : _muted,
                                ),
                              ],
                            ),
                            const SizedBox(height: 2),
                            Text(
                              _formatPrice(tier.package),
                              style: TextStyle(
                                color: tier.accent,
                                fontSize: 24,
                                fontWeight: FontWeight.w900,
                                letterSpacing: -0.3,
                              ),
                            ),
                            Text(
                              '${tier.package.vipDurationDays} gün aktiv',
                              style: const TextStyle(
                                color: _muted,
                                fontSize: 11,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    ...tier.details.map(
                      (point) => Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Icon(Icons.check_circle_rounded,
                                color: _success, size: 18),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                point,
                                style: const TextStyle(
                                  color: Color(0xFFF3F4F6),
                                  height: 1.3,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildProCard() {
    const package = PaymentCatalog.proSubscription;
    final isSelected = _selectedPackage?.id == package.id;

    return Container(
      margin: const EdgeInsets.only(top: 14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isSelected ? _accent : Colors.white12,
          width: isSelected ? 1.6 : 1,
        ),
      ),
      child: Material(
        color: _surface,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () => setState(() => _selectedPackage = package),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF2563EB), Color(0xFF60A5FA)],
                    ),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Icon(Icons.workspace_premium_rounded,
                      color: Colors.white),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        appLang.translate(package.nameKey),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 15.5,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        'Tətbiq daxilində aylıq təkmilləşdirilmiş təcrübə',
                        style: TextStyle(color: _muted, fontSize: 12.5),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      _formatPrice(package),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Icon(
                      isSelected
                          ? Icons.radio_button_checked_rounded
                          : Icons.radio_button_off_rounded,
                      color: isSelected ? _accent : _muted,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFFF59E0B), Color(0xFFFB7185)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(14),
              ),
              child: const Icon(Icons.bolt_rounded, color: Colors.white),
            ),
            const SizedBox(width: 12),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Paket Seçimi',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.w900,
                      letterSpacing: -0.4,
                    ),
                  ),
                  SizedBox(height: 4),
                  Text(
                    'VIP görünürlüğü, analitikanı və müraciət həcmini bir premium seçimdə topla.',
                    style: TextStyle(
                      color: _muted,
                      height: 1.35,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        const Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            _HeaderChip(icon: Icons.map_rounded, label: 'Xəritə VIP'),
            _HeaderChip(icon: Icons.analytics_rounded, label: 'Müraciət analitikası'),
            _HeaderChip(icon: Icons.support_agent_rounded, label: 'B2B dəstək'),
          ],
        ),
      ],
    );
  }

  String _ctaLabel() {
    final package = _selectedPackage;
    if (package == null) return 'Davam Et';
    return 'Seçilmiş Paketi Satın Al (${_formatPrice(package)})';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _backgroundBottom,
      appBar: AppBar(
        backgroundColor: _backgroundBottom,
        foregroundColor: Colors.white,
        elevation: 0,
        title: Text(
          appLang.translate('checkout_title'),
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
      bottomNavigationBar: SafeArea(
        child: Container(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
          decoration: BoxDecoration(
            color: const Color(0xFF0C0C0F),
            border: Border(
              top: BorderSide(color: Colors.white.withValues(alpha: 0.08)),
            ),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      _selectedPackage == null
                          ? 'Paket seçin'
                          : appLang.translate(_selectedPackage!.nameKey),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _selectedPackage == null
                          ? 'Yuxarıdan bir kart seçin'
                          : '${_formatPrice(_selectedPackage!)} • ${_selectedPackage!.vipDurationDays} gün aktivlik',
                      style: const TextStyle(color: _muted, fontSize: 12),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              SizedBox(
                height: 52,
                child: ElevatedButton(
                  onPressed:
                      (_selectedPackage == null || _isProcessing) ? null : _pay,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _accent,
                    disabledBackgroundColor: Colors.white10,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 18),
                  ),
                  child: _isProcessing
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : Text(
                          _ctaLabel(),
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [_backgroundTop, _backgroundBottom],
          ),
        ),
        child: SafeArea(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 24),
            children: [
              _buildHeader(),
              const SizedBox(height: 20),
              ..._tiers.map(
                (tier) => Padding(
                  padding: const EdgeInsets.only(bottom: 14),
                  child: _buildTierCard(tier),
                ),
              ),
              const SizedBox(height: 8),
                const Text(
                'Pro Abunəlik',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 10),
              _buildProCard(),
              const SizedBox(height: 100),
            ],
          ),
        ),
      ),
    );
  }
}

class _PricingTier {
  final PaymentPackage package;
  final String eyebrow;
  final String badge;
  final bool featured;
  final Color accent;
  final String shortSummary;
  final List<String> details;
  final String terms;
  final String refundPolicy;

  const _PricingTier({
    required this.package,
    required this.eyebrow,
    required this.badge,
    this.featured = false,
    required this.accent,
    required this.shortSummary,
    required this.details,
    required this.terms,
    required this.refundPolicy,
  });
}

class _HeaderChip extends StatelessWidget {
  final IconData icon;
  final String label;

  const _HeaderChip({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFF111113),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: const Color(0xFF7DD3FC), size: 16),
          const SizedBox(width: 8),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12.5,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
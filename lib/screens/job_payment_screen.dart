import 'dart:async';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../services/app_language.dart';
import '../services/payment_service.dart';

class JobPaymentScreen extends StatefulWidget {
  final Map<String, dynamic> jobDraft;
  final bool preferPremium;

  /// Inserts the (unpaid) job and returns its id.
  final Future<String?> Function(Map<String, dynamic> jobData) publishJob;

  const JobPaymentScreen({
    super.key,
    required this.jobDraft,
    required this.publishJob,
    this.preferPremium = false,
  });

  @override
  State<JobPaymentScreen> createState() => _JobPaymentScreenState();
}

class _ListingPackage {
  final PaymentPackage package;
  final String title;
  final String description;
  final bool isPremium;
  final Color accent;

  const _ListingPackage({
    required this.package,
    required this.title,
    required this.description,
    required this.isPremium,
    required this.accent,
  });

  String get id => package.id;
  double get amount => package.amount;
}

class _JobPaymentScreenState extends State<JobPaymentScreen> {
  static const Color _background = Color(0xFF081120);
  static const Color _surface = Color(0xFF111A2D);
  static const Color _surfaceAlt = Color(0xFF162238);
  static const Color _muted = Color(0xFF93A4C3);
  static const Color _accent = Color(0xFF3B82F6);

  static const List<_ListingPackage> _packages = [
    _ListingPackage(
      package: PaymentPackage(
        id: 'standard_listing',
        nameKey: 'Standard Listing',
        amount: 10,
        vipDurationDays: 30,
      ),
      title: 'Standard Listing',
      description: '10 AZN - Vakansiyanı standart görünüşlə dərc et.',
      isPremium: false,
      accent: Color(0xFF38BDF8),
    ),
    _ListingPackage(
      package: PaymentPackage(
        id: 'premium_listing',
        nameKey: 'Premium Listing',
        amount: 20,
        vipDurationDays: 30,
      ),
      title: 'Premium Listing',
      description: '20 AZN - Daha görünən, VIP öncelikli elan.',
      isPremium: true,
      accent: Color(0xFFF59E0B),
    ),
  ];

  late _ListingPackage _selectedPackage;
  late String _orderId;

  // The job is inserted once (unpaid); retries and package changes reuse it.
  String? _jobId;
  Timer? _statusPoll;
  bool _isProcessing = false;
  bool _awaitingPayment = false;
  bool _hasFinished = false;

  @override
  void initState() {
    super.initState();
    _selectedPackage = widget.preferPremium ? _packages.last : _packages.first;
    _orderId = _newOrderId();
  }

  @override
  void dispose() {
    _statusPoll?.cancel();
    super.dispose();
  }

  String _newOrderId() => 'job_${DateTime.now().millisecondsSinceEpoch}';

  String _pkgTitle(_ListingPackage p) =>
      appLang.translate(p.isPremium ? 'pj_premium' : 'pj_standard');

  String _pkgDesc(_ListingPackage p) =>
      appLang.translate(p.isPremium ? 'pj_premium_desc' : 'pj_standard_desc');

  String get _description =>
      '${_pkgTitle(_selectedPackage)} - ${widget.jobDraft['title'] ?? appLang.translate('pj_default_title')}';

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red),
    );
  }

  Future<String?> _ensureJobCreated(String userId) async {
    if (_jobId != null) return _jobId;

    // Stays hidden from the map until the Epoint callback activates it.
    final jobData = Map<String, dynamic>.from(widget.jobDraft)
      ..['ad_status'] = 'pending_payment'
      ..['is_vip'] = false
      ..['owner_id'] = userId
      ..['created_by'] = userId;
    _jobId = await widget.publishJob(jobData);
    return _jobId;
  }

  Future<void> _pay() async {
    if (_isProcessing || _hasFinished) return;

    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId == null || !PaymentService.isValidUuid(userId)) {
      _showError(appLang.translate('pj_login_required'));
      return;
    }

    setState(() {
      _isProcessing = true;
      _orderId = _newOrderId();
    });

    try {
      final jobId = await _ensureJobCreated(userId);
      if (jobId == null || !PaymentService.isValidUuid(jobId)) {
        _showError(appLang.translate('pj_create_failed'));
        return;
      }

      final error = await PaymentService.instance.createPayment(
        package: _selectedPackage.package,
        targetId: jobId,
        targetType: PaymentTargetType.job,
        orderId: _orderId,
        sameTabOnWeb: true,
      );
      if (error != null) {
        _showError(error);
        return;
      }

      if (mounted) setState(() => _awaitingPayment = true);
      _startStatusPolling(jobId);
    } catch (error) {
      _showError('${appLang.translate('pj_start_failed')}: $error');
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  void _startStatusPolling(String jobId) {
    _statusPoll?.cancel();
    _statusPoll = Timer.periodic(const Duration(seconds: 4), (_) {
      unawaited(_checkPaymentStatus(jobId));
    });
  }

  Future<void> _checkPaymentStatus(String jobId, {bool manual = false}) async {
    if (_hasFinished) return;
    try {
      final row = await Supabase.instance.client
          .from('jobs')
          .select('ad_status')
          .eq('id', jobId)
          .maybeSingle();
      final status = row?['ad_status']?.toString().toLowerCase().trim();
      if (status == 'active' || status == 'approved' || status == 'vip') {
        await _onPaymentConfirmed();
      } else if (manual) {
        _showError(appLang.translate('pj_not_confirmed'));
      }
    } catch (_) {
      if (manual) _showError(appLang.translate('pj_status_failed'));
    }
  }

  Future<void> _onPaymentConfirmed() async {
    if (_hasFinished) return;
    _hasFinished = true;
    _statusPoll?.cancel();
    if (!mounted) return;

    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: _surface,
        title: Text(
          appLang.translate('pj_success'),
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
        ),
        content: Text(
          appLang.translate('pj_success_sub'),
          style: const TextStyle(color: _muted),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: Text(appLang.translate('pj_continue')),
          ),
        ],
      ),
    );

    if (mounted) Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _background,
      appBar: AppBar(
        backgroundColor: _background,
        foregroundColor: Colors.white,
        elevation: 0,
        title: Text(
          appLang.translate('pj_checkout'),
          style: const TextStyle(fontWeight: FontWeight.w800),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildPackageSelector(),
              const SizedBox(height: 16),
              _buildPayloadCard(),
              const SizedBox(height: 16),
              if (_awaitingPayment) ...[
                _buildAwaitingCard(),
                const SizedBox(height: 16),
              ],
              _buildPayButton(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPayButton() {
    return SizedBox(
      height: 52,
      child: ElevatedButton(
        onPressed: _isProcessing ? null : _pay,
        style: ElevatedButton.styleFrom(
          backgroundColor: _accent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
        child: _isProcessing
            ? const SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(
                  strokeWidth: 2.2,
                  color: Colors.white,
                ),
              )
            : Text(
                appLang.translate('pj_pay'),
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                ),
              ),
      ),
    );
  }

  Widget _buildAwaitingCard() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            appLang.translate('pj_waiting'),
            style: const TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            appLang.translate('pj_waiting_sub'),
            style: const TextStyle(color: _muted, height: 1.4),
          ),
          const SizedBox(height: 10),
          TextButton(
            onPressed: _jobId == null
                ? null
                : () => _checkPaymentStatus(_jobId!, manual: true),
            child: Text(appLang.translate('pj_check')),
          ),
        ],
      ),
    );
  }

  Widget _buildPackageSelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          appLang.translate('pj_options'),
          style: const TextStyle(
              color: Colors.white, fontSize: 22, fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 8),
        Text(
          appLang.translate('pj_options_sub'),
          style: const TextStyle(color: _muted, height: 1.4),
        ),
        const SizedBox(height: 12),
        Row(
          children: _packages.map((option) {
            final isSelected = option.id == _selectedPackage.id;
            return Expanded(
              child: Padding(
                padding:
                    EdgeInsets.only(left: option == _packages.first ? 0 : 8),
                child: GestureDetector(
                  onTap: _isProcessing
                      ? null
                      : () => setState(() => _selectedPackage = option),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 220),
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? option.accent.withOpacity(0.18)
                          : _surface,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: isSelected ? option.accent : Colors.white10,
                        width: 1.2,
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              width: 38,
                              height: 38,
                              decoration: BoxDecoration(
                                color: option.accent.withOpacity(0.16),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                option.isPremium
                                    ? Icons.workspace_premium_rounded
                                    : Icons.list_alt_rounded,
                                color: option.accent,
                              ),
                            ),
                            const Spacer(),
                            if (isSelected)
                              Icon(Icons.check_circle_rounded,
                                  color: option.accent, size: 20),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Text(
                          _pkgTitle(option),
                          style: const TextStyle(
                              color: Colors.white, fontWeight: FontWeight.w700),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          '${option.amount.toStringAsFixed(0)} AZN',
                          style: TextStyle(
                              color: option.accent,
                              fontSize: 20,
                              fontWeight: FontWeight.w800),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _pkgDesc(option),
                          style: const TextStyle(
                              color: _muted, fontSize: 12.5, height: 1.35),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildPayloadCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _surfaceAlt,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            appLang.translate('pj_summary'),
            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 10),
          _payloadRow(appLang.translate('pj_amount'), _selectedPackage.amount.toStringAsFixed(2)),
          _payloadRow(appLang.translate('pj_currency'), 'AZN'),
          _payloadRow(appLang.translate('pj_order_id'), _orderId),
          _payloadRow(appLang.translate('pj_description'), _description),
        ],
      ),
    );
  }

  Widget _payloadRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          SizedBox(
            width: 96,
            child: Text(
              label,
              style: const TextStyle(color: _muted, fontSize: 12.5),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                  color: Colors.white, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}

import 'dart:async';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class JobPaymentScreen extends StatefulWidget {
  final Map<String, dynamic> jobDraft;
  final bool preferPremium;
  final Future<void> Function(Map<String, dynamic> jobData) publishJob;

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
  final String id;
  final String title;
  final String description;
  final double amount;
  final bool isPremium;
  final Color accent;

  const _ListingPackage({
    required this.id,
    required this.title,
    required this.description,
    required this.amount,
    required this.isPremium,
    required this.accent,
  });
}

class _JobPaymentScreenState extends State<JobPaymentScreen> {
  static const String _publicKey = 'PUBLIC_KEY';
  static const String _privateKey = 'PRIVATE_KEY';
  static const String _baseDomain = 'epoint.az';
  static const Color _background = Color(0xFF081120);
  static const Color _surface = Color(0xFF111A2D);
  static const Color _surfaceAlt = Color(0xFF162238);
  static const Color _muted = Color(0xFF93A4C3);
  static const Color _accent = Color(0xFF3B82F6);

  WebViewController? _controller;
  late final List<_ListingPackage> _packages;
  late _ListingPackage _selectedPackage;

  bool _checkoutLoaded = false;
  bool _isPublishing = false;
  bool _hasHandledSuccess = false;
  bool _webCheckoutLaunched = false;

  bool get _isMockMode =>
      _publicKey == 'PUBLIC_KEY' || _privateKey == 'PRIVATE_KEY';

  @override
  void initState() {
    super.initState();
    _packages = const [
      _ListingPackage(
        id: 'standard_listing',
        title: 'Standard Listing',
        description: '10 AZN - Vakansiyanı standart görünüşlə dərc et.',
        amount: 10,
        isPremium: false,
        accent: Color(0xFF38BDF8),
      ),
      _ListingPackage(
        id: 'premium_listing',
        title: 'Premium Listing',
        description: '20 AZN - Daha görünən, VIP öncelikli elan.',
        amount: 20,
        isPremium: true,
        accent: Color(0xFFF59E0B),
      ),
    ];
    _selectedPackage = widget.preferPremium ? _packages.last : _packages.first;

    if (kIsWeb && !_isMockMode) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          unawaited(_openCheckoutInBrowser());
        }
      });
      return;
    }

    if (kIsWeb) {
      return;
    }

    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(
        NavigationDelegate(
          onNavigationRequest: _handleNavigationRequest,
          onPageFinished: (_) {
            if (mounted) {
              setState(() => _checkoutLoaded = true);
            }
          },
        ),
      )
      ..loadHtmlString(_buildCheckoutHtml(),
          baseUrl: 'https://$_baseDomain/checkout');
  }

  String _escapeHtml(Object? value) {
    return value
            ?.toString()
            .replaceAll('&', '&amp;')
            .replaceAll('<', '&lt;')
            .replaceAll('>', '&gt;')
            .replaceAll('"', '&quot;')
            .replaceAll("'", '&#39;') ??
        '';
  }

  Map<String, dynamic> _buildEpointPayload() {
    final orderId = 'job_${DateTime.now().millisecondsSinceEpoch}';
    return <String, dynamic>{
      'public_key': _publicKey,
      'private_key': _privateKey,
      'amount': _selectedPackage.amount.toStringAsFixed(2),
      'currency': 'AZN',
      'order_id': orderId,
      'description':
          '${_selectedPackage.title} - ${widget.jobDraft['title'] ?? 'Job listing'}',
      'success_url': 'https://$_baseDomain/success?order_id=$orderId',
      'fail_url': 'https://$_baseDomain/fail?order_id=$orderId',
    };
  }

  String _buildPaymentUrl() {
    final payload = _buildEpointPayload();
    final uri = Uri.https(_baseDomain, '/checkout', <String, String>{
      'public_key': payload['public_key']?.toString() ?? _publicKey,
      'amount': payload['amount']?.toString() ??
          _selectedPackage.amount.toStringAsFixed(2),
      'currency': payload['currency']?.toString() ?? 'AZN',
      'order_id': payload['order_id']?.toString() ?? '',
      'description': payload['description']?.toString() ?? '',
      'success_url':
          payload['success_url']?.toString() ?? 'https://$_baseDomain/success',
      'fail_url': payload['fail_url']?.toString() ?? 'https://$_baseDomain/fail',
    });
    return uri.toString();
  }

  Future<void> _openCheckoutInBrowser() async {
    if (_isMockMode) {
      await _showMockPaymentDialog();
      return;
    }

    if (_webCheckoutLaunched) return;
    _webCheckoutLaunched = true;
    final paymentUrl = _buildPaymentUrl();
    final launched = await launchUrl(
      Uri.parse(paymentUrl),
      webOnlyWindowName: '_blank',
    );

    if (!launched && mounted) {
      _webCheckoutLaunched = false;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Checkout could not be opened in a new tab.'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  String _buildCheckoutHtml() {
    final payload = _buildEpointPayload();
    return '''
<!DOCTYPE html>
<html>
<head>
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <style>
    body {
      margin: 0;
      font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif;
      background: linear-gradient(180deg, #0f172a 0%, #111827 100%);
      color: #e5eefc;
      display: flex;
      min-height: 100vh;
      align-items: center;
      justify-content: center;
      padding: 24px;
      box-sizing: border-box;
    }
    .card {
      width: 100%;
      max-width: 520px;
      background: rgba(15, 23, 42, 0.92);
      border: 1px solid rgba(148, 163, 184, 0.18);
      border-radius: 24px;
      padding: 24px;
      box-shadow: 0 24px 80px rgba(0, 0, 0, 0.4);
    }
    .badge {
      display: inline-flex;
      align-items: center;
      gap: 8px;
      padding: 8px 12px;
      border-radius: 999px;
      background: rgba(59, 130, 246, 0.16);
      color: #93c5fd;
      font-size: 12px;
      font-weight: 700;
      letter-spacing: 0.04em;
      text-transform: uppercase;
    }
    h1 {
      margin: 16px 0 8px;
      font-size: 28px;
      line-height: 1.1;
    }
    p { color: #93a4c3; line-height: 1.5; }
    .summary {
      margin: 20px 0;
      padding: 16px;
      border-radius: 18px;
      background: rgba(255, 255, 255, 0.04);
      border: 1px solid rgba(255, 255, 255, 0.08);
    }
    .summary-row {
      display: flex;
      justify-content: space-between;
      gap: 16px;
      padding: 6px 0;
      font-size: 14px;
    }
    .summary-row strong { color: #f8fafc; }
    .actions {
      display: grid;
      gap: 12px;
      margin-top: 22px;
    }
    button, a.button {
      appearance: none;
      border: 0;
      border-radius: 16px;
      padding: 14px 16px;
      font-weight: 700;
      text-align: center;
      text-decoration: none;
      cursor: pointer;
      transition: transform 120ms ease, opacity 120ms ease;
    }
    button:hover, a.button:hover { transform: translateY(-1px); }
    .primary { background: #3b82f6; color: white; }
    .secondary { background: rgba(255, 255, 255, 0.08); color: #e5eefc; }
    .meta {
      margin-top: 18px;
      font-size: 12px;
      color: #93a4c3;
      word-break: break-all;
    }
    code { color: #bfdbfe; }
  </style>
</head>
<body>
  <div class="card">
    <div class="badge">Epoint Checkout</div>
    <h1>${_escapeHtml(_selectedPackage.title)}</h1>
    <p>${_escapeHtml(_selectedPackage.description)}</p>

    <div class="summary">
      <div class="summary-row"><span>Amount</span><strong>${_escapeHtml(_selectedPackage.amount.toStringAsFixed(2))} AZN</strong></div>
      <div class="summary-row"><span>Currency</span><strong>AZN</strong></div>
      <div class="summary-row"><span>Order ID</span><strong>${_escapeHtml(payload['order_id'])}</strong></div>
      <div class="summary-row"><span>Description</span><strong>${_escapeHtml(payload['description'])}</strong></div>
    </div>

    <div class="actions">
      <a class="button primary" href="/success?order_id=${_escapeHtml(payload['order_id'])}">Pay and continue</a>
      <a class="button secondary" href="/fail?order_id=${_escapeHtml(payload['order_id'])}">Simulate failure</a>
    </div>

    <div class="meta">
      Payload preview: <code>${payload['public_key']}</code> / <code>${payload['private_key']}</code>
    </div>
  </div>
</body>
</html>
''';
  }

  NavigationDecision _handleNavigationRequest(NavigationRequest request) {
    final uri = Uri.tryParse(request.url);
    if (uri == null) {
      return NavigationDecision.navigate;
    }

    final path = uri.path.toLowerCase();
    if (path.contains('/success')) {
      if (!_hasHandledSuccess) {
        _hasHandledSuccess = true;
        unawaited(_publishAfterPayment(uri));
      }
      return NavigationDecision.prevent;
    }

    if (path.contains('/fail')) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Epoint checkout rejected the payment.'),
          backgroundColor: Colors.red,
        ),
      );
      return NavigationDecision.prevent;
    }

    return NavigationDecision.navigate;
  }

  void _reloadCheckout() {
    if (_isMockMode) {
      unawaited(_showMockPaymentDialog());
      return;
    }

    if (kIsWeb) {
      unawaited(_openCheckoutInBrowser());
      return;
    }
    setState(() {
      _checkoutLoaded = false;
    });
    _controller?.loadHtmlString(
      _buildCheckoutHtml(),
      baseUrl: 'https://$_baseDomain/checkout',
    );
  }

  Future<void> _showMockPaymentDialog() async {
    final proceed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return AlertDialog(
          backgroundColor: _surface,
          title: const Text(
            'Test mode payment',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
          ),
          content: const Text(
            'No active Epoint keys are configured. This will simulate a successful payment and publish the job directly.',
            style: TextStyle(color: _muted, height: 1.45),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              style: ElevatedButton.styleFrom(backgroundColor: _accent),
              child: const Text(
                'Simulate success',
                style: TextStyle(color: Colors.white),
              ),
            ),
          ],
        );
      },
    );

    if (proceed == true) {
      await _publishMockSuccess();
    }
  }

  Future<void> _publishMockSuccess() async {
    if (_isPublishing) return;
    setState(() => _isPublishing = true);

    try {
      final mockOrderId = 'mock_${DateTime.now().millisecondsSinceEpoch}';
      final jobData = Map<String, dynamic>.from(widget.jobDraft);
      final currentUserId = Supabase.instance.client.auth.currentUser?.id;
      jobData['ad_status'] = 'active';
      jobData['status'] = 'active';
      jobData['is_active'] = true;
      jobData['has_vacancy'] = true;
      jobData['is_vip'] = _selectedPackage.isPremium;
      jobData['package_type'] = _selectedPackage.isPremium ? 'Premium' : 'Standard';
      jobData['owner_id'] = currentUserId ?? jobData['owner_id'];
      jobData['created_by'] = currentUserId ?? jobData['created_by'];
      jobData['listing_package'] = _selectedPackage.id;
      jobData['listing_amount'] = _selectedPackage.amount;
      jobData['listing_currency'] = 'AZN';
      jobData['payment_reference'] = mockOrderId;

      await widget.publishJob(jobData);

      if (!mounted) return;
      await showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (dialogContext) {
          return AlertDialog(
            backgroundColor: _surface,
            title: const Text(
              'Payment successful',
              style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
            ),
            content: const Text(
              'Test payment was simulated successfully and the job was published.',
              style: TextStyle(color: _muted, height: 1.45),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(),
                child: const Text('Continue'),
              ),
            ],
          );
        },
      );

      if (mounted) {
        Navigator.of(context).pop(true);
      }
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Test payment simulation failed: $error'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isPublishing = false);
      }
    }
  }

  Future<void> _publishAfterPayment(Uri uri) async {
    if (_isPublishing) return;
    setState(() => _isPublishing = true);

    try {
      final jobData = Map<String, dynamic>.from(widget.jobDraft);
        final currentUserId = Supabase.instance.client.auth.currentUser?.id;
      jobData['ad_status'] = 'active';
      jobData['status'] = 'active';
      jobData['is_active'] = true;
      jobData['has_vacancy'] = true;
      jobData['is_vip'] = _selectedPackage.isPremium;
      jobData['package_type'] = _selectedPackage.isPremium ? 'Premium' : 'Standard';
        jobData['owner_id'] = currentUserId ?? jobData['owner_id'];
        jobData['created_by'] = currentUserId ?? jobData['created_by'];
      jobData['listing_package'] = _selectedPackage.id;
      jobData['listing_amount'] = _selectedPackage.amount;
      jobData['listing_currency'] = 'AZN';
      jobData['payment_reference'] =
          uri.queryParameters['order_id'] ?? _buildEpointPayload()['order_id'];

      await widget.publishJob(jobData);

      if (!mounted) return;
      await showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (dialogContext) {
          return AlertDialog(
            backgroundColor: _surface,
            title: const Text(
              'Payment successful',
              style:
                  TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
            ),
            content: const Text(
              'Your job listing has been published successfully.',
              style: TextStyle(color: _muted),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(),
                child: const Text('Continue'),
              ),
            ],
          );
        },
      );

      if (mounted) {
        Navigator.of(context).pop(true);
      }
    } catch (error) {
      if (!mounted) return;
      setState(() => _isPublishing = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Job publishing failed: $error'),
          backgroundColor: Colors.red,
        ),
      );
      _hasHandledSuccess = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _background,
      appBar: AppBar(
        backgroundColor: _background,
        foregroundColor: Colors.white,
        elevation: 0,
        title: const Text(
          'Job Checkout',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
          child: _isMockMode
              ? _buildMockLayout()
              : (kIsWeb ? _buildWebLayout() : _buildMobileLayout()),
        ),
      ),
    );
  }

  Widget _buildMobileLayout() {
    return Column(
      children: [
        _buildPackageSelector(),
        const SizedBox(height: 16),
        _buildPayloadCard(),
        const SizedBox(height: 16),
        Expanded(child: _buildMobileWebView()),
        const SizedBox(height: 16),
        SizedBox(
          width: double.infinity,
          height: 52,
          child: ElevatedButton(
            onPressed: _isPublishing ? null : _reloadCheckout,
            style: ElevatedButton.styleFrom(
              backgroundColor: _accent,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
            child: _isPublishing
                ? const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.2,
                      color: Colors.white,
                    ),
                  )
                : const Text(
                    'Reload checkout',
                    style:
                        TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
                  ),
          ),
        ),
      ],
    );
  }

  Widget _buildWebLayout() {
    return LayoutBuilder(
      builder: (context, constraints) {
        return SingleChildScrollView(
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: constraints.maxHeight),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildPackageSelector(),
                const SizedBox(height: 16),
                _buildPayloadCard(),
                const SizedBox(height: 16),
                _buildWebPlaceholder(),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton(
                    onPressed: _isPublishing ? null : _openCheckoutInBrowser,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _accent,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    child: _isPublishing
                        ? const SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.2,
                              color: Colors.white,
                            ),
                          )
                        : const Text(
                            'Epoint ilə Ödəniş Et',
                            style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w700),
                          ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildMockLayout() {
    return LayoutBuilder(
      builder: (context, constraints) {
        return SingleChildScrollView(
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: constraints.maxHeight),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildPackageSelector(),
                const SizedBox(height: 16),
                _buildPayloadCard(),
                const SizedBox(height: 16),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: _surface,
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(color: Colors.white10),
                  ),
                  child: const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.science_rounded, color: _accent, size: 34),
                      SizedBox(height: 14),
                      Text(
                        'Test mode enabled',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      SizedBox(height: 8),
                      Text(
                        'Placeholder Epoint credentials are configured, so the button below will simulate a successful payment and publish the job directly.',
                        style: TextStyle(color: _muted, height: 1.45),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton(
                    onPressed: _isPublishing ? null : _showMockPaymentDialog,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _accent,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    child: _isPublishing
                        ? const SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.2,
                              color: Colors.white,
                            ),
                          )
                        : const Text(
                            'Epoint ilə Ödəniş Et',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w700,
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
  }

  Widget _buildMobileWebView() {
    return ClipRRect(
      borderRadius: BorderRadius.circular(24),
      child: Stack(
        children: [
          WebViewWidget(controller: _controller!),
          if (!_checkoutLoaded)
            const Positioned.fill(
              child: ColoredBox(
                color: _surface,
                child: Center(
                  child: CircularProgressIndicator(color: _accent),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildWebPlaceholder() {
    final paymentUrl = _buildPaymentUrl();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white10),
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(Icons.open_in_new_rounded, color: _accent, size: 34),
            const SizedBox(height: 14),
            const Text(
              'Web checkout opens in a new tab',
              style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 8),
            const Text(
              'The mobile WebView flow is disabled on web. Click the button below to launch the Epoint checkout in a separate tab.',
              style: TextStyle(color: _muted, height: 1.45),
            ),
            const SizedBox(height: 16),
            Text(
              paymentUrl,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: Colors.white70, fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPackageSelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Listing options',
          style: TextStyle(
              color: Colors.white, fontSize: 22, fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 8),
        const Text(
          'Choose the package before completing the Epoint payment flow.',
          style: TextStyle(color: _muted, height: 1.4),
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
                  onTap: () {
                    setState(() => _selectedPackage = option);
                    _reloadCheckout();
                  },
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
                          option.title,
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
                          option.description,
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
    final payload = _buildEpointPayload();
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
          const Text(
            'Epoint payload preview',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 10),
          _payloadRow('amount', payload['amount']?.toString() ?? '-'),
          _payloadRow('currency', payload['currency']?.toString() ?? '-'),
          _payloadRow('order_id', payload['order_id']?.toString() ?? '-'),
          _payloadRow('description', payload['description']?.toString() ?? '-'),
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

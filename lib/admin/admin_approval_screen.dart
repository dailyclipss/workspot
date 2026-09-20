import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AdminApprovalScreen extends StatefulWidget {
  const AdminApprovalScreen({super.key});

  @override
  State<AdminApprovalScreen> createState() => _AdminApprovalScreenState();
}

class _AdminApprovalScreenState extends State<AdminApprovalScreen> {
  static const _background = Color(0xFF0F172A);
  static const _surface = Color(0xFF1E293B);
  static const _muted = Color(0xFF94A3B8);
  static const _border = Color(0x33475569);

  List<Map<String, dynamic>> _requests = const [];
  Map<String, Map<String, dynamic>> _jobsById = const {};
  String? _errorMessage;
  String? _actionRequestId;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchPendingRequests();
  }

  Future<void> _fetchPendingRequests() async {
    if (mounted) {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });
    }

    try {
      final response = await Supabase.instance.client
          .from('payment_requests')
          .select()
          .eq('status', 'pending')
          .order('created_at', ascending: false);
      final requests = List<Map<String, dynamic>>.from(response);
      final jobIds = requests
          .map((request) => request['job_id']?.toString())
          .whereType<String>()
          .where((id) => id.isNotEmpty)
          .toSet()
          .toList();

      var jobsById = <String, Map<String, dynamic>>{};
      if (jobIds.isNotEmpty) {
        final jobsResponse = await Supabase.instance.client
            .from('jobs')
            .select('id, title, company_name')
            .inFilter('id', jobIds);
        jobsById = {
          for (final job in List<Map<String, dynamic>>.from(jobsResponse))
            job['id'].toString(): job,
        };
      }

      if (!mounted) return;
      setState(() {
        _requests = requests;
        _jobsById = jobsById;
        _isLoading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _errorMessage = 'Sorğular yüklənmədi: $error';
      });
    }
  }

  Future<void> _approvePayment(String requestId, String jobId) async {
    await _updatePayment(requestId, jobId, paymentStatus: 'approved');
  }

  Future<void> _rejectPayment(String requestId, String jobId) async {
    await _updatePayment(requestId, jobId, paymentStatus: 'rejected');
  }

  Future<void> _updatePayment(
    String requestId,
    String jobId, {
    required String paymentStatus,
  }) async {
    if (_actionRequestId != null) return;
    if (jobId.isEmpty) {
      _showMessage('Elan məlumatı tapılmadı.', isError: true);
      return;
    }

    setState(() => _actionRequestId = requestId);
    try {
      await Supabase.instance.client
          .from('payment_requests')
          .update({'status': paymentStatus}).eq('id', requestId);

      await Supabase.instance.client.from('jobs').update({
        'status': paymentStatus == 'approved' ? 'active' : 'rejected'
      }).eq('id', jobId);

      if (!mounted) return;
      _showMessage(
        paymentStatus == 'approved'
            ? 'Ödəniş təsdiqləndi və elan aktivləşdirildi.'
            : 'Ödəniş rədd edildi və elan rədd edildi.',
      );
      await _fetchPendingRequests();
    } catch (error) {
      if (!mounted) return;
      _showMessage('Əməliyyat uğursuz oldu: $error', isError: true);
    } finally {
      if (mounted) setState(() => _actionRequestId = null);
    }
  }

  void _showMessage(String message, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor:
              isError ? Colors.red.shade700 : Colors.green.shade700,
        ),
      );
  }

  Map<String, dynamic> _jobFor(Map<String, dynamic> request) {
    final jobId = request['job_id']?.toString() ?? '';
    return _jobsById[jobId] ?? const {};
  }

  String _text(dynamic value, String fallback) {
    final text = value?.toString().trim();
    return text == null || text.isEmpty ? fallback : text;
  }

  String _amount(dynamic value) {
    if (value is num) return '${value.toString()} ₼';
    return '${_text(value, '0')} ₼';
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
          'Ödəniş təsdiqləri',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        actions: [
          IconButton(
            tooltip: 'Yenilə',
            onPressed: _isLoading ? null : _fetchPendingRequests,
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoading && _requests.isEmpty) {
      return const Center(
        child: CircularProgressIndicator(color: Color(0xFF60A5FA)),
      );
    }

    if (_errorMessage != null && _requests.isEmpty) {
      return _StatusView(
        icon: Icons.cloud_off_rounded,
        message: _errorMessage!,
        actionLabel: 'Yenidən yoxla',
        onAction: _fetchPendingRequests,
      );
    }

    if (_requests.isEmpty) {
      return const _StatusView(
        icon: Icons.verified_rounded,
        message: 'Gözləyən ödəniş sorğusu yoxdur.',
      );
    }

    return RefreshIndicator(
      color: const Color(0xFF60A5FA),
      backgroundColor: _surface,
      onRefresh: _fetchPendingRequests,
      child: ListView.separated(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        itemCount: _requests.length,
        separatorBuilder: (_, __) => const SizedBox(height: 12),
        itemBuilder: (context, index) => _buildRequestCard(_requests[index]),
      ),
    );
  }

  Widget _buildRequestCard(Map<String, dynamic> request) {
    final requestId = request['id']?.toString() ?? '';
    final jobId = request['job_id']?.toString() ?? '';
    final job = _jobFor(request);
    final isUpdating = _actionRequestId == requestId;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: const Color(0xFF334155),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.receipt_long_rounded,
                  color: Color(0xFF60A5FA),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _text(request['package_name'], 'Standart Elan'),
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      _text(job['title'], 'Vakansiya'),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: _muted, fontSize: 13),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      _text(job['company_name'], 'Şirkət məlumatı yoxdur'),
                      style: const TextStyle(color: _muted, fontSize: 12),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Text(
                _amount(request['amount']),
                style: const TextStyle(
                  color: Color(0xFF86EFAC),
                  fontWeight: FontWeight.bold,
                  fontSize: 15,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _detailRow(
            Icons.numbers_rounded,
            'Köçürmə qeydi',
            _text(request['reference'] ?? request['transaction_note'],
                'Qeyd yoxdur'),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: isUpdating || requestId.isEmpty
                      ? null
                      : () => _rejectPayment(requestId, jobId),
                  icon: isUpdating && _actionRequestId == requestId
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Color(0xFFFCA5A5),
                          ),
                        )
                      : const Icon(Icons.close_rounded, size: 18),
                  label: const Text('Rədd et'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFFFCA5A5),
                    side: const BorderSide(color: Color(0xFFB91C1C)),
                    minimumSize: const Size(0, 46),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: isUpdating || requestId.isEmpty
                      ? null
                      : () => _approvePayment(requestId, jobId),
                  icon: isUpdating && _actionRequestId == requestId
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.check_rounded, size: 18),
                  label: const Text('Təsdiqlə'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF15803D),
                    foregroundColor: Colors.white,
                    minimumSize: const Size(0, 46),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _detailRow(IconData icon, String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: _muted, size: 17),
        const SizedBox(width: 8),
        Expanded(
          child: RichText(
            text: TextSpan(
              style: const TextStyle(color: _muted, fontSize: 12),
              children: [
                TextSpan(text: '$label: '),
                TextSpan(
                  text: value,
                  style: const TextStyle(color: Colors.white),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _StatusView extends StatelessWidget {
  final IconData icon;
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;

  const _StatusView({
    required this.icon,
    required this.message,
    this.actionLabel,
    this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: const Color(0xFF64748B), size: 48),
            const SizedBox(height: 14),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Color(0xFFCBD5E1), height: 1.4),
            ),
            if (actionLabel != null) ...[
              const SizedBox(height: 16),
              OutlinedButton(
                onPressed: onAction,
                child: Text(actionLabel!),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

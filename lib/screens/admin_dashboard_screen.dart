import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../admin/admin_approval_screen.dart';
import '../services/admin_auth_service.dart';
import '../services/job_location_resolver.dart';
import 'auth_screen.dart';
import 'home_map_screen.dart';

class AdminDashboardScreen extends StatefulWidget {
  final bool allowPasscodeOverride;

  const AdminDashboardScreen({super.key, this.allowPasscodeOverride = false});

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen> {
  static const _background = Color(0xFF09090B);
  static const _surface = Color(0xFF111113);
  static const _surfaceAlt = Color(0xFF16161A);
  static const _border = Color(0x3322222A);
  static const _muted = Color(0xFF9CA3AF);
  static const _accent = Color(0xFF38BDF8);
  static const _good = Color(0xFF22C55E);
  static const _warn = Color(0xFFF59E0B);
  static const _danger = Color(0xFFEF4444);

  final SupabaseClient _client = Supabase.instance.client;

  bool _isLoading = true;
  bool _isAuthorized = false;
  String? _errorMessage;
  String? _busyJobId;
  String? _adminLabel;
  List<Map<String, dynamic>> _jobs = const [];
  List<Map<String, dynamic>> _payments = const [];
  int _activeJobs = 0;
  int _pendingApprovals = 0;
  int _vipJobs = 0;
  double _monthlyRevenue = 0;

  @override
  void initState() {
    super.initState();
    _bootstrap();
  }
  Future<void> _bootstrap() async {
    final user = _client.auth.currentUser;
    _adminLabel = user?.email ?? user?.id;

    if (widget.allowPasscodeOverride) {
      if (!mounted) return;
      setState(() {
        _isAuthorized = true;
        _isLoading = true;
        _errorMessage = null;
      });
      await _loadDashboardData();
      return;
    }

    final isAdmin = await AdminAuthService.isAdminUser(_client);
    if (!isAdmin) {
      if (!mounted) return;
      setState(() {
        _isAuthorized = false;
        _isLoading = false;
      });
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(
            builder: (_) => const HomeMapScreen(
              flashMessage: 'Bu sahəyə giriş icazəniz yoxdur',
            ),
          ),
          (route) => false,
        );
      });
      return;
    }

    if (!mounted) return;
    setState(() {
      _isAuthorized = true;
      _isLoading = true;
      _errorMessage = null;
    });

    await _loadDashboardData();
  }

  Future<void> _logout() async {
    if (_busyJobId != null) return;

    try {
      await _client.auth.signOut();
    } catch (error) {
      debugPrint('Admin logout signOut failed: $error');
    }

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Admin panelindən çıxıldı')),
    );

    await Future<void>.delayed(const Duration(milliseconds: 250));
    if (!mounted) return;

    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const AuthScreen()),
      (route) => false,
    );
  }

  Future<void> _loadDashboardData() async {
    try {
      final jobsResponse = await _client.from('jobs').select('*').order('created_at', ascending: false);
      final paymentsResponse = await _client
          .from('transactions')
          .select()
          .order('created_at', ascending: false)
          .limit(50);

      final jobs = List<Map<String, dynamic>>.from(jobsResponse);
      final payments = List<Map<String, dynamic>>.from(paymentsResponse);
      final jobsById = <String, Map<String, dynamic>>{
        for (final job in jobs) job['id'].toString(): job,
      };

      final now = DateTime.now();
      final monthStart = DateTime(now.year, now.month, 1);
      final nextMonth = now.month == 12
          ? DateTime(now.year + 1, 1, 1)
          : DateTime(now.year, now.month + 1, 1);

      final monthlyPayments = payments.where((payment) {
        final createdAt = DateTime.tryParse(payment['created_at']?.toString() ?? '');
        final status = payment['status']?.toString().toLowerCase() ?? '';
        final targetType = payment['target_type']?.toString();
        if (createdAt == null) return false;
        final inMonth = !createdAt.isBefore(monthStart) && createdAt.isBefore(nextMonth);
        final isCompleted = status == 'completed' || status == 'approved';
        final isB2B = targetType == null || targetType != 'proSubscription';
        return inMonth && isCompleted && isB2B;
      }).toList();

      final activeJobs = jobs.where((job) => _jobAdStatus(job) == 'active' || _jobBool(job['is_vip'])).length;
      final pendingApprovals = jobs.where((job) => _isPendingJob(job)).length;
      final vipJobs = jobs.where((job) => _jobBool(job['is_vip'])).length;
      final monthlyRevenue = monthlyPayments.fold<double>(0, (sum, payment) {
        final amount = _parseAmount(payment['amount']);
        return sum + amount;
      });

      final recentPayments = monthlyPayments.map((payment) {
        final targetId = payment['target_id']?.toString() ?? '';
        final linkedJob = jobsById[targetId];
        return <String, dynamic>{
          ...payment,
          'company_name': linkedJob == null
              ? payment['package_name']?.toString() ?? 'N/A'
              : _jobBusinessName(linkedJob),
          'resolved_target': linkedJob,
        };
      }).toList();

      if (!mounted) return;
      setState(() {
        _jobs = jobs;
        _payments = recentPayments;
        _activeJobs = activeJobs;
        _pendingApprovals = pendingApprovals;
        _vipJobs = vipJobs;
        _monthlyRevenue = monthlyRevenue;
        _isLoading = false;
        _errorMessage = null;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _errorMessage = 'Dashboard məlumatları yüklənmədi: $error';
        _isLoading = false;
      });
    }
  }

  String _jobText(Map<String, dynamic> job, String key, String fallback) {
    final text = job[key]?.toString().trim();
    return text == null || text.isEmpty ? fallback : text;
  }

  String _jobBusinessName(Map<String, dynamic> job) {
    return _jobText(job, 'business_name', _jobText(job, 'company_name', _jobText(job, 'title', 'Şirkət')));
  }

  String _jobCategory(Map<String, dynamic> job) => _jobText(job, 'category', '—');

  String _jobDistrict(Map<String, dynamic> job) => _jobText(job, 'district', '—');

  String _jobAdStatus(Map<String, dynamic> job) {
    return _jobText(job, 'ad_status', _jobText(job, 'status', 'pending_payment')).toLowerCase();
  }

  bool _jobHasVacancy(Map<String, dynamic> job) {
    final value = job['has_vacancy'] ?? job['is_vacancy'] ?? true;
    if (value is bool) return value;
    final normalized = value.toString().trim().toLowerCase();
    return ['true', '1', 'yes', 'y'].contains(normalized);
  }

  bool _jobBool(dynamic value) {
    if (value is bool) return value;
    return ['true', '1', 'yes', 'y'].contains(value?.toString().toLowerCase().trim());
  }

  bool _isPendingJob(Map<String, dynamic> job) {
    final status = _jobAdStatus(job);
    return status == 'pending';
  }

  double _parseAmount(dynamic value) {
    if (value is num) return value.toDouble();
    return double.tryParse(value?.toString() ?? '') ?? 0;
  }

  String _formatAmount(double amount) {
    final text = amount % 1 == 0 ? amount.toStringAsFixed(0) : amount.toStringAsFixed(2);
    return '$text ₼';
  }

  String _formatDate(dynamic value) {
    final date = DateTime.tryParse(value?.toString() ?? '');
    if (date == null) return '—';
    final day = date.day.toString().padLeft(2, '0');
    final month = date.month.toString().padLeft(2, '0');
    return '$day.$month.${date.year}';
  }

  Color _statusColor(String status) {
    if (status == 'active') return _good;
    if (status == 'rejected') return _danger;
    return _warn;
  }

  String _statusLabel(String status) {
    if (status == 'active') return 'Active';
    if (status == 'rejected') return 'Rejected';
    if (status == 'pending_payment') return 'Pending Payment';
    return status;
  }

  void _recalculateJobMetrics(List<Map<String, dynamic>> jobs) {
    _activeJobs = jobs.where((job) => _jobAdStatus(job) == 'active' || _jobBool(job['is_vip'])).length;
    _pendingApprovals = jobs.where((job) => _isPendingJob(job)).length;
    _vipJobs = jobs.where((job) => _jobBool(job['is_vip'])).length;
  }

  void _replaceJobLocally(String jobId, Map<String, dynamic> patch) {
    final updatedJobs = _jobs.map((job) {
      if (job['id'].toString() != jobId) return job;
      return <String, dynamic>{...job, ...patch};
    }).toList();

    setState(() {
      _jobs = updatedJobs;
      _recalculateJobMetrics(updatedJobs);
    });
  }

  Future<void> _persistJobPatch(
    String jobId,
    Map<String, dynamic> payload, {
    Map<String, dynamic>? fallbackPayload,
  }) async {
    try {
      await _client.from('jobs').update(payload).eq('id', jobId);
    } catch (error) {
      if (fallbackPayload == null) rethrow;

      final needsFallback = error.toString().toLowerCase().contains('pgrst204') ||
          error.toString().toLowerCase().contains('has_vacancy') ||
          error.toString().toLowerCase().contains('is_vacancy');
      if (!needsFallback) rethrow;

      await _client.from('jobs').update(fallbackPayload).eq('id', jobId);
    }
  }

  Map<String, dynamic> _mergeJobWithFallbackCoordinates(
    Map<String, dynamic> job,
    Map<String, dynamic> payload,
  ) {
    final merged = <String, dynamic>{...job, ...payload};
    final resolved = JobLocationResolver.resolve(
      district: merged['district']?.toString(),
      address: merged['address']?.toString(),
      latitude: merged['latitude'] is num ? (merged['latitude'] as num).toDouble() : double.tryParse(merged['latitude']?.toString() ?? ''),
      longitude: merged['longitude'] is num ? (merged['longitude'] as num).toDouble() : double.tryParse(merged['longitude']?.toString() ?? ''),
    );
    merged['latitude'] = resolved.latitude;
    merged['longitude'] = resolved.longitude;
    return merged;
  }

  Future<void> _updateJob(
    String jobId,
    Map<String, dynamic> payload, {
    Map<String, dynamic>? baseJob,
  }) async {
    if (_busyJobId != null) return;
    setState(() => _busyJobId = jobId);
    try {
      final jobPayload = baseJob == null ? payload : _mergeJobWithFallbackCoordinates(baseJob, payload);
      await _persistJobPatch(jobId, jobPayload, fallbackPayload: jobPayload.containsKey('is_vacancy') || jobPayload.containsKey('has_vacancy')
          ? Map<String, dynamic>.from(jobPayload)
          : null);
      await _loadDashboardData();
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Əməliyyat uğursuz oldu: $error'), backgroundColor: _danger),
      );
    } finally {
      if (mounted) setState(() => _busyJobId = null);
    }
  }

  Future<void> _toggleVip(Map<String, dynamic> job, bool value) async {
    await _updateJob(job['id'].toString(), {
      'is_vip': value,
      'ad_status': value ? 'vip' : 'active',
      'status': value ? 'vip' : 'active',
    }, baseJob: job);
  }

  Future<void> _toggleVacancy(Map<String, dynamic> job, bool value) async {
    final jobId = job['id'].toString();
    final previousJob = Map<String, dynamic>.from(job);

    _replaceJobLocally(jobId, {
      'has_vacancy': value,
      'is_vacancy': value,
    });

    if (mounted) {
      setState(() => _busyJobId = jobId);
    }

    try {
      await _persistJobPatch(
        jobId,
        {'is_vacancy': value},
        fallbackPayload: {'has_vacancy': value},
      );
      await _loadDashboardData();
    } catch (error) {
      if (!mounted) return;
      _replaceJobLocally(jobId, previousJob);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Vacancy yenilənmədi: $error'), backgroundColor: _danger),
      );
    } finally {
      if (mounted) setState(() => _busyJobId = null);
    }
  }

  Future<void> _setAdStatus(Map<String, dynamic> job, String status) async {
    await _updateJob(job['id'].toString(), {
      'ad_status': status,
      'status': status,
    }, baseJob: job);
  }

  Future<void> _deleteJob(Map<String, dynamic> job) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: _surface,
        title: const Text('Elanı silmək istəyirsiniz?'),
        content: Text(_jobBusinessName(job)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('Ləğv et')),
          ElevatedButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            style: ElevatedButton.styleFrom(backgroundColor: _danger),
            child: const Text('Sil'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await _updateJob(job['id'].toString(), {
      'ad_status': 'deleted',
      'status': 'deleted',
    }, baseJob: job);
  }

  Future<void> _openEditJobSheet(Map<String, dynamic> job) async {
    final jobId = job['id'].toString();
    final businessController = TextEditingController(text: _jobBusinessName(job));
    final categoryController = TextEditingController(text: _jobCategory(job));
    final districtController = TextEditingController(text: _jobDistrict(job));
    final addressController = TextEditingController(text: _jobText(job, 'address', ''));
    final phoneController = TextEditingController(text: _jobText(job, 'phone_whatsapp', ''));
    final instagramController = TextEditingController(text: _jobText(job, 'instagram', ''));
    final contactController = TextEditingController(text: _jobText(job, 'contact_person', ''));
    final formKey = GlobalKey<FormState>();
    String adStatus = _jobAdStatus(job);
    bool hasVacancy = _jobHasVacancy(job);
    bool isVip = _jobBool(job['is_vip']);

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        return DraggableScrollableSheet(
          initialChildSize: 0.88,
          minChildSize: 0.65,
          maxChildSize: 0.96,
          builder: (context, controller) {
            return Container(
              decoration: const BoxDecoration(
                color: _background,
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
              ),
              child: StatefulBuilder(
                builder: (context, setSheetState) {
                  return SingleChildScrollView(
                    controller: controller,
                    padding: EdgeInsets.fromLTRB(
                      20,
                      10,
                      20,
                      20 + MediaQuery.of(context).viewInsets.bottom,
                    ),
                    child: Form(
                      key: formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Center(
                            child: Container(
                              width: 42,
                              height: 4,
                              decoration: BoxDecoration(
                                color: Colors.white24,
                                borderRadius: BorderRadius.circular(999),
                              ),
                            ),
                          ),
                          const SizedBox(height: 18),
                          const Text(
                            'Elanı redaktə et',
                            style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w800),
                          ),
                          const SizedBox(height: 16),
                          _sheetField(businessController, 'Biznes adı'),
                          const SizedBox(height: 12),
                          _sheetField(categoryController, 'Kateqoriya'),
                          const SizedBox(height: 12),
                          _sheetField(districtController, 'Rayon'),
                          const SizedBox(height: 12),
                          _sheetField(addressController, 'Ünvan'),
                          const SizedBox(height: 12),
                          _sheetField(phoneController, 'Telefon / WhatsApp'),
                          const SizedBox(height: 12),
                          _sheetField(instagramController, 'Instagram'),
                          const SizedBox(height: 12),
                          _sheetField(contactController, 'Kontakt şəxsi'),
                          const SizedBox(height: 12),
                          DropdownButtonFormField<String>(
                            initialValue: adStatus,
                            dropdownColor: _surface,
                            decoration: _sheetDecoration('Ad status'),
                            items: const [
                              DropdownMenuItem(value: 'pending_payment', child: Text('pending_payment')),
                              DropdownMenuItem(value: 'active', child: Text('active')),
                              DropdownMenuItem(value: 'rejected', child: Text('rejected')),
                            ],
                            onChanged: (value) => setSheetState(() => adStatus = value ?? adStatus),
                          ),
                          const SizedBox(height: 8),
                          SwitchListTile.adaptive(
                            contentPadding: EdgeInsets.zero,
                            value: hasVacancy,
                            onChanged: (value) => setSheetState(() => hasVacancy = value),
                            title: const Text('Has Vacancy', style: TextStyle(color: Colors.white)),
                          ),
                          SwitchListTile.adaptive(
                            contentPadding: EdgeInsets.zero,
                            value: isVip,
                            onChanged: (value) => setSheetState(() => isVip = value),
                            title: const Text('VIP Status', style: TextStyle(color: Colors.white)),
                          ),
                          const SizedBox(height: 12),
                          SizedBox(
                            width: double.infinity,
                            height: 52,
                            child: ElevatedButton(
                              onPressed: _busyJobId != null
                                  ? null
                                  : () async {
                                      final navigator = Navigator.of(sheetContext);
                                      if (!formKey.currentState!.validate()) return;
                                      await _updateJob(jobId, {
                                        'business_name': businessController.text.trim(),
                                        'company_name': businessController.text.trim(),
                                        'category': categoryController.text.trim(),
                                        'district': districtController.text.trim(),
                                        'address': addressController.text.trim(),
                                        'phone_whatsapp': phoneController.text.trim(),
                                        'instagram': instagramController.text.trim(),
                                        'contact_person': contactController.text.trim(),
                                        'ad_status': adStatus,
                                        'status': adStatus,
                                        'has_vacancy': hasVacancy,
                                        'is_vip': isVip,
                                      }, baseJob: job);
                                      if (mounted) navigator.pop();
                                    },
                              style: ElevatedButton.styleFrom(backgroundColor: _accent),
                              child: const Text('Yadda saxla'),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            );
          },
        );
      },
    );

    businessController.dispose();
    categoryController.dispose();
    districtController.dispose();
    addressController.dispose();
    phoneController.dispose();
    instagramController.dispose();
    contactController.dispose();
  }

  InputDecoration _sheetDecoration(String label) {
    return InputDecoration(
      labelText: label,
      labelStyle: const TextStyle(color: _muted),
      filled: true,
      fillColor: _surface,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: _border),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: _accent, width: 1.2),
      ),
    );
  }

  Widget _sheetField(TextEditingController controller, String label) {
    return TextFormField(
      controller: controller,
      style: const TextStyle(color: Colors.white),
      decoration: _sheetDecoration(label),
      validator: (value) {
        if (label == 'Instagram' || label == 'Kontakt şəxsi' || label == 'Telefon / WhatsApp') return null;
        return value == null || value.trim().isEmpty ? 'Tələb olunur' : null;
      },
    );
  }

  Widget _buildMetricCard({
    required String label,
    required String value,
    required IconData icon,
    required Color accent,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: accent.withValues(alpha: 0.28)),
        boxShadow: const [
          BoxShadow(color: Color(0x22000000), blurRadius: 18, offset: Offset(0, 8)),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: accent.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(icon, color: accent),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: const TextStyle(color: _muted, fontSize: 12.5)),
                const SizedBox(height: 6),
                Text(value, style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w800)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildJobsSection() {
    final wide = MediaQuery.of(context).size.width >= 900;
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: _border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Vacancy Management', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w800)),
                    SizedBox(height: 4),
                    Text('jobs table ilə elanlara sürətli nəzarət', style: TextStyle(color: _muted, fontSize: 12.5)),
                  ],
                ),
              ),
              TextButton.icon(
                onPressed: () {
                  Navigator.push(context, MaterialPageRoute(builder: (_) => const AdminApprovalScreen()));
                },
                icon: const Icon(Icons.receipt_long_rounded),
                label: const Text('Pending approvals'),
              ),
            ],
          ),
          const SizedBox(height: 14),
          if (wide) _buildJobsTable() else _buildJobsCards(),
        ],
      ),
    );
  }

  Widget _buildJobsTable() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: DataTable(
        headingRowColor: const WidgetStatePropertyAll(_surfaceAlt),
        dataRowColor: const WidgetStatePropertyAll(_surface),
        columnSpacing: 18,
        columns: const [
          DataColumn(label: Text('Business Name')),
          DataColumn(label: Text('Category')),
          DataColumn(label: Text('District')),
          DataColumn(label: Text('Ad Status')),
          DataColumn(label: Text('Has Vacancy')),
          DataColumn(label: Text('Actions')),
        ],
        rows: _jobs.map((job) {
          final jobId = job['id'].toString();
          final isBusy = _busyJobId == jobId;
          final status = _jobAdStatus(job);
          return DataRow(
            cells: [
              DataCell(Text(_jobBusinessName(job), style: const TextStyle(color: Color(0xDEFFFFFF), fontWeight: FontWeight.w600))),
              DataCell(Text(_jobCategory(job), style: const TextStyle(color: Color(0xDEFFFFFF), fontWeight: FontWeight.w600))),
              DataCell(Text(_jobDistrict(job), style: const TextStyle(color: Color(0xDEFFFFFF), fontWeight: FontWeight.w600))),
              DataCell(_StatusChip(label: _statusLabel(status), color: _statusColor(status))),
              DataCell(
                Switch.adaptive(
                  value: _jobHasVacancy(job),
                  onChanged: isBusy ? null : (value) => _toggleVacancy(job, value),
                ),
              ),
              DataCell(
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _TinyAction(
                        tooltip: 'Approve',
                        icon: Icons.check_rounded,
                        color: _good,
                        enabled: !isBusy,
                        onPressed: () => _setAdStatus(job, 'active'),
                      ),
                      const SizedBox(width: 6),
                      _TinyAction(
                        tooltip: 'Reject',
                        icon: Icons.close_rounded,
                        color: _danger,
                        enabled: !isBusy,
                        onPressed: () => _setAdStatus(job, 'rejected'),
                      ),
                      const SizedBox(width: 6),
                      _TinyAction(
                        tooltip: 'VIP',
                        icon: _jobBool(job['is_vip']) ? Icons.workspace_premium_rounded : Icons.workspace_premium_outlined,
                        color: _warn,
                        enabled: !isBusy,
                        onPressed: () => _toggleVip(job, !_jobBool(job['is_vip'])),
                      ),
                      const SizedBox(width: 6),
                      _TinyAction(
                        tooltip: 'Edit',
                        icon: Icons.edit_rounded,
                        color: _accent,
                        enabled: !isBusy,
                        onPressed: () => _openEditJobSheet(job),
                      ),
                      const SizedBox(width: 6),
                      _TinyAction(
                        tooltip: 'Delete',
                        icon: Icons.delete_outline_rounded,
                        color: _danger,
                        enabled: !isBusy,
                        onPressed: () => _deleteJob(job),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          );
        }).toList(),
      ),
    );
  }

  Widget _buildJobsCards() {
    return Column(
      children: _jobs.map((job) {
        final jobId = job['id'].toString();
        final isBusy = _busyJobId == jobId;
        final status = _jobAdStatus(job);
        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: _surfaceAlt,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: _border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(_jobBusinessName(job), style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w800)),
                        const SizedBox(height: 4),
                        Text('${_jobCategory(job)} • ${_jobDistrict(job)}', style: const TextStyle(color: _muted, fontSize: 12.5)),
                      ],
                    ),
                  ),
                  _StatusChip(label: _statusLabel(status), color: _statusColor(status)),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: SwitchListTile.adaptive(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Vacancy', style: TextStyle(color: Colors.white, fontSize: 13)),
                      value: _jobHasVacancy(job),
                      onChanged: isBusy ? null : (value) => _toggleVacancy(job, value),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: SwitchListTile.adaptive(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('VIP', style: TextStyle(color: Colors.white, fontSize: 13)),
                      value: _jobBool(job['is_vip']),
                      onChanged: isBusy ? null : (value) => _toggleVip(job, value),
                    ),
                  ),
                ],
              ),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _ActionPill(label: 'Approve', color: _good, onTap: isBusy ? null : () => _setAdStatus(job, 'active')),
                  _ActionPill(label: 'Reject', color: _danger, onTap: isBusy ? null : () => _setAdStatus(job, 'rejected')),
                  _ActionPill(label: 'Edit', color: _accent, onTap: isBusy ? null : () => _openEditJobSheet(job)),
                  _ActionPill(label: 'Delete', color: _danger, onTap: isBusy ? null : () => _deleteJob(job)),
                ],
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _buildPaymentsSection() {
    final wide = MediaQuery.of(context).size.width >= 900;
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: _border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('B2B Payments & Subscriptions', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w800)),
          const SizedBox(height: 4),
          const Text('recent package purchases', style: TextStyle(color: _muted, fontSize: 12.5)),
          const SizedBox(height: 14),
          if (wide) _buildPaymentsTable() else _buildPaymentsCards(),
        ],
      ),
    );
  }

  Widget _buildPaymentsTable() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: DataTable(
        headingRowColor: const WidgetStatePropertyAll(_surfaceAlt),
        dataRowColor: const WidgetStatePropertyAll(_surface),
        columnSpacing: 18,
        columns: const [
          DataColumn(label: Text('Package Name')),
          DataColumn(label: Text('Amount')),
          DataColumn(label: Text('Date')),
          DataColumn(label: Text('Company')),
          DataColumn(label: Text('Status')),
        ],
        rows: _payments.map((payment) {
          final status = payment['status']?.toString().toLowerCase() ?? '';
          return DataRow(
            cells: [
              DataCell(Text(payment['package_name']?.toString() ?? '—')),
              DataCell(Text(_formatAmount(_parseAmount(payment['amount'])))),
              DataCell(Text(_formatDate(payment['created_at']))),
              DataCell(Text(payment['company_name']?.toString() ?? '—')),
              DataCell(_StatusChip(label: _statusLabel(status), color: _statusColor(status))),
            ],
          );
        }).toList(),
      ),
    );
  }

  Widget _buildPaymentsCards() {
    return Column(
      children: _payments.map((payment) {
        final status = payment['status']?.toString().toLowerCase() ?? '';
        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: _surfaceAlt,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: _border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      payment['package_name']?.toString() ?? '—',
                      style: const TextStyle(color: Colors.white, fontSize: 15.5, fontWeight: FontWeight.w800),
                    ),
                  ),
                  _StatusChip(label: _statusLabel(status), color: _statusColor(status)),
                ],
              ),
              const SizedBox(height: 10),
              _infoLine('Amount', _formatAmount(_parseAmount(payment['amount']))),
              _infoLine('Date', _formatDate(payment['created_at'])),
              _infoLine('Company', payment['company_name']?.toString() ?? '—'),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _infoLine(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          SizedBox(width: 70, child: Text(label, style: const TextStyle(color: _muted, fontSize: 12))),
          Expanded(child: Text(value, style: const TextStyle(color: Colors.white, fontSize: 12.8, fontWeight: FontWeight.w600))),
        ],
      ),
    );
  }

  Widget _buildAccessDenied() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 460),
          child: Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: _surface,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: _border),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(
                    color: _danger.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: const Icon(Icons.lock_rounded, color: _danger, size: 34),
                ),
                const SizedBox(height: 16),
                const Text('Admin access required', style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w800)),
                const SizedBox(height: 8),
                const Text(
                  'This panel is only available for admin users. Set the user role to admin in Supabase app_metadata or whitelist the email in the dashboard screen.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: _muted, height: 1.4),
                ),
                const SizedBox(height: 14),
                Text('Signed in as: ${_adminLabel ?? 'unknown'}', textAlign: TextAlign.center, style: const TextStyle(color: Colors.white70, fontSize: 12.5)),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton(
                    onPressed: () => Navigator.pop(context),
                    style: ElevatedButton.styleFrom(backgroundColor: _accent),
                    child: const Text('Back'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildContent() {
    final width = MediaQuery.of(context).size.width;
    final metricWidth = width >= 1200 ? (width - 48 - 48) / 4 : width >= 700 ? (width - 48 - 16) / 2 : width - 32;
    final isWide = width >= 1100;

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF18181B), Color(0xFF0F172A)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: _border),
            ),
            child: Row(
              children: [
                Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    color: _accent.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: const Icon(Icons.dashboard_rounded, color: _accent),
                ),
                const SizedBox(width: 14),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Admin Dashboard', style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w900)),
                      SizedBox(height: 6),
                      Text('System management, jobs approvals and B2B revenue overview.', style: TextStyle(color: _muted, height: 1.35)),
                    ],
                  ),
                ),
                TextButton.icon(
                  onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AdminApprovalScreen())),
                  icon: const Icon(Icons.receipt_long_rounded),
                  label: const Text('Approvals'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 16,
            runSpacing: 16,
            children: [
              SizedBox(width: metricWidth, child: _buildMetricCard(label: 'Total Active Jobs', value: '$_activeJobs', icon: Icons.work_rounded, accent: _accent)),
              SizedBox(width: metricWidth, child: _buildMetricCard(label: 'Pending Approvals', value: '$_pendingApprovals', icon: Icons.hourglass_top_rounded, accent: _warn)),
              SizedBox(width: metricWidth, child: _buildMetricCard(label: 'VIP Jobs', value: '$_vipJobs', icon: Icons.workspace_premium_rounded, accent: _good)),
              SizedBox(width: metricWidth, child: _buildMetricCard(label: 'Monthly B2B Revenue', value: _formatAmount(_monthlyRevenue), icon: Icons.payments_rounded, accent: _danger)),
            ],
          ),
          const SizedBox(height: 18),
          if (isWide)
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(flex: 2, child: _buildJobsSection()),
                const SizedBox(width: 16),
                Expanded(flex: 1, child: _buildPaymentsSection()),
              ],
            )
          else ...[
            _buildJobsSection(),
            const SizedBox(height: 16),
            _buildPaymentsSection(),
          ],
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
        title: const Text('Admin Dashboard', style: TextStyle(fontWeight: FontWeight.bold)),
        actions: [
          TextButton.icon(
            onPressed: _isLoading ? null : _logout,
            icon: const Icon(Icons.logout_rounded, color: Colors.white, size: 18),
            label: const Text('Çıxış', style: TextStyle(color: Colors.white)),
            style: TextButton.styleFrom(
              foregroundColor: Colors.white,
              backgroundColor: Colors.white.withValues(alpha: 0.08),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
            ),
          ),
          const SizedBox(width: 8),
          IconButton(
            tooltip: 'Refresh',
            onPressed: _isLoading ? null : _bootstrap,
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: _accent))
          : !_isAuthorized
              ? _buildAccessDenied()
              : _errorMessage != null && _jobs.isEmpty
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.cloud_off_rounded, color: _danger, size: 40),
                            const SizedBox(height: 12),
                            Text(_errorMessage!, textAlign: TextAlign.center, style: const TextStyle(color: Colors.white)),
                            const SizedBox(height: 16),
                            ElevatedButton(onPressed: _bootstrap, child: const Text('Retry')),
                          ],
                        ),
                      ),
                    )
                  : _buildContent(),
    );
  }
}

class _StatusChip extends StatelessWidget {
  final String label;
  final Color color;

  const _StatusChip({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.28)),
      ),
      child: Text(label, style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w700)),
    );
  }
}

class _ActionPill extends StatelessWidget {
  final String label;
  final Color color;
  final VoidCallback? onTap;

  const _ActionPill({required this.label, required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return OutlinedButton(
      onPressed: onTap,
      style: OutlinedButton.styleFrom(
        foregroundColor: Colors.white,
        side: BorderSide(color: color.withValues(alpha: 0.38)),
        backgroundColor: color.withValues(alpha: 0.08),
      ),
      child: Text(label),
    );
  }
}

class _TinyAction extends StatelessWidget {
  final String tooltip;
  final IconData icon;
  final Color color;
  final bool enabled;
  final VoidCallback onPressed;

  const _TinyAction({
    required this.tooltip,
    required this.icon,
    required this.color,
    required this.enabled,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return InkResponse(
      radius: 18,
      onTap: enabled ? onPressed : null,
      child: Tooltip(
        message: tooltip,
        child: Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: color.withValues(alpha: 0.28)),
          ),
          child: Icon(icon, color: color, size: 18),
        ),
      ),
    );
  }
}
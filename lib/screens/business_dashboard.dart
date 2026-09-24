import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../services/app_language.dart';
import '../services/payment_service.dart';
import 'add_job_screen.dart';
import 'home_map_screen.dart';
import 'payment_checkout_screen.dart';

class BusinessDashboardScreen extends StatefulWidget {
  const BusinessDashboardScreen({super.key});

  @override
  State<BusinessDashboardScreen> createState() =>
      _BusinessDashboardScreenState();
}

class _BusinessDashboardScreenState extends State<BusinessDashboardScreen> {
  static const _background = Color(0xFF0F172A);
  static const _surface = Color(0xFF1E293B);
  static const _muted = Color(0xFF94A3B8);
  static const _blue = Color(0xFF2563EB);

  bool _isLoading = true;
  List<Map<String, dynamic>> _activeJobs = [];
  int _totalApplications = 0;

  @override
  void initState() {
    super.initState();
    appLang.addListener(_onLanguageChanged);
    _fetchDashboardData();
  }

  @override
  void dispose() {
    appLang.removeListener(_onLanguageChanged);
    super.dispose();
  }

  void _onLanguageChanged() {
    if (mounted) setState(() {});
  }

  Future<void> _fetchDashboardData() async {
    setState(() => _isLoading = true);
    try {
      final jobs = await Supabase.instance.client
          .from('jobs')
          .select()
          .eq('status', 'active');
      final applications =
          await Supabase.instance.client.from('applications').select('id');

      if (!mounted) return;
      setState(() {
        _activeJobs = List<Map<String, dynamic>>.from(jobs);
        _totalApplications = List<dynamic>.from(applications).length;
        _isLoading = false;
      });
    } catch (error) {
      debugPrint('Business dashboard y\u00fckl\u0259nm\u0259di: $error');
      if (!mounted) return;
      setState(() => _isLoading = false);
    }
  }

  Future<void> _openAddJob() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const AddJobScreen()),
    );
    if (mounted) await _fetchDashboardData();
  }

  void _openUpgrade() {
    final userId = Supabase.instance.client.auth.currentUser?.id ?? '';
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => PaymentCheckoutScreen(
          targetId: userId,
          targetType: PaymentTargetType.company,
        ),
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
        title: Text(appLang.translate('business_dashboard'),
            style: const TextStyle(fontWeight: FontWeight.bold)),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _fetchDashboardData,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
                children: [
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: ElevatedButton.icon(
                      onPressed: _openAddJob,
                      icon: const Icon(Icons.add_circle_outline_rounded,
                          color: Colors.white),
                      label: Text(appLang.translate('post_new_job'),
                          style: const TextStyle(
                              color: Colors.white, fontWeight: FontWeight.bold)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _blue,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14)),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  Text(appLang.translate('my_active_jobs'),
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold)),
                  const SizedBox(height: 10),
                  if (_activeJobs.isEmpty)
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: _surface,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Text(appLang.translate('no_jobs_found'),
                          style: const TextStyle(color: _muted)),
                    )
                  else
                    ..._activeJobs.map(_buildJobTile),
                  const SizedBox(height: 24),
                  Text(appLang.translate('analytics_title'),
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold)),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                          child: _buildStatCard(
                              appLang.translate('total_views'), '0')),
                      const SizedBox(width: 10),
                      Expanded(
                          child: _buildStatCard(
                              appLang.translate('total_applications'),
                              '$_totalApplications')),
                      const SizedBox(width: 10),
                      Expanded(
                          child: _buildStatCard(
                              appLang.translate('contact_views'), '0')),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFFFFE066), Color(0xFFB8860B)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.workspace_premium_rounded,
                            color: Colors.white),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            appLang.translate('upgrade_for_analytics'),
                            style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w600,
                                fontSize: 13),
                          ),
                        ),
                        TextButton(
                          onPressed: _openUpgrade,
                          child: const Text('Pro',
                              style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold)),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: () => Navigator.pushReplacement(
                        context,
                        MaterialPageRoute(builder: (_) => const HomeMapScreen()),
                      ),
                      icon: const Icon(Icons.map_rounded, color: Colors.white),
                      label: Text(appLang.translate('switch_to_map'),
                          style: const TextStyle(color: Colors.white)),
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: Colors.white24),
                        minimumSize: const Size(0, 48),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildJobTile(Map<String, dynamic> job) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(job['title']?.toString() ?? 'Vakansiya',
                    style: const TextStyle(
                        color: Colors.white, fontWeight: FontWeight.bold)),
                const SizedBox(height: 2),
                Text(job['company_name']?.toString() ?? '',
                    style: const TextStyle(color: _muted, fontSize: 12)),
              ],
            ),
          ),
          Text('${job['salary_amount'] ?? job['salary'] ?? 0}',
              style: const TextStyle(
                  color: Color(0xFF60A5FA), fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  Widget _buildStatCard(String label, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        children: [
          Text(value,
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          Text(label,
              textAlign: TextAlign.center,
              style: const TextStyle(color: _muted, fontSize: 11)),
        ],
      ),
    );
  }
}

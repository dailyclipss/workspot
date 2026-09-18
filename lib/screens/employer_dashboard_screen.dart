import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class EmployerDashboardScreen extends StatefulWidget {
  const EmployerDashboardScreen({Key? key}) : super(key: key);

  @override
  State<EmployerDashboardScreen> createState() => _EmployerDashboardScreenState();
}

class _EmployerDashboardScreenState extends State<EmployerDashboardScreen> {
  List<Map<String, dynamic>> _applications = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchEmployerApplications();
  }

  // İşəgötürənin elanlarına gələn müraciətləri Supabase-dən çəkmək
  Future<void> _fetchEmployerApplications() async {
    try {
      final response = await Supabase.instance.client
          .from('applications')
          .select('*, jobs(*)');

      if (mounted) {
        setState(() {
          _applications = List<Map<String, dynamic>>.from(response);
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Müraciətlər yüklənmədi: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // Namizədin statusunu dəyişmək ("Müsahibəyə dəvət et" və ya "İmtina")
  Future<void> _updateStatus(String appId, String newStatus) async {
    try {
      await Supabase.instance.client
          .from('applications')
          .update({'status': newStatus})
          .eq('id', appId);

      _fetchEmployerApplications(); // Yenilənmiş siyahını gətiririk

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Status "$newStatus" olaraq dəyişdirildi')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Xəta baş verdi: $e')),
      );
    }
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'Müsahibəyə dəvət et':
      case 'Qəbul edildi':
        return Colors.green;
      case 'İmtina':
        return Colors.red;
      case 'Baxıldı':
        return Colors.blue;
      default:
        return Colors.orange;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text('İşəgötürən Paneli', style: TextStyle(color: Color(0xFF0F172A), fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: Color(0xFF0F172A)),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _applications.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.people_outline, size: 64, color: Colors.grey.shade400),
                      const SizedBox(height: 16),
                      Text('Gələn müraciət tapılmadı', style: TextStyle(fontSize: 15, color: Colors.grey.shade600)),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _applications.length,
                  itemBuilder: (context, index) {
                    final app = _applications[index];
                    final job = app['jobs'] ?? {};
                    final status = app['status'] ?? 'Gözləmədə';

                    return Card(
                      margin: const EdgeInsets.only(bottom: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                      elevation: 0,
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Expanded(
                                  child: Text(
                                    job['title'] ?? 'Vakansiya',
                                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Color(0xFF0F172A)),
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: _getStatusColor(status).withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text(
                                    status,
                                    style: TextStyle(color: _getStatusColor(status), fontWeight: FontWeight.bold, fontSize: 12),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Text('Namizəd: İş Axtaran Namizəd', style: TextStyle(color: Colors.grey.shade700, fontSize: 14, fontWeight: FontWeight.w500)),
                            Text('Maaş: ${job['salary_amount'] ?? 0} AZN', style: TextStyle(color: Colors.grey.shade600, fontSize: 13)),
                            const Divider(height: 24),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.end,
                              children: [
                                OutlinedButton(
                                  onPressed: () => _updateStatus(app['id'], 'İmtina'),
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: Colors.red,
                                    side: const BorderSide(color: Colors.red),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                  ),
                                  child: const Text('İmtina'),
                                ),
                                const SizedBox(width: 8),
                                ElevatedButton(
                                  onPressed: () => _updateStatus(app['id'], 'Müsahibəyə dəvət et'),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.green,
                                    elevation: 0,
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                  ),
                                  child: const Text('Dəvət et', style: TextStyle(color: Colors.white)),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
    );
  }
}
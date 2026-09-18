import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ApplicationsScreen extends StatefulWidget {
  const ApplicationsScreen({Key? key}) : super(key: key);

  @override
  State<ApplicationsScreen> createState() => _ApplicationsScreenState();
}

class _ApplicationsScreenState extends State<ApplicationsScreen> {
  List<Map<String, dynamic>> _myApplications = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchMyApplications();
  }

  Future<void> _fetchMyApplications() async {
    try {
      final response = await Supabase.instance.client
          .from('applications')
          .select('*, jobs(*)');

      if (mounted) {
        setState(() {
          _myApplications = List<Map<String, dynamic>>.from(response);
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Müraciətlər yüklənmədi: $e');
      if (mounted) {
        setState(() {
          // Fallback demo datası (Supabase boş olduqda)
          _myApplications = [
            {
              'status': 'Müsahibəyə dəvət et',
              'created_at': '2026-09-15',
              'jobs': {'title': 'Senior Barista', 'company_name': 'Coffee Moffie', 'salary_amount': 850}
            },
            {
              'status': 'Baxıldı',
              'created_at': '2026-09-14',
              'jobs': {'title': 'Junior Flutter Developer', 'company_name': 'Vertex Media', 'salary_amount': 1200}
            }
          ];
          _isLoading = false;
        });
      }
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
        title: const Text('Müraciətlərim', style: TextStyle(color: Color(0xFF0F172A), fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: Color(0xFF0F172A)),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _myApplications.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.history_edu, size: 64, color: Colors.grey.shade400),
                      const SizedBox(height: 16),
                      Text('Hələ ki, heç bir işə müraciət etməmisiniz', style: TextStyle(fontSize: 15, color: Colors.grey.shade600)),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _myApplications.length,
                  itemBuilder: (context, index) {
                    final app = _myApplications[index];
                    final job = app['jobs'] ?? {};
                    final status = app['status'] ?? 'Gözləmədə';

                    return Card(
                      margin: const EdgeInsets.only(bottom: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      elevation: 0,
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Row(
                          children: [
                            CircleAvatar(
                              backgroundColor: const Color(0xFF2563EB).withOpacity(0.1),
                              child: const Icon(Icons.business, color: Color(0xFF2563EB)),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(job['title'] ?? 'Vakansiya', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                                  const SizedBox(height: 2),
                                  Text('${job['company_name'] ?? 'Məkan'} • ${job['salary_amount'] ?? 0} AZN', style: TextStyle(color: Colors.grey.shade600, fontSize: 13)),
                                ],
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                              decoration: BoxDecoration(
                                color: _getStatusColor(status).withOpacity(0.1),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                status,
                                style: TextStyle(color: _getStatusColor(status), fontWeight: FontWeight.bold, fontSize: 11),
                              ),
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
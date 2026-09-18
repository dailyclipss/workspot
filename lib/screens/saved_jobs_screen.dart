import 'package:flutter/material.dart';
import '../models/job_model.dart';

class SavedJobsScreen extends StatefulWidget {
  final List<JobModel>? savedJobsList;

  const SavedJobsScreen({Key? key, this.savedJobsList}) : super(key: key);

  @override
  State<SavedJobsScreen> createState() => _SavedJobsScreenState();
}

class _SavedJobsScreenState extends State<SavedJobsScreen> {
  // Demo və ya ötürülən bəyənilən işlər
  late List<JobModel> _savedJobs;

  @override
  void initState() {
    super.initState();
    _savedJobs = widget.savedJobsList ?? [
      JobModel(
        id: '1',
        title: 'Senior Barista',
        companyName: 'Coffee Moffie',
        category: 'İaşə & Restoran',
        employmentType: 'Tam iş günü',
        salaryAmount: 850,
        lat: 40.3712,
        lng: 49.8360,
        distanceMeters: 300,
        isVip: true,
      ),
      JobModel(
        id: '17',
        title: 'Satıcı-Məsləhətçi',
        companyName: 'Zara (Port Baku Mall)',
        category: 'Satış & Ticarət',
        employmentType: 'Tam iş günü',
        salaryAmount: 800,
        lat: 40.3728,
        lng: 49.8532,
        distanceMeters: 1400,
        isVip: true,
      ),
    ];
  }

  void _removeSavedJob(String id) {
    setState(() {
      _savedJobs.removeWhere((job) => job.id == id);
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Vakansiya sevimlilərdən silindi')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text('Bəyənilən İşlər', style: TextStyle(color: Color(0xFF0F172A), fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: Color(0xFF0F172A)),
      ),
      body: _savedJobs.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.star_outline, size: 64, color: Colors.grey.shade400),
                  const SizedBox(height: 16),
                  Text('Hələ ki, bəyənilən iş yoxdur', style: TextStyle(fontSize: 15, color: Colors.grey.shade600)),
                ],
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _savedJobs.length,
              itemBuilder: (context, index) {
                final job = _savedJobs[index];
                return Card(
                  margin: const EdgeInsets.only(bottom: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  elevation: 0,
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor: job.isVip ? Colors.amber.shade100 : const Color(0xFF2563EB).withOpacity(0.1),
                      child: Icon(
                        job.isVip ? Icons.workspace_premium : Icons.storefront,
                        color: job.isVip ? Colors.amber.shade900 : const Color(0xFF2563EB),
                      ),
                    ),
                    title: Text(job.title, style: const TextStyle(fontWeight: FontWeight.bold)),
                    subtitle: Text('${job.companyName} • ${job.salaryAmount.toInt()} AZN'),
                    trailing: IconButton(
                      icon: const Icon(Icons.star, color: Colors.amber),
                      onPressed: () => _removeSavedJob(job.id),
                    ),
                  ),
                );
              },
            ),
    );
  }
}
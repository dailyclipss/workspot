import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/job_model.dart';
import '../services/app_language.dart';

class CompanyDetailsScreen extends StatefulWidget {
  final String companyName;
  final List<JobModel> companyJobs;

  const CompanyDetailsScreen({
    super.key,
    required this.companyName,
    required this.companyJobs,
  });

  @override
  State<CompanyDetailsScreen> createState() => _CompanyDetailsScreenState();
}

class _CompanyDetailsScreenState extends State<CompanyDetailsScreen> {
  double _userRating = 5.0;
  final TextEditingController _reviewController = TextEditingController();

  final List<Map<String, dynamic>> _reviews = [
    {
      'name': 'Aysel Məmmədova',
      'rating': 5.0,
      'comment': 'Çox peşəkar komandadır. İş mühiti və kollektiv əladır.',
      'date': '12 Sen 2026',
    },
    {
      'name': 'Elvin Həsənov',
      'rating': 4.5,
      'comment': 'Maaşlar vaxtında verilir, rəhbərlik işçilərə diqqətlidir.',
      'date': '05 Sen 2026',
    },
  ];

  @override
  void dispose() {
    _reviewController.dispose();
    super.dispose();
  }

  Future<void> _makeCall(String phone) async {
    final url = Uri.parse('tel:$phone');
    if (await canLaunchUrl(url)) {
      await launchUrl(url);
    }
  }

  void _addReview() {
    if (_reviewController.text.trim().isEmpty) return;

    setState(() {
      _reviews.insert(0, {
        'name': 'Siz',
        'rating': _userRating,
        'comment': _reviewController.text.trim(),
        'date': 'İndi',
      });
      _reviewController.clear();
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Rəyiniz uğurla əlavə olundu!'),
        backgroundColor: Colors.green,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: Text(widget.companyName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF0F172A),
        elevation: 0.5,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Şirkət Başlıq və Profil Kartı
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 10, offset: const Offset(0, 4)),
                ],
              ),
              child: Column(
                children: [
                  CircleAvatar(
                    radius: 36,
                    backgroundColor: const Color(0xFF2563EB).withOpacity(0.1),
                    child: Text(
                      widget.companyName.isNotEmpty ? widget.companyName[0].toUpperCase() : 'Ş',
                      style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: Color(0xFF2563EB)),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    widget.companyName,
                    style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.star_rounded, color: Colors.amber, size: 20),
                      const SizedBox(width: 4),
                      const Text('4.8', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                      const SizedBox(width: 4),
                      Text('(${_reviews.length} rəy)', style: TextStyle(color: Colors.grey[600], fontSize: 13)),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      OutlinedButton.icon(
                        onPressed: () => _makeCall('+994501234567'),
                        icon: const Icon(Icons.phone, size: 18),
                        label: const Text('Əlaqə saxla'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: const Color(0xFF2563EB),
                          side: const BorderSide(color: Color(0xFF2563EB)),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Şirkətin Aktiv Vakansiyaları
            Text(
              'Aktiv Vakansiyalar (${widget.companyJobs.length})',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
            ),
            const SizedBox(height: 12),
            widget.companyJobs.isEmpty
                ? Container(
                    padding: const EdgeInsets.all(20),
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.grey.shade200),
                    ),
                    child: const Center(
                      child: Text('Bu şirkətin hazırda aktiv elanı yoxdur.', style: TextStyle(color: Colors.grey)),
                    ),
                  )
                : ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: widget.companyJobs.length,
                    itemBuilder: (context, index) {
                      final job = widget.companyJobs[index];
                      return Card(
                        margin: const EdgeInsets.only(bottom: 10),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                          side: job.isVip ? const BorderSide(color: Colors.amber, width: 1.5) : BorderSide.none,
                        ),
                        child: ListTile(
                          title: Text(job.title, style: const TextStyle(fontWeight: FontWeight.bold)),
                          subtitle: Text('${appLang.translate(job.category) ?? job.category} • ${job.employmentType}'),
                          trailing: Text('${job.salaryAmount.toInt()} ₼', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.green, fontSize: 15)),
                        ),
                      );
                    },
                  ),
            const SizedBox(height: 24),

            // Rəylər və Reytinqlər Bölməsi
            const Text(
              'İşçi Rəyləri və Reytinq',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
            ),
            const SizedBox(height: 12),

            // Rəy Yazma Forması
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Rəyiniz var? Şirkəti qiymətləndirin:', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                  const SizedBox(height: 8),
                  Row(
                    children: List.generate(5, (index) {
                      return IconButton(
                        icon: Icon(
                          index < _userRating ? Icons.star_rounded : Icons.star_outline_rounded,
                          color: Colors.amber,
                          size: 28,
                        ),
                        onPressed: () {
                          setState(() => _userRating = index + 1.0);
                        },
                      );
                    }),
                  ),
                  TextField(
                    controller: _reviewController,
                    decoration: InputDecoration(
                      hintText: 'Şirkət haqqında təcrübənizi yazın...',
                      hintStyle: const TextStyle(fontSize: 13),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    maxLines: 2,
                  ),
                  const SizedBox(height: 10),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _addReview,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF2563EB),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      child: const Text('Rəyi Göndər', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Mövcud Rəylər Siyahısı
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _reviews.length,
              itemBuilder: (context, index) {
                final review = _reviews[index];
                return Container(
                  margin: const EdgeInsets.only(bottom: 10),
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey.shade200),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(review['name'], style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                          Row(
                            children: [
                              const Icon(Icons.star_rounded, color: Colors.amber, size: 16),
                              const SizedBox(width: 2),
                              Text('${review['rating']}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(review['comment'], style: TextStyle(color: Colors.grey[800], fontSize: 13)),
                      const SizedBox(height: 4),
                      Text(review['date'], style: TextStyle(color: Colors.grey[500], fontSize: 11)),
                    ],
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
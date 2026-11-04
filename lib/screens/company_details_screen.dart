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
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      backgroundColor: scheme.surface,
      appBar: AppBar(
        title: Text(widget.companyName,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
        backgroundColor: scheme.surface,
        foregroundColor: scheme.onSurface,
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
                color: scheme.surface,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                      color: Colors.black.withOpacity(0.04),
                      blurRadius: 10,
                      offset: const Offset(0, 4)),
                ],
              ),
              child: Column(
                children: [
                  CircleAvatar(
                    radius: 36,
                    backgroundColor: const Color(0xFF2563EB).withOpacity(0.1),
                    child: Text(
                      widget.companyName.isNotEmpty
                          ? widget.companyName[0].toUpperCase()
                          : 'Ş',
                      style: const TextStyle(
                          fontSize: 32,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF2563EB)),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    widget.companyName,
                    style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: scheme.onSurface),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.star_rounded,
                          color: Colors.amber, size: 20),
                      const SizedBox(width: 4),
                      Text('4.8',
                          style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                              color: scheme.onSurface)),
                      const SizedBox(width: 4),
                      Text('(${_reviews.length} rəy)',
                          style: TextStyle(
                              color: scheme.onSurfaceVariant, fontSize: 13)),
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
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12)),
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
              style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: scheme.onSurface),
            ),
            const SizedBox(height: 12),
            widget.companyJobs.isEmpty
                ? Container(
                    padding: const EdgeInsets.all(20),
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: scheme.surface,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: scheme.outlineVariant),
                    ),
                    child: Center(
                      child: Text('Bu şirkətin hazırda aktiv elanı yoxdur.',
                          style: TextStyle(color: scheme.onSurfaceVariant)),
                    ),
                  )
                : ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: widget.companyJobs.length,
                    itemBuilder: (context, index) {
                      final job = widget.companyJobs[index];
                      final isVip = job.isVipActive;
                      final isDark =
                          Theme.of(context).brightness == Brightness.dark;
                      return Card(
                        margin: const EdgeInsets.only(bottom: 10),
                        elevation: isVip ? 0 : null,
                        color: isVip ? Colors.transparent : null,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                          side: isVip
                              ? const BorderSide(
                                  color: Color(0xFFFFC73C),
                                  width: 1.5,
                                )
                              : BorderSide.none,
                        ),
                        child: Container(
                          decoration: BoxDecoration(
                            gradient: isVip
                                ? const LinearGradient(
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                    colors: [
                                      Color(0xFFFFF9E8),
                                      Color(0xFFFFFFFF),
                                      Color(0xFFFFF4D2),
                                    ],
                                  )
                                : null,
                            borderRadius: BorderRadius.circular(14),
                            boxShadow: isVip
                                ? [
                                    BoxShadow(
                                      color: const Color(0xFFFFC73C)
                                          .withValues(alpha: 0.24),
                                      blurRadius: 14,
                                      spreadRadius: 1,
                                    ),
                                  ]
                                : null,
                          ),
                          child: Stack(
                            children: [
                              ListTile(
                                title: Text(
                                  job.title,
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: isVip && isDark
                                        ? const Color(0xFFFFD466)
                                        : const Color(0xFF0F172A),
                                  ),
                                ),
                                subtitle: Text(
                                  '${appLang.translate(job.category)} • ${job.employmentType}',
                                ),
                                trailing: Text(
                                  '${job.salaryAmount.toInt()} ₼',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: Colors.green,
                                    fontSize: 15,
                                  ),
                                ),
                              ),
                              if (isVip)
                                Positioned(
                                  top: 8,
                                  right: 8,
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 4,
                                    ),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFFFC73C),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: const Text(
                                      'VIP',
                                      style: TextStyle(
                                        color: Color(0xFF111625),
                                        fontSize: 11,
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
            const SizedBox(height: 24),

            // Rəylər və Reytinqlər Bölməsi
            Text(
              'İşçi Rəyləri və Reytinq',
              style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: scheme.onSurface),
            ),
            const SizedBox(height: 12),

            // Rəy Yazma Forması
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: scheme.surface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: scheme.outlineVariant),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Rəyiniz var? Şirkəti qiymətləndirin:',
                      style: TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                          color: scheme.onSurface)),
                  const SizedBox(height: 8),
                  Row(
                    children: List.generate(5, (index) {
                      return IconButton(
                        icon: Icon(
                          index < _userRating
                              ? Icons.star_rounded
                              : Icons.star_outline_rounded,
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
                    style: TextStyle(color: scheme.onSurface, fontSize: 13),
                    decoration: InputDecoration(
                      hintText: 'Şirkət haqqında təcrübənizi yazın...',
                      hintStyle:
                          TextStyle(fontSize: 13, color: scheme.onSurfaceVariant),
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12)),
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
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10)),
                      ),
                      child: const Text('Rəyi Göndər',
                          style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold)),
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
                    color: scheme.surface,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: scheme.outlineVariant),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(review['name'],
                              style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                  color: scheme.onSurface)),
                          Row(
                            children: [
                              const Icon(Icons.star_rounded,
                                  color: Colors.amber, size: 16),
                              const SizedBox(width: 2),
                              Text('${review['rating']}',
                                  style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 12,
                                      color: scheme.onSurface)),
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(review['comment'],
                          style: TextStyle(
                              color: scheme.onSurfaceVariant, fontSize: 13)),
                      const SizedBox(height: 4),
                      Text(review['date'],
                          style: TextStyle(
                              color: scheme.onSurfaceVariant, fontSize: 11)),
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

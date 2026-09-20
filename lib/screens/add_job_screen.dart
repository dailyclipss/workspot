import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/app_language.dart';
import 'payment_screen.dart';

class AddJobScreen extends StatefulWidget {
  const AddJobScreen({super.key});

  @override
  State<AddJobScreen> createState() => _AddJobScreenState();
}

class _AddJobScreenState extends State<AddJobScreen> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _companyController = TextEditingController();
  final TextEditingController _salaryController = TextEditingController();
  // final MapController _mapController = MapController();
  String _selectedCategory = 'catering';
  String _selectedEmploymentType = 'Tam iş günü';
  bool _isVip = false;
  bool _isSubmitting = false;

  // Standart seçim kimi Bakı mərkəzi
  LatLng _selectedLocation = const LatLng(40.3725, 49.8372);

  final List<Map<String, String>> _categories = const [
    {'id': 'catering', 'key': 'cat_catering'},
    {'id': 'it', 'key': 'cat_it'},
    {'id': 'sales', 'key': 'cat_sales'},
    {'id': 'logistics', 'key': 'cat_logistics'},
    {'id': 'customer_service', 'key': 'cat_customer_service'},
    {'id': 'construction', 'key': 'cat_construction'},
    {'id': 'education', 'key': 'cat_education'},
    {'id': 'medicine', 'key': 'cat_medicine'},
    {'id': 'beauty', 'key': 'cat_beauty'},
  ];

  final List<String> _employmentTypes = const [
    'Tam iş günü',
    'Yarım iş günü',
    'Növbəli',
    'Gündəlik',
    'Saatlıq / Sərbəst',
    'Uzaqdan (Remote)',
  ];

  @override
  void initState() {
    super.initState();
    appLang.addListener(_onLanguageChanged);
  }

  @override
  void dispose() {
    appLang.removeListener(_onLanguageChanged);
    _titleController.dispose();
    _companyController.dispose();
    _salaryController.dispose();
    super.dispose();
  }

  void _onLanguageChanged() {
    if (mounted) setState(() {});
  }

  String _employmentTypeLabel(String type) {
    switch (type) {
      case 'Tam iş günü':
        return appLang.translate('full_time');
      case 'Yarım iş günü':
        return appLang.translate('part_time');
      case 'Növbəli':
        return appLang.translate('shift_work');
      case 'Gündəlik':
        return appLang.translate('daily_work');
      case 'Saatlıq / Sərbəst':
        return appLang.translate('hourly_flexible');
      case 'Uzaqdan (Remote)':
        return appLang.translate('remote_work');
      default:
        return type;
    }
  }

  Future<void> _submitJob() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSubmitting = true);

    try {
      final salaryText = _salaryController.text.trim();
      final salaryInput = salaryText.replaceAll(RegExp(r'[^0-9.]'), '');
      final salaryAmount = double.tryParse(salaryInput) ?? 0.0;
      final String? selectedCategory =
          _selectedCategory.trim().isEmpty ? null : _selectedCategory.trim();
      final String? selectedJobType = _selectedEmploymentType.trim().isEmpty
          ? null
          : _selectedEmploymentType.trim();
      final LatLng? selectedLocation = _selectedLocation;
      final bool? isVip = _isVip;
      const location = 'Bakı';
      final latitude = selectedLocation?.latitude ?? 40.3725;
      final longitude = selectedLocation?.longitude ?? 49.8372;

      final job = await Supabase.instance.client
          .from('jobs')
          .insert({
            'title': _titleController.text.trim().isEmpty
                ? 'Vakansiya'
                : _titleController.text.trim(),
            'company_name': _companyController.text.trim().isEmpty
                ? 'Şirkət'
                : _companyController.text.trim(),
            'category': selectedCategory ?? 'Digər',
            'job_type': selectedJobType ?? 'Tam iş günü',
            'employment_type': selectedJobType ?? 'Tam iş günü',
            'salary': '${salaryText.isEmpty ? '0' : salaryText} AZN',
            'salary_amount': salaryAmount,
            'salary_type': 'Aylıq',
            'location': location,
            'latitude': latitude,
            'longitude': longitude,
            'status': 'pending_payment',
            'is_vip': isVip ?? false,
          })
          .select('id')
          .single();

      if (!mounted) return;
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => PaymentScreen(jobId: job['id'].toString()),
        ),
      );
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Xəta baş verdi: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(appLang.translate('add_vacancy'),
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF0F172A),
        elevation: 0.5,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Vakansiya Adı
              TextFormField(
                controller: _titleController,
                decoration: InputDecoration(
                  labelText: appLang.translate('job_title_required'),
                  hintText: 'məs: Senior Barista',
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12)),
                  prefixIcon: const Icon(Icons.work_outline),
                ),
                validator: (val) => (val == null || val.isEmpty)
                    ? 'Zəhmət olmasa vakansiya adını qeyd edin'
                    : null,
              ),
              const SizedBox(height: 14),

              // Şirkət Adı
              TextFormField(
                controller: _companyController,
                decoration: InputDecoration(
                  labelText: appLang.translate('company_place_required'),
                  hintText: 'məs: Coffee Moffie',
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12)),
                  prefixIcon: const Icon(Icons.business_outlined),
                ),
                validator: (val) => (val == null || val.isEmpty)
                    ? 'Zəhmət olmasa şirket adını qeyd edin'
                    : null,
              ),
              const SizedBox(height: 14),

              // Kateqoriya və İş Qrafiki (Row)
              Row(
                children: [
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      value: _selectedCategory,
                      decoration: InputDecoration(
                        labelText: appLang.translate('category_label'),
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12)),
                      ),
                      items: _categories.map((cat) {
                        return DropdownMenuItem(
                          value: cat['id'],
                          child: Text(
                            appLang.translate(cat['key']!),
                            style: const TextStyle(fontSize: 13),
                          ),
                        );
                      }).toList(),
                      onChanged: (val) {
                        if (val != null)
                          setState(() => _selectedCategory = val);
                      },
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      value: _selectedEmploymentType,
                      decoration: InputDecoration(
                        labelText: appLang.translate('job_type_label'),
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12)),
                      ),
                      items: _employmentTypes.map((type) {
                        return DropdownMenuItem(
                          value: type,
                            child: Text(
                              _employmentTypeLabel(type),
                              style: const TextStyle(fontSize: 13)),
                        );
                      }).toList(),
                      onChanged: (val) {
                        if (val != null)
                          setState(() => _selectedEmploymentType = val);
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),

              // Maaş
              TextFormField(
                controller: _salaryController,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: appLang.translate('salary_required'),
                  hintText: 'məs: 850',
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12)),
                  prefixIcon: const Icon(Icons.attach_money_rounded),
                ),
                validator: (val) => (val == null || val.isEmpty)
                    ? 'Zəhmət olmasa maaşı qeyd edin'
                    : null,
              ),
              const SizedBox(height: 14),

              // VIP Çekboks
              SwitchListTile(
                title: Text(appLang.translate('vip_publish'),
                    style: TextStyle(fontWeight: FontWeight.bold)),
                subtitle: Text(appLang.translate('vip_subtitle')),
                activeColor: Colors.amber.shade800,
                value: _isVip,
                onChanged: (val) => setState(() => _isVip = val),
              ),
              const SizedBox(height: 10),

              // Xəritədən Məkan Seçimi Başlıq
              Text(
                appLang.translate('select_location'),
                style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                    color: Color(0xFF0F172A)),
              ),
              const SizedBox(height: 8),

              // İnteraktiv Xəritə Məkan Seçicisi
              Container(
                height: 220,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  border:
                      Border.all(color: const Color(0xFF2563EB), width: 1.5),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(14),
                  child: GoogleMap(
                    initialCameraPosition: CameraPosition(
                      target: _selectedLocation,
                      zoom: 14.0,
                    ),
                    onTap: (LatLng point) {
                      if (!context.mounted) return;
                      try {
                        setState(() => _selectedLocation = point);
                      } catch (error) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Məkan seçilə bilmədi: $error'),
                          ),
                        );
                      }
                    },
                    markers: {
                      Marker(
                        markerId: const MarkerId('selected_job_loc'),
                        position: _selectedLocation,
                      ),
                    },
                  ),
                ),
              ),
              const SizedBox(height: 6),
              Text(
                '${appLang.translate('selected_coordinate')} ${_selectedLocation.latitude.toStringAsFixed(4)}, ${_selectedLocation.longitude.toStringAsFixed(4)}',
                style: const TextStyle(fontSize: 11, color: Colors.grey),
              ),
              const SizedBox(height: 24),

              // Təsdiq Düyməsi
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: _isSubmitting ? null : _submitJob,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF2563EB),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                  ),
                  child: _isSubmitting
                      ? const CircularProgressIndicator(color: Colors.white)
                        : Text(
                          appLang.translate('publish_vacancy'),
                          style: TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.bold),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/app_language.dart';

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
  final MapController _mapController = MapController();

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

  Future<void> _submitJob() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSubmitting = true);

    try {
      final salary = double.tryParse(_salaryController.text.trim()) ?? 0.0;

      await Supabase.instance.client.from('jobs').insert({
        'title': _titleController.text.trim(),
        'company_name': _companyController.text.trim(),
        'category': _selectedCategory,
        'employment_type': _selectedEmploymentType,
        'salary_amount': salary,
        'lat': _selectedLocation.latitude,
        'lng': _selectedLocation.longitude,
        'distance_meters': 300,
        'is_vip': _isVip,
        'created_at': DateTime.now().toIso8601String(),
      });

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Vakansiya uğurla yerləşdirildi!'),
          backgroundColor: Colors.green,
        ),
      );
      Navigator.pop(context, true);
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
        title: const Text('Yeni Vakansiya Əlavə Et', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
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
                  labelText: 'Vakansiya Adı *',
                  hintText: 'məs: Senior Barista',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  prefixIcon: const Icon(Icons.work_outline),
                ),
                validator: (val) => (val == null || val.isEmpty) ? 'Zəhmət olmasa vakansiya adını qeyd edin' : null,
              ),
              const SizedBox(height: 14),

              // Şirkət Adı
              TextFormField(
                controller: _companyController,
                decoration: InputDecoration(
                  labelText: 'Şirkət / Məkan Adı *',
                  hintText: 'məs: Coffee Moffie',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  prefixIcon: const Icon(Icons.business_outlined),
                ),
                validator: (val) => (val == null || val.isEmpty) ? 'Zəhmət olmasa şirket adını qeyd edin' : null,
              ),
              const SizedBox(height: 14),

              // Kateqoriya və İş Qrafiki (Row)
              Row(
                children: [
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      value: _selectedCategory,
                      decoration: InputDecoration(
                        labelText: 'Kateqoriya',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      items: _categories.map((cat) {
                        return DropdownMenuItem(
                          value: cat['id'],
                          child: Text(
                            appLang.translate(cat['key']!) ?? cat['id']!,
                            style: const TextStyle(fontSize: 13),
                          ),
                        );
                      }).toList(),
                      onChanged: (val) {
                        if (val != null) setState(() => _selectedCategory = val);
                      },
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      value: _selectedEmploymentType,
                      decoration: InputDecoration(
                        labelText: 'İş Rejimi',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      items: _employmentTypes.map((type) {
                        return DropdownMenuItem(
                          value: type,
                          child: Text(type, style: const TextStyle(fontSize: 13)),
                        );
                      }).toList(),
                      onChanged: (val) {
                        if (val != null) setState(() => _selectedEmploymentType = val);
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
                  labelText: 'Maaş (AZN) *',
                  hintText: 'məs: 850',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  prefixIcon: const Icon(Icons.attach_money_rounded),
                ),
                validator: (val) => (val == null || val.isEmpty) ? 'Zəhmət olmasa maaşı qeyd edin' : null,
              ),
              const SizedBox(height: 14),

              // VIP Çekboks
              SwitchListTile(
                title: const Text('VIP Elan kimi yerləşdir', style: TextStyle(fontWeight: FontWeight.bold)),
                subtitle: const Text('Xəritədə qızılı rəngdə üst sırada göstərilir'),
                activeColor: Colors.amber.shade800,
                value: _isVip,
                onChanged: (val) => setState(() => _isVip = val),
              ),
              const SizedBox(height: 10),

              // Xəritədən Məkan Seçimi Başlıq
              const Text(
                'İş Məkanını Xəritədə Seçin (Xəritəyə toxunun):',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Color(0xFF0F172A)),
              ),
              const SizedBox(height: 8),

              // İnteraktiv Xəritə Məkan Seçicisi
              Container(
                height: 220,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFF2563EB), width: 1.5),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(14),
                  child: FlutterMap(
                    mapController: _mapController,
                    options: MapOptions(
                      initialCenter: _selectedLocation,
                      initialZoom: 14.0,
                      onTap: (tapPosition, point) {
                        setState(() => _selectedLocation = point);
                      },
                    ),
                    children: [
                      TileLayer(
                        urlTemplate: 'https://server.arcgisonline.com/ArcGIS/rest/services/World_Street_Map/MapServer/tile/{z}/{y}/{x}',
                        userAgentPackageName: 'com.workspot.app',
                      ),
                      MarkerLayer(
                        markers: [
                          Marker(
                            point: _selectedLocation,
                            width: 40,
                            height: 40,
                            alignment: Alignment.center,
                            child: const Icon(
                              Icons.location_on,
                              color: Colors.redAccent,
                              size: 40,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Seçilmiş kordinat: ${_selectedLocation.latitude.toStringAsFixed(4)}, ${_selectedLocation.longitude.toStringAsFixed(4)}',
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
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  child: _isSubmitting
                      ? const CircularProgressIndicator(color: Colors.white)
                      : const Text(
                          'Vakansiyanı Dərc Et',
                          style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
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
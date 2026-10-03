import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart' as gmaps;
import 'package:supabase_flutter/supabase_flutter.dart';

import '../services/app_language.dart';
import '../services/job_location_resolver.dart';
import 'job_payment_screen.dart';

typedef LatLng = gmaps.LatLng;

class AddJobScreen extends StatefulWidget {
  const AddJobScreen({super.key});

  @override
  State<AddJobScreen> createState() => _AddJobScreenState();
}

class _AddJobScreenState extends State<AddJobScreen> {
  static const LatLng _defaultLocation = LatLng(40.3800, 49.8450);

  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  gmaps.GoogleMapController? _mapController;

  final TextEditingController _businessNameController = TextEditingController();
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _addressController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _contactPersonController = TextEditingController();
  final TextEditingController _instagramController = TextEditingController();
  final TextEditingController _salaryController = TextEditingController();

  final List<_CategoryOption> _categories = const [
    _CategoryOption('Restoran & Kafe', Icons.restaurant_rounded),
    _CategoryOption('İT', Icons.code_rounded),
    _CategoryOption('Satış', Icons.storefront_rounded),
    _CategoryOption('Səhiyyə və Tibb', Icons.medical_services_rounded),
    _CategoryOption('Logistika', Icons.local_shipping_rounded),
    _CategoryOption('Müştəri Xidmətləri', Icons.headset_mic_rounded),
    _CategoryOption('Tikinti', Icons.construction_rounded),
    _CategoryOption('Təhsil', Icons.school_rounded),
    _CategoryOption('Gözəllik', Icons.content_cut_rounded),
    _CategoryOption('Dizayn', Icons.palette_outlined),
  ];

  final List<String> _districts = const [
    'Nərimanov',
    '28 May',
    'Yasamal',
    'Gənclik',
    'Xətai',
    'Nizami',
    'Səbail',
    'Binəqədi',
    'Nəsimi',
    'Suraxanı',
    'Sabunçu',
    'Koroğlu',
    'İçərişəhər',
  ];

  final List<String> _schedules = const [
    'Tam iş günü',
    'Növbəli',
    'Sərbəst',
    'Tələbələr üçün',
  ];

  String? _selectedCategory;
  String? _selectedDistrict;
  String? _selectedSchedule;
  bool _salaryByAgreement = false;
  bool _hasVacancy = true;
  bool _isVip = false;
  bool _isSubmitting = false;
  bool _hasExplicitLocation = false;
  LatLng _selectedLocation = _defaultLocation;
  String _selectedDistrictPreview = 'Nərimanov';

  @override
  void initState() {
    super.initState();
    appLang.addListener(_onLanguageChanged);
    _selectedCategory = _categories.first.label;
    _selectedDistrict = _districts.first;
    _selectedSchedule = _schedules.first;
    _selectedDistrictPreview = _districts.first;
  }

  @override
  void dispose() {
    appLang.removeListener(_onLanguageChanged);
    _businessNameController.dispose();
    _titleController.dispose();
    _addressController.dispose();
    _descriptionController.dispose();
    _phoneController.dispose();
    _contactPersonController.dispose();
    _instagramController.dispose();
    _salaryController.dispose();
    super.dispose();
  }

  void _onLanguageChanged() {
    if (mounted) setState(() {});
  }

  void _onMapTap(LatLng point) {
    setState(() {
      _selectedLocation = point;
      _selectedDistrictPreview = _districtFromLocation(point);
      _selectedDistrict ??= _selectedDistrictPreview;
      _hasExplicitLocation = true;
    });
    _mapController?.animateCamera(gmaps.CameraUpdate.newLatLng(point));
  }

  void _onMapDragEnd(LatLng point) {
    setState(() {
      _selectedLocation = point;
      _selectedDistrictPreview = _districtFromLocation(point);
      _selectedDistrict = _selectedDistrictPreview;
      _hasExplicitLocation = true;
    });
  }

  String _districtFromLocation(LatLng point) {
    final lat = point.latitude;
    final lng = point.longitude;
    if (lat >= 40.40 && lng >= 49.86) return 'Nərimanov';
    if (lat >= 40.37 && lat < 40.40 && lng >= 49.83 && lng < 49.86) return '28 May';
    if (lat >= 40.36 && lng < 49.84) return 'Yasamal';
    if (lat >= 40.39 && lng < 49.81) return 'Nizami';
    if (lat < 40.37 && lng >= 49.84) return 'Xətai';
    return 'Bakı';
  }

  Set<gmaps.Marker> get _locationMarkers => {
        gmaps.Marker(
          markerId: const gmaps.MarkerId('selected_job_location'),
          position: _selectedLocation,
          draggable: true,
          onDragEnd: _onMapDragEnd,
          anchor: const Offset(0.5, 1.0),
        ),
      };

  String _normalizePhoneForStorage(String value) {
    final digits = value.replaceAll(RegExp(r'\D'), '');
    if (digits.isEmpty) return '';
    if (digits.startsWith('994')) return '+$digits';
    if (digits.length == 9) return '+994$digits';
    if (digits.length == 10 && digits.startsWith('0')) {
      return '+994${digits.substring(1)}';
    }
    return value.startsWith('+') ? value : '+$digits';
  }

  String _salaryDisplayValue() {
    if (_salaryByAgreement) return 'Razılaşma ilə';
    final value = _salaryController.text.trim();
    if (value.isEmpty) return '';
    return value.contains('₼') ? value : '$value ₼';
  }

  String? _requiredValidator(String? value, String message) {
    if (value == null || value.trim().isEmpty) return message;
    return null;
  }

  String? _phoneValidator(String? value) {
    final digits = value?.replaceAll(RegExp(r'\D'), '') ?? '';
    if (digits.isEmpty) return 'Telefon / WhatsApp nömrəsini daxil edin';
    if (digits.length < 9) return 'Düzgün telefon nömrəsi daxil edin';
    return null;
  }

  String? _salaryValidator(String? value) {
    if (_salaryByAgreement) return null;
    if (value == null || value.trim().isEmpty) {
      return 'Maaşı daxil edin və ya "Razılaşma ilə" seçin';
    }
    final numeric = value.replaceAll(RegExp(r'[^0-9,\.]'), '');
    if (double.tryParse(numeric.replaceAll(',', '.')) == null) {
      return 'Düzgün maaş daxil edin';
    }
    return null;
  }

  Map<String, dynamic> _buildJobPayload() {
    final businessName = _businessNameController.text.trim().isEmpty
        ? 'Test Müəssisə'
        : _businessNameController.text.trim();
    final title = _titleController.text.trim().isEmpty ? 'Yeni Vakansiya' : _titleController.text.trim();
    final districtValue = (_selectedDistrict?.trim().isNotEmpty ?? false) ? _selectedDistrict!.trim() : 'Nərimanov';
    final latitude = _hasExplicitLocation ? _selectedLocation.latitude : null;
    final longitude = _hasExplicitLocation ? _selectedLocation.longitude : null;
    final resolvedLocation = JobLocationResolver.resolve(
      district: districtValue,
      address: _addressController.text.trim(),
      latitude: latitude,
      longitude: longitude,
    );

    return <String, dynamic>{
      'business_name': businessName,
      'title': title,
      'category': _selectedCategory ?? 'Xidmət',
      'district': districtValue,
      'description': _descriptionController.text.trim(),
      'latitude': resolvedLocation.latitude,
      'longitude': resolvedLocation.longitude,
      'has_vacancy': _hasVacancy,
      'is_vip': _isVip,
      'owner_id': Supabase.instance.client.auth.currentUser?.id,
      'created_by': Supabase.instance.client.auth.currentUser?.id,
      'ad_status': 'pending',
      'created_at': DateTime.now().toIso8601String(),
    };
  }

  String _extractInsertErrorMessage(Object error) {
    if (error is PostgrestException && error.message.trim().isNotEmpty) {
      return error.message.trim();
    }
    final raw = error.toString().trim();
    return raw.isEmpty ? 'Naməlum xəta' : raw;
  }

  bool _isSchemaColumnError(Object error) {
    final message = error.toString().toLowerCase();
    return message.contains('could not find the') && message.contains('column') ||
        message.contains('schema cache') ||
        message.contains('column "');
  }

  String? _extractMissingColumnKey(Object error) {
    final message = error.toString();
    final patterns = [
      RegExp(r"could not find the '([^']+)' column", caseSensitive: false),
      RegExp(r'column\s+"([^"]+)"', caseSensitive: false),
      RegExp(r"column\s+'([^']+)'", caseSensitive: false),
    ];

    for (final pattern in patterns) {
      final match = pattern.firstMatch(message);
      if (match != null) return match.group(1);
    }
    return null;
  }

  Future<List<Map<String, dynamic>>> _insertJobWithFallback(Map<String, dynamic> payload) async {
    final jobs = Supabase.instance.client.from('jobs');
    final workingPayload = Map<String, dynamic>.from(payload);
    Object? lastError;

    for (var attempt = 0; attempt < 8; attempt++) {
      try {
        final result = await jobs.insert(workingPayload).select();
        print('Inserted row: $result');
        return List<Map<String, dynamic>>.from(result);
      } catch (error) {
        lastError = error;
        if (!_isSchemaColumnError(error)) {
          rethrow;
        }

        final missingColumn = _extractMissingColumnKey(error);
        if (missingColumn == null) {
          debugPrint('jobs insert schema mismatch without column name: $error');
          continue;
        }

        if (workingPayload.containsKey(missingColumn)) {
          debugPrint('jobs insert removing missing column "$missingColumn": $error');
          workingPayload.remove(missingColumn);
          if (missingColumn == 'district') {
            final districtValue = (payload['district']?.toString().trim().isNotEmpty ?? false)
                ? payload['district'].toString().trim()
                : 'Nərimanov';
            final addressValue = _addressController.text.trim();
            workingPayload['address'] = addressValue.isEmpty ? 'Rayon: $districtValue' : '$addressValue | Rayon: $districtValue';
          }
          continue;
        }

        debugPrint('jobs insert schema mismatch already stripped "$missingColumn": $error');
      }
    }

    throw lastError ?? Exception('Job insert failed');
  }

  Future<void> _submitJob() async {
    if (_selectedCategory == null || _selectedDistrict == null || _selectedSchedule == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Zəhmət olmasa bütün seçimləri tamamlayın.')),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      final jobData = _buildJobPayload();
      final didPublish = await Navigator.of(context).push<bool>(
        MaterialPageRoute(
          builder: (_) => JobPaymentScreen(
            jobDraft: jobData,
            preferPremium: _isVip,
            publishJob: (payload) async {
              await _insertJobWithFallback(payload);
            },
          ),
        ),
      );

      if (!mounted) return;
      if (didPublish == true) {
        Navigator.of(context).pop(true);
      }
    } catch (error) {
      final errorMessage = error.toString().trim().isEmpty ? _extractInsertErrorMessage(error) : error.toString();
      debugPrint('Job insert failed: $errorMessage');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Xəta: $errorMessage')),
      );
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: Text(
          appLang.translate('add_vacancy'),
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
        ),
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF0F172A),
        elevation: 0.5,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _sectionCard(
                title: 'Biznes Məlumatları',
                icon: Icons.business_rounded,
                children: [
                  TextFormField(
                    controller: _businessNameController,
                    decoration: _fieldDecoration('Biznes adı', 'Məs: Coffee Moffie', Icons.storefront_rounded),
                    validator: (value) => _requiredValidator(value, 'Biznes adını daxil edin'),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _titleController,
                    decoration: _fieldDecoration('Vakansiya adı', 'Məs: Barista / Kassir', Icons.badge_rounded),
                    validator: (value) => _requiredValidator(value, 'Vakansiya adını daxil edin'),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    value: _selectedCategory,
                    decoration: _fieldDecoration('Kateqoriya', 'Məs: Restoran & Kafe', Icons.category_rounded),
                    items: _categories
                        .map(
                          (category) => DropdownMenuItem<String>(
                            value: category.label,
                            child: Text(category.label),
                          ),
                        )
                        .toList(),
                    onChanged: (value) => setState(() => _selectedCategory = value),
                    validator: (value) => _requiredValidator(value, 'Kateqoriya seçin'),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    value: _selectedDistrict,
                    decoration: _fieldDecoration('Rayon', 'Məs: Nərimanov', Icons.location_city_rounded),
                    items: _districts
                        .map(
                          (district) => DropdownMenuItem<String>(
                            value: district,
                            child: Text(district),
                          ),
                        )
                        .toList(),
                    onChanged: (value) => setState(() => _selectedDistrict = value),
                    validator: (value) => _requiredValidator(value, 'Rayon seçin'),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _addressController,
                    maxLines: 2,
                    decoration: _fieldDecoration('Ünvan', 'Tam ünvan / yaxınlıq', Icons.place_rounded),
                    validator: (value) => _requiredValidator(value, 'Ünvanı daxil edin'),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _descriptionController,
                    maxLines: 5,
                    minLines: 3,
                    keyboardType: TextInputType.multiline,
                    textInputAction: TextInputAction.newline,
                    decoration: _fieldDecoration('Description / Job Details', 'İşin təsviri / Tələblər', Icons.description_outlined),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              _sectionCard(
                title: 'Əlaqə & Sosial Şəbəkə',
                icon: Icons.call_rounded,
                children: [
                  TextFormField(
                    controller: _phoneController,
                    keyboardType: TextInputType.phone,
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(RegExp(r'[0-9+\s\-()]')),
                      _AzerbaijanPhoneFormatter(),
                    ],
                    decoration: _fieldDecoration('Telefon / WhatsApp', '+994 XX XXX XX XX', Icons.phone_rounded),
                    validator: _phoneValidator,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _contactPersonController,
                    decoration: _fieldDecoration('Kontakt şəxsi', 'Məs: Əli m.', Icons.person_rounded),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _instagramController,
                    decoration: _fieldDecoration('Instagram', 'Username / Link', Icons.camera_alt_rounded),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              _sectionCard(
                title: 'Vakansiya Şərtləri',
                icon: Icons.badge_rounded,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: _salaryController,
                          enabled: !_salaryByAgreement,
                          keyboardType: TextInputType.number,
                          decoration: _fieldDecoration('Maaş (AZN)', 'Məs: 850', Icons.attach_money_rounded),
                          validator: _salaryValidator,
                        ),
                      ),
                      const SizedBox(width: 12),
                      SizedBox(
                        width: 150,
                        child: CheckboxListTile(
                          value: _salaryByAgreement,
                          onChanged: (value) => setState(() => _salaryByAgreement = value ?? false),
                          title: const Text('Razılaşma ilə', style: TextStyle(fontSize: 12.5)),
                          controlAffinity: ListTileControlAffinity.leading,
                          contentPadding: EdgeInsets.zero,
                          dense: true,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    value: _selectedSchedule,
                    decoration: _fieldDecoration('Qrafik', 'İş qrafiki', Icons.schedule_rounded),
                    items: _schedules
                        .map(
                          (schedule) => DropdownMenuItem<String>(
                            value: schedule,
                            child: Text(schedule),
                          ),
                        )
                        .toList(),
                    onChanged: (value) => setState(() => _selectedSchedule = value),
                    validator: (value) => _requiredValidator(value, 'Qrafiki seçin'),
                  ),
                  const SizedBox(height: 12),
                  SwitchListTile.adaptive(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Vakansiya Var?', style: TextStyle(fontWeight: FontWeight.w600)),
                    subtitle: const Text('Aktiv elan kimi göstərilsin'),
                    value: _hasVacancy,
                    onChanged: (value) => setState(() => _hasVacancy = value),
                  ),
                  const Divider(height: 16),
                  SwitchListTile.adaptive(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('VIP Elan', style: TextStyle(fontWeight: FontWeight.w600)),
                    subtitle: const Text('Daha ön planda görünəcək'),
                    activeColor: Colors.amber.shade700,
                    value: _isVip,
                    onChanged: (value) => setState(() => _isVip = value),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              _sectionCard(
                title: 'Məkan Seçimi',
                icon: Icons.map_rounded,
                children: [
                  Container(
                    height: 240,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: const Color(0xFF2563EB).withOpacity(0.2)),
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: gmaps.GoogleMap(
                      initialCameraPosition: const gmaps.CameraPosition(
                        target: _defaultLocation,
                        zoom: 13.8,
                      ),
                      onMapCreated: (controller) {
                        _mapController = controller;
                      },
                      onTap: _onMapTap,
                      markers: _locationMarkers,
                      myLocationButtonEnabled: false,
                      zoomControlsEnabled: false,
                      mapToolbarEnabled: false,
                      compassEnabled: false,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: const Color(0xFFCBD5E1).withOpacity(0.35)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Seçilən koordinat',
                          style: TextStyle(fontSize: 12, color: Color(0xFF64748B), fontWeight: FontWeight.w600),
                        ),
                        const SizedBox(height: 6),
                        Text('Rayon: ${_selectedDistrictPreview}', style: const TextStyle(fontWeight: FontWeight.w700)),
                        Text('Lat: ${_selectedLocation.latitude.toStringAsFixed(6)}', style: const TextStyle(fontWeight: FontWeight.w600)),
                        Text('Lng: ${_selectedLocation.longitude.toStringAsFixed(6)}', style: const TextStyle(fontWeight: FontWeight.w600)),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: _isSubmitting ? null : _submitJob,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF2563EB),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  child: _isSubmitting
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.2),
                        )
                      : const Text(
                          'Ödənişə Keç və Dərc Et',
                          style: TextStyle(color: Colors.white, fontSize: 15.5, fontWeight: FontWeight.w700),
                        ),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                _salaryByAgreement ? 'Maaş: Razılaşma ilə' : 'Maaş: ${_salaryDisplayValue()}',
                style: const TextStyle(color: Color(0xFF64748B), fontSize: 12),
              ),
            ],
          ),
        ),
      ),
    );
  }

  InputDecoration _fieldDecoration(String label, String hint, IconData icon) {
    return InputDecoration(
      labelText: label,
      hintText: hint,
      prefixIcon: Icon(icon),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: Color(0xFF2563EB), width: 1.4),
      ),
      filled: true,
      fillColor: Colors.white,
    );
  }

  Widget _sectionCard({
    required String title,
    required IconData icon,
    required List<Widget> children,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: const [
          BoxShadow(color: Color(0x0F000000), blurRadius: 18, offset: Offset(0, 6)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: const Color(0xFF2563EB).withOpacity(0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: const Color(0xFF2563EB), size: 19),
              ),
              const SizedBox(width: 10),
              Text(title, style: const TextStyle(fontSize: 15.5, fontWeight: FontWeight.w800, color: Color(0xFF0F172A))),
            ],
          ),
          const SizedBox(height: 14),
          ...children,
        ],
      ),
    );
  }
}

class _CategoryOption {
  final String label;
  final IconData icon;

  const _CategoryOption(this.label, this.icon);
}

class _AzerbaijanPhoneFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) {
    final digits = newValue.text.replaceAll(RegExp(r'\D'), '');
    if (digits.isEmpty) {
      return const TextEditingValue(
        text: '+994',
        selection: TextSelection.collapsed(offset: 4),
      );
    }

    String national = digits;
    if (national.startsWith('994')) national = national.substring(3);
    if (national.startsWith('0')) national = national.substring(1);
    if (national.length > 9) national = national.substring(0, 9);

    final buffer = StringBuffer('+994');
    if (national.isNotEmpty) {
      buffer.write(' ');
      final groups = <int>[2, 3, 2, 2];
      var index = 0;
      for (var i = 0; i < groups.length; i++) {
        if (index >= national.length) break;
        final end = min(index + groups[i], national.length);
        if (i > 0) buffer.write(' ');
        buffer.write(national.substring(index, end));
        index = end;
      }
    }

    final text = buffer.toString();
    return TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: text.length),
    );
  }
}
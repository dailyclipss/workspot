import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart' as gmaps;
import 'package:supabase_flutter/supabase_flutter.dart';

import '../services/app_language.dart';
import '../services/geocoding_service.dart';
import '../services/job_location_resolver.dart';
import '../widgets/location_pin_marker.dart';
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
  Timer? _searchDebounce;
  List<AddressSuggestion> _suggestions = const [];
  bool _isSearchingAddress = false;
  bool _suppressAddressSearch = false;
  int _geocodeRequestId = 0;
  gmaps.BitmapDescriptor? _pinIcon;

  @override
  void initState() {
    super.initState();
    LocationPinMarker.create().then((icon) {
      if (mounted && icon != null) setState(() => _pinIcon = icon);
    });
    appLang.addListener(_onLanguageChanged);
    _selectedCategory = _categories.first.label;
    _selectedDistrict = _districts.first;
    _selectedSchedule = _schedules.first;
    _selectedDistrictPreview = _districts.first;
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
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
      _suggestions = const [];
    });
    _mapController?.animateCamera(gmaps.CameraUpdate.newLatLng(point));
    _reverseGeocode(point);
  }

  void _onMapDragEnd(LatLng point) {
    setState(() {
      _selectedLocation = point;
      _selectedDistrictPreview = _districtFromLocation(point);
      _selectedDistrict = _districts.contains(_selectedDistrictPreview) ? _selectedDistrictPreview : _selectedDistrict;
      _hasExplicitLocation = true;
      _suggestions = const [];
    });
    _reverseGeocode(point);
  }

  String? _matchDistrict(String? name) {
    if (name == null) return null;
    final lower = name.toLowerCase();
    for (final district in _districts) {
      final d = district.toLowerCase();
      if (lower.contains(d) || d.contains(lower)) return district;
    }
    return null;
  }

  Future<void> _reverseGeocode(LatLng point) async {
    final requestId = ++_geocodeRequestId;
    final result = await GeocodingService.reverse(
      point.latitude,
      point.longitude,
      lang: appLang.currentLanguage,
    );
    if (!mounted || requestId != _geocodeRequestId || result == null) return;
    _suppressAddressSearch = true;
    _addressController.text = result.displayName;
    _suppressAddressSearch = false;
    final matched = _matchDistrict(result.district);
    if (matched != null) {
      setState(() {
        _selectedDistrict = matched;
        _selectedDistrictPreview = matched;
      });
    }
  }

  void _onAddressChanged(String value) {
    if (_suppressAddressSearch) return;
    _searchDebounce?.cancel();
    if (value.trim().length < 3) {
      setState(() {
        _suggestions = const [];
        _isSearchingAddress = false;
      });
      return;
    }
    setState(() => _isSearchingAddress = true);
    _searchDebounce = Timer(const Duration(milliseconds: 450), () async {
      final results = await GeocodingService.search(value, lang: appLang.currentLanguage);
      if (!mounted || _addressController.text != value) return;
      setState(() {
        _suggestions = results;
        _isSearchingAddress = false;
      });
    });
  }

  void _selectSuggestion(AddressSuggestion suggestion) {
    FocusManager.instance.primaryFocus?.unfocus();
    final point = LatLng(suggestion.latitude, suggestion.longitude);
    _geocodeRequestId++;
    _suppressAddressSearch = true;
    _addressController.text = suggestion.displayName;
    _suppressAddressSearch = false;
    final matched = _matchDistrict(suggestion.district);
    setState(() {
      _selectedLocation = point;
      _selectedDistrictPreview = matched ?? _districtFromLocation(point);
      _selectedDistrict = matched ?? _selectedDistrict;
      _hasExplicitLocation = true;
      _suggestions = const [];
    });
    _mapController?.animateCamera(gmaps.CameraUpdate.newLatLngZoom(point, 16.5));
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
          icon: _pinIcon ?? gmaps.BitmapDescriptor.defaultMarker,
          anchor: const Offset(0.5, 0.89),
        ),
      };

  num _salaryAmountValue() {
    if (_salaryByAgreement) return 0;
    final numeric = _salaryController.text.replaceAll(RegExp(r'[^0-9,\.]'), '').replaceAll(',', '.');
    final parsed = double.tryParse(numeric) ?? 0;
    return parsed == parsed.roundToDouble() ? parsed.toInt() : parsed;
  }

  String? _requiredValidator(String? value, String message) {
    if (value == null || value.trim().isEmpty) return message;
    return null;
  }

  String? _phoneValidator(String? value) {
    final digits = value?.replaceAll(RegExp(r'\D'), '') ?? '';
    if (digits.isEmpty) return appLang.translate('aj_phone_req');
    if (digits.length < 9) return appLang.translate('aj_phone_invalid');
    return null;
  }

  String? _salaryValidator(String? value) {
    if (_salaryByAgreement) return null;
    if (value == null || value.trim().isEmpty) {
      return appLang.translate('aj_salary_req');
    }
    final numeric = value.replaceAll(RegExp(r'[^0-9,\.]'), '');
    if (double.tryParse(numeric.replaceAll(',', '.')) == null) {
      return appLang.translate('aj_salary_invalid');
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
      'salary_amount': _salaryAmountValue(),
      'salary': _salaryAmountValue().toString(),
      'phone_whatsapp': _phoneController.text.trim(),
      'contact_person': _contactPersonController.text.trim(),
      'instagram': _instagramController.text.trim(),
      'address': _addressController.text.trim(),
      'address_text': _addressController.text.trim(),
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

    for (var attempt = 0; attempt < 14; attempt++) {
      try {
        final result = await jobs.insert(workingPayload).select();
        return List<Map<String, dynamic>>.from(result);
      } catch (error) {
        lastError = error;
        if (!_isSchemaColumnError(error)) {
          rethrow;
        }

        final missingColumn = _extractMissingColumnKey(error);
        if (missingColumn == null) {
          continue;
        }

        if (workingPayload.containsKey(missingColumn)) {
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

      }
    }

    throw lastError ?? Exception('Job insert failed');
  }

  Future<void> _submitJob() async {
    if (_selectedCategory == null || _selectedDistrict == null || _selectedSchedule == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(appLang.translate('aj_complete_all'))),
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
              final inserted = await _insertJobWithFallback(payload);
              return inserted.isEmpty ? null : inserted.first['id']?.toString();
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
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${appLang.translate('aj_error_prefix')}: $errorMessage')),
      );
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
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
                title: appLang.translate('aj_business_info'),
                icon: Icons.business_rounded,
                children: [
                  TextFormField(
                    controller: _businessNameController,
                    decoration: _fieldDecoration(appLang.translate('aj_business_name'), appLang.translate('aj_business_name_hint'), Icons.storefront_rounded),
                    validator: (value) => _requiredValidator(value, appLang.translate('aj_business_name_req')),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _titleController,
                    decoration: _fieldDecoration(appLang.translate('aj_title_label'), appLang.translate('aj_title_hint'), Icons.badge_rounded),
                    validator: (value) => _requiredValidator(value, appLang.translate('aj_title_req')),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    value: _selectedCategory,
                    decoration: _fieldDecoration(appLang.translate('aj_category'), appLang.translate('aj_category_hint'), Icons.category_rounded),
                    items: [
                      for (var i = 0; i < _categories.length; i++)
                        DropdownMenuItem<String>(
                          value: _categories[i].label,
                          child: Text(appLang.translate('aj_cat_$i')),
                        ),
                    ],
                    onChanged: (value) => setState(() => _selectedCategory = value),
                    validator: (value) => _requiredValidator(value, appLang.translate('aj_category_req')),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    value: _selectedDistrict,
                    decoration: _fieldDecoration(appLang.translate('aj_district'), appLang.translate('aj_district_hint'), Icons.location_city_rounded),
                    items: [
                      for (var i = 0; i < _districts.length; i++)
                        DropdownMenuItem<String>(
                          value: _districts[i],
                          child: Text(appLang.translate('aj_dist_$i')),
                        ),
                    ],
                    onChanged: (value) => setState(() => _selectedDistrict = value),
                    validator: (value) => _requiredValidator(value, appLang.translate('aj_district_req')),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _descriptionController,
                    maxLines: 5,
                    minLines: 3,
                    keyboardType: TextInputType.multiline,
                    textInputAction: TextInputAction.newline,
                    decoration: _fieldDecoration(appLang.translate('aj_description'), appLang.translate('aj_description_hint'), Icons.description_outlined),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              _sectionCard(
                title: appLang.translate('aj_contact_section'),
                icon: Icons.call_rounded,
                children: [
                  TextFormField(
                    controller: _phoneController,
                    keyboardType: TextInputType.phone,
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(RegExp(r'[0-9+\s\-()]')),
                      _AzerbaijanPhoneFormatter(),
                    ],
                    decoration: _fieldDecoration(appLang.translate('aj_phone'), '+994 XX XXX XX XX', Icons.phone_rounded),
                    validator: _phoneValidator,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _contactPersonController,
                    decoration: _fieldDecoration(appLang.translate('aj_contact_person'), appLang.translate('aj_contact_person_hint'), Icons.person_rounded),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _instagramController,
                    decoration: _fieldDecoration('Instagram', appLang.translate('aj_instagram_hint'), Icons.camera_alt_rounded),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              _sectionCard(
                title: appLang.translate('aj_terms_section'),
                icon: Icons.badge_rounded,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: _salaryController,
                          enabled: !_salaryByAgreement,
                          keyboardType: TextInputType.number,
                          decoration: _fieldDecoration(appLang.translate('aj_salary'), appLang.translate('aj_salary_hint'), Icons.attach_money_rounded),
                          validator: _salaryValidator,
                        ),
                      ),
                      const SizedBox(width: 12),
                      SizedBox(
                        width: 150,
                        child: CheckboxListTile(
                          value: _salaryByAgreement,
                          onChanged: (value) => setState(() => _salaryByAgreement = value ?? false),
                          title: Text(appLang.translate('aj_salary_agreement'), style: const TextStyle(fontSize: 12.5)),
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
                    decoration: _fieldDecoration(appLang.translate('aj_schedule'), appLang.translate('aj_schedule_hint'), Icons.schedule_rounded),
                    items: [
                      for (var i = 0; i < _schedules.length; i++)
                        DropdownMenuItem<String>(
                          value: _schedules[i],
                          child: Text(appLang.translate('aj_sch_$i')),
                        ),
                    ],
                    onChanged: (value) => setState(() => _selectedSchedule = value),
                    validator: (value) => _requiredValidator(value, appLang.translate('aj_schedule_req')),
                  ),
                  const SizedBox(height: 12),
                  SwitchListTile.adaptive(
                    contentPadding: EdgeInsets.zero,
                    title: Text(appLang.translate('aj_has_vacancy'), style: const TextStyle(fontWeight: FontWeight.w600)),
                    subtitle: Text(appLang.translate('aj_has_vacancy_sub')),
                    value: _hasVacancy,
                    onChanged: (value) => setState(() => _hasVacancy = value),
                  ),
                  const Divider(height: 16),
                  SwitchListTile.adaptive(
                    contentPadding: EdgeInsets.zero,
                    title: Text(appLang.translate('aj_vip'), style: const TextStyle(fontWeight: FontWeight.w600)),
                    subtitle: Text(appLang.translate('aj_vip_sub')),
                    activeColor: Colors.amber.shade700,
                    value: _isVip,
                    onChanged: (value) => setState(() => _isVip = value),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              _sectionCard(
                title: appLang.translate('location_section'),
                icon: Icons.map_rounded,
                children: [
                  TextFormField(
                    controller: _addressController,
                    maxLines: 2,
                    minLines: 1,
                    onChanged: _onAddressChanged,
                    decoration: _fieldDecoration(appLang.translate('address_search_label'), appLang.translate('address_search_hint'), Icons.search_rounded).copyWith(
                      suffixIcon: _isSearchingAddress
                          ? const Padding(
                              padding: EdgeInsets.all(14),
                              child: SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              ),
                            )
                          : null,
                    ),
                    validator: (value) => _requiredValidator(value, appLang.translate('address_required')),
                  ),
                  if (_suggestions.isNotEmpty)
                    Container(
                      margin: const EdgeInsets.only(top: 6),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                        boxShadow: [
                          BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 10, offset: const Offset(0, 4)),
                        ],
                      ),
                      child: Column(
                        children: [
                          for (final suggestion in _suggestions)
                            ListTile(
                              dense: true,
                              leading: const Icon(Icons.place_outlined, color: Color(0xFF2563EB)),
                              title: Text(
                                suggestion.displayName,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(fontSize: 13.5),
                              ),
                              onTap: () => _selectSuggestion(suggestion),
                            ),
                        ],
                      ),
                    ),
                  const SizedBox(height: 12),
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
                      : Text(
                          appLang.translate('aj_submit'),
                          style: TextStyle(color: Colors.white, fontSize: 15.5, fontWeight: FontWeight.w700),
                        ),
                ),
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
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:typed_data';
import '../services/app_language.dart';
import '../services/admin_auth_service.dart';
import '../services/payment_service.dart';
import 'auth_screen.dart';
import 'home_map_screen.dart';
import 'payment_checkout_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  bool _isLoading = true;
  List<Map<String, dynamic>> _myApplications = [];
  String _selectedFilter = 'all';

  // Profil Məlumatları
  String _userName = '';
  String _userRole = '';
  String _userPhone = '';
  bool _profileLoading = true;
  int _savedJobsCount = 0;
  RealtimeChannel? _realtimeChannel;
  String _uploadedCvName = '';
  String _cvPath = '';
  Uint8List? _profileImageBytes;
  String? _profileImageUrl;
  bool _isUploadingProfileImage = false;
  bool _isUploadingCv = false;
  bool _isAdminUser = false;

  // Settings parametrlləri
  bool _pushNotifications = true;

  @override
  void initState() {
    super.initState();
    appLang.addListener(_onLanguageChanged);
    final avatarUrl = Supabase.instance.client.auth.currentUser?.userMetadata?['avatar_url']?.toString();
    if (avatarUrl != null && avatarUrl.isNotEmpty) {
      _profileImageUrl = avatarUrl;
    }
    _loadAdminStatus();
    _loadProfile();
    _fetchMyApplications();
    _fetchSavedJobsCount();
    _subscribeToChanges();
  }

  @override
  void dispose() {
    final channel = _realtimeChannel;
    if (channel != null) Supabase.instance.client.removeChannel(channel);
    appLang.removeListener(_onLanguageChanged);
    super.dispose();
  }

  // Theme-aware palette driven by the app-wide ThemeService via ThemeData.
  bool get _isDark => Theme.of(context).brightness == Brightness.dark;
  Color get _bg =>
      _isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC);
  Color get _surface => _isDark ? const Color(0xFF1E293B) : Colors.white;
  Color get _text => _isDark ? Colors.white : const Color(0xFF0F172A);
  Color get _textSoft =>
      _isDark ? const Color(0xFFCBD5E1) : const Color(0xFF475569);
  Color get _muted =>
      _isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);
  Color get _line =>
      _isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0);
  Color get _border => _isDark ? Colors.white10 : const Color(0x1F000000);

  InputDecoration _fieldDecoration(String label, String hint) {
    OutlineInputBorder border(Color color) => OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: color),
        );
    return InputDecoration(
      labelText: label,
      hintText: hint,
      labelStyle: TextStyle(color: _muted),
      hintStyle: TextStyle(color: _muted),
      filled: true,
      fillColor: _surface,
      enabledBorder: border(_isDark ? const Color(0xFF475569) : _line),
      focusedBorder: border(const Color(0xFF2563EB)),
    );
  }

  void _onLanguageChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  Future<void> _loadAdminStatus() async {
    final isAdmin = await AdminAuthService.isAdminUser(Supabase.instance.client);
    if (!mounted) return;
    setState(() => _isAdminUser = isAdmin);
  }

  // Profile completeness: name, profession, phone and an uploaded CV, 25% each.
  double get _cvCompletionPercent {
    var filled = 0;
    if (_userName.trim().isNotEmpty) filled++;
    if (_userRole.trim().isNotEmpty) filled++;
    if (_userPhone.trim().isNotEmpty) filled++;
    if (_cvPath.isNotEmpty) filled++;
    return filled / 4;
  }

  // Applications an employer has already reviewed or accepted.
  int get _reviewedCount => _myApplications.where((app) {
        final status = (app['status'] ?? '').toString().toLowerCase();
        return status.contains('baxıldı') ||
            status.contains('reviewed') ||
            status.contains('qəbul') ||
            status.contains('accepted');
      }).length;

  String get _cvLabel =>
      _uploadedCvName.isEmpty ? appLang.translate('cv_not_uploaded') : _uploadedCvName;

  Future<void> _loadProfile() async {
    final client = Supabase.instance.client;
    final user = client.auth.currentUser;
    if (user == null) return;
    Future<Map<String, dynamic>?> fetch(String columns) => client
        .from('profiles')
        .select(columns)
        .eq('id', user.id)
        .maybeSingle();

    Map<String, dynamic>? profile;
    try {
      try {
        profile = await fetch('full_name, phone, profession, cv_path, cv_name');
      } on PostgrestException catch (error) {
        // CV columns may not exist yet (migration not applied): the name,
        // profession and phone must still load.
        debugPrint('Profile load (with CV) failed: ${error.code} ${error.message}');
        profile = await fetch('full_name, phone, profession');
      }
      if (!mounted) return;
      setState(() {
        _userName = (profile?['full_name'] ?? '').toString();
        _userRole = (profile?['profession'] ?? '').toString();
        _userPhone = (profile?['phone'] ?? user.phone ?? '').toString();
        _cvPath = (profile?['cv_path'] ?? '').toString();
        _uploadedCvName = (profile?['cv_name'] ?? '').toString();
        _profileLoading = false;
      });
    } catch (error) {
      // Keep whatever is already shown instead of wiping it on a failed read.
      debugPrint('Profile load failed: $error');
      if (!mounted) return;
      setState(() {
        if (_userPhone.isEmpty) _userPhone = user.phone ?? '';
        _profileLoading = false;
      });
    }
  }

  Future<bool> _saveProfile(String name, String role, String phone) async {
    final client = Supabase.instance.client;
    final user = client.auth.currentUser;
    if (user == null) {
      _showUploadMessage(appLang.translate('edit_profile_save_failed'),
          isError: true);
      return false;
    }
    final values = {
      'full_name': name.trim(),
      'profession': role.trim(),
      'phone': phone.trim(),
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    };
    try {
      // Update without sending `id`: it is not an updatable column under the
      // column-level grants, and an upsert would try to set it.
      final updated = await client
          .from('profiles')
          .update(values)
          .eq('id', user.id)
          .select('id');
      if (updated.isEmpty) {
        await client.from('profiles').insert({'id': user.id, ...values});
      }
      if (!mounted) return true;
      setState(() {
        _userName = values['full_name']!;
        _userRole = values['profession']!;
        _userPhone = values['phone']!;
      });
      return true;
    } on PostgrestException catch (error) {
      debugPrint('Profile save failed: ${error.code} ${error.message}');
      _showUploadMessage(
          '${appLang.translate('edit_profile_save_failed')} (${error.code ?? 'error'})',
          isError: true);
      return false;
    } catch (error) {
      debugPrint('Profile save failed: $error');
      _showUploadMessage(appLang.translate('edit_profile_save_failed'),
          isError: true);
      return false;
    }
  }

  Future<void> _fetchSavedJobsCount() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return;
    try {
      final count = await Supabase.instance.client
          .from('saved_jobs')
          .count(CountOption.exact)
          .eq('user_id', user.id);
      if (mounted) setState(() => _savedJobsCount = count);
    } catch (_) {}
  }

  void _subscribeToChanges() {
    final client = Supabase.instance.client;
    _realtimeChannel = client
        .channel('profile-counters')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'applications',
          callback: (_) => _fetchMyApplications(),
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'saved_jobs',
          callback: (_) => _fetchSavedJobsCount(),
        )
        .subscribe();
  }

  Future<void> _fetchMyApplications() async {
    try {
      final client = Supabase.instance.client;
      final phone = client.auth.currentUser?.phone;
      final applicant = phone == null
          ? null
          : await client
              .from('users')
              .select('id')
              .eq('phone_number', phone)
              .maybeSingle();
      if (applicant == null) {
        if (mounted) {
          setState(() {
            _myApplications = [];
            _isLoading = false;
          });
        }
        return;
      }

      final response = await client
          .from('applications')
          .select('*, jobs(title, company_name, salary_amount, category)')
          .eq('applicant_id', applicant['id'])
          .order('created_at', ascending: false);

      if (mounted) {
        setState(() {
          _myApplications = List<Map<String, dynamic>>.from(response);
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _pickCvFile() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf'],
      withData: true,
    );
    if (!mounted || result == null || result.files.isEmpty) return;

    final file = result.files.single;
    const maxFileSize = 10 * 1024 * 1024;
    if (file.size > maxFileSize) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('CV faylının həcmi 10 MB-dan çox ola bilməz.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    final user = Supabase.instance.client.auth.currentUser;
    final bytes = file.bytes;
    if (user == null || bytes == null) {
      _showUploadMessage('CV yükləmək üçün hesaba daxil olun.', isError: true);
      return;
    }

    setState(() => _isUploadingCv = true);
    try {
      final safeName = file.name.replaceAll(RegExp(r'[^A-Za-z0-9._-]'), '_');
      final path =
          '${user.id}/${DateTime.now().millisecondsSinceEpoch}_$safeName';
      await Supabase.instance.client.storage.from('resumes').uploadBinary(
            path,
            bytes,
            fileOptions: const FileOptions(
              contentType: 'application/pdf',
              upsert: true,
            ),
          );
      final cvValues = {'cv_path': path, 'cv_name': file.name};
      final updated = await Supabase.instance.client
          .from('profiles')
          .update(cvValues)
          .eq('id', user.id)
          .select('id');
      if (updated.isEmpty) {
        await Supabase.instance.client
            .from('profiles')
            .insert({'id': user.id, ...cvValues});
      }

      if (!mounted) return;
      setState(() {
        _uploadedCvName = file.name;
        _cvPath = path;
        _isUploadingCv = false;
      });
      Navigator.pop(context);
      _showUploadMessage('CV faylı uğurla yükləndi və yeniləndi!');
    } catch (error) {
      if (!mounted) return;
      setState(() => _isUploadingCv = false);
      _showUploadMessage('CV yüklənmədi: $error', isError: true);
    }
  }

  Future<void> _pickProfileImage() async {
    try {
      final image = await ImagePicker().pickImage(
        source: ImageSource.gallery,
        imageQuality: 85,
      );
      if (!mounted || image == null) return;

      final imageBytes = await image.readAsBytes();
      if (!mounted) return;
      final user = Supabase.instance.client.auth.currentUser;
      if (user == null) {
        _showUploadMessage('Şəkil yükləmək üçün hesaba daxil olun.', isError: true);
        return;
      }

      setState(() => _isUploadingProfileImage = true);
      final extension = image.path.split('.').last.toLowerCase();
      final contentType = image.mimeType ?? 'image/$extension';
      final path =
          '${user.id}/${DateTime.now().millisecondsSinceEpoch}.$extension';
      await Supabase.instance.client.storage.from('avatars').uploadBinary(
            path,
            imageBytes,
            fileOptions: FileOptions(contentType: contentType, upsert: true),
          );
      final publicUrl = Supabase.instance.client.storage
          .from('avatars')
          .getPublicUrl(path);
      await Supabase.instance.client.auth.updateUser(
        UserAttributes(data: {'avatar_url': publicUrl}),
      );

      if (!mounted) return;
      setState(() {
        _profileImageBytes = imageBytes;
        _profileImageUrl = publicUrl;
        _isUploadingProfileImage = false;
      });
      _showUploadMessage('Profil şəkli uğurla yeniləndi!');
    } catch (error) {
      if (!mounted) return;
      setState(() => _isUploadingProfileImage = false);
      _showUploadMessage('Profil şəkli yüklənmədi: $error', isError: true);
    }
  }

  void _showUploadMessage(String message, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.red : Colors.green,
      ),
    );
  }

  List<Map<String, dynamic>> get _filteredApplications {
    if (_selectedFilter == 'all') return _myApplications;
    return _myApplications.where((app) {
      final status = (app['status'] ?? '').toString().toLowerCase();
      if (_selectedFilter == 'reviewed') {
        return status.contains('baxıldı') || status.contains('reviewed');
      }
      if (_selectedFilter == 'accepted') {
        return status.contains('qəbul') || status.contains('accepted');
      }
      return true;
    }).toList();
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'qəbul edildi':
      case 'accepted':
        return Colors.green;
      case 'baxıldı':
      case 'reviewed':
        return const Color(0xFF2563EB);
      case 'imtina edildi':
      case 'rejected':
        return Colors.red;
      default:
        return Colors.orange;
    }
  }

  // TƏNZİMLƏMƏLƏR MODALİ (SETTINGS)
  void _showSettingsModal() {
    showModalBottomSheet(
      context: context,
      backgroundColor: _surface,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Padding(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: const Color(0xFF64748B),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(appLang.translate('settings_title'),
                          style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: _text)),
                      IconButton(
                        onPressed: () => Navigator.pop(context),
                        icon: Icon(Icons.close, color: _text),
                        tooltip: appLang.translate('close'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Bildiriş ayarı
                  SwitchListTile(
                    title: Text(appLang.translate('settings_notifications'),
                        style: TextStyle(
                        color: _text,
                        fontWeight: FontWeight.w600,
                        fontSize: 14)),
                    subtitle: Text(
                      appLang.translate('notifications_nearby_subtitle'),
                      style: TextStyle(
                        color: _muted, fontSize: 12)),
                    value: _pushNotifications,
                    activeColor: const Color(0xFF2563EB),
                    onChanged: (val) {
                      setModalState(() => _pushNotifications = val);
                      setState(() {});
                    },
                  ),
                  Divider(color: _line),

                  // WorkSpot Biznes & Paketlər
                  ListTile(
                    leading: const Icon(Icons.workspace_premium_rounded,
                        color: Color(0xFFFFD700)),
                    title: Text(appLang.translate('biznes_packages_title'),
                        style: TextStyle(
                            color: _text,
                            fontWeight: FontWeight.w600,
                            fontSize: 14)),
                    subtitle: Text(
                        appLang.translate('biznes_packages_subtitle'),
                        style: TextStyle(color: _muted, fontSize: 12)),
                    onTap: () {
                      Navigator.pop(context);
                      final userId =
                          Supabase.instance.client.auth.currentUser?.id ?? '';
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => PaymentCheckoutScreen(
                            targetId: userId,
                            targetType: PaymentTargetType.proSubscription,
                          ),
                        ),
                      );
                    },
                  ),
                  Divider(color: _line),

                  if (_isAdminUser) ...[
                    ListTile(
                      leading: const Icon(Icons.dashboard_rounded,
                          color: Color(0xFF38BDF8)),
                      title: Text('Admin Dashboard',
                          style: TextStyle(
                              color: _text,
                              fontWeight: FontWeight.w600,
                              fontSize: 14)),
                      subtitle: Text(
                        'Total system management',
                        style: TextStyle(color: _muted, fontSize: 12),
                      ),
                      onTap: () {
                        Navigator.pop(context);
                        Navigator.pushNamed(context, '/admin');
                      },
                    ),
                    Divider(color: _line),
                  ],

                  // Çıxış düyməsi
                  ListTile(
                    leading:
                        const Icon(Icons.logout_rounded, color: Colors.red),
                    title: Text(appLang.translate('logout'),
                        style: TextStyle(
                            color: Colors.red,
                            fontWeight: FontWeight.bold,
                            fontSize: 14)),
                    onTap: () async {
                      final navigator = Navigator.of(this.context);
                      Navigator.pop(
                          context); // Əvvəlcə Ayarlar modalını bağlayır
                      try {
                        await Supabase.instance.client.auth.signOut();
                      } catch (error) {
                        debugPrint('signOut failed: $error');
                      }
                      // Arxadakı bütün ekranları silir və Giriş ekranına atır
                      navigator.pushAndRemoveUntil(
                        MaterialPageRoute(
                            builder: (_) => const AuthScreen()),
                        (Route<dynamic> route) => false,
                      );
                    },
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  // CV YÜKLƏMƏ / YENİLMƏ MODALİ
  void _showCvUploadModal() {
    showModalBottomSheet(
      context: context,
      backgroundColor: _bg,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Rəqəmsal CV-ni Yenilə',
                  style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: _text)),
              const SizedBox(height: 8),
              Text('${appLang.translate('current_file')}: $_cvLabel',
                  style: TextStyle(fontSize: 12, color: _textSoft)),
              const SizedBox(height: 16),

              // Fayl Yükləmə Sahəsi
              InkWell(
                onTap: _isUploadingCv ? null : _pickCvFile,
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: _surface,
                    borderRadius: BorderRadius.circular(16),
                    border:
                        Border.all(color: const Color(0xFF2563EB), width: 1.5),
                  ),
                  child: Column(
                    children: [
                      _isUploadingCv
                          ? const SizedBox(
                              width: 40,
                              height: 40,
                              child: CircularProgressIndicator(
                                color: Color(0xFF2563EB),
                              ),
                            )
                          : const Icon(Icons.cloud_upload_outlined,
                              size: 40, color: Color(0xFF2563EB)),
                      SizedBox(height: 8),
                      Text('PDF faylı seçin',
                          style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF2563EB))),
                      SizedBox(height: 4),
                      Text('Maksimum fayl həcmi: 10 MB',
                          style: TextStyle(fontSize: 11, color: _muted)),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _showEditProfileModal() {
    final nameController = TextEditingController(text: _userName);
    final roleController = TextEditingController(text: _userRole);
    final phoneController = TextEditingController(text: _userPhone);

    showModalBottomSheet(
      context: context,
      backgroundColor: _bg,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return Padding(
          padding: EdgeInsets.only(
            top: 20,
            left: 20,
            right: 20,
            bottom: MediaQuery.of(context).viewInsets.bottom + 20,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(appLang.translate('edit_profile'),
                      style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: _text)),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: Icon(Icons.close, color: _text),
                    tooltip: appLang.translate('close'),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              TextField(
                controller: nameController,
                style: TextStyle(color: _text),
                decoration: _fieldDecoration(
                  appLang.translate('edit_profile_name_label'),
                  appLang.translate('edit_profile_name_hint'),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: roleController,
                style: TextStyle(color: _text),
                decoration: _fieldDecoration(
                  appLang.translate('edit_profile_role_label'),
                  appLang.translate('edit_profile_role_hint'),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: phoneController,
                style: TextStyle(color: _text),
                keyboardType: TextInputType.phone,
                decoration: _fieldDecoration(
                  appLang.translate('edit_profile_phone_label'),
                  '+994 50 123 45 67',
                ),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  onPressed: () async {
                    final saved = await _saveProfile(nameController.text,
                        roleController.text, phoneController.text);
                    if (saved && context.mounted) Navigator.pop(context);
                  },
                  style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF2563EB)),
                  child: Text(appLang.translate('edit_profile_save'),
                      style: const TextStyle(
                          color: Colors.white, fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        title: Text(appLang.translate('profile_title'),
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
        backgroundColor: _bg,
        foregroundColor: _text,
        elevation: 0.5,
        actions: [
          IconButton(
            icon: Icon(Icons.settings_outlined, color: _textSoft),
            tooltip: appLang.translate('settings_title'),
            onPressed: _showSettingsModal,
          ),
        ],
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 900),
          child: RefreshIndicator(
            onRefresh: () async {
              setState(() => _isLoading = true);
              await _fetchMyApplications();
            },
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20.0),
              physics: const AlwaysScrollableScrollPhysics(),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Əsas Profil Kartı
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: _surface,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: _border),
                    ),
                    child: Column(
                      children: [
                        Row(
                          children: [
                            SizedBox(
                              width: 64,
                              height: 64,
                              child: Stack(
                                clipBehavior: Clip.none,
                                children: [
                                  Container(
                                    width: 64,
                                    height: 64,
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF2563EB)
                                          .withOpacity(0.12),
                                      shape: BoxShape.circle,
                                      border: Border.all(
                                          color: const Color(0xFF2563EB),
                                          width: 2),
                                      image: _profileImageBytes != null
                                          ? DecorationImage(
                                              image: MemoryImage(
                                                  _profileImageBytes!),
                                              fit: BoxFit.cover,
                                            )
                                          : _profileImageUrl != null
                                              ? DecorationImage(
                                                  image: NetworkImage(
                                                      _profileImageUrl!),
                                                  fit: BoxFit.cover,
                                                )
                                              : null,
                                    ),
                                    child: _profileImageBytes == null &&
                                            _profileImageUrl == null
                                        ? const Icon(Icons.person,
                                            size: 38,
                                            color: Color(0xFF2563EB))
                                        : null,
                                  ),
                                  Positioned(
                                    right: -4,
                                    bottom: -4,
                                    child: Material(
                                      color: const Color(0xFF2563EB),
                                      shape: const CircleBorder(),
                                      child: InkWell(
                                        onTap: _isUploadingProfileImage
                                            ? null
                                            : _pickProfileImage,
                                        customBorder: const CircleBorder(),
                                        child: Padding(
                                          padding: const EdgeInsets.all(6),
                                          child: _isUploadingProfileImage
                                              ? const SizedBox(
                                                  width: 14,
                                                  height: 14,
                                                  child:
                                                      CircularProgressIndicator(
                                                    strokeWidth: 2,
                                                    color: Colors.white,
                                                  ),
                                                )
                                              : const Icon(Icons.camera_alt,
                                                  size: 14,
                                                  color: Colors.white),
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                      _userName.trim().isEmpty
                                          ? _profileLoading
                                              ? '...'
                                              : appLang.translate(
                                              'profile_name_placeholder')
                                          : _userName,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                          fontSize: 18,
                                          fontWeight: FontWeight.bold,
                                          color: _userName.trim().isEmpty
                                              ? _muted
                                              : _text)),
                                  const SizedBox(height: 2),
                                  Text(
                                      _userRole.trim().isEmpty
                                          ? appLang.translate(
                                              'profile_role_placeholder')
                                          : _userRole,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                          color: _userRole.trim().isEmpty
                                              ? _muted
                                              : _textSoft,
                                          fontSize: 13)),
                                  const SizedBox(height: 6),
                                  Row(
                                    children: [
                                      Icon(Icons.phone_outlined,
                                          size: 14, color: _muted),
                                      const SizedBox(width: 4),
                                      Text(
                                          _userPhone.trim().isEmpty
                                              ? appLang.translate(
                                                  'profile_phone_placeholder')
                                              : _userPhone,
                                          style: TextStyle(
                                              color: _userPhone.trim().isEmpty
                                                  ? _muted
                                                  : _textSoft,
                                              fontSize: 12)),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.edit_note_rounded,
                                  color: Color(0xFF2563EB), size: 28),
                              onPressed: _showEditProfileModal,
                            ),
                          ],
                        ),
                        const SizedBox(height: 18),
                        Divider(height: 1, color: _line),
                        const SizedBox(height: 16),

                        // Rəqəmsal CV Statusu və Yükləmə Düyməsi
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Row(
                                  children: [
                                    const Icon(Icons.description_outlined,
                                        size: 18, color: Color(0xFF2563EB)),
                                    const SizedBox(width: 6),
                                    Text(appLang.translate('cv_status'),
                                        style: TextStyle(
                                            fontSize: 13,
                                            fontWeight: FontWeight.w600,
                                            color: _text)),
                                  ],
                                ),
                                Text('${(_cvCompletionPercent * 100).toInt()}%',
                                    style: const TextStyle(
                                        color: Color(0xFF2563EB),
                                        fontWeight: FontWeight.bold,
                                        fontSize: 13)),
                              ],
                            ),
                            const SizedBox(height: 8),
                            ClipRRect(
                              borderRadius: BorderRadius.circular(6),
                              child: LinearProgressIndicator(
                                value: _cvCompletionPercent,
                                minHeight: 8,
                                backgroundColor: _line,
                                valueColor: const AlwaysStoppedAnimation<Color>(
                                    Color(0xFF2563EB)),
                              ),
                            ),
                            const SizedBox(height: 12),

                            // CV Faylı Düyməsi
                            ElevatedButton.icon(
                              onPressed: _showCvUploadModal,
                              icon: const Icon(Icons.upload_file_rounded,
                                  size: 18, color: Colors.white),
                              label: Text(
                                  '${appLang.translate('update_cv')} ($_cvLabel)',
                                  style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold)),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF334155),
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(10)),
                                minimumSize: const Size(double.infinity, 38),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Statistikalar
                  Row(
                    children: [
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              vertical: 16, horizontal: 12),
                          decoration: BoxDecoration(
                            color: _surface,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: _border),
                          ),
                          child: Column(
                            children: [
                              Text('${_myApplications.length}',
                                  style: const TextStyle(
                                      fontSize: 22,
                                      fontWeight: FontWeight.bold,
                                      color: Color(0xFF2563EB))),
                              const SizedBox(height: 4),
                              Text(appLang.translate('stat_applications'),
                                  style: TextStyle(
                                      fontSize: 12,
                                      color: _textSoft,
                                      fontWeight: FontWeight.w500)),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              vertical: 16, horizontal: 12),
                          decoration: BoxDecoration(
                            color: _surface,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: _border),
                          ),
                          child: Column(
                            children: [
                              Text('$_reviewedCount',
                                  style: const TextStyle(
                                      fontSize: 22,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.green)),
                              SizedBox(height: 4),
                              Text(appLang.translate('stat_cv_views'),
                                  style: TextStyle(
                                      fontSize: 12,
                                      color: _textSoft,
                                      fontWeight: FontWeight.w500)),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              vertical: 16, horizontal: 12),
                          decoration: BoxDecoration(
                            color: _surface,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: _border),
                          ),
                          child: Column(
                            children: [
                              Text('$_savedJobsCount',
                                  style: TextStyle(
                                      fontSize: 22,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.amber)),
                              SizedBox(height: 4),
                              Text(appLang.translate('stat_favorites'),
                                  style: TextStyle(
                                      fontSize: 12,
                                      color: _textSoft,
                                      fontWeight: FontWeight.w500)),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),

                  // Müraciətlərim Başlıq
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(appLang.translate('my_applications'),
                          style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: _text)),
                      IconButton(
                        icon: const Icon(Icons.sync_rounded,
                            size: 22, color: Color(0xFF2563EB)),
                        tooltip: appLang.translate('refresh'),
                        onPressed: () {
                          setState(() => _isLoading = true);
                          _fetchMyApplications();
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),

                  // Süzgəclər
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        FilterChip(
                            label: Text(
                              '${appLang.translate('tab_all')} (${_myApplications.length})'),
                          selected: _selectedFilter == 'all',
                          selectedColor: const Color(0xFF2563EB),
                          backgroundColor: _surface,
                          side: BorderSide(color: _border),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(20)),
                          labelStyle: TextStyle(
                              color: _selectedFilter == 'all'
                                  ? Colors.white
                                  : _textSoft,
                              fontSize: 12),
                          onSelected: (val) =>
                              setState(() => _selectedFilter = 'all'),
                        ),
                        const SizedBox(width: 8),
                        FilterChip(
                          label: Text(appLang.translate('tab_reviewed')),
                          selected: _selectedFilter == 'reviewed',
                          selectedColor: const Color(0xFF2563EB),
                          backgroundColor: _surface,
                          side: BorderSide(color: _border),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(20)),
                          labelStyle: TextStyle(
                              color: _selectedFilter == 'reviewed'
                                  ? Colors.white
                                  : _textSoft,
                              fontSize: 12),
                          onSelected: (val) =>
                              setState(() => _selectedFilter = 'reviewed'),
                        ),
                        const SizedBox(width: 8),
                        FilterChip(
                          label: Text(appLang.translate('tab_accepted')),
                          selected: _selectedFilter == 'accepted',
                          selectedColor: const Color(0xFF2563EB),
                          backgroundColor: _surface,
                          side: BorderSide(color: _border),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(20)),
                          labelStyle: TextStyle(
                              color: _selectedFilter == 'accepted'
                                  ? Colors.white
                                  : _textSoft,
                              fontSize: 12),
                          onSelected: (val) =>
                              setState(() => _selectedFilter = 'accepted'),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),

                  // Müraciətlər Siyahısı
                  _isLoading
                      ? const Center(
                          child: Padding(
                              padding: EdgeInsets.all(40),
                              child: CircularProgressIndicator()))
                      : _filteredApplications.isEmpty
                          ? Container(
                              padding: const EdgeInsets.all(32),
                              width: double.infinity,
                              decoration: BoxDecoration(
                                color: _surface,
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(color: _border),
                              ),
                              child: Column(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(16),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF2563EB)
                                          .withOpacity(0.08),
                                      shape: BoxShape.circle,
                                    ),
                                    child: const Icon(
                                        Icons.work_outline_rounded,
                                        size: 44,
                                        color: Color(0xFF2563EB)),
                                  ),
                                  const SizedBox(height: 14),
                                  Text(
                                    appLang.translate('no_applications_yet'),
                                    style: TextStyle(
                                        color: _text,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 15),
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    appLang.translate('no_applications_sub'),
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                        color: _muted, fontSize: 13),
                                  ),
                                  const SizedBox(height: 18),
                                  ElevatedButton.icon(
                                    onPressed: () {
                                      Navigator.pushReplacement(
                                        context,
                                        MaterialPageRoute(
                                          builder: (_) => const HomeMapScreen(),
                                        ),
                                      );
                                    },
                                    icon: const Icon(Icons.map_outlined,
                                        color: Colors.white, size: 18),
                                    label: Text(appLang.translate('find_jobs_map'),
                                        style: TextStyle(
                                            color: Colors.white,
                                            fontWeight: FontWeight.bold)),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: const Color(0xFF2563EB),
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 20, vertical: 12),
                                      shape: RoundedRectangleBorder(
                                          borderRadius:
                                              BorderRadius.circular(12)),
                                    ),
                                  ),
                                ],
                              ),
                            )
                          : ListView.builder(
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              itemCount: _filteredApplications.length,
                              itemBuilder: (context, index) {
                                final item = _filteredApplications[index];
                                final jobData =
                                    item['jobs'] as Map<String, dynamic>?;
                                final status = item['status'] ?? 'Gözləmədə';

                                return Container(
                                  margin: const EdgeInsets.only(bottom: 12),
                                  decoration: BoxDecoration(
                                    color: _surface,
                                    borderRadius: BorderRadius.circular(16),
                                    border: Border.all(color: _border),
                                    boxShadow: [
                                      BoxShadow(
                                          color: Colors.black.withOpacity(0.02),
                                          blurRadius: 6,
                                          offset: const Offset(0, 2)),
                                    ],
                                  ),
                                  child: ListTile(
                                    contentPadding: const EdgeInsets.symmetric(
                                        horizontal: 16, vertical: 8),
                                    leading: CircleAvatar(
                                      backgroundColor: const Color(0xFF2563EB)
                                          .withOpacity(0.1),
                                      child: const Icon(
                                          Icons.business_center_rounded,
                                          color: Color(0xFF2563EB),
                                          size: 20),
                                    ),
                                    title: Text(
                                      jobData?['title'] ?? 'Vakansiya',
                                      style: TextStyle(
                                          color: _text,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 15),
                                    ),
                                    subtitle: Padding(
                                      padding: const EdgeInsets.only(top: 4.0),
                                      child: Text(
                                        '${jobData?['company_name'] ?? 'Şirkət'} • ${jobData?['salary_amount'] ?? 0} AZN',
                                        style: TextStyle(
                                            color: _muted, fontSize: 13),
                                      ),
                                    ),
                                    trailing: Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 10, vertical: 6),
                                      decoration: BoxDecoration(
                                        color: _getStatusColor(status)
                                            .withOpacity(0.12),
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                      child: Text(
                                        status,
                                        style: TextStyle(
                                          color: _getStatusColor(status),
                                          fontWeight: FontWeight.bold,
                                          fontSize: 12,
                                        ),
                                      ),
                                    ),
                                  ),
                                );
                              },
                            ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:typed_data';
import '../services/app_language.dart';
import 'auth_screen.dart';
import 'home_map_screen.dart';

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
  String _userName = 'Mirhüseyn Kazımzadə';
  String _userRole = 'Flutter Developer / System Builder';
  String _userPhone = '+994 50 123 45 67';
  String _uploadedCvName = 'Mirhuseyn_Kazimzade_CV.pdf';
  double _cvCompletionPercent = 0.85;
  Uint8List? _profileImageBytes;
  String? _profileImageUrl;
  bool _isUploadingProfileImage = false;
  bool _isUploadingCv = false;

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
    _fetchMyApplications();
  }

  @override
  void dispose() {
    appLang.removeListener(_onLanguageChanged);
    super.dispose();
  }

  void _onLanguageChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  Future<void> _fetchMyApplications() async {
    try {
      final response = await Supabase.instance.client
          .from('applications')
          .select('*, jobs(title, company_name, salary_amount, category)')
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
      await Supabase.instance.client.storage.from('cvs').uploadBinary(
            path,
            bytes,
            fileOptions: const FileOptions(
              contentType: 'application/pdf',
              upsert: true,
            ),
          );
      final publicUrl = Supabase.instance.client.storage
          .from('cvs')
          .getPublicUrl(path);
      await Supabase.instance.client.auth.updateUser(
        UserAttributes(data: {'cv_url': publicUrl, 'cv_name': file.name}),
      );

      if (!mounted) return;
      setState(() {
        _uploadedCvName = file.name;
        _cvCompletionPercent = 1.0;
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
    final image = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      imageQuality: 85,
    );
    if (!mounted || image == null) return;

    final imageBytes = await image.readAsBytes();
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) {
      _showUploadMessage('Şəkil yükləmək üçün hesaba daxil olun.', isError: true);
      return;
    }

    setState(() => _isUploadingProfileImage = true);
    try {
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
      if (_selectedFilter == 'reviewed')
        return status.contains('baxıldı') || status.contains('reviewed');
      if (_selectedFilter == 'accepted')
        return status.contains('qəbul') || status.contains('accepted');
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
      backgroundColor: const Color(0xFF1E293B),
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
                              color: Colors.white)),
                      IconButton(
                        onPressed: () => Navigator.pop(context),
                        icon: const Icon(Icons.close, color: Colors.white),
                        tooltip: 'Bağla',
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Bildiriş ayarı
                  SwitchListTile(
                    title: Text(appLang.translate('settings_notifications'),
                        style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                        fontSize: 14)),
                    subtitle: Text(
                      appLang.translate('notifications_nearby_subtitle'),
                      style: TextStyle(
                        color: Colors.grey[400], fontSize: 12)),
                    value: _pushNotifications,
                    activeColor: const Color(0xFF2563EB),
                    onChanged: (val) {
                      setModalState(() => _pushNotifications = val);
                      setState(() {});
                    },
                  ),
                  const Divider(color: Color(0xFF334155)),

                  // Çıxış düyməsi
                  ListTile(
                    leading:
                        const Icon(Icons.logout_rounded, color: Colors.red),
                    title: Text(appLang.translate('logout'),
                        style: TextStyle(
                            color: Colors.red,
                            fontWeight: FontWeight.bold,
                            fontSize: 14)),
                    onTap: () {
                      Navigator.pop(
                          context); // Əvvəlcə Ayarlar modalını bağlayır
                      Navigator.of(context).pushAndRemoveUntil(
                        MaterialPageRoute(
                            builder: (context) => const AuthScreen()),
                        (Route<dynamic> route) =>
                            false, // Arxadakı bütün ekranları silir və Giriş ekranına atır
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
      backgroundColor: const Color(0xFF0F172A),
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
              const Text('Rəqəmsal CV-ni Yenilə',
                  style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.white)),
              const SizedBox(height: 8),
              Text('Mövcud fayl: $_uploadedCvName',
                  style:
                      const TextStyle(fontSize: 12, color: Color(0xFFCBD5E1))),
              const SizedBox(height: 16),

              // Fayl Yükləmə Sahəsi
              InkWell(
                onTap: _isUploadingCv ? null : _pickCvFile,
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1E293B),
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
                      Text('PDF və ya DOCX faylı seçin',
                          style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF2563EB))),
                      SizedBox(height: 4),
                      Text('Maksimum fayl həcmi: 10 MB',
                          style: TextStyle(
                              fontSize: 11, color: Color(0xFF94A3B8))),
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
      backgroundColor: const Color(0xFF0F172A),
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
                          color: Colors.white)),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close, color: Colors.white),
                    tooltip: 'Bağla',
                  ),
                ],
              ),
              const SizedBox(height: 16),
              TextField(
                controller: nameController,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  labelText: 'Ad və Soyad',
                  hintText: 'Ad və soyadınızı daxil edin',
                  labelStyle: TextStyle(color: Colors.grey[400]),
                  hintStyle: TextStyle(color: Colors.grey[400]),
                  filled: true,
                  fillColor: const Color(0xFF1E293B),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Color(0xFF475569)),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Color(0xFF2563EB)),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: roleController,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  labelText: 'İxtisas / Vəzifə',
                  hintText: 'İxtisasınızı və ya vəzifənizi daxil edin',
                  labelStyle: TextStyle(color: Colors.grey[400]),
                  hintStyle: TextStyle(color: Colors.grey[400]),
                  filled: true,
                  fillColor: const Color(0xFF1E293B),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Color(0xFF475569)),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Color(0xFF2563EB)),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: phoneController,
                style: const TextStyle(color: Colors.white),
                keyboardType: TextInputType.phone,
                decoration: InputDecoration(
                  labelText: 'Telefon Nömrəsi',
                  hintText: '+994 50 123 45 67',
                  labelStyle: TextStyle(color: Colors.grey[400]),
                  hintStyle: TextStyle(color: Colors.grey[400]),
                  filled: true,
                  fillColor: const Color(0xFF1E293B),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Color(0xFF475569)),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Color(0xFF2563EB)),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  onPressed: () {
                    setState(() {
                      _userName = nameController.text;
                      _userRole = roleController.text;
                      _userPhone = phoneController.text;
                    });
                    Navigator.pop(context);
                  },
                  style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF2563EB)),
                  child: const Text('Yadda Saqla',
                      style: TextStyle(
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
      backgroundColor: const Color(0xFF0F172A),
      appBar: AppBar(
        title: Text(appLang.translate('profile_title'),
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
        backgroundColor: const Color(0xFF0F172A),
        foregroundColor: Colors.white,
        elevation: 0.5,
        actions: [
          IconButton(
            icon: const Icon(Icons.settings_outlined, color: Color(0xFFCBD5E1)),
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
                      color: const Color(0xFF1E293B),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: Colors.white10),
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
                                  Text(_userName,
                                      style: const TextStyle(
                                          fontSize: 18,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.white)),
                                  const SizedBox(height: 2),
                                  Text(_userRole,
                                      style: const TextStyle(
                                          color: Color(0xFFCBD5E1),
                                          fontSize: 13)),
                                  const SizedBox(height: 6),
                                  Row(
                                    children: [
                                      const Icon(Icons.phone_outlined,
                                          size: 14, color: Color(0xFF94A3B8)),
                                      const SizedBox(width: 4),
                                      Text(_userPhone,
                                          style: const TextStyle(
                                              color: Color(0xFFCBD5E1),
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
                        const Divider(height: 1, color: Color(0xFF334155)),
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
                                            color: Colors.white)),
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
                                backgroundColor: const Color(0xFF334155),
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
                                  '${appLang.translate('update_cv')} ($_uploadedCvName)',
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
                            color: const Color(0xFF1E293B),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: Colors.white10),
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
                                      color: Color(0xFFCBD5E1),
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
                            color: const Color(0xFF1E293B),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: Colors.white10),
                          ),
                          child: Column(
                            children: [
                              Text('12',
                                  style: TextStyle(
                                      fontSize: 22,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.green)),
                              SizedBox(height: 4),
                              Text(appLang.translate('stat_cv_views'),
                                  style: TextStyle(
                                      fontSize: 12,
                                      color: Color(0xFFCBD5E1),
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
                            color: const Color(0xFF1E293B),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: Colors.white10),
                          ),
                          child: Column(
                            children: [
                              Text('5',
                                  style: TextStyle(
                                      fontSize: 22,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.amber)),
                              SizedBox(height: 4),
                              Text(appLang.translate('stat_favorites'),
                                  style: TextStyle(
                                      fontSize: 12,
                                      color: Color(0xFFCBD5E1),
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
                              color: Colors.white)),
                      IconButton(
                        icon: const Icon(Icons.sync_rounded,
                            size: 22, color: Color(0xFF2563EB)),
                        tooltip: 'Yenilə',
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
                          backgroundColor: const Color(0xFF1E293B),
                          side: const BorderSide(color: Colors.white10),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(20)),
                          labelStyle: TextStyle(
                              color: _selectedFilter == 'all'
                                  ? Colors.white
                                  : const Color(0xFFCBD5E1),
                              fontSize: 12),
                          onSelected: (val) =>
                              setState(() => _selectedFilter = 'all'),
                        ),
                        const SizedBox(width: 8),
                        FilterChip(
                          label: Text(appLang.translate('tab_reviewed')),
                          selected: _selectedFilter == 'reviewed',
                          selectedColor: const Color(0xFF2563EB),
                          backgroundColor: const Color(0xFF1E293B),
                          side: const BorderSide(color: Colors.white10),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(20)),
                          labelStyle: TextStyle(
                              color: _selectedFilter == 'reviewed'
                                  ? Colors.white
                                  : const Color(0xFFCBD5E1),
                              fontSize: 12),
                          onSelected: (val) =>
                              setState(() => _selectedFilter = 'reviewed'),
                        ),
                        const SizedBox(width: 8),
                        FilterChip(
                          label: Text(appLang.translate('tab_accepted')),
                          selected: _selectedFilter == 'accepted',
                          selectedColor: const Color(0xFF2563EB),
                          backgroundColor: const Color(0xFF1E293B),
                          side: const BorderSide(color: Colors.white10),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(20)),
                          labelStyle: TextStyle(
                              color: _selectedFilter == 'accepted'
                                  ? Colors.white
                                  : const Color(0xFFCBD5E1),
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
                                color: const Color(0xFF1E293B),
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(color: Colors.white10),
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
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 15),
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    appLang.translate('no_applications_sub'),
                                    textAlign: TextAlign.center,
                                    style: const TextStyle(
                                        color: Color(0xFF94A3B8), fontSize: 13),
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
                                    color: const Color(0xFF1E293B),
                                    borderRadius: BorderRadius.circular(16),
                                    border: Border.all(color: Colors.white10),
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
                                      style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 15),
                                    ),
                                    subtitle: Padding(
                                      padding: const EdgeInsets.only(top: 4.0),
                                      child: Text(
                                        '${jobData?['company_name'] ?? 'Şirkət'} • ${jobData?['salary_amount'] ?? 0} AZN',
                                        style: const TextStyle(
                                            color: Color(0xFF94A3B8),
                                            fontSize: 13),
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

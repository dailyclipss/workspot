import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/app_language.dart';
import 'auth_screen.dart';

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

  // Settings parametrlləri
  bool _pushNotifications = true;
  String _currentLangCode = 'az';

  @override
  void initState() {
    super.initState();
    appLang.addListener(_onLanguageChanged);
    _fetchMyApplications();
  }

  @override
  void dispose() {
    appLang.removeListener(_onLanguageChanged);
    super.dispose();
  }

  void _onLanguageChanged() {
    if (mounted) setState(() {});
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

  List<Map<String, dynamic>> get _filteredApplications {
    if (_selectedFilter == 'all') return _myApplications;
    return _myApplications.where((app) {
      final status = (app['status'] ?? '').toString().toLowerCase();
      if (_selectedFilter == 'reviewed') return status.contains('baxıldı') || status.contains('reviewed');
      if (_selectedFilter == 'accepted') return status.contains('qəbul') || status.contains('accepted');
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
                    child: Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2))),
                  ),
                  const SizedBox(height: 16),
                  const Text('Tənzimləmələr', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
                  const SizedBox(height: 16),
                  
                  // Bildiriş ayarı
                  SwitchListTile(
                    title: const Text('Vakansiya Bildirişləri', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                    subtitle: const Text('Yaxınlıqda yeni iş çıxdıqda bildiriş al', style: TextStyle(fontSize: 12)),
                    value: _pushNotifications,
                    activeColor: const Color(0xFF2563EB),
                    onChanged: (val) {
                      setModalState(() => _pushNotifications = val);
                      setState(() {});
                    },
                  ),
                  const Divider(),

                  // Tətbiq Dili
                  ListTile(
                    leading: const Icon(Icons.language, color: Color(0xFF2563EB)),
                    title: const Text('Tətbiq Dili', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                    trailing: DropdownButton<String>(
                      value: _currentLangCode,
                      underline: const SizedBox(),
                      items: const [
                        DropdownMenuItem(value: 'az', child: Text('Aze 🇦🇿')),
                        DropdownMenuItem(value: 'ru', child: Text('Rus 🇷🇺')),
                        DropdownMenuItem(value: 'en', child: Text('Eng 🇬🇧')),
                      ],
                      onChanged: (lang) {
                        if (lang != null) {
                          setState(() {
                            _currentLangCode = lang;
                          });
                          Navigator.pop(context);
                        }
                      },
                    ),
                  ),
                  const Divider(),

                  // Çıxış düyməsi
                  ListTile(
                    leading: const Icon(Icons.logout_rounded, color: Colors.red),
                    title: const Text('Hesabdan Çıx', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold, fontSize: 14)),
                    onTap: () {
  Navigator.pop(context); // Əvvəlcə Ayarlar modalını bağlayır
  Navigator.of(context).pushAndRemoveUntil(
    MaterialPageRoute(builder: (context) => const AuthScreen()),
    (Route<dynamic> route) => false, // Arxadakı bütün ekranları silir və Giriş ekranına atır
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
              const Text('Rəqəmsal CV-ni Yenilə', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
              const SizedBox(height: 8),
              Text('Mövcud fayl: $_uploadedCvName', style: const TextStyle(fontSize: 12, color: Colors.grey)),
              const SizedBox(height: 16),

              // Fayl Yükləmə Sahəsi
              InkWell(
                onTap: () {
                  setState(() {
                    _uploadedCvName = 'Yenilenmis_Mirhuseyn_CV.pdf';
                    _cvCompletionPercent = 1.0;
                  });
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('CV faylı uğurla yükləndi və yeniləndi!'), backgroundColor: Colors.green),
                  );
                },
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: const Color(0xFF2563EB).withOpacity(0.05),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFF2563EB), width: 1.5),
                  ),
                  child: Column(
                    children: const [
                      Icon(Icons.cloud_upload_outlined, size: 40, color: Color(0xFF2563EB)),
                      SizedBox(height: 8),
                      Text('PDF və ya DOCX faylı seçin', style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF2563EB))),
                      SizedBox(height: 4),
                      Text('Maksimum fayl həcmi: 10 MB', style: TextStyle(fontSize: 11, color: Colors.grey)),
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
              const Text('Profili Redaktə Et', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 16),
              TextField(
                controller: nameController,
                decoration: InputDecoration(
                  labelText: 'Ad və Soyad',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: roleController,
                decoration: InputDecoration(
                  labelText: 'İxtisas / Vəzifə',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: phoneController,
                decoration: InputDecoration(
                  labelText: 'Telefon Nömrəsi',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
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
                  style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF2563EB)),
                  child: const Text('Yadda Saqla', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
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
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text('Şəxsi Kabinet', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF0F172A),
        elevation: 0.5,
        actions: [
          IconButton(
            icon: const Icon(Icons.settings_outlined, color: Color(0xFF0F172A)),
            tooltip: 'Tənzimləmələr',
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
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 10, offset: const Offset(0, 4)),
                      ],
                    ),
                    child: Column(
                      children: [
                        Row(
                          children: [
                            Container(
                              width: 64,
                              height: 64,
                              decoration: BoxDecoration(
                                color: const Color(0xFF2563EB).withOpacity(0.12),
                                shape: BoxShape.circle,
                                border: Border.all(color: const Color(0xFF2563EB), width: 2),
                              ),
                              child: const Icon(Icons.person, size: 38, color: Color(0xFF2563EB)),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(_userName, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
                                  const SizedBox(height: 2),
                                  Text(_userRole, style: TextStyle(color: Colors.grey[600], fontSize: 13)),
                                  const SizedBox(height: 6),
                                  Row(
                                    children: [
                                      Icon(Icons.phone_outlined, size: 14, color: Colors.grey[500]),
                                      const SizedBox(width: 4),
                                      Text(_userPhone, style: TextStyle(color: Colors.grey[600], fontSize: 12)),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.edit_note_rounded, color: Color(0xFF2563EB), size: 28),
                              onPressed: _showEditProfileModal,
                            ),
                          ],
                        ),
                        const SizedBox(height: 18),
                        const Divider(height: 1),
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
                                    const Icon(Icons.description_outlined, size: 18, color: Color(0xFF2563EB)),
                                    const SizedBox(width: 6),
                                    const Text('Rəqəmsal CV statusu', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                                  ],
                                ),
                                Text('${(_cvCompletionPercent * 100).toInt()}%', style: const TextStyle(color: Color(0xFF2563EB), fontWeight: FontWeight.bold, fontSize: 13)),
                              ],
                            ),
                            const SizedBox(height: 8),
                            ClipRRect(
                              borderRadius: BorderRadius.circular(6),
                              child: LinearProgressIndicator(
                                value: _cvCompletionPercent,
                                minHeight: 8,
                                backgroundColor: Colors.grey.shade200,
                                valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF2563EB)),
                              ),
                            ),
                            const SizedBox(height: 12),
                            
                            // CV Faylı Düyməsi
                            OutlinedButton.icon(
                              onPressed: _showCvUploadModal,
                              icon: const Icon(Icons.upload_file_rounded, size: 18, color: Color(0xFF2563EB)),
                              label: Text('CV Faylını Yenilə ($_uploadedCvName)', style: const TextStyle(color: Color(0xFF2563EB), fontSize: 12, fontWeight: FontWeight.bold)),
                              style: OutlinedButton.styleFrom(
                                side: const BorderSide(color: Color(0xFF2563EB)),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
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
                          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: Colors.grey.shade200),
                          ),
                          child: Column(
                            children: [
                              Text('${_myApplications.length}', style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Color(0xFF2563EB))),
                              const SizedBox(height: 4),
                              Text('Müraciətlər', style: TextStyle(fontSize: 12, color: Colors.grey[600], fontWeight: FontWeight.w500)),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: Colors.grey.shade200),
                          ),
                          child: Column(
                            children: const [
                              Text('12', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.green)),
                              SizedBox(height: 4),
                              Text('Baxılan CV-lər', style: TextStyle(fontSize: 12, color: Colors.grey, fontWeight: FontWeight.w500)),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: Colors.grey.shade200),
                          ),
                          child: Column(
                            children: const [
                              Text('5', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.amber)),
                              SizedBox(height: 4),
                              Text('Bəyənilənlər', style: TextStyle(fontSize: 12, color: Colors.grey, fontWeight: FontWeight.w500)),
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
                      const Text('Göndərdiyim Müraciətlər', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
                      IconButton(
                        icon: const Icon(Icons.sync_rounded, size: 22, color: Color(0xFF2563EB)),
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
                          label: Text('Hamısı (${_myApplications.length})'),
                          selected: _selectedFilter == 'all',
                          selectedColor: const Color(0xFF2563EB),
                          labelStyle: TextStyle(color: _selectedFilter == 'all' ? Colors.white : Colors.black87, fontSize: 12),
                          onSelected: (val) => setState(() => _selectedFilter = 'all'),
                        ),
                        const SizedBox(width: 8),
                        FilterChip(
                          label: const Text('Baxılanlar'),
                          selected: _selectedFilter == 'reviewed',
                          selectedColor: const Color(0xFF2563EB),
                          labelStyle: TextStyle(color: _selectedFilter == 'reviewed' ? Colors.white : Colors.black87, fontSize: 12),
                          onSelected: (val) => setState(() => _selectedFilter = 'reviewed'),
                        ),
                        const SizedBox(width: 8),
                        FilterChip(
                          label: const Text('Qəbul Edilənlər'),
                          selected: _selectedFilter == 'accepted',
                          selectedColor: const Color(0xFF2563EB),
                          labelStyle: TextStyle(color: _selectedFilter == 'accepted' ? Colors.white : Colors.black87, fontSize: 12),
                          onSelected: (val) => setState(() => _selectedFilter = 'accepted'),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),

                  // Müraciətlər Siyahısı
                  _isLoading
                      ? const Center(child: Padding(padding: EdgeInsets.all(40), child: CircularProgressIndicator()))
                      : _filteredApplications.isEmpty
                          ? Container(
                              padding: const EdgeInsets.all(32),
                              width: double.infinity,
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(color: Colors.grey.shade200),
                              ),
                              child: Column(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(16),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF2563EB).withOpacity(0.08),
                                      shape: BoxShape.circle,
                                    ),
                                    child: const Icon(Icons.work_outline_rounded, size: 44, color: Color(0xFF2563EB)),
                                  ),
                                  const SizedBox(height: 14),
                                  const Text(
                                    'Hələ ki heç bir vakansiyaya müraciət etməmisiniz.',
                                    style: TextStyle(color: Color(0xFF0F172A), fontWeight: FontWeight.bold, fontSize: 15),
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    'Xəritəyə keçid edərək sizə ən yaxın iş elanlarını kəşf edin və bir kliklə CV-nizi göndərin.',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(color: Colors.grey[600], fontSize: 13),
                                  ),
                                  const SizedBox(height: 18),
                                  ElevatedButton.icon(
                                    onPressed: () => Navigator.pop(context),
                                    icon: const Icon(Icons.map_outlined, color: Colors.white, size: 18),
                                    label: const Text('Xəritədə İş Axtar', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: const Color(0xFF2563EB),
                                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
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
                                final jobData = item['jobs'] as Map<String, dynamic>?;
                                final status = item['status'] ?? 'Gözləmədə';

                                return Container(
                                  margin: const EdgeInsets.only(bottom: 12),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(16),
                                    border: Border.all(color: Colors.grey.shade200),
                                    boxShadow: [
                                      BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 6, offset: const Offset(0, 2)),
                                    ],
                                  ),
                                  child: ListTile(
                                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                    leading: CircleAvatar(
                                      backgroundColor: const Color(0xFF2563EB).withOpacity(0.1),
                                      child: const Icon(Icons.business_center_rounded, color: Color(0xFF2563EB), size: 20),
                                    ),
                                    title: Text(
                                      jobData?['title'] ?? 'Vakansiya',
                                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                                    ),
                                    subtitle: Padding(
                                      padding: const EdgeInsets.only(top: 4.0),
                                      child: Text(
                                        '${jobData?['company_name'] ?? 'Şirkət'} • ${jobData?['salary_amount'] ?? 0} AZN',
                                        style: TextStyle(color: Colors.grey[600], fontSize: 13),
                                      ),
                                    ),
                                    trailing: Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                      decoration: BoxDecoration(
                                        color: _getStatusColor(status).withOpacity(0.12),
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
import 'package:flutter/material.dart';
import '../services/app_language.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  int _selectedFilterIndex = 0; // 0: Bütün, 1: Oxunmamışlar

  final List<Map<String, dynamic>> _notifications = [
    {
      'id': '1',
      'title': 'CV-nizə baxıldı!',
      'message': 'Coffee Moffie şirkəti "Senior Barista" vakansiyası üçün göndərdiyiniz müraciətə baxdı.',
      'time': '10 dəq əvvəl',
      'isRead': false,
      'type': 'application',
    },
    {
      'id': '2',
      'title': 'Müsahibə Dəvəti 🎯',
      'message': 'Vertex Media şirkəti sizi "Junior Flutter Developer" vakansiyası üzrə onlayn müsahibəyə dəvət edir.',
      'time': '2 saat əvvəl',
      'isRead': false,
      'type': 'interview',
    },
    {
      'id': '3',
      'title': 'Ərazinizdə Yeni Vakansiya 📍',
      'message': 'Yaxınlığınızda (500m məsafədə) yeni "Kassa Operatoru" elanı yerləşdirildi.',
      'time': 'Dünən',
      'isRead': true,
      'type': 'new_job',
    },
    {
      'id': '4',
      'title': 'Sistem Bildirişi',
      'message': 'WorkSpot tətbiqində profil məlumatlarınızı tamamlayaraq daha çox işəgötürənin diqqətini çəkə bilərsiniz.',
      'time': '3 gün əvvəl',
      'isRead': true,
      'type': 'system',
    },
  ];

  @override
  void initState() {
    super.initState();
    appLang.addListener(_onLanguageChanged);
  }

  @override
  void dispose() {
    appLang.removeListener(_onLanguageChanged);
    super.dispose();
  }

  void _onLanguageChanged() {
    if (mounted) setState(() {});
  }

  void _markAllAsRead() {
    setState(() {
      for (var item in _notifications) {
        item['isRead'] = true;
      }
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Bütün bildirişlər oxunmuş kimi işarələndi'),
        duration: Duration(seconds: 2),
      ),
    );
  }

  IconData _getNotificationIcon(String type) {
    switch (type) {
      case 'application':
        return Icons.assignment_turned_in_rounded;
      case 'interview':
        return Icons.videocam_rounded;
      case 'new_job':
        return Icons.near_me_rounded;
      default:
        return Icons.notifications_active_rounded;
    }
  }

  Color _getNotificationColor(String type) {
    switch (type) {
      case 'application':
        return const Color(0xFF2563EB);
      case 'interview':
        return Colors.green;
      case 'new_job':
        return Colors.amber.shade800;
      default:
        return Colors.purple;
    }
  }

  @override
  Widget build(BuildContext context) {
    final filteredList = _selectedFilterIndex == 0
        ? _notifications
        : _notifications.where((n) => n['isRead'] == false).toList();

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text('Bildirişlər', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF0F172A),
        elevation: 0.5,
        actions: [
          IconButton(
            icon: const Icon(Icons.done_all_rounded, color: Color(0xFF2563EB)),
            tooltip: 'Hamısını oxunmuş et',
            onPressed: _markAllAsRead,
          ),
        ],
      ),
      body: Column(
        children: [
          // Filter Tab-ları
          Container(
            color: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                ChoiceChip(
                  label: Text('Bütün bildirişlər (${_notifications.length})'),
                  selected: _selectedFilterIndex == 0,
                  selectedColor: const Color(0xFF2563EB),
                  labelStyle: TextStyle(
                    color: _selectedFilterIndex == 0 ? Colors.white : Colors.black87,
                    fontWeight: FontWeight.w600,
                    fontSize: 12,
                  ),
                  onSelected: (val) => setState(() => _selectedFilterIndex = 0),
                ),
                const SizedBox(width: 8),
                ChoiceChip(
                  label: Text('Oxunmamışlar (${_notifications.where((n) => !n['isRead']).length})'),
                  selected: _selectedFilterIndex == 1,
                  selectedColor: const Color(0xFF2563EB),
                  labelStyle: TextStyle(
                    color: _selectedFilterIndex == 1 ? Colors.white : Colors.black87,
                    fontWeight: FontWeight.w600,
                    fontSize: 12,
                  ),
                  onSelected: (val) => setState(() => _selectedFilterIndex = 1),
                ),
              ],
            ),
          ),
          const Divider(height: 1),

          // Siyahı
          Expanded(
            child: filteredList.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.notifications_off_outlined, size: 64, color: Colors.grey[300]),
                        const SizedBox(height: 12),
                        Text(
                          _selectedFilterIndex == 1 ? 'Oxunmamış bildirişiniz yoxdur' : 'Bildiriş tapılmadı',
                          style: const TextStyle(color: Colors.grey, fontSize: 14),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: filteredList.length,
                    itemBuilder: (context, index) {
                      final item = filteredList[index];
                      final isRead = item['isRead'] as bool;

                      return Dismissible(
                        key: Key(item['id']),
                        direction: DismissDirection.endToStart,
                        background: Container(
                          alignment: Alignment.centerRight,
                          padding: const EdgeInsets.only(right: 20),
                          margin: const EdgeInsets.only(bottom: 12),
                          decoration: BoxDecoration(
                            color: Colors.red.shade400,
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: const Icon(Icons.delete_outline, color: Colors.white),
                        ),
                        onDismissed: (direction) {
                          setState(() {
                            _notifications.removeWhere((n) => n['id'] == item['id']);
                          });
                        },
                        child: Container(
                          margin: const EdgeInsets.only(bottom: 12),
                          decoration: BoxDecoration(
                            color: isRead ? Colors.white : const Color(0xFFEFF6FF),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: isRead ? Colors.grey.shade200 : const Color(0xFFBFDBFE),
                            ),
                            boxShadow: [
                              if (!isRead)
                                BoxShadow(
                                  color: const Color(0xFF2563EB).withOpacity(0.06),
                                  blurRadius: 8,
                                  offset: const Offset(0, 2),
                                )
                            ],
                          ),
                          child: ListTile(
                            contentPadding: const EdgeInsets.all(14),
                            leading: CircleAvatar(
                              backgroundColor: _getNotificationColor(item['type']).withOpacity(0.12),
                              child: Icon(
                                _getNotificationIcon(item['type']),
                                color: _getNotificationColor(item['type']),
                                size: 22,
                              ),
                            ),
                            title: Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    item['title'],
                                    style: TextStyle(
                                      fontWeight: isRead ? FontWeight.w600 : FontWeight.bold,
                                      fontSize: 15,
                                      color: const Color(0xFF0F172A),
                                    ),
                                  ),
                                ),
                                if (!isRead)
                                  Container(
                                    width: 8,
                                    height: 8,
                                    decoration: const BoxDecoration(
                                      color: Color(0xFF2563EB),
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                              ],
                            ),
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const SizedBox(height: 4),
                                Text(
                                  item['message'],
                                  style: TextStyle(
                                    color: Colors.grey[700],
                                    fontSize: 13,
                                    height: 1.3,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  item['time'],
                                  style: TextStyle(color: Colors.grey[400], fontSize: 11),
                                ),
                              ],
                            ),
                            onTap: () {
                              setState(() {
                                item['isRead'] = true;
                              });
                            },
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
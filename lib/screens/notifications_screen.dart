import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../services/app_language.dart';
import '../services/notification_service.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  static const _background = Color(0xFFF8FAFC);
  static const _surface = Colors.white;
  static const _primary = Color(0xFF2563EB);
  static const _text = Color(0xFF0F172A);
  static const _muted = Color(0xFF64748B);

  int _selectedFilterIndex = 0;
  final Set<String> _optimisticallyReadIds = <String>{};

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

  String? get _currentUserId => NotificationService.instance.currentUserId;

  bool _matchesCurrentUser(Map<String, dynamic> item) {
    final userId = _currentUserId;
    if (userId == null || userId.isEmpty) return false;

    const fields = ['recipient_id', 'user_id', 'owner_id', 'candidate_id'];
    for (final field in fields) {
      final value = item[field]?.toString().trim();
      if (value != null && value.isNotEmpty && value == userId) {
        return true;
      }
    }

    return false;
  }

  bool _isRead(Map<String, dynamic> item) {
    final id = item['id']?.toString() ?? '';
    if (id.isNotEmpty && _optimisticallyReadIds.contains(id)) return true;

    final value = item['is_read'];
    if (value is bool) return value;
    if (value is num) return value != 0;
    if (value is String) {
      final normalized = value.toLowerCase().trim();
      return normalized == 'true' || normalized == '1' || normalized == 'yes';
    }
    return item['read_at'] != null;
  }

  String _notificationType(Map<String, dynamic> item) {
    final type = item['type']?.toString().trim() ?? item['notification_type']?.toString().trim();
    if (type == null || type.isEmpty) return 'system';
    return type;
  }

  String _notificationTitle(Map<String, dynamic> item) {
    final title = item['title']?.toString().trim() ?? item['subject']?.toString().trim();
    if (title != null && title.isNotEmpty) return title;

    switch (_notificationType(item)) {
      case 'application_received':
        return 'Yeni müraciət gəldi';
      case 'application_submitted':
        return 'Müraciət göndərildi';
      case 'job_approved':
        return 'Vakansiya təsdiqləndi';
      case 'job_rejected':
        return 'Vakansiya rədd edildi';
      default:
        return appLang.translate('notification_system_title');
    }
  }

  String _notificationMessage(Map<String, dynamic> item) {
    final message = item['message']?.toString().trim() ?? item['body']?.toString().trim() ?? item['content']?.toString().trim() ?? item['text']?.toString().trim();
    if (message != null && message.isNotEmpty) return message;

    final job = item['job_title']?.toString().trim() ?? item['title_text']?.toString().trim() ?? 'vakansiya';
    final company = item['company_name']?.toString().trim() ?? item['company']?.toString().trim() ?? 'şirkət';

    switch (_notificationType(item)) {
      case 'application_received':
        return '$company şirkətinə "$job" vakansiyası üzrə yeni müraciət var.';
      case 'application_submitted':
        return '"$job" vakansiyasına müraciətiniz göndərildi.';
      case 'job_approved':
        return '"$job" vakansiyanız admin tərəfindən təsdiqləndi.';
      case 'job_rejected':
        return '"$job" vakansiyanız admin tərəfindən rədd edildi.';
      default:
        return appLang.translate('notification_system_message');
    }
  }

  DateTime _notificationTime(Map<String, dynamic> item) {
    final candidates = [
      item['created_at'],
      item['inserted_at'],
      item['updated_at'],
      item['read_at'],
    ];

    for (final candidate in candidates) {
      final parsed = DateTime.tryParse(candidate?.toString() ?? '');
      if (parsed != null) return parsed.toLocal();
    }

    return DateTime.now();
  }

  String _formatRelativeTime(DateTime time) {
    final now = DateTime.now();
    final difference = now.difference(time);

    if (difference.inMinutes < 1) {
      return 'İndi';
    }
    if (difference.inMinutes < 60) {
      return '${difference.inMinutes} dəq əvvəl';
    }
    if (difference.inHours < 24) {
      return '${difference.inHours} saat əvvəl';
    }

    final yesterday = DateTime(now.year, now.month, now.day).subtract(const Duration(days: 1));
    if (time.year == yesterday.year && time.month == yesterday.month && time.day == yesterday.day) {
      return appLang.translate('time_yesterday');
    }

    if (difference.inDays < 7) {
      return '${difference.inDays} gün əvvəl';
    }

    final day = time.day.toString().padLeft(2, '0');
    final month = time.month.toString().padLeft(2, '0');
    return '$day.$month.${time.year}';
  }

  IconData _notificationIcon(String type) {
    switch (type) {
      case 'application_received':
        return Icons.person_add_alt_1_rounded;
      case 'application_submitted':
        return Icons.send_rounded;
      case 'job_approved':
        return Icons.verified_rounded;
      case 'job_rejected':
        return Icons.cancel_rounded;
      case 'interview':
        return Icons.videocam_rounded;
      case 'new_job':
        return Icons.near_me_rounded;
      default:
        return Icons.notifications_active_rounded;
    }
  }

  Color _notificationColor(String type) {
    switch (type) {
      case 'application_received':
        return const Color(0xFF2563EB);
      case 'application_submitted':
        return const Color(0xFF0EA5E9);
      case 'job_approved':
        return const Color(0xFF16A34A);
      case 'job_rejected':
        return const Color(0xFFDC2626);
      case 'interview':
        return const Color(0xFF7C3AED);
      case 'new_job':
        return const Color(0xFFF59E0B);
      default:
        return _primary;
    }
  }

  bool _isMissingTableError(Object? error) {
    final message = error?.toString().toLowerCase() ?? '';
    return message.contains('notifications') &&
        (message.contains('does not exist') ||
            message.contains('relation') ||
            message.contains('schema cache'));
  }

  Stream<List<Map<String, dynamic>>> _notificationsStream() {
    return Supabase.instance.client.from('notifications').stream(primaryKey: ['id']);
  }

  List<Map<String, dynamic>> _visibleNotifications(List<Map<String, dynamic>> items) {
    final currentUserId = _currentUserId;
    if (currentUserId == null || currentUserId.isEmpty) return const [];

    final ownItems = items.where(_matchesCurrentUser).toList();
    if (_selectedFilterIndex == 1) {
      return ownItems.where((item) => !_isRead(item)).toList();
    }
    return ownItems;
  }

  Future<void> _markAllAsRead(List<Map<String, dynamic>> visibleItems) async {
    final unreadIds = visibleItems
        .where((item) => !_isRead(item))
        .map((item) => item['id']?.toString() ?? '')
        .where((id) => id.isNotEmpty)
        .toList();

    if (unreadIds.isEmpty) {
      return;
    }

    try {
      await NotificationService.instance.markAllAsRead(unreadIds);
      if (!mounted) return;
      setState(() {
        _optimisticallyReadIds.addAll(unreadIds);
      });
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(appLang.translate('mark_all_read'))),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Bildirişlər yenilənmədi: $error')),
      );
    }
  }

  Future<void> _markAsRead(Map<String, dynamic> item) async {
    if (_isRead(item)) return;
    final id = item['id']?.toString() ?? '';
    if (id.isEmpty) return;

    try {
      await NotificationService.instance.markAsRead(id);
      if (!mounted) return;
      setState(() {
        _optimisticallyReadIds.add(id);
      });
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Bildiriş statusu yenilənmədi.')),
      );
    }
  }

  Widget _buildHeader(List<Map<String, dynamic>> visibleItems) {
    final allCount = visibleItems.length;
    final unreadCount = visibleItems.where((item) => !_isRead(item)).length;

    return Container(
      color: _surface,
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      child: Row(
        children: [
          Expanded(
            child: ChoiceChip(
              label: Text('${appLang.translate('all_notifications')} ($allCount)'),
              selected: _selectedFilterIndex == 0,
              selectedColor: _primary,
              labelStyle: TextStyle(
                color: _selectedFilterIndex == 0 ? Colors.white : _text,
                fontWeight: FontWeight.w600,
              ),
              onSelected: (_) => setState(() => _selectedFilterIndex = 0),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: ChoiceChip(
              label: Text('${appLang.translate('unread_notifications')} ($unreadCount)'),
              selected: _selectedFilterIndex == 1,
              selectedColor: _primary,
              labelStyle: TextStyle(
                color: _selectedFilterIndex == 1 ? Colors.white : _text,
                fontWeight: FontWeight.w600,
              ),
              onSelected: (_) => setState(() => _selectedFilterIndex = 1),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState({required bool unreadOnly}) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 104,
              height: 104,
              decoration: BoxDecoration(
                color: const Color(0xFFEFF6FF),
                borderRadius: BorderRadius.circular(32),
              ),
              child: const Icon(
                Icons.notifications_off_outlined,
                size: 54,
                color: Color(0xFF60A5FA),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              appLang.translate('notifications_empty'),
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: _text,
                fontWeight: FontWeight.w700,
                fontSize: 18,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              unreadOnly
                  ? appLang.translate('notifications_unread_empty')
                  : appLang.translate('notifications_empty_subtitle'),
              textAlign: TextAlign.center,
              style: const TextStyle(color: _muted, fontSize: 13, height: 1.4),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorEmptyState({required bool unreadOnly}) {
    return _buildEmptyState(unreadOnly: unreadOnly);
  }

  Widget _buildNotificationCard(Map<String, dynamic> item) {
    final isRead = _isRead(item);
    final type = _notificationType(item);
    final title = _notificationTitle(item);
    final message = _notificationMessage(item);
    final timeLabel = _formatRelativeTime(_notificationTime(item));

    return InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: () => _markAsRead(item),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isRead ? _surface : const Color(0xFFEFF6FF),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: isRead ? const Color(0xFFE2E8F0) : const Color(0xFFBFDBFE)),
          boxShadow: [
            if (!isRead)
              BoxShadow(
                color: _primary.withValues(alpha: 0.06),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
          ],
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                color: _notificationColor(type).withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(
                _notificationIcon(type),
                color: _notificationColor(type),
                size: 24,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Text(
                          title,
                          style: TextStyle(
                            color: _text,
                            fontWeight: isRead ? FontWeight.w600 : FontWeight.w800,
                            fontSize: 15,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        timeLabel,
                        style: const TextStyle(color: _muted, fontSize: 11),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    message,
                    style: const TextStyle(
                      color: _muted,
                      fontSize: 13,
                      height: 1.45,
                    ),
                  ),
                  if (!isRead) ...[
                    const SizedBox(height: 10),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          color: _primary,
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: const Text(
                          'Oxunmayıb',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _background,
      appBar: AppBar(
        title: Text(
          appLang.translate('notifications'),
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
        ),
        backgroundColor: _surface,
        foregroundColor: _text,
        elevation: 0.5,
        actions: [
          StreamBuilder<List<Map<String, dynamic>>>(
            stream: _notificationsStream(),
            builder: (context, snapshot) {
              final visibleItems = _visibleNotifications(snapshot.data ?? const []);
              final hasUnread = visibleItems.any((item) => !_isRead(item));
              return IconButton(
                icon: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Icon(
                      Icons.done_all_rounded,
                      color: hasUnread ? _primary : Colors.grey.shade400,
                    ),
                    if (hasUnread)
                      Positioned(
                        right: -2,
                        top: -2,
                        child: Container(
                          width: 10,
                          height: 10,
                          decoration: const BoxDecoration(
                            color: Color(0xFFEF4444),
                            shape: BoxShape.circle,
                          ),
                        ),
                      ),
                  ],
                ),
                        tooltip: appLang.translate('mark_all_read'),
                        onPressed: hasUnread ? () => _markAllAsRead(visibleItems) : null,
                      );
            },
          ),
        ],
      ),
      body: StreamBuilder<List<Map<String, dynamic>>>(
        stream: _notificationsStream(),
        builder: (context, snapshot) {
          if (snapshot.hasError && _isMissingTableError(snapshot.error)) {
            return Column(
              children: [
                _buildHeader(const []),
                const Divider(height: 1),
                Expanded(child: _buildErrorEmptyState(unreadOnly: _selectedFilterIndex == 1)),
              ],
            );
          }

          if (snapshot.hasError) {
            return Column(
              children: [
                _buildHeader(const []),
                const Divider(height: 1),
                Expanded(child: _buildErrorEmptyState(unreadOnly: _selectedFilterIndex == 1)),
              ],
            );
          }

          if (snapshot.connectionState == ConnectionState.waiting && (snapshot.data == null || snapshot.data!.isEmpty)) {
            return const Center(
              child: CircularProgressIndicator(color: _primary),
            );
          }

          final items = snapshot.data ?? const [];
          final visibleItems = List<Map<String, dynamic>>.from(_visibleNotifications(items))
            ..sort((left, right) => _notificationTime(right).compareTo(_notificationTime(left)));

          return Column(
            children: [
              _buildHeader(visibleItems),
              const Divider(height: 1),
              Expanded(
                child: visibleItems.isEmpty
                    ? _buildEmptyState(unreadOnly: _selectedFilterIndex == 1)
                    : ListView.builder(
                        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                        itemCount: visibleItems.length,
                        itemBuilder: (context, index) => _buildNotificationCard(visibleItems[index]),
                      ),
              ),
            ],
          );
        },
      ),
    );
  }
}
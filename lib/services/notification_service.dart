import 'package:supabase_flutter/supabase_flutter.dart';

class NotificationService {
  NotificationService._();

  static final NotificationService instance = NotificationService._();

  SupabaseClient get _client => Supabase.instance.client;

  String? get currentUserId => _client.auth.currentUser?.id;

  bool _isMissingColumnError(Object error) {
    final message = error.toString().toLowerCase();
    return message.contains('column') &&
        (message.contains('does not exist') ||
            message.contains('could not find the') ||
            message.contains('schema cache'));
  }

  bool _isMissingTableError(Object error) {
    final message = error.toString().toLowerCase();
    return message.contains('notifications') &&
        (message.contains('does not exist') ||
            message.contains('relation') ||
            message.contains('schema cache'));
  }

  String? _extractMissingColumn(Object error) {
    final message = error.toString();
    final patterns = [
      RegExp(r"could not find the '([^']+)' column", caseSensitive: false),
      RegExp(r'column\s+"([^"]+)"', caseSensitive: false),
      RegExp(r"column\s+'([^']+)'", caseSensitive: false),
    ];

    for (final pattern in patterns) {
      final match = pattern.firstMatch(message);
      if (match != null) {
        return match.group(1);
      }
    }
    return null;
  }

  Future<List<Map<String, dynamic>>> fetchForCurrentUser({bool unreadOnly = false}) async {
    final userId = currentUserId;
    if (userId == null || userId.isEmpty) return [];

    final rowsById = <String, Map<String, dynamic>>{};
    const recipientFields = ['recipient_id', 'user_id', 'owner_id', 'candidate_id'];

    for (final field in recipientFields) {
      try {
        var query = _client.from('notifications').select('*').eq(field, userId);
        if (unreadOnly) {
          query = query.eq('is_read', false);
        }
        final response = await query;
        for (final row in List<Map<String, dynamic>>.from(response)) {
          final id = row['id']?.toString();
          if (id == null || id.isEmpty) continue;
          rowsById[id] = row;
        }
      } catch (error) {
        if (_isMissingColumnError(error) || _isMissingTableError(error)) {
          continue;
        }
        rethrow;
      }
    }

    final rows = rowsById.values.toList();
    rows.sort((left, right) {
      final leftDate = DateTime.tryParse(left['created_at']?.toString() ?? '') ?? DateTime.fromMillisecondsSinceEpoch(0);
      final rightDate = DateTime.tryParse(right['created_at']?.toString() ?? '') ?? DateTime.fromMillisecondsSinceEpoch(0);
      return rightDate.compareTo(leftDate);
    });
    return rows;
  }

  Future<void> createNotification({
    required String recipientId,
    required String type,
    required String title,
    required String message,
    String? jobId,
    String? actorId,
    String? relatedId,
  }) async {
    final payload = <String, dynamic>{
      'recipient_id': recipientId,
      'user_id': recipientId,
      'owner_id': recipientId,
      'candidate_id': recipientId,
      'type': type,
      'notification_type': type,
      'title': title,
      'message': message,
      'body': message,
      'content': message,
      'text': message,
      'job_id': jobId,
      'related_id': relatedId,
      'actor_id': actorId,
      'is_read': false,
      'created_at': DateTime.now().toIso8601String(),
    };

    final workingPayload = Map<String, dynamic>.from(payload)
      ..removeWhere((key, value) => value == null);

    Object? lastError;
    for (var attempt = 0; attempt < 10; attempt++) {
      try {
        await _client.from('notifications').insert(workingPayload);
        return;
      } catch (error) {
        lastError = error;
        if (_isMissingTableError(error)) {
          return;
        }
        if (!_isMissingColumnError(error)) {
          rethrow;
        }

        final missingColumn = _extractMissingColumn(error);
        if (missingColumn == null) {
          continue;
        }

        if (workingPayload.containsKey(missingColumn)) {
          workingPayload.remove(missingColumn);
          continue;
        }
      }
    }

    throw lastError ?? Exception('Notification insert failed');
  }

  Future<void> markAsRead(String notificationId) async {
    try {
      await _client.from('notifications').update({
        'is_read': true,
        'read_at': DateTime.now().toIso8601String(),
      }).eq('id', notificationId);
    } catch (error) {
      if (_isMissingTableError(error)) return;
      rethrow;
    }
  }

  Future<void> markAllAsRead(Iterable<String> notificationIds) async {
    final ids = notificationIds.where((id) => id.trim().isNotEmpty).toList();
    if (ids.isEmpty) return;

    try {
      await _client.from('notifications').update({
        'is_read': true,
        'read_at': DateTime.now().toIso8601String(),
      }).inFilter('id', ids);
    } catch (error) {
      if (_isMissingTableError(error)) return;
      rethrow;
    }
  }
}
import 'package:supabase_flutter/supabase_flutter.dart';

class JobModerationService {
  final SupabaseClient _client = Supabase.instance.client;

  Future<Set<String>> loadBlockedEmployerIds() async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) return {};

    final rows = await _client
        .from('blocked_employers')
        .select('employer_id')
        .eq('blocker_id', userId);
    return rows.map((row) => row['employer_id'].toString()).toSet();
  }

  Future<void> reportJob({
    required String jobId,
    required String reason,
    String? details,
  }) async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) {
      throw StateError('Sign in is required to report a job.');
    }

    try {
      await _client.from('job_reports').insert({
        'job_id': jobId,
        'reporter_id': userId,
        'reason': reason,
        'details': details,
      });
    } on PostgrestException catch (error) {
      // Already reported by this user; treat as success.
      if (error.code != '23505') rethrow;
    }
  }

  Future<void> blockEmployer(String employerId) async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) {
      throw StateError('Sign in is required to block an employer.');
    }
    if (userId == employerId) {
      throw ArgumentError.value(employerId, 'employerId', 'Cannot block self.');
    }

    await _client.from('blocked_employers').upsert(
      {
        'blocker_id': userId,
        'employer_id': employerId,
      },
      onConflict: 'blocker_id,employer_id',
      ignoreDuplicates: true,
    );
  }
}

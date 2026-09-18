import 'package:supabase_flutter/supabase_flutter.dart';

class ApplicationService {
  final SupabaseClient _supabase = Supabase.instance.client;

  Future<void> applyForJob(String jobId) async {
    final phone = _supabase.auth.currentUser?.phone;
    if (phone == null) throw Exception('İstifadəçi daxil olmayıb');

    final userProfile = await _supabase
        .from('users')
        .select('id')
        .eq('phone_number', phone)
        .maybeSingle();

    if (userProfile == null) throw Exception('İstifadəçi profili tapılmadı');

    await _supabase.from('applications').insert({
      'job_id': jobId,
      'applicant_id': userProfile['id'],
      'status': 'Gözləmədə',
    });
  }

  Future<bool> hasAlreadyApplied(String jobId) async {
    final phone = _supabase.auth.currentUser?.phone;
    if (phone == null) return false;

    final userProfile = await _supabase
        .from('users')
        .select('id')
        .eq('phone_number', phone)
        .maybeSingle();

    if (userProfile == null) return false;

    final response = await _supabase
        .from('applications')
        .select('id')
        .eq('job_id', jobId)
        .eq('applicant_id', userProfile['id'])
        .maybeSingle();

    return response != null;
  }
}
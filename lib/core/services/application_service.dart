import 'package:supabase_flutter/supabase_flutter.dart';

import '../../services/notification_service.dart';

class ApplicationService {
  final SupabaseClient _supabase = Supabase.instance.client;

  Future<void> applyForJob(String jobId) async {
    final currentUser = _supabase.auth.currentUser;
    final phone = currentUser?.phone;
    if (phone == null) throw Exception('İstifadəçi daxil olmayıb');

    final userProfile = await _supabase
        .from('users')
        .select('id')
        .eq('phone_number', phone)
        .maybeSingle();

    if (userProfile == null) throw Exception('İstifadəçi profili tapılmadı');

    final job = await _supabase
        .from('jobs')
        .select('id, title, business_name, company_name, owner_id, created_by, user_id, employer_id, posted_by')
        .eq('id', jobId)
        .maybeSingle();

    await _supabase.from('applications').insert({
      'job_id': jobId,
      'applicant_id': userProfile['id'],
      'status': 'Gözləmədə',
    });

    final applicantUserId = currentUser?.id;
    final employerId = _jobOwnerId(job);
    final jobTitle = _jobTitle(job);
    final companyName = _jobCompanyName(job);

    if (applicantUserId != null) {
      await NotificationService.instance.createNotification(
        recipientId: applicantUserId,
        type: 'application_submitted',
        title: 'Müraciət göndərildi',
        message: '"$jobTitle" vakansiyasına müraciətiniz göndərildi.',
        jobId: jobId,
        actorId: applicantUserId,
      );
    }

    if (employerId != null && employerId.isNotEmpty) {
      await NotificationService.instance.createNotification(
        recipientId: employerId,
        type: 'application_received',
        title: 'Yeni müraciət gəldi',
        message: '$companyName üçün "$jobTitle" vakansiyasına yeni müraciət var.',
        jobId: jobId,
        actorId: applicantUserId,
      );
    }
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

  String? _jobOwnerId(Map<String, dynamic>? job) {
    if (job == null) return null;
    final candidateKeys = ['owner_id', 'created_by', 'user_id', 'employer_id', 'posted_by'];
    for (final key in candidateKeys) {
      final value = job[key]?.toString().trim();
      if (value != null && value.isNotEmpty) return value;
    }
    return null;
  }

  String _jobTitle(Map<String, dynamic>? job) {
    if (job == null) return 'vakansiya';
    final value = job['title']?.toString().trim();
    return value == null || value.isEmpty ? 'vakansiya' : value;
  }

  String _jobCompanyName(Map<String, dynamic>? job) {
    if (job == null) return 'İşəgötürən';
    final value = job['company_name']?.toString().trim() ?? job['business_name']?.toString().trim();
    return value == null || value.isEmpty ? 'İşəgötürən' : value;
  }
}
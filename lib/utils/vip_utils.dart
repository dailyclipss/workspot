/// True when the job is flagged VIP and its VIP period has not expired.
/// A missing `vip_until`/`vip_expires_at` means the VIP never expires.
bool isJobVipActive(Map<String, dynamic> job) {
  final isVip = job['is_vip'] == true ||
      job['is_vip'] == 1 ||
      job['is_vip'].toString().toLowerCase().trim() == 'true';
  if (!isVip) return false;

  final rawExpiry = job['vip_until'] ?? job['vip_expires_at'];
  if (rawExpiry == null || rawExpiry.toString().trim().isEmpty) return true;
  final expiry = DateTime.tryParse(rawExpiry.toString());
  return expiry == null || expiry.isAfter(DateTime.now());
}

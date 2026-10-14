import 'package:url_launcher/url_launcher.dart';

Future<void> makePhoneCall(String phoneNumber) async {
  final cleanNumber = phoneNumber.replaceAll(RegExp(r'[^\d+]'), '');
  final launchUri = Uri(scheme: 'tel', path: cleanNumber);
  if (await canLaunchUrl(launchUri)) {
    await launchUrl(launchUri);
  }
}

Future<void> openWhatsApp(String phoneNumber, {String? message}) async {
  final cleanNumber = phoneNumber.replaceAll(RegExp(r'[^\d]'), '');
  final text = Uri.encodeComponent(
    message ?? 'Salam, Workspot tətbiqindəki elanla bağlı yazıram.',
  );
  final whatsappUri = Uri.parse('https://wa.me/$cleanNumber?text=$text');

  if (await canLaunchUrl(whatsappUri)) {
    await launchUrl(whatsappUri, mode: LaunchMode.externalApplication);
  }
}

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../services/app_language.dart';

class LegalInfo {
  static const String voen = '1103325022';
  static const String phone = '+994 50 470 36 66';
  static const String phoneUri = 'tel:+994504703666';
  static const String email = 'support@workspot.az';
}

class _LegalTexts {
  final String about, contact, privacy, close;
  final String aboutTitle, contactTitle, privacyTitle;
  final String aboutBody, phoneLabel, emailLabel, addressLabel, address;
  final List<MapEntry<String, String>> privacySections;

  const _LegalTexts({
    required this.about,
    required this.contact,
    required this.privacy,
    required this.close,
    required this.aboutTitle,
    required this.contactTitle,
    required this.privacyTitle,
    required this.aboutBody,
    required this.phoneLabel,
    required this.emailLabel,
    required this.addressLabel,
    required this.address,
    required this.privacySections,
  });
}

const Map<String, _LegalTexts> _texts = {
  'az': _LegalTexts(
    about: 'Haqqımızda',
    contact: 'Əlaqə',
    privacy: 'Məxfilik Siyasəti',
    close: 'Bağla',
    aboutTitle: 'Haqqımızda',
    contactTitle: 'Əlaqə',
    privacyTitle: 'Məxfilik Siyasəti və Qaytarma Şərtləri',
    aboutBody:
        'Workspot vakansiya və iş elanları platformasıdır. İşəgötürənlər elan '
        'yerləşdirir, iş axtaranlar isə xəritə üzərindən özlərinə yaxın '
        'vakansiyaları tapıb müraciət edirlər.\n\nVÖEN: ${LegalInfo.voen}',
    phoneLabel: 'Telefon',
    emailLabel: 'E-poçt',
    addressLabel: 'Ünvan',
    address: 'Bakı şəhəri, Azərbaycan.',
    privacySections: [
      MapEntry('Məxfilik',
          'İstifadəçi məlumatlarının məxfiliyi qorunur. Məlumatlar üçüncü tərəflərə yalnız qanunvericiliyin tələb etdiyi hallarda təqdim olunur.'),
      MapEntry('Ödənişlər',
          'Kart məlumatları Workspot tərəfindən saxlanılmır və emal edilmir. Ödənişlər Epoint / PAŞA Bank tərəfindən təhlükəsiz şəkildə emal olunur.'),
      MapEntry('Paketlərin aktivləşdirilməsi',
          'Ödənilmiş paketlər ödəniş təsdiqləndikdən dərhal sonra anında aktiv olunur.'),
      MapEntry('İmtina / Qaytarma Şərtləri',
          'Paket aktivləşdirildikdən sonra xidmət göstərilmiş hesab olunur. Texniki xəta və ya təkrar çıxılma hallarında ${LegalInfo.email} ünvanına müraciət edə bilərsiniz.'),
    ],
  ),
  'ru': _LegalTexts(
    about: 'О нас',
    contact: 'Контакты',
    privacy: 'Политика конфиденциальности',
    close: 'Закрыть',
    aboutTitle: 'О нас',
    contactTitle: 'Контакты',
    privacyTitle: 'Политика конфиденциальности и условия возврата',
    aboutBody:
        'Workspot — платформа вакансий и объявлений о работе. Работодатели '
        'размещают объявления, а соискатели находят ближайшие вакансии на '
        'карте и откликаются на них.\n\nVÖEN: ${LegalInfo.voen}',
    phoneLabel: 'Телефон',
    emailLabel: 'E-mail',
    addressLabel: 'Адрес',
    address: 'г. Баку, Азербайджан.',
    privacySections: [
      MapEntry('Конфиденциальность',
          'Конфиденциальность данных пользователей защищена. Данные передаются третьим лицам только в случаях, предусмотренных законодательством.'),
      MapEntry('Платежи',
          'Данные карт не хранятся и не обрабатываются Workspot. Платежи безопасно обрабатываются Epoint / PAŞA Bank.'),
      MapEntry('Активация пакетов',
          'Оплаченные пакеты активируются мгновенно после подтверждения платежа.'),
      MapEntry('Отказ / Возврат',
          'После активации пакета услуга считается оказанной. При технической ошибке или повторном списании обращайтесь на ${LegalInfo.email}.'),
    ],
  ),
  'en': _LegalTexts(
    about: 'About Us',
    contact: 'Contact',
    privacy: 'Privacy Policy',
    close: 'Close',
    aboutTitle: 'About Us',
    contactTitle: 'Contact',
    privacyTitle: 'Privacy Policy and Refund Terms',
    aboutBody:
        'Workspot is a vacancy and job listings platform. Employers post '
        'listings, and job seekers find nearby vacancies on the map and '
        'apply to them.\n\nVÖEN (Tax ID): ${LegalInfo.voen}',
    phoneLabel: 'Phone',
    emailLabel: 'Email',
    addressLabel: 'Address',
    address: 'Baku, Azerbaijan.',
    privacySections: [
      MapEntry('Privacy',
          'The privacy of user data is protected. Data is shared with third parties only where required by law.'),
      MapEntry('Payments',
          'Card details are not stored or processed by Workspot. Payments are securely processed by Epoint / PAŞA Bank.'),
      MapEntry('Package activation',
          'Paid packages are activated instantly once the payment is confirmed.'),
      MapEntry('Cancellation / Refund Terms',
          'Once a package is activated the service is considered delivered. In case of a technical error or duplicate charge, contact ${LegalInfo.email}.'),
    ],
  ),
};

_LegalTexts get _t => _texts[appLang.currentLanguage] ?? _texts['az']!;

Future<void> _showLegalDialog(
  BuildContext context, {
  required String title,
  required Widget body,
}) {
  return showDialog<void>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480),
        child: SingleChildScrollView(child: body),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(),
          child: Text(_t.close),
        ),
      ],
    ),
  );
}

Widget _contactRow(IconData icon, String label, String value, [String? uri]) {
  return Padding(
    padding: const EdgeInsets.symmetric(vertical: 6),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 18, color: const Color(0xFF2563EB)),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label,
                  style: const TextStyle(fontSize: 12, color: Colors.grey)),
              uri == null
                  ? Text(value, style: const TextStyle(fontSize: 14))
                  : InkWell(
                      onTap: () => launchUrl(Uri.parse(uri)),
                      child: Text(
                        value,
                        style: const TextStyle(
                          fontSize: 14,
                          color: Color(0xFF2563EB),
                          decoration: TextDecoration.underline,
                        ),
                      ),
                    ),
            ],
          ),
        ),
      ],
    ),
  );
}

void showAboutDialogWorkspot(BuildContext context) => _showLegalDialog(
      context,
      title: _t.aboutTitle,
      body: Text(_t.aboutBody, style: const TextStyle(height: 1.5)),
    );

void showContactDialogWorkspot(BuildContext context) => _showLegalDialog(
      context,
      title: _t.contactTitle,
      body: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _contactRow(Icons.phone_rounded, _t.phoneLabel, LegalInfo.phone,
              LegalInfo.phoneUri),
          _contactRow(Icons.email_rounded, _t.emailLabel, LegalInfo.email,
              'mailto:${LegalInfo.email}'),
          _contactRow(Icons.location_on_rounded, _t.addressLabel, _t.address),
        ],
      ),
    );

void showPrivacyDialogWorkspot(BuildContext context) => _showLegalDialog(
      context,
      title: _t.privacyTitle,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final s in _t.privacySections) ...[
            Text(s.key, style: const TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            Text(s.value, style: const TextStyle(height: 1.5)),
            const SizedBox(height: 14),
          ],
        ],
      ),
    );

class LegalFooter extends StatelessWidget {
  const LegalFooter({super.key});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: appLang,
      builder: (context, _) {
        final t = _t;
        final color = Theme.of(context).brightness == Brightness.dark
            ? Colors.white70
            : const Color(0xFF475569);
        Widget link(String label, VoidCallback onTap) => TextButton(
              onPressed: onTap,
              style: TextButton.styleFrom(
                foregroundColor: color,
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              child: Text(label, style: const TextStyle(fontSize: 12)),
            );

        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Wrap(
              alignment: WrapAlignment.center,
              children: [
                link(t.about, () => showAboutDialogWorkspot(context)),
                link(t.contact, () => showContactDialogWorkspot(context)),
                link(t.privacy, () => showPrivacyDialogWorkspot(context)),
              ],
            ),
            Text(
              '© Workspot · VÖEN ${LegalInfo.voen}',
              style: TextStyle(fontSize: 11, color: color),
            ),
          ],
        );
      },
    );
  }
}

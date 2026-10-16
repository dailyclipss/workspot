import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../services/app_language.dart';

class LegalInfo {
  static const String voen = '1103325022';
  static const String phone = '+994 50 470 36 66';
  static const String phoneUri = 'tel:+994504703666';
  static const String email = 'support@workspot.az';
}

enum LegalPageType { about, contact, privacy, terms }

extension LegalPageTypeRoute on LegalPageType {
  String get route => '/$name';
}

class _LegalTexts {
  final String about, contact, privacy, terms, back;
  final String privacyTitle, termsTitle;
  final String aboutBody, phoneLabel, emailLabel, addressLabel, address;
  final List<MapEntry<String, String>> privacySections;
  final List<MapEntry<String, String>> termsSections;

  const _LegalTexts({
    required this.about,
    required this.contact,
    required this.privacy,
    required this.terms,
    required this.back,
    required this.privacyTitle,
    required this.termsTitle,
    required this.aboutBody,
    required this.phoneLabel,
    required this.emailLabel,
    required this.addressLabel,
    required this.address,
    required this.privacySections,
    required this.termsSections,
  });
}

const Map<String, _LegalTexts> _texts = {
  'az': _LegalTexts(
    about: 'Haqqımızda',
    contact: 'Əlaqə',
    privacy: 'Məxfilik Siyasəti',
    terms: 'İstifadə Şərtləri',
    back: 'Geri',
    privacyTitle: 'Məxfilik Siyasəti və Qaytarma Şərtləri',
    termsTitle: 'İstifadə Şərtləri',
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
    termsSections: [
      MapEntry('Xidmət haqqında',
          'Workspot vakansiya və iş elanlarının yerləşdirildiyi və axtarıldığı platformadır. Platformadan istifadə etməklə bu şərtləri qəbul etmiş olursunuz.'),
      MapEntry('İstifadəçi öhdəlikləri',
          'İstifadəçi düzgün və aktual məlumat təqdim etməli, qanunsuz və ya yanıldıcı elan yerləşdirməməlidir. Qaydaları pozan elanlar və hesablar məhdudlaşdırıla bilər.'),
      MapEntry('Ödənişli xidmətlər',
          'Elanların yerləşdirilməsi və ya önə çıxarılması ödənişli ola bilər. Qiymətlər ödənişdən əvvəl göstərilir, ödəniş AZN ilə Epoint vasitəsilə həyata keçirilir və paket ödəniş təsdiqləndikdən sonra anında aktiv olunur.'),
      MapEntry('Qaytarma',
          'Qaytarma şərtləri Məxfilik Siyasəti və Qaytarma Şərtləri səhifəsində göstərilib. Suallar üçün: ${LegalInfo.email}'),
    ],
  ),
  'ru': _LegalTexts(
    about: 'О нас',
    contact: 'Контакты',
    privacy: 'Политика конфиденциальности',
    terms: 'Условия использования',
    back: 'Назад',
    privacyTitle: 'Политика конфиденциальности и условия возврата',
    termsTitle: 'Условия использования',
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
    termsSections: [
      MapEntry('О сервисе',
          'Workspot — платформа для размещения и поиска вакансий. Используя платформу, вы принимаете настоящие условия.'),
      MapEntry('Обязанности пользователя',
          'Пользователь обязан предоставлять достоверные данные и не размещать незаконные или вводящие в заблуждение объявления. Нарушающие правила объявления и аккаунты могут быть ограничены.'),
      MapEntry('Платные услуги',
          'Размещение или продвижение объявлений может быть платным. Цены указываются до оплаты, оплата производится в AZN через Epoint, пакет активируется мгновенно после подтверждения платежа.'),
      MapEntry('Возврат',
          'Условия возврата указаны на странице политики конфиденциальности и возврата. Вопросы: ${LegalInfo.email}'),
    ],
  ),
  'en': _LegalTexts(
    about: 'About Us',
    contact: 'Contact',
    privacy: 'Privacy Policy',
    terms: 'Terms of Use',
    back: 'Back',
    privacyTitle: 'Privacy Policy and Refund Terms',
    termsTitle: 'Terms of Use',
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
    termsSections: [
      MapEntry('About the service',
          'Workspot is a platform for posting and searching vacancies and job listings. By using the platform you accept these terms.'),
      MapEntry('User responsibilities',
          'Users must provide accurate information and must not post unlawful or misleading listings. Listings and accounts that violate the rules may be restricted.'),
      MapEntry('Paid services',
          'Posting or promoting listings may be paid. Prices are shown before payment, payment is made in AZN through Epoint, and the package is activated instantly once the payment is confirmed.'),
      MapEntry('Refunds',
          'Refund terms are described on the Privacy Policy and Refund Terms page. Questions: ${LegalInfo.email}'),
    ],
  ),
};

_LegalTexts get _t => _texts[appLang.currentLanguage] ?? _texts['az']!;

String _titleOf(LegalPageType type, _LegalTexts t) => switch (type) {
      LegalPageType.about => t.about,
      LegalPageType.contact => t.contact,
      LegalPageType.privacy => t.privacyTitle,
      LegalPageType.terms => t.termsTitle,
    };

Widget _sections(List<MapEntry<String, String>> items) => Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final s in items) ...[
          Text(s.key,
              style:
                  const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          const SizedBox(height: 4),
          Text(s.value, style: const TextStyle(height: 1.6)),
          const SizedBox(height: 18),
        ],
      ],
    );

Widget _contactRow(IconData icon, String label, String value, [String? uri]) {
  return Padding(
    padding: const EdgeInsets.symmetric(vertical: 8),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 20, color: const Color(0xFF2563EB)),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label,
                  style: const TextStyle(fontSize: 12, color: Colors.grey)),
              uri == null
                  ? Text(value, style: const TextStyle(fontSize: 15))
                  : InkWell(
                      onTap: () => launchUrl(Uri.parse(uri)),
                      child: Text(
                        value,
                        style: const TextStyle(
                          fontSize: 15,
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

/// Directly addressable legal page (/about, /contact, /privacy, /terms).
class LegalPage extends StatelessWidget {
  final LegalPageType type;
  const LegalPage({super.key, required this.type});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: appLang,
      builder: (context, _) {
        final t = _t;
        final Widget body = switch (type) {
          LegalPageType.about =>
            Text(t.aboutBody, style: const TextStyle(height: 1.6)),
          LegalPageType.contact => Column(
              children: [
                _contactRow(Icons.phone_rounded, t.phoneLabel, LegalInfo.phone,
                    LegalInfo.phoneUri),
                _contactRow(Icons.email_rounded, t.emailLabel, LegalInfo.email,
                    'mailto:${LegalInfo.email}'),
                _contactRow(
                    Icons.location_on_rounded, t.addressLabel, t.address),
              ],
            ),
          LegalPageType.privacy => _sections(t.privacySections),
          LegalPageType.terms => _sections(t.termsSections),
        };

        return Scaffold(
          appBar: AppBar(
            title: Text(_titleOf(type, t)),
            leading: IconButton(
              icon: const Icon(Icons.arrow_back_rounded),
              tooltip: t.back,
              onPressed: () {
                final nav = Navigator.of(context);
                if (nav.canPop()) {
                  nav.pop();
                } else {
                  nav.pushReplacementNamed('/');
                }
              },
            ),
          ),
          body: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 720),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _titleOf(type, t),
                      style: const TextStyle(
                          fontSize: 26, fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(height: 20),
                    body,
                    const SizedBox(height: 24),
                    const Divider(),
                    const Center(child: LegalFooter(replace: true)),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class LegalFooter extends StatelessWidget {
  /// On legal pages, links replace the current route so the back stack stays short.
  final bool replace;
  const LegalFooter({super.key, this.replace = false});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: appLang,
      builder: (context, _) {
        final t = _t;
        final color = Theme.of(context).brightness == Brightness.dark
            ? Colors.white70
            : const Color(0xFF475569);

        void go(LegalPageType type) {
          final nav = Navigator.of(context);
          replace
              ? nav.pushReplacementNamed(type.route)
              : nav.pushNamed(type.route);
        }

        Widget link(String label, LegalPageType type) => TextButton(
              onPressed: () => go(type),
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
                link(t.about, LegalPageType.about),
                link(t.contact, LegalPageType.contact),
                link(t.privacy, LegalPageType.privacy),
                link(t.terms, LegalPageType.terms),
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

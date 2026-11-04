import 'package:flutter/material.dart';

import '../services/app_language.dart';
import '../services/theme_service.dart';

/// Language labels shown in the dropdown.
const Map<String, String> kLanguageLabels = {
  'az': 'AZ',
  'en': 'EN',
  'ru': 'RU',
};

/// Theme toggle + language picker, shared by AuthScreen, HomeMapScreen and
/// ProfileScreen so guests can change language/theme without signing in.
/// Reuses [themeService] and [appLang]; no logic is duplicated.
class LanguageThemeControls extends StatelessWidget {
  const LanguageThemeControls({super.key});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([themeService, appLang]),
      builder: (context, _) {
        final isDark = themeService.isDarkMode;
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: BoxDecoration(
            color: isDark
                ? const Color(0xFF111827).withValues(alpha: 0.88)
                : Colors.white.withValues(alpha: 0.88),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
                color: isDark ? Colors.white12 : const Color(0x1A0F172A)),
            boxShadow: const [
              BoxShadow(
                  color: Colors.black12, blurRadius: 16, offset: Offset(0, 6)),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                tooltip: isDark
                    ? appLang.translate('auth_light_mode')
                    : appLang.translate('auth_dark_mode'),
                visualDensity: VisualDensity.compact,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                onPressed: themeService.toggleTheme,
                icon: Icon(
                  isDark ? Icons.light_mode_rounded : Icons.dark_mode_rounded,
                  color:
                      isDark ? Colors.amber.shade200 : const Color(0xFF0F172A),
                ),
              ),
              const SizedBox(width: 6),
              Container(
                width: 1,
                height: 22,
                color: isDark ? Colors.white12 : const Color(0x1A0F172A),
              ),
              const SizedBox(width: 8),
              DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: appLang.currentLanguage,
                  isDense: true,
                  icon: Icon(
                    Icons.expand_more_rounded,
                    size: 18,
                    color: isDark ? Colors.white70 : const Color(0xFF0F172A),
                  ),
                  borderRadius: BorderRadius.circular(14),
                  dropdownColor:
                      isDark ? const Color(0xFF111827) : Colors.white,
                  style: TextStyle(
                    color: isDark ? Colors.white : const Color(0xFF0F172A),
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                  ),
                  items: kLanguageLabels.entries
                      .map(
                        (entry) => DropdownMenuItem<String>(
                          value: entry.key,
                          child: Text(entry.value),
                        ),
                      )
                      .toList(),
                  onChanged: (value) {
                    if (value == null) return;
                    appLang.changeLanguage(value);
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

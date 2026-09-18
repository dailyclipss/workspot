import 'package:flutter/material.dart';
import '../services/theme_service.dart';
import '../services/app_language.dart';
import 'phone_input_screen.dart';
import 'home_map_screen.dart';

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _scaleAnimation;

  bool _isLoadingGoogle = false;
  bool _isLoadingApple = false;
  bool _isGuestLoading = false;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );

    _fadeAnimation = CurvedAnimation(
      parent: _animationController,
      curve: const Interval(0.0, 0.65, curve: Curves.easeIn),
    );

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0.0, 0.15),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: const Interval(0.2, 1.0, curve: Curves.easeOutCubic),
    ));

    _scaleAnimation = Tween<double>(
      begin: 0.85,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: const Interval(0.0, 0.7, curve: Curves.easeOutBack),
    ));

    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _handleGoogleAuth() async {
    setState(() => _isLoadingGoogle = true);
    await Future.delayed(const Duration(milliseconds: 1200));
    if (mounted) {
      setState(() => _isLoadingGoogle = false);
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const HomeMapScreen()),
      );
    }
  }

  Future<void> _handleAppleAuth() async {
    setState(() => _isLoadingApple = true);
    await Future.delayed(const Duration(milliseconds: 1200));
    if (mounted) {
      setState(() => _isLoadingApple = false);
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const HomeMapScreen()),
      );
    }
  }

  Future<void> _handleGuestAuth() async {
    setState(() => _isGuestLoading = true);
    await Future.delayed(const Duration(milliseconds: 600));
    if (mounted) {
      setState(() => _isGuestLoading = false);
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const HomeMapScreen()),
      );
    }
  }

  void _showLanguageSelector() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        final isDark = Theme.of(context).brightness == Brightness.dark;
        return ListenableBuilder(
          listenable: appLang,
          builder: (context, child) {
            return Container(
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1E293B) : Colors.white,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
              ),
              padding: const EdgeInsets.all(24.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 48,
                      height: 5,
                      decoration: BoxDecoration(
                        color: isDark ? Colors.grey[700] : Colors.grey[300],
                        borderRadius: BorderRadius.circular(3),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      const Icon(Icons.language_rounded, color: Color(0xFF2563EB), size: 26),
                      const SizedBox(width: 10),
                      Text(
                        appLang.translate('select_language'),
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: isDark ? Colors.white : const Color(0xFF0F172A),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  _buildLanguageItem(
                    flag: '🇦🇿',
                    title: 'Azərbaycan dili',
                    code: 'az',
                    isDark: isDark,
                  ),
                  const Divider(height: 1),
                  _buildLanguageItem(
                    flag: '🇷🇺',
                    title: 'Русский язык',
                    code: 'ru',
                    isDark: isDark,
                  ),
                  const Divider(height: 1),
                  _buildLanguageItem(
                    flag: '🇬🇧',
                    title: 'English Language',
                    code: 'en',
                    isDark: isDark,
                  ),
                  const SizedBox(height: 16),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildLanguageItem({
    required String flag,
    required String title,
    required String code,
    required bool isDark,
  }) {
    final isSelected = appLang.currentLanguage == code;

    return ListTile(
      contentPadding: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
      leading: Text(flag, style: const TextStyle(fontSize: 26)),
      title: Text(
        title,
        style: TextStyle(
          fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
          color: isSelected
              ? const Color(0xFF2563EB)
              : (isDark ? Colors.grey[200] : const Color(0xFF0F172A)),
          fontSize: 16,
        ),
      ),
      trailing: isSelected
          ? Container(
              padding: const EdgeInsets.all(4),
              decoration: const BoxDecoration(
                color: Color(0xFF2563EB),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.check, color: Colors.white, size: 16),
            )
          : null,
      onTap: () {
        appLang.changeLanguage(code);
        Navigator.pop(context);
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    // BÜTÜN EKRANI APPLANG DİNLƏYİCİSİ İLƏ BÜKÜRÜK (KÖKÜNDƏN HƏLL)
    return ListenableBuilder(
      listenable: appLang,
      builder: (context, child) {
        return Scaffold(
          extendBodyBehindAppBar: true,
          appBar: AppBar(
            backgroundColor: Colors.transparent,
            elevation: 0,
            actions: [
              Container(
                margin: const EdgeInsets.only(right: 6),
                decoration: BoxDecoration(
                  color: isDark ? Colors.white.withOpacity(0.08) : Colors.black.withOpacity(0.04),
                  shape: BoxShape.circle,
                ),
                child: IconButton(
                  icon: const Icon(Icons.language_rounded, size: 22),
                  tooltip: 'Dil',
                  onPressed: _showLanguageSelector,
                ),
              ),
              ValueListenableBuilder<ThemeMode>(
                valueListenable: themeService,
                builder: (context, mode, child) {
                  final activeDark = mode == ThemeMode.dark;
                  return Container(
                    margin: const EdgeInsets.only(right: 16),
                    decoration: BoxDecoration(
                      color: activeDark ? Colors.amber.withOpacity(0.15) : const Color(0xFF2563EB).withOpacity(0.1),
                      shape: BoxShape.circle,
                    ),
                    child: IconButton(
                      icon: Icon(
                        activeDark ? Icons.wb_sunny_rounded : Icons.nights_stay_rounded,
                        color: activeDark ? Colors.amber : const Color(0xFF2563EB),
                        size: 22,
                      ),
                      onPressed: () {
                        themeService.toggleTheme();
                      },
                    ),
                  );
                },
              ),
            ],
          ),
          body: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: isDark
                    ? [const Color(0xFF0F172A), const Color(0xFF020617)]
                    : [const Color(0xFFF8FAFC), const Color(0xFFEFF6FF)],
              ),
            ),
            child: SafeArea(
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 460),
                  child: FadeTransition(
                    opacity: _fadeAnimation,
                    child: SlideTransition(
                      position: _slideAnimation,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 24.0),
                        child: Column(
                          children: [
                            const Spacer(flex: 2),

                            ScaleTransition(
                              scale: _scaleAnimation,
                              child: Stack(
                                alignment: Alignment.center,
                                children: [
                                  Container(
                                    width: 110,
                                    height: 110,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      boxShadow: [
                                        BoxShadow(
                                          color: const Color(0xFF2563EB).withOpacity(0.35),
                                          blurRadius: 36,
                                          spreadRadius: 6,
                                        ),
                                      ],
                                    ),
                                  ),
                                  Container(
                                    width: 105,
                                    height: 105,
                                    decoration: BoxDecoration(
                                      gradient: const LinearGradient(
                                        begin: Alignment.topLeft,
                                        end: Alignment.bottomRight,
                                        colors: [Color(0xFF3B82F6), Color(0xFF1D4ED8)],
                                      ),
                                      borderRadius: BorderRadius.circular(28),
                                      boxShadow: [
                                        BoxShadow(
                                          color: const Color(0xFF1E40AF).withOpacity(0.3),
                                          blurRadius: 16,
                                          offset: const Offset(0, 8),
                                        )
                                      ],
                                    ),
                                    child: const Center(
                                      child: Icon(
                                        Icons.location_on_rounded,
                                        size: 52,
                                        color: Colors.white,
                                      ),
                                    ),
                                  ),
                                  Positioned(
                                    right: 6,
                                    top: 6,
                                    child: Container(
                                      padding: const EdgeInsets.all(6),
                                      decoration: BoxDecoration(
                                        color: isDark ? const Color(0xFF0F172A) : Colors.white,
                                        shape: BoxShape.circle,
                                        boxShadow: const [
                                          BoxShadow(color: Colors.black12, blurRadius: 4),
                                        ],
                                      ),
                                      child: const Icon(
                                        Icons.work_rounded,
                                        size: 16,
                                        color: Color(0xFF2563EB),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 28),

                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                              decoration: BoxDecoration(
                                color: const Color(0xFF2563EB).withOpacity(0.1),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Text(
                                appLang.translate('tag'),
                                style: const TextStyle(
                                  color: Color(0xFF2563EB),
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                            const SizedBox(height: 10),

                            Text(
                              appLang.translate('app_title'),
                              style: TextStyle(
                                fontSize: 38,
                                fontWeight: FontWeight.w900,
                                letterSpacing: -0.5,
                                color: isDark ? Colors.white : const Color(0xFF0F172A),
                              ),
                            ),
                            const SizedBox(height: 12),
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 16.0),
                              child: Text(
                                appLang.translate('subtitle'),
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: 14,
                                  height: 1.55,
                                  color: isDark ? Colors.grey[400] : Colors.grey[600],
                                  fontWeight: FontWeight.w400,
                                ),
                              ),
                            ),

                            const Spacer(flex: 3),

                            SizedBox(
                              width: double.infinity,
                              height: 54,
                              child: ElevatedButton.icon(
                                onPressed: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(builder: (context) => const PhoneInputScreen()),
                                  );
                                },
                                icon: const Icon(Icons.phone_android_rounded, color: Colors.white, size: 22),
                                label: Text(
                                  appLang.translate('phone_login'),
                                  style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                                ),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF2563EB),
                                  foregroundColor: Colors.white,
                                  elevation: 6,
                                  shadowColor: const Color(0xFF2563EB).withOpacity(0.4),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                ),
                              ),
                            ),
                            const SizedBox(height: 16),

                            Row(
                              children: [
                                Expanded(child: Divider(color: isDark ? Colors.grey[800] : Colors.grey[300])),
                                Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 12.0),
                                  child: Text(
                                    appLang.translate('or_social'),
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: isDark ? Colors.grey[500] : Colors.grey[500],
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ),
                                Expanded(child: Divider(color: isDark ? Colors.grey[800] : Colors.grey[300])),
                              ],
                            ),
                            const SizedBox(height: 16),

                            Row(
                              children: [
                                Expanded(
                                  child: OutlinedButton(
                                    onPressed: _isLoadingGoogle ? null : _handleGoogleAuth,
                                    style: OutlinedButton.styleFrom(
                                      minimumSize: const Size(double.infinity, 50),
                                      side: BorderSide(
                                        color: isDark ? Colors.grey[700]! : Colors.grey.shade300,
                                        width: 1.2,
                                      ),
                                      backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                                    ),
                                    child: _isLoadingGoogle
                                        ? const SizedBox(
                                            width: 20,
                                            height: 20,
                                            child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF2563EB)),
                                          )
                                        : Row(
                                            mainAxisAlignment: MainAxisAlignment.center,
                                            children: [
                                              Image.network(
                                                'https://upload.wikimedia.org/wikipedia/commons/5/53/Google_%22G%22_Logo.svg',
                                                height: 18,
                                                errorBuilder: (context, error, stackTrace) =>
                                                    const Icon(Icons.g_mobiledata_rounded, size: 28, color: Colors.redAccent),
                                              ),
                                              const SizedBox(width: 8),
                                              Text(
                                                'Google',
                                                style: TextStyle(
                                                  fontWeight: FontWeight.bold,
                                                  fontSize: 14,
                                                  color: isDark ? Colors.white : const Color(0xFF0F172A),
                                                ),
                                              ),
                                            ],
                                          ),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: OutlinedButton(
                                    onPressed: _isLoadingApple ? null : _handleAppleAuth,
                                    style: OutlinedButton.styleFrom(
                                      minimumSize: const Size(double.infinity, 50),
                                      side: BorderSide(
                                        color: isDark ? Colors.grey[700]! : Colors.grey.shade300,
                                        width: 1.2,
                                      ),
                                      backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                                    ),
                                    child: _isLoadingApple
                                        ? SizedBox(
                                            width: 20,
                                            height: 20,
                                            child: CircularProgressIndicator(
                                              strokeWidth: 2,
                                              color: isDark ? Colors.white : Colors.black,
                                            ),
                                          )
                                        : Row(
                                            mainAxisAlignment: MainAxisAlignment.center,
                                            children: [
                                              Icon(
                                                Icons.apple,
                                                size: 20,
                                                color: isDark ? Colors.white : Colors.black,
                                              ),
                                              const SizedBox(width: 6),
                                              Text(
                                                'Apple',
                                                style: TextStyle(
                                                  fontWeight: FontWeight.bold,
                                                  fontSize: 14,
                                                  color: isDark ? Colors.white : const Color(0xFF0F172A),
                                                ),
                                              ),
                                            ],
                                          ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 18),

                            TextButton.icon(
                              onPressed: _isGuestLoading ? null : _handleGuestAuth,
                              icon: _isGuestLoading
                                  ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                                  : const Icon(Icons.explore_outlined, size: 18, color: Color(0xFF2563EB)),
                              label: Text(
                                appLang.translate('guest_login'),
                                style: const TextStyle(
                                  color: Color(0xFF2563EB),
                                  fontWeight: FontWeight.w600,
                                  fontSize: 14,
                                  decoration: TextDecoration.underline,
                                ),
                              ),
                            ),

                            const Spacer(flex: 1),

                            Padding(
                              padding: const EdgeInsets.only(bottom: 12.0),
                              child: Text(
                                appLang.translate('terms'),
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: 11,
                                  color: isDark ? Colors.grey[600] : Colors.grey[500],
                                  height: 1.3,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
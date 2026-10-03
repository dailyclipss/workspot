import 'package:flutter/material.dart';

import '../services/app_language.dart';
import '../services/theme_service.dart';
import 'home_map_screen.dart';

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen>
    with SingleTickerProviderStateMixin {
  static const String _adminBypassPin = String.fromEnvironment(
    'WORKSPOT_ADMIN_BYPASS_PIN',
    defaultValue: '123456',
  );

  static const Map<String, String> _languageLabels = {
    'az': 'AZ',
    'en': 'EN',
    'ru': 'RU',
  };

  late final AnimationController _animationController;
  late final Animation<double> _fadeAnimation;
  late final Animation<Offset> _slideAnimation;
  late final Animation<double> _scaleAnimation;

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
    ).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: const Interval(0.2, 1.0, curve: Curves.easeOutCubic),
      ),
    );

    _scaleAnimation = Tween<double>(
      begin: 0.85,
      end: 1.0,
    ).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: const Interval(0.0, 0.7, curve: Curves.easeOutBack),
      ),
    );

    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  Widget _buildCornerControls(bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: isDark
            ? const Color(0xFF111827).withValues(alpha: 0.88)
            : Colors.white.withValues(alpha: 0.88),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: isDark ? Colors.white12 : const Color(0x1A0F172A)),
        boxShadow: const [
          BoxShadow(color: Colors.black12, blurRadius: 16, offset: Offset(0, 6)),
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
              color: isDark ? Colors.amber.shade200 : const Color(0xFF0F172A),
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
              dropdownColor: isDark ? const Color(0xFF111827) : Colors.white,
              style: TextStyle(
                color: isDark ? Colors.white : const Color(0xFF0F172A),
                fontWeight: FontWeight.w700,
                fontSize: 13,
              ),
              items: _languageLabels.entries
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
  }

  Future<void> _openAdminPinDialog() async {
    final pinController = TextEditingController();

    final accepted = await showDialog<bool>(
      context: context,
      barrierDismissible: true,
      builder: (dialogContext) {
        bool obscurePin = true;

        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              backgroundColor: const Color(0xFF111827),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              title: Text(
                appLang.translate('auth_admin_title'),
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                ),
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    appLang.translate('auth_pin_prompt'),
                    style: const TextStyle(color: Color(0xFF9CA3AF)),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: pinController,
                    keyboardType: TextInputType.number,
                    obscureText: obscurePin,
                    maxLength: 6,
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      labelText: appLang.translate('auth_pin_label'),
                      labelStyle: const TextStyle(color: Colors.white70),
                      counterText: '',
                      filled: true,
                      fillColor: const Color(0xFF0F172A),
                      suffixIcon: IconButton(
                        onPressed: () => setState(() => obscurePin = !obscurePin),
                        icon: Icon(
                          obscurePin
                              ? Icons.visibility_off_rounded
                              : Icons.visibility_rounded,
                          color: Colors.white70,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(),
                  child: Text(appLang.translate('auth_cancel')),
                ),
                ElevatedButton(
                  onPressed: () {
                    final pin = pinController.text.trim();
                    if (!RegExp(r'^\d{6}$').hasMatch(pin)) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text(appLang.translate('auth_pin_length_error'))),
                      );
                      return;
                    }
                    Navigator.of(dialogContext).pop(pin == _adminBypassPin);
                  },
                  child: Text(appLang.translate('auth_login')),
                ),
              ],
            );
          },
        );
      },
    );

    pinController.dispose();

    if (accepted == true && mounted) {
      Navigator.pushReplacementNamed(
        context,
        '/admin',
        arguments: const {'passcodeOverride': true},
      );
    } else if (accepted == false && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(appLang.translate('auth_pin_invalid'))),
      );
    }
  }

  Future<void> _handleGoogleAuth() async {
    setState(() => _isLoadingGoogle = true);
    await Future.delayed(const Duration(milliseconds: 1200));
    if (!mounted) return;
    setState(() => _isLoadingGoogle = false);
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (context) => const HomeMapScreen()),
    );
  }

  Future<void> _handleAppleAuth() async {
    setState(() => _isLoadingApple = true);
    await Future.delayed(const Duration(milliseconds: 1200));
    if (!mounted) return;
    setState(() => _isLoadingApple = false);
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (context) => const HomeMapScreen()),
    );
  }

  Future<void> _handleGuestAuth() async {
    setState(() => _isGuestLoading = true);
    await Future.delayed(const Duration(milliseconds: 600));
    if (!mounted) return;
    setState(() => _isGuestLoading = false);
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (context) => const HomeMapScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([themeService, appLang]),
      builder: (context, _) {
        final isDark = themeService.isDarkMode;

        return Scaffold(
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
              child: Stack(
                children: [
                  Positioned(
                    top: 8,
                    right: 16,
                    child: _buildCornerControls(isDark),
                  ),
                  Center(
                    child: FadeTransition(
                      opacity: _fadeAnimation,
                      child: SlideTransition(
                        position: _slideAnimation,
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 460),
                          child: SingleChildScrollView(
                            physics: const BouncingScrollPhysics(),
                            padding: const EdgeInsets.fromLTRB(24, 64, 24, 20),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const SizedBox(height: 8),
                                GestureDetector(
                                  onLongPress: _openAdminPinDialog,
                                  child: ScaleTransition(
                                    scale: _scaleAnimation,
                                    child: Container(
                                      width: 112,
                                      height: 112,
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        boxShadow: [
                                          BoxShadow(
                                            color: const Color(0xFF2563EB)
                                                .withValues(alpha: 0.35),
                                            blurRadius: 34,
                                            spreadRadius: 5,
                                          ),
                                        ],
                                      ),
                                      child: Stack(
                                        alignment: Alignment.center,
                                        children: [
                                          Container(
                                            width: 104,
                                            height: 104,
                                            decoration: BoxDecoration(
                                              gradient: const LinearGradient(
                                                begin: Alignment.topLeft,
                                                end: Alignment.bottomRight,
                                                colors: [
                                                  Color(0xFF3B82F6),
                                                  Color(0xFF1D4ED8),
                                                ],
                                              ),
                                              borderRadius: BorderRadius.circular(28),
                                            ),
                                            child: const Icon(
                                              Icons.location_on_rounded,
                                              size: 52,
                                              color: Colors.white,
                                            ),
                                          ),
                                          Positioned(
                                            right: 6,
                                            top: 6,
                                            child: Container(
                                              padding: const EdgeInsets.all(6),
                                              decoration: BoxDecoration(
                                                color: isDark
                                                    ? const Color(0xFF0F172A)
                                                    : Colors.white,
                                                shape: BoxShape.circle,
                                                boxShadow: const [
                                                  BoxShadow(
                                                    color: Colors.black12,
                                                    blurRadius: 4,
                                                  ),
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
                                  ),
                                ),
                                const SizedBox(height: 22),
                                Text(
                                  appLang.translate('app_title'),
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    fontSize: 38,
                                    fontWeight: FontWeight.w900,
                                    letterSpacing: -0.6,
                                    color: isDark ? Colors.white : const Color(0xFF0F172A),
                                  ),
                                ),
                                const SizedBox(height: 28),
                                SizedBox(
                                  width: double.infinity,
                                  height: 54,
                                  child: ElevatedButton.icon(
                                    onPressed: () {
                                      showModalBottomSheet(
                                        context: context,
                                        isScrollControlled: true,
                                        backgroundColor: Colors.transparent,
                                        builder: (sheetContext) {
                                          return SafeArea(
                                            top: false,
                                            child: Container(
                                              padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
                                              decoration: const BoxDecoration(
                                                color: Color(0xFF111827),
                                                borderRadius: BorderRadius.vertical(
                                                  top: Radius.circular(24),
                                                ),
                                              ),
                                              child: Column(
                                                mainAxisSize: MainAxisSize.min,
                                                crossAxisAlignment: CrossAxisAlignment.start,
                                                children: [
                                                  Text(
                                                    appLang.translate('auth_phone_login'),
                                                    style: const TextStyle(
                                                      color: Colors.white,
                                                      fontSize: 18,
                                                      fontWeight: FontWeight.w800,
                                                    ),
                                                  ),
                                                  const SizedBox(height: 16),
                                                  TextField(
                                                    keyboardType: TextInputType.phone,
                                                    style: const TextStyle(color: Colors.white),
                                                    decoration: InputDecoration(
                                                      hintText: appLang.translate('auth_phone_placeholder'),
                                                      hintStyle: const TextStyle(color: Colors.grey),
                                                      filled: true,
                                                      fillColor: const Color(0xFF0F172A),
                                                      border: const OutlineInputBorder(),
                                                    ),
                                                  ),
                                                  const SizedBox(height: 16),
                                                  SizedBox(
                                                    width: double.infinity,
                                                    child: ElevatedButton(
                                                      onPressed: () => Navigator.pop(sheetContext),
                                                      child: Text(appLang.translate('auth_send_code')),
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          );
                                        },
                                      );
                                    },
                                    icon: const Icon(
                                      Icons.phone_android_rounded,
                                      color: Colors.white,
                                      size: 22,
                                    ),
                                    label: Text(
                                      appLang.translate('auth_phone_login'),
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: const Color(0xFF2563EB),
                                      foregroundColor: Colors.white,
                                      elevation: 6,
                                      shadowColor:
                                          const Color(0xFF2563EB).withValues(alpha: 0.35),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(16),
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 16),
                                Row(
                                  children: [
                                    Expanded(
                                      child: Divider(
                                        color: isDark ? Colors.grey[800] : Colors.grey[300],
                                      ),
                                    ),
                                    Padding(
                                      padding: const EdgeInsets.symmetric(horizontal: 12.0),
                                      child: Text(
                                        appLang.translate('auth_or'),
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: isDark ? Colors.grey[500] : Colors.grey[500],
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ),
                                    Expanded(
                                      child: Divider(
                                        color: isDark ? Colors.grey[800] : Colors.grey[300],
                                      ),
                                    ),
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
                                            color: isDark
                                                ? Colors.grey[700]!
                                                : Colors.grey.shade300,
                                            width: 1.2,
                                          ),
                                          backgroundColor:
                                              isDark ? const Color(0xFF1E293B) : Colors.white,
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(14),
                                          ),
                                        ),
                                        child: _isLoadingGoogle
                                            ? const SizedBox(
                                                width: 20,
                                                height: 20,
                                                child: CircularProgressIndicator(
                                                  strokeWidth: 2,
                                                  color: Color(0xFF2563EB),
                                                ),
                                              )
                                            : Row(
                                                mainAxisAlignment: MainAxisAlignment.center,
                                                children: [
                                                  Image.network(
                                                    'https://upload.wikimedia.org/wikipedia/commons/5/53/Google_%22G%22_Logo.svg',
                                                    height: 18,
                                                    errorBuilder: (context, error, stackTrace) =>
                                                        const Icon(
                                                      Icons.g_mobiledata_rounded,
                                                      size: 28,
                                                      color: Colors.redAccent,
                                                    ),
                                                  ),
                                                  const SizedBox(width: 8),
                                                  Text(
                                                    appLang.translate('auth_google'),
                                                    style: TextStyle(
                                                      fontWeight: FontWeight.bold,
                                                      fontSize: 14,
                                                      color: isDark
                                                          ? Colors.white
                                                          : const Color(0xFF0F172A),
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
                                            color: isDark
                                                ? Colors.grey[700]!
                                                : Colors.grey.shade300,
                                            width: 1.2,
                                          ),
                                          backgroundColor:
                                              isDark ? const Color(0xFF1E293B) : Colors.white,
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(14),
                                          ),
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
                                                    appLang.translate('auth_apple'),
                                                    style: TextStyle(
                                                      fontWeight: FontWeight.bold,
                                                      fontSize: 14,
                                                      color: isDark
                                                          ? Colors.white
                                                          : const Color(0xFF0F172A),
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
                                      ? const SizedBox(
                                          width: 16,
                                          height: 16,
                                          child: CircularProgressIndicator(strokeWidth: 2),
                                        )
                                      : const Icon(
                                          Icons.explore_outlined,
                                          size: 18,
                                          color: Color(0xFF2563EB),
                                        ),
                                  label: Text(
                                    appLang.translate('auth_guest_continue'),
                                    style: const TextStyle(
                                      color: Color(0xFF2563EB),
                                      fontWeight: FontWeight.w600,
                                      fontSize: 14,
                                      decoration: TextDecoration.underline,
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
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
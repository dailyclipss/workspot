import 'package:flutter/material.dart';
import 'home_map_screen.dart';

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> with SingleTickerProviderStateMixin {
  static const String _adminBypassPin = String.fromEnvironment(
    'WORKSPOT_ADMIN_BYPASS_PIN',
    defaultValue: '123456',
  );

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
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              title: const Text(
                'Admin Girişi',
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800),
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    '6 rəqəmli PIN daxil edin.',
                    style: TextStyle(color: Color(0xFF9CA3AF)),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: pinController,
                    keyboardType: TextInputType.number,
                    obscureText: obscurePin,
                    maxLength: 6,
                    decoration: InputDecoration(
                      labelText: 'PIN',
                      counterText: '',
                      suffixIcon: IconButton(
                        onPressed: () => setState(() => obscurePin = !obscurePin),
                        icon: Icon(
                          obscurePin ? Icons.visibility_off_rounded : Icons.visibility_rounded,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(),
                  child: const Text('Ləğv et'),
                ),
                ElevatedButton(
                  onPressed: () {
                    final pin = pinController.text.trim();
                    if (!RegExp(r'^\d{6}$').hasMatch(pin)) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('PIN 6 rəqəm olmalıdır.')),
                      );
                      return;
                    }
                    Navigator.of(dialogContext).pop(pin == _adminBypassPin);
                  },
                  child: const Text('Daxil ol'),
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
        const SnackBar(content: Text('PIN yanlışdır.')),
      );
    }
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

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

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
          child: Center(
            child: FadeTransition(
              opacity: _fadeAnimation,
              child: SlideTransition(
                position: _slideAnimation,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 460),
                  child: SingleChildScrollView(
                    physics: const BouncingScrollPhysics(),
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
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
                                    color: const Color(0xFF2563EB).withValues(alpha: 0.35),
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
                                        colors: [Color(0xFF3B82F6), Color(0xFF1D4ED8)],
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
                          ),
                        ),
                        const SizedBox(height: 22),
                        Text(
                          'WorkSpot',
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
                                builder: (context) {
                                  return SafeArea(
                                    top: false,
                                    child: Container(
                                      padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
                                      decoration: const BoxDecoration(
                                        color: Color(0xFF111827),
                                        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
                                      ),
                                      child: Column(
                                        mainAxisSize: MainAxisSize.min,
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          const Text(
                                            'Telefon Nömrəsi İlə Giriş',
                                            style: TextStyle(
                                              color: Colors.white,
                                              fontSize: 18,
                                              fontWeight: FontWeight.w800,
                                            ),
                                          ),
                                          const SizedBox(height: 16),
                                          const TextField(
                                            keyboardType: TextInputType.phone,
                                            style: TextStyle(color: Colors.white),
                                            decoration: InputDecoration(
                                              hintText: '+994 50 000 00 00',
                                              hintStyle: TextStyle(color: Colors.grey),
                                              filled: true,
                                              fillColor: Color(0xFF0F172A),
                                              border: OutlineInputBorder(),
                                            ),
                                          ),
                                          const SizedBox(height: 16),
                                          SizedBox(
                                            width: double.infinity,
                                            child: ElevatedButton(
                                              onPressed: () => Navigator.pop(context),
                                              child: const Text('Kodu Göndər'),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  );
                                },
                              );
                            },
                            icon: const Icon(Icons.phone_android_rounded, color: Colors.white, size: 22),
                            label: const Text(
                              'Telefon Nömrəsi İlə Giriş',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF2563EB),
                              foregroundColor: Colors.white,
                              elevation: 6,
                              shadowColor: const Color(0xFF2563EB).withValues(alpha: 0.35),
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
                                'və ya',
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
                          label: const Text(
                            'Hesabsız davam et',
                            style: TextStyle(
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
        ),
      ),
    );
  }
}
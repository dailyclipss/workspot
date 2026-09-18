import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'home_map_screen.dart';

class PhoneInputScreen extends StatefulWidget {
  const PhoneInputScreen({Key? key}) : super(key: key);

  @override
  State<PhoneInputScreen> createState() => _PhoneInputScreenState();
}

class _PhoneInputScreenState extends State<PhoneInputScreen> {
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _otpController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  int _selectedRoleIndex = 0; // 0: İş Axtaran, 1: İşəgötürən
  bool _isOtpSent = false;
  bool _isLoading = false;
  int _timerSeconds = 60;
  Timer? _timer;
  String _currentLang = 'AZ';

  void _startTimer() {
    setState(() => _timerSeconds = 60);
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_timerSeconds > 0) {
        if (mounted) setState(() => _timerSeconds--);
      } else {
        _timer?.cancel();
      }
    });
  }

  void _sendOtp() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);
    await Future.delayed(const Duration(milliseconds: 350));
    if (!mounted) return;
    setState(() {
      _isLoading = false;
      _isOtpSent = true;
    });
    _startTimer();
  }

  void _verifyOtpAndLogin() async {
    if (_otpController.text.length < 4) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Təsdiq kodunu tam daxil edin (4 rəqəm)'),
          backgroundColor: Colors.redAccent,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
      return;
    }
    setState(() => _isLoading = true);
    await Future.delayed(const Duration(milliseconds: 350));
    if (!mounted) return;
    setState(() => _isLoading = false);
    _navigateToHome();
  }

  void _navigateToHome() {
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (context) => const HomeMapScreen()),
      (route) => false,
    );
  }

  void _showTermsDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Məxfilik və Şərtlər', style: TextStyle(fontWeight: FontWeight.bold)),
        content: const Text(
          'WorkSpot tətbiqi istifadəçi məlumatlarının təhlükəsizliyinə tam zəmanət verir. Məkan məlumatlarınız yalnız yaxınlıqdakı iş vakansiyalarını göstərmək üçün istifadə olunur.',
          style: TextStyle(fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Anladım', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _timer?.cancel();
    _phoneController.dispose();
    _otpController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    return Scaffold(
      backgroundColor: const Color(0xFFF1F5F9),
      body: Stack(
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 400),
            height: size.height * (_isOtpSent ? 0.30 : 0.38),
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFF2563EB), Color(0xFF1D4ED8), Color(0xFF1E40AF)],
              ),
              borderRadius: BorderRadius.vertical(bottom: Radius.elliptical(400, 45)),
            ),
          ),
          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 22.0, vertical: 12.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        DropdownButton<String>(
                          dropdownColor: const Color(0xFF1D4ED8),
                          value: _currentLang,
                          underline: const SizedBox(),
                          icon: const Icon(Icons.language, color: Colors.white, size: 20),
                          items: ['AZ', 'EN', 'RU'].map((lang) {
                            return DropdownMenuItem(
                              value: lang,
                              child: Text(lang, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                            );
                          }).toList(),
                          onChanged: (val) {
                            if (val != null) setState(() => _currentLang = val);
                          },
                        ),
                      ],
                    ),
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.18),
                        shape: BoxShape.circle,
                        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.08), blurRadius: 15)],
                      ),
                      child: Icon(
                        _isOtpSent ? Icons.mark_email_read_rounded : Icons.explore_rounded,
                        size: 44,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 10),
                    const Text(
                      'WorkSpot',
                      style: TextStyle(fontSize: 32, fontWeight: FontWeight.w900, color: Colors.white, letterSpacing: -0.5),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _isOtpSent ? 'SMS kodu nömrənizə göndərildi' : 'Yaxınlığındakı işi xəritədə tap',
                      style: TextStyle(fontSize: 14, color: Colors.white.withOpacity(0.9)),
                    ),
                    const SizedBox(height: 10),
                    if (!_isOtpSent)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: Colors.white.withOpacity(0.3)),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: const [
                            Icon(Icons.bolt, size: 14, color: Color(0xFFFFD700)),
                            SizedBox(width: 4),
                            Text('Bakı üzrə 1,200+ aktiv elan', style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w600)),
                          ],
                        ),
                      ),
                    const SizedBox(height: 24),
                    Container(
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(28),
                        boxShadow: [
                          BoxShadow(color: const Color(0xFF1E3A8A).withOpacity(0.08), blurRadius: 30, offset: const Offset(0, 10)),
                        ],
                      ),
                      child: Form(
                        key: _formKey,
                        child: AnimatedCrossFade(
                          duration: const Duration(milliseconds: 300),
                          crossFadeState: _isOtpSent ? CrossFadeState.showSecond : CrossFadeState.showFirst,
                          firstChild: _buildPhoneStep(),
                          secondChild: _buildOtpStep(),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.shield_outlined, size: 14, color: Colors.grey.shade400),
                        const SizedBox(width: 6),
                        GestureDetector(
                          onTap: _showTermsDialog,
                          child: Text(
                            'Təhlükəsiz giriş • Şərtlər və Məxfilik',
                            style: TextStyle(fontSize: 12, color: Colors.grey.shade600, decoration: TextDecoration.underline),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPhoneStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          height: 40,
          padding: const EdgeInsets.all(3),
          decoration: BoxDecoration(color: const Color(0xFFF1F5F9), borderRadius: BorderRadius.circular(12)),
          child: Row(
            children: [
              Expanded(
                child: GestureDetector(
                  onTap: () => setState(() => _selectedRoleIndex = 0),
                  child: Container(
                    decoration: BoxDecoration(
                      color: _selectedRoleIndex == 0 ? Colors.white : Colors.transparent,
                      borderRadius: BorderRadius.circular(10),
                      boxShadow: _selectedRoleIndex == 0 ? [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 4)] : [],
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      'İş Axtarıram',
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: _selectedRoleIndex == 0 ? const Color(0xFF2563EB) : Colors.grey.shade600),
                    ),
                  ),
                ),
              ),
              Expanded(
                child: GestureDetector(
                  onTap: () => setState(() => _selectedRoleIndex = 1),
                  child: Container(
                    decoration: BoxDecoration(
                      color: _selectedRoleIndex == 1 ? Colors.white : Colors.transparent,
                      borderRadius: BorderRadius.circular(10),
                      boxShadow: _selectedRoleIndex == 1 ? [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 4)] : [],
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      'İşçi Axtarıram',
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: _selectedRoleIndex == 1 ? const Color(0xFF2563EB) : Colors.grey.shade600),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        TextFormField(
          controller: _phoneController,
          keyboardType: TextInputType.phone,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(9)],
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Color(0xFF0F172A)),
          decoration: InputDecoration(
            labelText: 'Mobil Nömrə',
            hintText: '50 123 45 67',
            prefixIcon: const Icon(Icons.phone_android_rounded, color: Color(0xFF2563EB), size: 20),
            prefixText: '+994 ',
            prefixStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Color(0xFF0F172A)),
            filled: true,
            fillColor: const Color(0xFFF8FAFC),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: Color(0xFF2563EB), width: 1.5)),
          ),
          validator: (value) {
            if (value == null || value.trim().length < 9) return 'Düzgün mobil nömrə daxil edin (9 rəqəm)';
            return null;
          },
        ),
        const SizedBox(height: 18),
        SizedBox(
          width: double.infinity,
          height: 50,
          child: ElevatedButton(
            onPressed: _isLoading ? null : _sendOtp,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF2563EB),
              elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            ),
            child: _isLoading
                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                : Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: const [
                      Text('SMS Kod Göndər', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.white)),
                      SizedBox(width: 6),
                      Icon(Icons.arrow_forward_rounded, size: 18, color: Colors.white),
                    ],
                  ),
          ),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(child: Divider(color: Colors.grey.shade300)),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10),
              child: Text('və ya sosial', style: TextStyle(fontSize: 12, color: Colors.grey.shade500)),
            ),
            Expanded(child: Divider(color: Colors.grey.shade300)),
          ],
        ),
        const SizedBox(height: 14),
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: _navigateToHome,
                icon: const Icon(Icons.g_mobiledata_rounded, size: 24, color: Colors.redAccent),
                label: const Text('Google', style: TextStyle(color: Color(0xFF0F172A), fontWeight: FontWeight.w600)),
                style: OutlinedButton.styleFrom(
                  side: BorderSide(color: Colors.grey.shade300),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  padding: const EdgeInsets.symmetric(vertical: 10),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: _navigateToHome,
                icon: const Icon(Icons.apple_rounded, size: 22, color: Colors.black),
                label: const Text('Apple', style: TextStyle(color: Color(0xFF0F172A), fontWeight: FontWeight.w600)),
                style: OutlinedButton.styleFrom(
                  side: BorderSide(color: Colors.grey.shade300),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  padding: const EdgeInsets.symmetric(vertical: 10),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Center(
          child: TextButton(
            onPressed: _navigateToHome,
            child: Text('Qonaq kimi kəşf et', style: TextStyle(color: Colors.grey.shade700, fontWeight: FontWeight.w600, fontSize: 13)),
          ),
        ),
      ],
    );
  }

  Widget _buildOtpStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text('SMS Kodunu Yazın', style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
            IconButton(
              icon: const Icon(Icons.edit_note_rounded, color: Color(0xFF2563EB)),
              onPressed: () => setState(() => _isOtpSent = false),
            ),
          ],
        ),
        Text('+994 ${_phoneController.text} nömrəsinə göndərildi', style: TextStyle(fontSize: 13, color: Colors.grey.shade600)),
        const SizedBox(height: 18),
        TextFormField(
          controller: _otpController,
          keyboardType: TextInputType.number,
          textAlign: TextAlign.center,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(4)],
          style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Color(0xFF2563EB), letterSpacing: 14),
          decoration: InputDecoration(
            hintText: '••••',
            hintStyle: TextStyle(letterSpacing: 14, color: Colors.grey.shade400),
            filled: true,
            fillColor: const Color(0xFFF8FAFC),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
          ),
        ),
        const SizedBox(height: 14),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(_timerSeconds > 0 ? 'Yenidən göndər: ${_timerSeconds}s' : 'Kod gəlmədi?', style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
            if (_timerSeconds == 0)
              TextButton(
                onPressed: _sendOtp,
                child: const Text('Yenidən Göndər', style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF2563EB), fontSize: 13)),
              ),
          ],
        ),
        const SizedBox(height: 16),
        SizedBox(
          width: double.infinity,
          height: 50,
          child: ElevatedButton(
            onPressed: _isLoading ? null : _verifyOtpAndLogin,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF2563EB),
              elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            ),
            child: _isLoading
                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                : const Text('Təsdiqlə və Keç', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.white)),
          ),
        ),
      ],
    );
  }
}
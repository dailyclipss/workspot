import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'home_map_screen.dart';

class PaymentScreen extends StatefulWidget {
  final String jobId;

  const PaymentScreen({super.key, required this.jobId});

  @override
  State<PaymentScreen> createState() => _PaymentScreenState();
}

class _PaymentScreenState extends State<PaymentScreen> {
  static const _background = Color(0xFF0F172A);
  static const _surface = Color(0xFF1E293B);
  static const _muted = Color(0xFF94A3B8);
  static const _blue = Color(0xFF2563EB);

  final _noteController = TextEditingController();
  bool _isSubmitting = false;

  @override
  void dispose() {
    _noteController.dispose();
    super.dispose();
  }

  Future<void> _handlePaymentSuccess() async {
    setState(() => _isSubmitting = true);
    try {
      await Supabase.instance.client.from('payment_requests').insert({
        'job_id': widget.jobId,
        'amount': 10,
        'package_name': 'Standart Elan',
        'payment_method': 'm10_card',
        'transaction_note': _noteController.text,
        'reference': _noteController.text,
        'status': 'pending',
      });

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
              'Ödəniş sorğusu göndərildi! Admin təsdiqindən sonra aktivləşəcək.'),
          backgroundColor: Colors.green,
          duration: Duration(seconds: 2),
        ),
      );

      if (Navigator.canPop(context)) {
        Navigator.of(context).pop();
      } else {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (context) => const HomeMapScreen()),
          (route) => false,
        );
      }
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Ödəniş sorğusu göndərilmədi: $error'),
          backgroundColor: Colors.red,
        ),
      );
      setState(() => _isSubmitting = false);
    }
  }

  Future<void> _copy(String value, String label) async {
    await Clipboard.setData(ClipboardData(text: value));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('$label kopyalandı.')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _background,
      appBar: AppBar(
        backgroundColor: _background,
        foregroundColor: Colors.white,
        elevation: 0,
        title:
            const Text('Ödəniş', style: TextStyle(fontWeight: FontWeight.bold)),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Elanın yayımlanması',
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              const Text(
                  'Ödəniş məlumatlarını tamamlayın. Elanınız admin təsdiqindən sonra aktivləşəcək.',
                  style: TextStyle(color: _muted, height: 1.4)),
              const SizedBox(height: 20),
              _section(
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Standart Elan',
                            style: TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.bold)),
                        SizedBox(height: 4),
                        Text('1 vakansiya / 30 gün',
                            style: TextStyle(color: _muted, fontSize: 12)),
                      ],
                    ),
                    Text('10 ₼',
                        style: TextStyle(
                            color: Color(0xFF60A5FA),
                            fontSize: 22,
                            fontWeight: FontWeight.bold)),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              const Text('Ödəniş köçürməsi',
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: 17,
                      fontWeight: FontWeight.bold)),
              const SizedBox(height: 10),
              _transferRow('M10 nömrəsi', '+994 50 000 00 00'),
              const SizedBox(height: 8),
              _transferRow('Kart nömrəsi', '0000 0000 0000 0000'),
              const SizedBox(height: 20),
              const Text('Tranzaksiya qeydi',
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: 17,
                      fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              TextField(
                controller: _noteController,
                style: const TextStyle(color: Colors.white),
                textInputAction: TextInputAction.done,
                decoration: InputDecoration(
                  hintText: 'Ödəniş kodu, göndərən ad və ya telefon',
                  hintStyle: const TextStyle(color: _muted),
                  filled: true,
                  fillColor: _surface,
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide.none),
                  focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: const BorderSide(color: _blue)),
                ),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: _isSubmitting ? null : _handlePaymentSuccess,
                  style: ElevatedButton.styleFrom(
                      backgroundColor: _blue,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14))),
                  child: _isSubmitting
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white))
                      : const Text('Ödənişi Təsdiqə Göndər',
                          style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _section({required Widget child}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
          color: _surface,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: Colors.white10)),
      child: child,
    );
  }

  Widget _transferRow(String label, String value) {
    return _section(
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    style: const TextStyle(color: _muted, fontSize: 12)),
                const SizedBox(height: 4),
                Text(value,
                    style: const TextStyle(
                        color: Colors.white, fontWeight: FontWeight.bold)),
              ],
            ),
          ),
          IconButton(
            tooltip: 'Kopyala',
            onPressed: () => _copy(value, label),
            icon: const Icon(Icons.copy_rounded,
                color: Color(0xFF60A5FA), size: 19),
          ),
        ],
      ),
    );
  }
}

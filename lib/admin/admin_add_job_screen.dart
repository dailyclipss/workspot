import 'package0/flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AdminAddJobScreen extends StatefulWidget {
  const AdminAddJobScreen({Key? key}) : super(key: key);

  @override
  State<AdminAddJobScreen> createState() => _AdminAddJobScreenState();
}

class _AdminAddJobScreenState extends State<AdminAddJobScreen> {
  final _titleController = TextEditingController();
  final _salaryController = TextEditingController();
  final _latController = TextEditingController();
  final _lngController = TextEditingController();
  
  String _category = 'İaşə';
  String _employmentType = 'Tam iş günü';
  String _salaryType = 'Aylıq';
  bool _isLoading = false;

  Future<void> _submitJob() async {
    if (_titleController.text.isEmpty || _salaryController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Xanaları tam doldurun')),
      );
      return;
    }

    setState(() => _isLoading = true);
    try {
      final lat = double.parse(_latController.text);
      final lng = double.parse(_lngController.text);

      await Supabase.instance.client.from('jobs').insert({
        'title': _titleController.text.trim(),
        'category': _category,
        'employment_type': _employmentType,
        'salary_amount': double.parse(_salaryController.text),
        'salary_type': _salaryType,
        'location': 'POINT($lng $lat)',
        'is_active': true,
      });

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Yeni elan uğurla əlavə olundu!')),
      );
      _titleController.clear();
      _salaryController.clear();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Xəta: $e')),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('WorkSpot Admin — Elan Əlavə Et')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          children: [
            TextField(controller: _titleController, decoration: const InputDecoration(labelText: 'Vakansiya Adı')),
            const SizedBox(height: 12),
            TextField(controller: _salaryController, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Məbləğ (AZN)')),
            const SizedBox(height: 12),
            TextField(controller: _latController, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Enlik (Latitude e.g. 40.4092)')),
            const SizedBox(height: 12),
            TextField(controller: _lngController, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Uzunluq (Longitude e.g. 49.8670)')),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _submitJob,
                child: _isLoading ? const CircularProgressIndicator() : const Text('Elanı Paylaş'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
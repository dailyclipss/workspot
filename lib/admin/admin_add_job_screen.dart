import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../utils/salary_utils.dart';

class AdminAddJobScreen extends StatefulWidget {
  const AdminAddJobScreen({Key? key}) : super(key: key);

  @override
  State<AdminAddJobScreen> createState() => _AdminAddJobScreenState();
}

class _AdminAddJobScreenState extends State<AdminAddJobScreen> {
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _salaryMinController = TextEditingController();
  final _salaryMaxController = TextEditingController();
  final _latController = TextEditingController();
  final _lngController = TextEditingController();
  
  String _category = 'İaşə';
  String _employmentType = 'Tam iş günü';
  String _salaryType = 'Aylıq';
  bool _isLoading = false;

  Future<void> _submitJob() async {
    if (_titleController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Xanaları tam doldurun')),
      );
      return;
    }

    final salaryError = validateSalaryInputs(
      _salaryMinController.text,
      _salaryMaxController.text,
      invalidMessage: 'Düzgün maaş daxil edin',
      orderMessage: 'Minimum maaş maksimum maaşdan böyük ola bilməz',
    );
    if (salaryError != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(salaryError)),
      );
      return;
    }
    final salary =
        salaryFromInputs(_salaryMinController.text, _salaryMaxController.text);

    setState(() => _isLoading = true);
    try {
      final lat = double.parse(_latController.text);
      final lng = double.parse(_lngController.text);

      await Supabase.instance.client.from('jobs').insert({
        'title': _titleController.text.trim(),
        'description': _descriptionController.text.trim(),
        'category': _category,
        'employment_type': _employmentType,
        ...salaryPayload(salary),
        'salary_type': _salaryType,
        'location': 'POINT($lng $lat)',
        'is_active': true,
        'user_id': Supabase.instance.client.auth.currentUser?.id,
      });

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Yeni elan uğurla əlavə olundu!')),
      );
      _titleController.clear();
      _salaryMinController.clear();
      _salaryMaxController.clear();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Xəta: $e')),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _salaryMinController.dispose();
    _salaryMaxController.dispose();
    _latController.dispose();
    _lngController.dispose();
    super.dispose();
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
            TextField(
              controller: _descriptionController,
              maxLines: 4,
              keyboardType: TextInputType.multiline,
              decoration: const InputDecoration(labelText: 'Description / Job Details', alignLabelWithHint: true),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _salaryMinController,
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    maxLength: 6,
                    decoration: const InputDecoration(labelText: 'Minimum maaş (AZN)', counterText: ''),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    controller: _salaryMaxController,
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    maxLength: 6,
                    decoration: const InputDecoration(labelText: 'Maksimum maaş (AZN)', counterText: ''),
                  ),
                ),
              ],
            ),
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
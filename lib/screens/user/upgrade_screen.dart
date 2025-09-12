import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../../logic/user.dart';

class UpgradeScreen extends StatefulWidget {
  const UpgradeScreen({super.key});

  @override
  State<UpgradeScreen> createState() => _UpgradeScreenState();
}

class _UpgradeScreenState extends State<UpgradeScreen> {
  final _departmentController = TextEditingController();
  final _enrollmentController = TextEditingController();
  String _collegeIdProofUrl = '';
  bool _isLoading = false;

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.gallery);
    if (pickedFile != null) {
      final bytes = await pickedFile.readAsBytes();
      setState(() => _collegeIdProofUrl = base64Encode(bytes));
    }
  }

  Future<void> _submitUpgrade() async {
    if (_isLoading) return;
    setState(() => _isLoading = true);
    try {
      await UserLogic.upgradeIfNeeded(
        _departmentController.text,
        _enrollmentController.text,
        _collegeIdProofUrl,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Upgrade request submitted')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Upgrade to Participant')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            TextField(
              controller: _departmentController,
              decoration: const InputDecoration(labelText: 'Department'),
            ),
            TextField(
              controller: _enrollmentController,
              decoration: const InputDecoration(labelText: 'Enrollment Number'),
            ),
            ElevatedButton(
              onPressed: _pickImage,
              child: const Text('Upload College ID Proof'),
            ),
            if (_collegeIdProofUrl.isNotEmpty)
              const Text('ID Proof Uploaded'),
            ElevatedButton(
              onPressed: _submitUpgrade,
              child: _isLoading ? const CircularProgressIndicator() : const Text('Submit'),
            ),
          ],
        ),
      ),
    );
  }
}
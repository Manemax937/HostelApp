import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:hostelapp/services/complaint_service.dart';
import 'package:hostelapp/services/auth_service.dart';
import 'package:hostelapp/models/complaint_model.dart';
// reusing built-in widgets; custom widget imports removed

class HousekeeperSupportScreen extends StatefulWidget {
  const HousekeeperSupportScreen({super.key});

  @override
  State<HousekeeperSupportScreen> createState() => _HousekeeperSupportScreenState();
}

class _HousekeeperSupportScreenState extends State<HousekeeperSupportScreen> {
  final _formKey = GlobalKey<FormState>();
  ComplaintCategory _category = ComplaintCategory.other;
  final _descController = TextEditingController();
  bool _isSubmitting = false;

  @override
  void dispose() {
    _descController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthService>(context);
    final user = auth.currentUserModel;
    final complaintService = Provider.of<ComplaintService>(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Support / Facility')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Form(
              key: _formKey,
              child: Column(
                children: [
                  DropdownButtonFormField<ComplaintCategory>(
                    value: _category,
                    items: ComplaintCategory.values.map((c) {
                      return DropdownMenuItem(
                        value: c,
                        child: Text(c.toString().split('.').last),
                      );
                    }).toList(),
                    onChanged: (v) => setState(() => _category = v ?? ComplaintCategory.other),
                    decoration: const InputDecoration(labelText: 'Category'),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _descController,
                    maxLines: 5,
                    validator: (v) => (v == null || v.trim().isEmpty) ? 'Please enter a description' : null,
                    decoration: const InputDecoration(
                      labelText: 'Description',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _isSubmitting ? null : () async {
                        if (!_formKey.currentState!.validate()) return;
                        if (user == null) return;

                        setState(() => _isSubmitting = true);
                        try {
                          await complaintService.submitComplaint(
                            userId: user.uid,
                            userName: user.fullName,
                            roomNo: user.roomNo ?? 'N/A',
                            residenceName: user.residenceName ?? '',
                            category: _category,
                            description: _descController.text.trim(),
                          );

                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Report submitted')),
                            );
                            Navigator.pop(context);
                          }
                        } catch (e) {
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('Error: $e')),
                            );
                          }
                        } finally {
                          if (mounted) setState(() => _isSubmitting = false);
                        }
                      },
                      child: _isSubmitting ? const CircularProgressIndicator() : const Text('SUBMIT REPORT'),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import '../services/admin_api_service.dart';

class AdminVersionSettingsScreen extends StatefulWidget {
  const AdminVersionSettingsScreen({super.key});

  @override
  State<AdminVersionSettingsScreen> createState() => _AdminVersionSettingsScreenState();
}

class _AdminVersionSettingsScreenState extends State<AdminVersionSettingsScreen> {
  final _formKey = GlobalKey<FormState>();
  final _codeController = TextEditingController();
  final _nameController = TextEditingController();
  final _urlController = TextEditingController();
  bool _isLoading = false;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    setState(() => _isLoading = true);
    try {
      final data = await const AdminApiService().fetchVersionSettings();
      _codeController.text = (data['version_code'] ?? '').toString();
      _nameController.text = (data['version_name'] ?? '').toString();
      _urlController.text = (data['download_url'] ?? '').toString();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error loading settings: $e')),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _saveSettings() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);
    try {
      await const AdminApiService().updateRequiredVersion(
        versionCode: int.parse(_codeController.text.trim()),
        versionName: _nameController.text.trim(),
        downloadUrl: _urlController.text.trim(),
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Version settings updated successfully')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error saving settings: $e')),
      );
    } finally {
      setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('App Version Management'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: Theme.of(context).textTheme.titleLarge?.color,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Mandatory Update Settings',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.5,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Setting a version higher than the current app version will force all users to update before they can use the app.',
                      style: TextStyle(
                        color: Theme.of(context).textTheme.bodySmall?.color,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 32),
                    TextFormField(
                      controller: _codeController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Required Version Code',
                        hintText: 'e.g. 2',
                        prefixIcon: Icon(Icons.code_rounded),
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) return 'Enter version code';
                        if (int.tryParse(value) == null) return 'Must be an integer';
                        return null;
                      },
                    ),
                    const SizedBox(height: 20),
                    TextFormField(
                      controller: _nameController,
                      decoration: const InputDecoration(
                        labelText: 'Display Version Name',
                        hintText: 'e.g. 1.0.1',
                        prefixIcon: Icon(Icons.label_outline_rounded),
                      ),
                      validator: (value) =>
                          value == null || value.isEmpty ? 'Enter version name' : null,
                    ),
                    const SizedBox(height: 20),
                    TextFormField(
                      controller: _urlController,
                      decoration: const InputDecoration(
                        labelText: 'Download URL',
                        hintText: 'e.g. https://catuc.cloud/download',
                        prefixIcon: Icon(Icons.link_rounded),
                      ),
                    ),
                    const SizedBox(height: 48),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton(
                        onPressed: _isSaving ? null : _saveSettings,
                        style: FilledButton.styleFrom(
                          backgroundColor: Theme.of(context).colorScheme.primary,
                          padding: const EdgeInsets.symmetric(vertical: 18),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                        child: Text(
                          _isSaving ? 'Saving...' : 'Save Settings',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}

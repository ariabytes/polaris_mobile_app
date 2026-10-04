import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../../../controllers/auth_controller.dart';

import 'package:polaris_mobile_app/services/theme_service.dart';
class AdminEditProfileView extends StatefulWidget {
  const AdminEditProfileView({super.key});

  @override
  State<AdminEditProfileView> createState() => _AdminEditProfileViewState();
}

class _AdminEditProfileViewState extends State<AdminEditProfileView> {
  Color get cream => context.pc.background;
  Color get navy => context.pc.ink;
  Color get orange => context.pc.accent;


  final _formKey = GlobalKey<FormState>();

  late final TextEditingController _nameController;
  late final TextEditingController _bioController;

  DateTime? _birthday;
  File? _pickedPhoto;

  @override
  void initState() {
    super.initState();
    final profile = context.read<AuthController>().currentUserProfile;

    _nameController = TextEditingController(text: profile?.name ?? '');
    _bioController = TextEditingController(text: profile?.bio ?? '');
    _birthday = profile?.birthday;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _bioController.dispose();
    super.dispose();
  }

  Future<void> _pickPhoto() async {
    final picked = await ImagePicker().pickImage(source: ImageSource.gallery, imageQuality: 85);
    if (picked == null) return;
    setState(() => _pickedPhoto = File(picked.path));
  }

  Future<void> _pickBirthday() async {
    final now = DateTime.now();
    final selected = await showDatePicker(
      context: context,
      initialDate: _birthday ?? DateTime(now.year - 18, now.month, now.day),
      firstDate: DateTime(1950),
      lastDate: now,
    );
    if (selected != null) {
      setState(() => _birthday = selected);
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    final authController = context.read<AuthController>();
    final profile = authController.currentUserProfile;
    final uid = profile?.userId;
    if (uid == null) return;

    // Photo upload is a separate write from the profile-fields update (same
    // pattern as MaterialController: create, then attach files). Do it
    // first so a failed upload doesn't leave the form thinking it saved.
    if (_pickedPhoto != null) {
      final photoOk = await authController.uploadProfilePhoto(
        uid,
        _pickedPhoto!,
        _pickedPhoto!.path.split('/').last,
      );
      if (!photoOk) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(authController.errorMessage ?? 'Could not upload photo.')),
        );
        return;
      }
    }

    // updateProfile() always writes every field it's given, including a
    // bare null, so university/college/program/yearLevel — which this
    // admin form doesn't expose — are passed back unchanged here rather
    // than omitted, to avoid silently clearing them.
    final success = await authController.updateProfile(
      name: _nameController.text.trim(),
      birthday: _birthday,
      university: profile?.university,
      college: profile?.college,
      program: profile?.program,
      yearLevel: profile?.yearLevel,
      bio: _bioController.text.trim(),
    );

    if (!mounted) return;

    if (success) {
      Navigator.of(context).pop();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(authController.errorMessage ?? 'Could not update profile.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final authController = context.watch<AuthController>();
    final profile = authController.currentUserProfile;
    final photoUrl = profile?.profilePhoto?['url'] as String?;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Edit Profile', style: TextStyle(fontWeight: FontWeight.bold)),
        actions: [
          IconButton(
            icon: authController.isLoading
                ? SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2, color: cream),
                  )
                : const Icon(Icons.check),
            onPressed: authController.isLoading ? null : _save,
          ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            Center(
              child: GestureDetector(
                onTap: _pickPhoto,
                child: Stack(
                  children: [
                    CircleAvatar(
                      radius: 48,
                      backgroundColor: navy.withOpacity(0.1),
                      backgroundImage: _pickedPhoto != null
                          ? FileImage(_pickedPhoto!) as ImageProvider
                          : (photoUrl != null ? NetworkImage(photoUrl) as ImageProvider : null),
                      child: _pickedPhoto == null && photoUrl == null
                          ? Text(
                              (profile?.name.isNotEmpty ?? false)
                                  ? profile!.name[0].toUpperCase()
                                  : '?',
                              style: const TextStyle(fontSize: 32),
                            )
                          : null,
                    ),
                    Positioned(
                      right: 0,
                      bottom: 0,
                      child: CircleAvatar(
                        radius: 16,
                        backgroundColor: orange,
                        child: Icon(Icons.edit, size: 16, color: cream),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
            TextFormField(
              controller: _nameController,
              decoration: const InputDecoration(labelText: 'Name'),
              validator: (value) =>
                  (value == null || value.trim().isEmpty) ? 'Name is required' : null,
            ),
            const SizedBox(height: 16),
            InkWell(
              onTap: _pickBirthday,
              child: InputDecorator(
                decoration: const InputDecoration(labelText: 'Birthday'),
                child: Text(
                  _birthday != null
                      ? '${_birthday!.month}/${_birthday!.day}/${_birthday!.year}'
                      : 'Not set',
                ),
              ),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _bioController,
              decoration: const InputDecoration(labelText: 'Bio'),
              maxLines: 3,
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';

import '/controllers/auth_controller.dart';

class EditProfileView extends StatefulWidget {
  const EditProfileView({super.key});

  @override
  State<EditProfileView> createState() =>
      _EditProfileViewState();
}

class _EditProfileViewState extends State<EditProfileView> {
  static const Color cream = Color(0xFFFCF6F0);
  static const Color navy = Color(0xFF252A5A);
  static const Color purple = Color(0xFF7B5EA7);
  static const Color gold = Color(0xFFE8B94A);

  static const List<String> _yearLevels = [
    '1st Year',
    '2nd Year',
    '3rd Year',
    '4th Year',
    '5th Year',
  ];

  late final TextEditingController _nameController;
  late final TextEditingController _universityController;
  late final TextEditingController _collegeController;
  late final TextEditingController _programController;
  late final TextEditingController _bioController;

  String? _selectedYearLevel;
  DateTime? _selectedBirthday;

  File? _pickedPhoto;

  bool _uploadingPhoto = false;

  @override
  void initState() {
    super.initState();

    final profile =
        context.read<AuthController>().currentUserProfile;

    _nameController = TextEditingController(
      text: profile?.name ?? '',
    );

    _universityController = TextEditingController(
      text: profile?.university ?? '',
    );

    _collegeController = TextEditingController(
      text: profile?.college ?? '',
    );

    _programController = TextEditingController(
      text: profile?.program ?? '',
    );

    _bioController = TextEditingController(
      text: profile?.bio ?? '',
    );

    _selectedYearLevel = profile?.yearLevel;
    _selectedBirthday = profile?.birthday;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _universityController.dispose();
    _collegeController.dispose();
    _programController.dispose();
    _bioController.dispose();

    super.dispose();
  }

  // ============================================================
  // BIRTHDAY
  // ============================================================

  Future<void> _pickBirthday() async {
    final now = DateTime.now();

    final picked = await showDatePicker(
      context: context,
      initialDate:
          _selectedBirthday ?? DateTime(now.year - 18),
      firstDate: DateTime(1950),
      lastDate: now,
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: navy,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null && mounted) {
      setState(() {
        _selectedBirthday = picked;
      });
    }
  }

  // ============================================================
  // PROFILE PHOTO
  // ============================================================

  Future<void> _pickAndUploadPhoto() async {
    if (_uploadingPhoto) {
      return;
    }

    final auth = context.read<AuthController>();

    final uid = auth.currentUserProfile?.userId;

    if (uid == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'No logged-in user found.',
          ),
        ),
      );

      return;
    }

    final picker = ImagePicker();

    final picked = await picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 80,
    );

    if (picked == null) {
      return;
    }

    final file = File(picked.path);

    if (!await file.exists()) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'The selected image could not be found.',
          ),
        ),
      );

      return;
    }

    setState(() {
      _pickedPhoto = file;
      _uploadingPhoto = true;
    });

    try {
      final success = await auth.uploadProfilePhoto(
        uid,
        file,
        picked.name,
      );

      if (!mounted) return;

      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Profile photo updated!',
            ),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              auth.errorMessage ??
                  'Could not upload profile photo.',
            ),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _uploadingPhoto = false;
        });
      }
    }
  }

  // ============================================================
  // SAVE PROFILE
  // ============================================================

  Future<void> _save() async {
    final auth = context.read<AuthController>();

    final success = await auth.updateProfile(
      name: _nameController.text.trim(),
      birthday: _selectedBirthday,
      university: _universityController.text.trim(),
      college: _collegeController.text.trim(),
      program: _programController.text.trim(),
      yearLevel: _selectedYearLevel,
      bio: _bioController.text.trim(),
    );

    if (!mounted) return;

    if (success) {
      Navigator.of(context).pop();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            auth.errorMessage ??
                'Could not save your profile.',
          ),
        ),
      );
    }
  }

  // ============================================================
  // BUILD
  // ============================================================

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthController>();

    final currentPhotoUrl =
        auth.currentUserProfile?.profilePhoto?['url']
            as String?;

    return Scaffold(
      backgroundColor: cream,

      appBar: AppBar(
        backgroundColor: navy,
        foregroundColor: Colors.white,
        title: const Text(
          'Edit Profile',
          style: TextStyle(
            fontWeight: FontWeight.bold,
          ),
        ),
      ),

      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          // ======================================================
          // PROFILE PHOTO
          // ======================================================

          Center(
            child: GestureDetector(
              onTap: _uploadingPhoto
                  ? null
                  : _pickAndUploadPhoto,
              child: Stack(
                alignment: Alignment.bottomRight,
                children: [
                  CircleAvatar(
                    radius: 54,
                    backgroundColor:
                        purple.withOpacity(0.2),

                    backgroundImage:
                        _pickedPhoto != null
                            ? FileImage(_pickedPhoto!)
                            : currentPhotoUrl != null
                                ? NetworkImage(
                                    currentPhotoUrl,
                                  )
                                : null,

                    child:
                        _pickedPhoto == null &&
                                currentPhotoUrl == null
                            ? const Icon(
                                Icons.person,
                                size: 54,
                                color: navy,
                              )
                            : null,
                  ),

                  if (_uploadingPhoto)
                    const Positioned.fill(
                      child: Center(
                        child: CircularProgressIndicator(
                          color: navy,
                        ),
                      ),
                    )
                  else
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration:
                          const BoxDecoration(
                        color: navy,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.camera_alt,
                        size: 16,
                        color: Colors.white,
                      ),
                    ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 28),

          // ======================================================
          // NAME
          // ======================================================

          const _FieldLabel('Name'),

          TextField(
            controller: _nameController,
            decoration: _inputDecoration(),
          ),

          const SizedBox(height: 18),

          // ======================================================
          // BIRTHDAY
          // ======================================================

          const _FieldLabel('Birthday'),

          InkWell(
            onTap: _pickBirthday,
            child: InputDecorator(
              decoration: _inputDecoration(),
              child: Text(
                _selectedBirthday != null
                    ? '${_selectedBirthday!.month}/${_selectedBirthday!.day}/${_selectedBirthday!.year}'
                    : 'Select your birthday',
                style: TextStyle(
                  color: _selectedBirthday != null
                      ? Colors.black87
                      : Colors.black38,
                ),
              ),
            ),
          ),

          const SizedBox(height: 18),

          // ======================================================
          // UNIVERSITY
          // ======================================================

          const _FieldLabel('University'),

          TextField(
            controller: _universityController,
            decoration: _inputDecoration(
              hint: 'e.g. University of Mindanao',
            ),
          ),

          const SizedBox(height: 18),

          // ======================================================
          // COLLEGE
          // ======================================================

          const _FieldLabel('Department / College'),

          TextField(
            controller: _collegeController,
            decoration: _inputDecoration(
              hint: 'e.g. College of Computing Education',
            ),
          ),

          const SizedBox(height: 18),

          // ======================================================
          // COURSE
          // ======================================================

          const _FieldLabel('Program'),

          TextField(
            controller: _programController,
            decoration: _inputDecoration(
              hint: 'e.g. BS Information Technology',
            ),
          ),

          const SizedBox(height: 18),

          // ======================================================
          // YEAR LEVEL
          // ======================================================

          const _FieldLabel('Year Level'),

          DropdownButtonFormField<String>(
            initialValue: _selectedYearLevel,
            decoration: _inputDecoration(),
            hint: const Text('Select year level'),
            items: _yearLevels
                .map(
                  (year) => DropdownMenuItem(
                    value: year,
                    child: Text(year),
                  ),
                )
                .toList(),
            onChanged: (value) {
              setState(() {
                _selectedYearLevel = value;
              });
            },
          ),

          const SizedBox(height: 18),

          // ======================================================
          // BIO
          // ======================================================

          const _FieldLabel('Bio'),

          TextField(
            controller: _bioController,
            maxLength: 150,
            maxLines: 3,
            decoration: _inputDecoration(
              hint: 'A short, cute intro about yourself',
            ),
          ),

          const SizedBox(height: 12),

          // ======================================================
          // SAVE
          // ======================================================

          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton(
              onPressed:
                  auth.isLoading || _uploadingPhoto
                      ? null
                      : _save,
              style: ElevatedButton.styleFrom(
                backgroundColor: navy,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius:
                      BorderRadius.circular(14),
                ),
              ),
              child: auth.isLoading
                  ? const SizedBox(
                      height: 22,
                      width: 22,
                      child:
                          CircularProgressIndicator(
                        strokeWidth: 2.5,
                        color: Colors.white,
                      ),
                    )
                  : const Text(
                      'Save Changes',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // INPUT DECORATION
  // ============================================================

  InputDecoration _inputDecoration({
    String? hint,
  }) {
    return InputDecoration(
      hintText: hint,
      filled: true,
      fillColor: Colors.white,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      contentPadding:
          const EdgeInsets.symmetric(
        horizontal: 14,
        vertical: 14,
      ),
    );
  }
}

// ================================================================
// FIELD LABEL
// ================================================================

class _FieldLabel extends StatelessWidget {
  const _FieldLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Text(
        text,
        style: const TextStyle(
          fontWeight: FontWeight.w600,
          fontSize: 13,
          color: Colors.black54,
        ),
      ),
    );
  }
}
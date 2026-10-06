import 'dart:io';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';

import '/controllers/auth_controller.dart';
import '/controllers/material_controller.dart';

import 'package:polaris_mobile_app/services/theme_service.dart';
import 'package:polaris_mobile_app/views/widgets/suggest_field.dart';

class EditProfileView extends StatefulWidget {
  const EditProfileView({super.key});

  @override
  State<EditProfileView> createState() =>
      _EditProfileViewState();
}

class _EditProfileViewState extends State<EditProfileView> {
  Color get cream => context.pc.background;
  Color get navy => context.pc.ink;
  Color get purple => context.pc.accent;
  Color get mutedColor => context.pc.muted;


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

  final FocusNode _universityFocus = FocusNode();
  final FocusNode _collegeFocus = FocusNode();
  final FocusNode _programFocus = FocusNode();

  // university -> college -> programs, learned from public materials
  Map<String, Map<String, List<String>>> _suggestions = {};

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

    _loadSuggestions();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _universityController.dispose();
    _collegeController.dispose();
    _programController.dispose();
    _bioController.dispose();
    _universityFocus.dispose();
    _collegeFocus.dispose();
    _programFocus.dispose();

    super.dispose();
  }

  // SUGGESTIONS (university -> college -> program)
  Future<void> _loadSuggestions() async {
    final data =
        await context.read<MaterialController>().academicSuggestions();

    if (!mounted) return;
    setState(() => _suggestions = data);
  }

  List<String> _filter(Iterable<String> pool, String text) {
    final query = text.trim().toLowerCase();

    final matches = pool.toSet().where((option) {
      final lower = option.toLowerCase();
      return lower != query && (query.isEmpty || lower.contains(query));
    }).toList()
      ..sort();

    return matches.take(8).toList();
  }

  /// Colleges of the university typed so far, or null if it isn't known.
  Map<String, List<String>>? _collegesOf(String university) {
    final key = university.trim().toLowerCase();

    for (final entry in _suggestions.entries) {
      if (entry.key.toLowerCase() == key) return entry.value;
    }
    return null;
  }

  List<String> _universityOptions(String text) =>
      _filter(_suggestions.keys, text);

  // Narrowed to the chosen university; if it's unknown, suggest from all.
  List<String> _collegeOptions(String text) {
    final colleges = _collegesOf(_universityController.text);
    final Iterable<String> pool =
        colleges?.keys ?? _suggestions.values.expand((c) => c.keys);

    return _filter(pool, text);
  }

  // Narrowed to the chosen college (and university) when they're known.
  List<String> _programOptions(String text) {
    final colleges = _collegesOf(_universityController.text);
    final collegeKey = _collegeController.text.trim().toLowerCase();

    final Iterable<String> pool;
    if (colleges != null) {
      final matched = colleges.entries
          .where((e) => e.key.toLowerCase() == collegeKey)
          .toList();

      pool = matched.isNotEmpty
          ? matched.first.value
          : colleges.values.expand((p) => p);
    } else {
      pool = _suggestions.values
          .expand((c) => c.values)
          .expand((p) => p);
    }

    return _filter(pool, text);
  }

  // BIRTHDAY
  Future<void> _pickBirthday() async {
    final now = DateTime.now();

    final picked = await showDatePicker(
      context: context,
      initialDate:
          _selectedBirthday ?? DateTime(now.year - 18),
      firstDate: DateTime(1950),
      lastDate: now,
      );

    if (picked != null && mounted) {
      setState(() {
        _selectedBirthday = picked;
      });
    }
  }

  // PROFILE PHOTO
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

  // SAVE PROFILE
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

  // BUILD
  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthController>();

    final currentPhotoUrl =
        auth.currentUserProfile?.profilePhoto?['url']
            as String?;

    return Scaffold(
      appBar: AppBar(
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
                            ? Icon(
                                Icons.person,
                                size: 54,
                                color: navy,
                              )
                            : null,
                  ),

                  if (_uploadingPhoto)
                    Positioned.fill(
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
                          BoxDecoration(
                        color: navy,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.camera_alt,
                        size: 16,
                        color: cream,
                      ),
                    ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 28),

          // NAME
          const _FieldLabel('Name'),

          TextField(
            controller: _nameController,
            decoration: _inputDecoration(),
          ),

          const SizedBox(height: 18),

          // BIRTHDAY
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
                      ? navy
                      : mutedColor,
                ),
              ),
            ),
          ),

          const SizedBox(height: 18),

          // UNIVERSITY
          const _FieldLabel('University'),

          SuggestField(
            controller: _universityController,
            focusNode: _universityFocus,
            optionsFor: _universityOptions,
            decoration: _inputDecoration(
              hint: 'e.g. University of Mindanao',
            ),
          ),

          const SizedBox(height: 18),

          // COLLEGE
          const _FieldLabel('Department / College'),

          SuggestField(
            controller: _collegeController,
            focusNode: _collegeFocus,
            optionsFor: _collegeOptions,
            decoration: _inputDecoration(
              hint: 'e.g. College of Computing Education',
            ),
          ),

          const SizedBox(height: 18),

          // COURSE
          const _FieldLabel('Program'),

          SuggestField(
            controller: _programController,
            focusNode: _programFocus,
            optionsFor: _programOptions,
            decoration: _inputDecoration(
              hint: 'e.g. BS Information Technology',
            ),
          ),

          const SizedBox(height: 18),

          // YEAR LEVEL
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

          // BIO
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

          // SAVE
          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton(
              onPressed:
                  auth.isLoading || _uploadingPhoto
                      ? null
                      : _save,
              child: auth.isLoading
                  ? SizedBox(
                      height: 22,
                      width: 22,
                      child:
                          CircularProgressIndicator(
                        strokeWidth: 2.5,
                        color: cream,
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

  // INPUT DECORATION
  InputDecoration _inputDecoration({
    String? hint,
  }) {
    return InputDecoration(
      hintText: hint,
      contentPadding:
          const EdgeInsets.symmetric(
        horizontal: 14,
        vertical: 14,
      ),
    );
  }
}

// FIELD LABEL
class _FieldLabel extends StatelessWidget {
  const _FieldLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    final _pc = context.pc;
    final mutedColor = _pc.muted;

    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Text(
        text,
        style: TextStyle(
          fontWeight: FontWeight.w600,
          fontSize: 13,
          color: mutedColor,
        ),
      ),
    );
  }
}
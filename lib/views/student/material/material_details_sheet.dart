import 'package:flutter/material.dart';
import '/models/material_model.dart';

class MaterialDetailsSheet extends StatefulWidget {
  const MaterialDetailsSheet({
    super.key,
    this.initialUniversity,
    this.initialCollege,
    this.initialProgram,
    this.existingMaterial,
  });

  // Used by CREATE mode
  final String? initialUniversity;
  final String? initialCollege;
  final String? initialProgram;

  // Used by EDIT DETAILS mode
  final MaterialModel? existingMaterial;

  bool get isEditing => existingMaterial != null;

  @override
  State<MaterialDetailsSheet> createState() => _MaterialDetailsSheetState();
}

class _MaterialDetailsSheetState extends State<MaterialDetailsSheet> {
  static const Color cream = Color(0xFFFCF6F0);
  static const Color navy = Color(0xFF252A5A);

  late final TextEditingController _universityController;
  late final TextEditingController _collegeController;
  late final TextEditingController _programController;
  late final TextEditingController _courseController;
  late final TextEditingController _schoolYearController;
  late final TextEditingController _professorController;
  late final TextEditingController _priceController;

  String? _semester;
  String _visibility = 'private';

  static const List<String> _semesters = [
    '1st Semester',
    '2nd Semester',
    'Summer',
  ];

  @override
  void initState() {
    super.initState();

    final material = widget.existingMaterial;

    if (material != null) {
      // EDIT MODE
      _universityController =
          TextEditingController(text: material.university);

      _collegeController =
          TextEditingController(text: material.college);

      _programController =
          TextEditingController(text: material.program);

      _courseController =
          TextEditingController(text: material.course);

      _schoolYearController =
          TextEditingController(text: material.schoolYear);

      _professorController =
          TextEditingController(text: material.professor ?? '');

      _priceController = TextEditingController(
        text: material.price?.toStringAsFixed(2) ?? '',
      );

      _semester = material.semester;
      _visibility = material.visibility;
    } else {
      // CREATE MODE
      _universityController =
          TextEditingController(text: widget.initialUniversity ?? '');

      _collegeController =
          TextEditingController(text: widget.initialCollege ?? '');

      _programController =
          TextEditingController(text: widget.initialProgram ?? '');

      _courseController = TextEditingController();
      _schoolYearController = TextEditingController();
      _professorController = TextEditingController();
      _priceController = TextEditingController();
    }
  }

  @override
  void dispose() {
    _universityController.dispose();
    _collegeController.dispose();
    _programController.dispose();
    _courseController.dispose();
    _schoolYearController.dispose();
    _professorController.dispose();
    _priceController.dispose();

    super.dispose();
  }

  void _confirm() {
    if (_universityController.text.trim().isEmpty ||
        _collegeController.text.trim().isEmpty ||
        _programController.text.trim().isEmpty ||
        _courseController.text.trim().isEmpty ||
        _semester == null ||
        _schoolYearController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please fill in all required fields.'),
        ),
      );
      return;
    }

    if (_visibility == 'public_paid' &&
        _priceController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please set a price for a paid material.'),
        ),
      );
      return;
    }

    Navigator.of(context).pop({
      'university': _universityController.text.trim(),
      'college': _collegeController.text.trim(),
      'program': _programController.text.trim(),
      'course': _courseController.text.trim(),
      'semester': _semester!,
      'schoolYear': _schoolYearController.text.trim(),
      'professor': _professorController.text.trim(),

      // These are important for EDIT DETAILS.
      'visibility': _visibility,
      'price': _priceController.text.trim(),
    });
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Container(
        decoration: const BoxDecoration(
          color: cream,
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(24),
          ),
        ),
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: navy.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ),

              Text(
                widget.isEditing
                    ? 'Edit Material Details'
                    : 'Just a few more details',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: navy,
                ),
              ),

              const SizedBox(height: 4),

              Text(
                widget.isEditing
                    ? 'Update the information used to organize and find this material.'
                    : 'This helps other students find this material.',
                style: const TextStyle(
                  color: Colors.black54,
                  fontSize: 13,
                ),
              ),

              const SizedBox(height: 18),

              TextField(
                controller: _universityController,
                decoration: _decoration('University'),
              ),

              const SizedBox(height: 12),

              TextField(
                controller: _collegeController,
                decoration: _decoration('Department / College'),
              ),

              const SizedBox(height: 12),

              TextField(
                controller: _programController,
                decoration: _decoration(
                  'Program (e.g. BS Information Technology)',
                ),
              ),

              const SizedBox(height: 12),

              TextField(
                controller: _courseController,
                decoration: _decoration(
                  'Course / Subject (e.g. Data Structures and Algorithms)',
                ),
              ),

              const SizedBox(height: 12),

              DropdownButtonFormField<String>(
                initialValue: _semester,
                decoration: _decoration('Semester'),
                items: _semesters
                    .map(
                      (s) => DropdownMenuItem(
                        value: s,
                        child: Text(s),
                      ),
                    )
                    .toList(),
                onChanged: (value) {
                  setState(() {
                    _semester = value;
                  });
                },
              ),

              const SizedBox(height: 12),

              TextField(
                controller: _schoolYearController,
                decoration: _decoration(
                  'School Year (e.g. 2025-2026)',
                ),
              ),

              const SizedBox(height: 12),

              TextField(
                controller: _professorController,
                decoration: _decoration(
                  'Professor (optional)',
                ),
              ),

              const SizedBox(height: 18),

              const Text(
                'Visibility',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: Colors.black54,
                  fontSize: 13,
                ),
              ),

              const SizedBox(height: 8),

              _VisibilityChips(
                value: _visibility,
                onChanged: (value) {
                  setState(() {
                    _visibility = value;

                    // Clear price when material is no longer paid.
                    if (value != 'public_paid') {
                      _priceController.clear();
                    }
                  });
                },
              ),

              if (_visibility == 'public_paid') ...[
                const SizedBox(height: 12),

                TextField(
                  controller: _priceController,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: InputDecoration(
                    prefixText: '₱ ',
                    labelText: 'Price',
                    filled: true,
                    fillColor: Colors.white,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ],

              const SizedBox(height: 20),

              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  onPressed: _confirm,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: navy,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: Text(
                    widget.isEditing
                        ? 'Save Details'
                        : 'Confirm & Save',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
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

  InputDecoration _decoration(String label) {
    return InputDecoration(
      labelText: label,
      filled: true,
      fillColor: Colors.white,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      contentPadding: const EdgeInsets.symmetric(
        horizontal: 14,
        vertical: 12,
      ),
    );
  }
}

class _VisibilityChips extends StatelessWidget {
  const _VisibilityChips({
    required this.value,
    required this.onChanged,
  });

  final String value;
  final ValueChanged<String> onChanged;

  static const Color navy = Color(0xFF252A5A);

  @override
  Widget build(BuildContext context) {
    const options = {
      'private': 'Private',
      'public_free': 'Public (Free)',
      'public_paid': 'Public (Paid)',
    };

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: options.entries.map((entry) {
        final selected = value == entry.key;

        return ChoiceChip(
          label: Text(entry.value),
          selected: selected,
          onSelected: (_) => onChanged(entry.key),
          selectedColor: navy,
          labelStyle: TextStyle(
            color: selected ? Colors.white : navy,
          ),
          backgroundColor: Colors.white,
          side: BorderSide(
            color: navy.withOpacity(0.4),
          ),
        );
      }).toList(),
    );
  }
}
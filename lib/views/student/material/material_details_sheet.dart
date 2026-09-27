import 'package:flutter/material.dart';

/// Asks for whatever academic details aren't already known — pre-fill
/// university/college/course from the caller if the student's profile
/// has them; semester and school year are always asked since they aren't
/// stored on the profile. Used by both CreateMaterialView (the full
/// editor) and MyMaterialsView (the quick file-upload FAB).
class MaterialDetailsSheet extends StatefulWidget {
  const MaterialDetailsSheet({
    super.key,
    this.initialUniversity,
    this.initialCollege,
    this.initialCourse,
  });

  final String? initialUniversity;
  final String? initialCollege;
  final String? initialCourse;

  @override
  State<MaterialDetailsSheet> createState() => _MaterialDetailsSheetState();
}

class _MaterialDetailsSheetState extends State<MaterialDetailsSheet> {
  static const Color cream = Color(0xFFFCF6F0);
  static const Color navy = Color(0xFF252A5A);

  late final TextEditingController _universityController;
  late final TextEditingController _collegeController;
  late final TextEditingController _courseController;
  final TextEditingController _schoolYearController = TextEditingController();
  final TextEditingController _professorController = TextEditingController();

  String? _semester;

  static const List<String> _semesters = ['1st Semester', '2nd Semester', 'Summer'];

  @override
  void initState() {
    super.initState();
    _universityController = TextEditingController(text: widget.initialUniversity ?? '');
    _collegeController = TextEditingController(text: widget.initialCollege ?? '');
    _courseController = TextEditingController(text: widget.initialCourse ?? '');
  }

  @override
  void dispose() {
    _universityController.dispose();
    _collegeController.dispose();
    _courseController.dispose();
    _schoolYearController.dispose();
    _professorController.dispose();
    super.dispose();
  }

  void _confirm() {
    if (_universityController.text.trim().isEmpty ||
        _collegeController.text.trim().isEmpty ||
        _courseController.text.trim().isEmpty ||
        _semester == null ||
        _schoolYearController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please fill in all required fields.')),
      );
      return;
    }

    Navigator.of(context).pop({
      'university': _universityController.text.trim(),
      'college': _collegeController.text.trim(),
      'course': _courseController.text.trim(),
      'semester': _semester!,
      'schoolYear': _schoolYearController.text.trim(),
      'professor': _professorController.text.trim(),
    });
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        decoration: const BoxDecoration(
          color: cream,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
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
              const Text(
                'Just a few more details',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: navy),
              ),
              const SizedBox(height: 4),
              const Text(
                'This helps other students find this material.',
                style: TextStyle(color: Colors.black54, fontSize: 13),
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
                controller: _courseController,
                decoration: _decoration('Program / Course'),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: _semester,
                decoration: _decoration('Semester'),
                items: _semesters
                    .map((s) => DropdownMenuItem(value: s, child: Text(s)))
                    .toList(),
                onChanged: (v) => setState(() => _semester = v),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _schoolYearController,
                decoration: _decoration('School Year (e.g. 2025-2026)'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _professorController,
                decoration: _decoration('Professor (optional)'),
              ),

              const SizedBox(height: 20),

              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  onPressed: _confirm,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: navy,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: const Text('Confirm & Save', style: TextStyle(fontWeight: FontWeight.bold)),
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
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
    );
  }
}
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '/controllers/material_controller.dart';
import '/models/material_model.dart';
import '/services/transaction_service.dart';

import 'package:polaris_mobile_app/services/theme_service.dart';
import 'package:polaris_mobile_app/views/widgets/suggest_field.dart';

class MaterialDetailsSheet extends StatefulWidget {
  const MaterialDetailsSheet({
    super.key,
    this.initialUniversity,
    this.initialCollege,
    this.initialProgram,
    this.existingMaterial,
  });

  final String? initialUniversity;
  final String? initialCollege;
  final String? initialProgram;

  final MaterialModel? existingMaterial;

  bool get isEditing => existingMaterial != null;

  @override
  State<MaterialDetailsSheet> createState() => _MaterialDetailsSheetState();
}

class _MaterialDetailsSheetState extends State<MaterialDetailsSheet> {
  Color get navy => context.pc.ink;
  Color get cardColor => context.pc.card;
  Color get mutedColor => context.pc.muted;

  late final TextEditingController _universityController;
  late final TextEditingController _collegeController;
  late final TextEditingController _programController;
  late final TextEditingController _courseController;
  late final TextEditingController _schoolYearController;
  late final TextEditingController _professorController;
  late final TextEditingController _priceController;

  final FocusNode _universityFocus = FocusNode();
  final FocusNode _courseFocus = FocusNode();
  final FocusNode _professorFocus = FocusNode();

  String? _semester;
  String _visibility = 'private';

  // course name give professors who have taught/used it at this university
  Map<String, List<String>> _suggestions = {};
  String? _loadedUniversity;

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
      _universityController =
          TextEditingController(text: material.university);
      _collegeController = TextEditingController(text: material.college);
      _programController = TextEditingController(text: material.program);
      _courseController = TextEditingController(text: material.course);
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

    _universityFocus.addListener(() {
      if (!_universityFocus.hasFocus) _loadSuggestions();
    });

    _loadSuggestions();
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
    _universityFocus.dispose();
    _courseFocus.dispose();
    _professorFocus.dispose();
    super.dispose();
  }

  Future<void> _loadSuggestions() async {
    final university = _universityController.text.trim();
    if (university.isEmpty || university == _loadedUniversity) return;

    _loadedUniversity = university;

    final data =
        await context.read<MaterialController>().courseSuggestions(university);

    if (!mounted) return;
    setState(() => _suggestions = data);
  }

  List<String> _courseOptions(String text) {
    final query = text.trim().toLowerCase();

    final matches = _suggestions.keys.where((course) {
      final lower = course.toLowerCase();
      return lower != query && (query.isEmpty || lower.contains(query));
    }).toList()
      ..sort();

    return matches.take(8).toList();
  }

  List<String> _professorOptions(String text) {
    final query = text.trim().toLowerCase();
    final course = _courseController.text.trim().toLowerCase();

    final matchedCourse = _suggestions.keys.where(
      (c) => c.toLowerCase() == course,
    );

    final pool = matchedCourse.isNotEmpty
        ? _suggestions[matchedCourse.first]!
        : _suggestions.values.expand((p) => p).toSet().toList();

    final matches = pool.where((prof) {
      final lower = prof.toLowerCase();
      return lower != query && (query.isEmpty || lower.contains(query));
    }).toList()
      ..sort();

    return matches.take(8).toList();
  }

  Future<void> _pickSchoolYear() async {
    FocusScope.of(context).unfocus();

    final now = DateTime.now();
    final currentStart =
        int.tryParse(_schoolYearController.text.split('-').first) ?? now.year;

    final picked = await showDialog<int>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('School year starts'),
        content: SizedBox(
          width: 300,
          height: 300,
          child: YearPicker(
            firstDate: DateTime(now.year - 10),
            lastDate: DateTime(now.year + 1),
            selectedDate: DateTime(currentStart),
            onChanged: (date) => Navigator.of(dialogContext).pop(date.year),
          ),
        ),
      ),
    );

    if (picked == null) return;
    setState(() => _schoolYearController.text = '$picked-${picked + 1}');
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
        decoration: BoxDecoration(
          color: cardColor,
          borderRadius: const BorderRadius.vertical(
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
                style: TextStyle(
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
                style: TextStyle(color: mutedColor, fontSize: 13),
              ),
              const SizedBox(height: 18),
              TextField(
                controller: _universityController,
                focusNode: _universityFocus,
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
                decoration: _decoration('Program'),
              ),
              const SizedBox(height: 12),
              SuggestField(
                controller: _courseController,
                focusNode: _courseFocus,
                decoration: _decoration('Course / Subject'),
                optionsFor: _courseOptions,
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: _semester,
                decoration: _decoration('Semester'),
                items: _semesters
                    .map((s) => DropdownMenuItem(value: s, child: Text(s)))
                    .toList(),
                onChanged: (value) => setState(() => _semester = value),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _schoolYearController,
                readOnly: true,
                onTap: _pickSchoolYear,
                decoration: _decoration('School Year').copyWith(
                  suffixIcon: const Icon(
                    Icons.calendar_today_outlined,
                    size: 18,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              SuggestField(
                controller: _professorController,
                focusNode: _professorFocus,
                decoration: _decoration('Professor (optional)'),
                optionsFor: _professorOptions,
              ),
              const SizedBox(height: 18),
              Text(
                'Visibility',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: mutedColor,
                  fontSize: 13,
                ),
              ),
              const SizedBox(height: 8),
              _VisibilityChips(
                value: _visibility,
                onChanged: (value) {
                  setState(() {
                    _visibility = value;
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
                  onChanged: (_) => setState(() {}),
                  decoration: const InputDecoration(
                    prefixText: '₱ ',
                    labelText: 'Price',
                  ),
                ),
                const SizedBox(height: 10),
                _buildEarningsNote(),
              ],
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  onPressed: _confirm,
                  child: Text(
                    widget.isEditing ? 'Save Details' : 'Confirm & Save',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Tells the seller how a paid sale is split. Uses the same rate as
  /// TransactionService so the note can never drift from the real fee.
  Widget _buildEarningsNote() {
    final pc = context.pc;
    final rate = TransactionService.platformFeeRate;
    final percent = (rate * 100).round();

    final price = double.tryParse(_priceController.text.trim());
    final hasPrice = price != null && price > 0;

    final fee = hasPrice ? double.parse((price * rate).toStringAsFixed(2)) : 0.0;
    final earnings = hasPrice ? double.parse((price - fee).toStringAsFixed(2)) : 0.0;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: pc.field,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.info_outline, size: 18, color: pc.accent),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              hasPrice
                  ? 'Polaris keeps $percent% (₱${fee.toStringAsFixed(2)}) of each sale. '
                      'You receive ₱${earnings.toStringAsFixed(2)}.'
                  : 'Polaris keeps $percent% of each sale as a platform fee. '
                      'The rest is yours.',
              style: TextStyle(color: pc.muted, fontSize: 12.5),
            ),
          ),
        ],
      ),
    );
  }

  InputDecoration _decoration(String label) {
    return InputDecoration(
      labelText: label,
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

  @override
  Widget build(BuildContext context) {
    final pc = context.pc;

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
          selectedColor: pc.accent,
          labelStyle: TextStyle(
            color: selected ? pc.background : pc.ink,
          ),
          backgroundColor: pc.field,
          side: BorderSide.none,
        );
      }).toList(),
    );
  }
}
import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'package:markdown/markdown.dart' as md;
import 'package:markdown_quill/markdown_quill.dart';
import 'package:provider/provider.dart';
import '/controllers/auth_controller.dart';
import '/controllers/material_controller.dart';
import '/models/material_model.dart';
import 'material_details_sheet.dart';

class CreateMaterialView extends StatefulWidget {
  const CreateMaterialView({super.key, this.existingMaterial});

  /// Pass an existing material to reuse this screen as an edit form.
  /// Leave null for the normal create flow.
  final MaterialModel? existingMaterial;

  @override
  State<CreateMaterialView> createState() => _CreateMaterialViewState();
}

class _CreateMaterialViewState extends State<CreateMaterialView> {
  static const Color cream = Color(0xFFFCF6F0);
  static const Color navy = Color(0xFF252A5A);
  static const Color purple = Color(0xFF7B5EA7);
  static const Color gold = Color(0xFFE8B94A);

  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  final TextEditingController _priceController = TextEditingController();

  late final QuillController _quillController;
  String _visibility = 'private'; // "private" | "public_free" | "public_paid"

  bool get _isEditing => widget.existingMaterial != null;

  @override
  void initState() {
    super.initState();

    final existing = widget.existingMaterial;

    if (existing == null) {
      _quillController = QuillController.basic();
      return;
    }

    // ---- Edit mode: pre-fill everything from the existing material ----
    _titleController.text = existing.title;
    _descriptionController.text = existing.description ?? '';
    _visibility = existing.visibility;
    if (existing.price != null) {
      _priceController.text = existing.price!.toStringAsFixed(2);
    }

    // The material's content is stored as Markdown — convert it back into
    // Quill's Delta format so the WYSIWYG editor can display/edit it.
    final mdDocument = md.Document(encodeHtml: false);
    final delta = MarkdownToDelta(markdownDocument: mdDocument).convert(existing.content);
    _quillController = QuillController(
      document: Document.fromDelta(delta),
      selection: const TextSelection.collapsed(offset: 0),
    );
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _priceController.dispose();
    _quillController.dispose();
    super.dispose();
  }

  // ---------- Save flow ----------

  Future<void> _handleSave() async {
    final title = _titleController.text.trim();
    final plainText = _quillController.document.toPlainText().trim();

    if (title.isEmpty || plainText.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please add a title and some content first.')),
      );
      return;
    }

    if (_visibility == 'public_paid' && _priceController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please set a price for a paid material.')),
      );
      return;
    }

    // This is the actual WYSIWYG -> Markdown conversion. The editor works
    // in Quill's internal Delta format; DeltaToMarkdown() turns that into
    // the .md string that gets stored in Firestore.
    final markdownContent = DeltaToMarkdown().convert(_quillController.document.toDelta());

    final materialController = context.read<MaterialController>();

    // ---- Edit mode: update only the fields this form actually covers.
    // Academic fields (university/course/semester/etc.) aren't touched here
    // — they were set at creation and don't need re-asking on every edit.
    if (_isEditing) {
      final success = await materialController.updateMaterial(
        widget.existingMaterial!.materialId,
        {
          'title': title,
          'description': _descriptionController.text.trim().isEmpty
              ? null
              : _descriptionController.text.trim(),
          'content': markdownContent,
          'visibility': _visibility,
          'price': _visibility == 'public_paid'
              ? double.tryParse(_priceController.text.trim())
              : null,
        },
      );

      if (!mounted) return;

      if (success) {
        Navigator.of(context).pop();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(materialController.errorMessage ?? 'Could not update your material.')),
        );
      }
      return;
    }

    // ---- Create mode (unchanged) ----
    final auth = context.read<AuthController>();
    final profile = auth.currentUserProfile;

    // Ask for whatever the profile doesn't already answer — semester and
    // school year always, university/college/course only if missing.
    final details = await showModalBottomSheet<Map<String, String>>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => MaterialDetailsSheet(
        initialUniversity: profile?.university,
        initialCollege: profile?.college,
        initialCourse: profile?.course,
      ),
    );

    if (details == null || !mounted) return; // user cancelled

    final uid = profile?.userId;
    if (uid == null) return;

    final newMaterialId = await materialController.createMaterial(
      ownerId: uid,
      title: title,
      description: _descriptionController.text.trim().isEmpty
          ? null
          : _descriptionController.text.trim(),
      content: markdownContent, // stored as Markdown, not Delta JSON
      university: details['university']!,
      college: details['college']!,
      course: details['course']!,
      semester: details['semester']!,
      schoolYear: details['schoolYear']!,
      professor: (details['professor'] ?? '').isEmpty ? null : details['professor'],
      visibility: _visibility,
      price: _visibility == 'public_paid'
          ? double.tryParse(_priceController.text.trim())
          : null,
    );

    if (!mounted) return;

    if (newMaterialId != null) {
      Navigator.of(context).pop();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(materialController.errorMessage ?? 'Could not save your material.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final materialController = context.watch<MaterialController>();

    return Scaffold(
      backgroundColor: cream,
      appBar: AppBar(
        backgroundColor: navy,
        foregroundColor: Colors.white,
        title: Text(_isEditing ? 'Edit Material' : 'Create Material',
            style: const TextStyle(fontWeight: FontWeight.bold)),
        actions: [
          TextButton(
            onPressed: materialController.isSaving ? null : _handleSave,
            child: materialController.isSaving
                ? const SizedBox(
                    height: 18,
                    width: 18,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                  )
                : const Text('Save', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          TextField(
            controller: _titleController,
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: navy),
            decoration: const InputDecoration(
              hintText: 'Material title',
              border: InputBorder.none,
            ),
          ),
          const Divider(),
          TextField(
            controller: _descriptionController,
            maxLines: 2,
            decoration: const InputDecoration(
              hintText: 'Short description (optional)',
              border: InputBorder.none,
            ),
          ),
          const Divider(),

          const SizedBox(height: 8),

          _VisibilitySelector(
            value: _visibility,
            onChanged: (v) => setState(() => _visibility = v),
          ),

          if (_visibility == 'public_paid') ...[
            const SizedBox(height: 10),
            TextField(
              controller: _priceController,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: InputDecoration(
                prefixText: '₱ ',
                hintText: 'Price',
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ],

          const SizedBox(height: 16),

          const Text(
            'Content',
            style: TextStyle(fontWeight: FontWeight.w600, color: Colors.black54, fontSize: 13),
          ),
          const SizedBox(height: 8),

          // Quill editor — this is a real WYSIWYG editor. What the student
          // sees (bold text, actual bullet points) is what gets converted
          // to Markdown on save, not raw ** or # symbols while typing.
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: purple.withOpacity(0.2)),
            ),
            child: Column(
              children: [
                QuillSimpleToolbar(
                  controller: _quillController,
                  config: const QuillSimpleToolbarConfig(
                    showFontFamily: false,
                    showFontSize: false,
                    showBoldButton: true,
                    showItalicButton: true,
                    showSmallButton: false,
                    showUnderLineButton: false,
                    showStrikeThrough: false,
                    showInlineCode: false,
                    showColorButton: false,
                    showBackgroundColorButton: false,
                    showClearFormat: false,
                    showAlignmentButtons: false,
                    showHeaderStyle: true,
                    showListNumbers: true,
                    showListBullets: true,
                    showListCheck: false,
                    showCodeBlock: false,
                    showQuote: false,
                    showIndent: false,
                    showLink: false,
                    showUndo: true,
                    showRedo: true,
                    showDirection: false,
                    showSearchButton: false,
                    showSubscript: false,
                    showSuperscript: false,
                    showDividers: false,
                  ),
                ),
                const Divider(height: 1),
                Container(
                  constraints: const BoxConstraints(minHeight: 260, maxHeight: 420),
                  padding: const EdgeInsets.all(10),
                  child: QuillEditor.basic(
                    controller: _quillController,
                    config: const QuillEditorConfig(
                      placeholder: 'Write your notes here...',
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _VisibilitySelector extends StatelessWidget {
  const _VisibilitySelector({required this.value, required this.onChanged});

  final String value;
  final ValueChanged<String> onChanged;

  static const Color navy = Color(0xFF252A5A);

  @override
  Widget build(BuildContext context) {
    final options = const {
      'private': 'Private',
      'public_free': 'Public (Free)',
      'public_paid': 'Public (Paid)',
    };

    return Wrap(
      spacing: 8,
      children: options.entries.map((entry) {
        final selected = value == entry.key;
        return ChoiceChip(
          label: Text(entry.value),
          selected: selected,
          onSelected: (_) => onChanged(entry.key),
          selectedColor: navy,
          labelStyle: TextStyle(color: selected ? Colors.white : navy),
          backgroundColor: Colors.white,
          side: BorderSide(color: navy.withOpacity(0.4)),
        );
      }).toList(),
    );
  }
}
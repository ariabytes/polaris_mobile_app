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
  const CreateMaterialView({
    super.key,
    this.existingMaterial,
  });

  /// Pass an existing material to reuse this screen as an edit form.
  /// Leave null for the normal create flow.
  final MaterialModel? existingMaterial;

  @override
  State<CreateMaterialView> createState() =>
      _CreateMaterialViewState();
}

class _CreateMaterialViewState extends State<CreateMaterialView> {
  static const Color cream = Color(0xFFFCF6F0);
  static const Color navy = Color(0xFF252A5A);
  static const Color purple = Color(0xFF7B5EA7);
  static const Color gold = Color(0xFFE8B94A);

  final TextEditingController _titleController =
      TextEditingController();

  final TextEditingController _descriptionController =
      TextEditingController();

  final TextEditingController _priceController =
      TextEditingController();

  late final QuillController _quillController;

  String _visibility = 'private';

  bool get _isEditing => widget.existingMaterial != null;

  @override
  void initState() {
    super.initState();

    final existing = widget.existingMaterial;

    // ============================================================
    // CREATE MODE
    // ============================================================

    if (existing == null) {
      _quillController = QuillController.basic();
      return;
    }

    // ============================================================
    // EDIT MODE
    // ============================================================

    _titleController.text = existing.title;
    _descriptionController.text = existing.description ?? '';

    _visibility = existing.visibility;

    if (existing.price != null) {
      _priceController.text =
          existing.price!.toStringAsFixed(2);
    }

    // ============================================================
    // MARKDOWN -> QUILL
    // ============================================================

    final mdDocument = md.Document(
      encodeHtml: false,
      extensionSet: md.ExtensionSet.gitHubFlavored,
    );

    final delta = MarkdownToDelta(
      markdownDocument: mdDocument,
    ).convert(existing.content);

    _quillController = QuillController(
      document: Document.fromDelta(delta),
      selection: const TextSelection.collapsed(
        offset: 0,
      ),
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

  // ============================================================
  // SAVE
  // ============================================================

  Future<void> _handleSave() async {
    final title = _titleController.text.trim();

    final plainText =
        _quillController.document.toPlainText().trim();

    if (title.isEmpty || plainText.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Please add a title and some content first.',
          ),
        ),
      );

      return;
    }

    if (_visibility == 'public_paid' &&
        _priceController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Please set a price for a paid material.',
          ),
        ),
      );

      return;
    }

    // ============================================================
    // QUILL -> MARKDOWN
    // ============================================================

    final markdownContent = DeltaToMarkdown().convert(
      _quillController.document.toDelta(),
    );

    final materialController =
        context.read<MaterialController>();

    // ============================================================
    // EDIT EXISTING MATERIAL
    // ============================================================

    if (_isEditing) {
      final success =
          await materialController.updateMaterial(
        widget.existingMaterial!.materialId,
        {
          'title': title,
          'description':
              _descriptionController.text.trim().isEmpty
                  ? null
                  : _descriptionController.text.trim(),
          'content': markdownContent,
          'visibility': _visibility,
          'price': _visibility == 'public_paid'
              ? double.tryParse(
                  _priceController.text.trim(),
                )
              : null,
        },
      );

      if (!mounted) return;

      if (success) {
        Navigator.of(context).pop();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              materialController.errorMessage ??
                  'Could not update your material.',
            ),
          ),
        );
      }

      return;
    }

    // ============================================================
    // CREATE NEW MATERIAL
    // ============================================================

    final auth = context.read<AuthController>();
    final profile = auth.currentUserProfile;

    final details =
        await showModalBottomSheet<Map<String, String>>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => MaterialDetailsSheet(
        initialUniversity: profile?.university,
        initialCollege: profile?.college,
        initialProgram: profile?.program,
      ),
    );

    if (details == null || !mounted) return;

    final uid = profile?.userId;

    if (uid == null) return;

    final newMaterialId =
        await materialController.createMaterial(
      ownerId: uid,
      title: title,
      description:
          _descriptionController.text.trim().isEmpty
              ? null
              : _descriptionController.text.trim(),
      content: markdownContent,
      university: details['university']!,
      college: details['college']!,
      program: details['program']!,
      course: details['course']!,
      semester: details['semester']!,
      schoolYear: details['schoolYear']!,
      professor:
          (details['professor'] ?? '').isEmpty
              ? null
              : details['professor'],
      visibility: _visibility,
      price: _visibility == 'public_paid'
          ? double.tryParse(
              _priceController.text.trim(),
            )
          : null,
    );

    if (!mounted) return;

    if (newMaterialId != null) {
      Navigator.of(context).pop();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            materialController.errorMessage ??
                'Could not save your material.',
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
    final materialController =
        context.watch<MaterialController>();

    return Scaffold(
      backgroundColor: cream,

      // ==========================================================
      // APP BAR
      // ==========================================================

      appBar: AppBar(
        backgroundColor: navy,
        foregroundColor: Colors.white,
        title: Text(
          _isEditing
              ? 'Edit Material'
              : 'Create Material',
          style: const TextStyle(
            fontWeight: FontWeight.bold,
          ),
        ),
        actions: [
          TextButton(
            onPressed: materialController.isSaving
                ? null
                : _handleSave,
            child: materialController.isSaving
                ? const SizedBox(
                    height: 18,
                    width: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Text(
                    'Save',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
          ),
        ],
      ),

      // ==========================================================
      // BODY
      // ==========================================================

      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // ======================================================
          // TITLE
          // ======================================================

          TextField(
            controller: _titleController,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: navy,
            ),
            decoration: const InputDecoration(
              hintText: 'Material title',
              border: InputBorder.none,
            ),
          ),

          const Divider(),

          // ======================================================
          // DESCRIPTION
          // ======================================================

          TextField(
            controller: _descriptionController,
            maxLines: 2,
            decoration: const InputDecoration(
              hintText:
                  'Short description (optional)',
              border: InputBorder.none,
            ),
          ),

          const Divider(),

          const SizedBox(height: 8),

          // ======================================================
          // VISIBILITY
          // ======================================================

          _VisibilitySelector(
            value: _visibility,
            onChanged: (value) {
              setState(() {
                _visibility = value;
              });
            },
          ),

          // ======================================================
          // PRICE
          // ======================================================

          if (_visibility == 'public_paid') ...[
            const SizedBox(height: 10),

            TextField(
              controller: _priceController,
              keyboardType:
                  const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: InputDecoration(
                prefixText: '₱ ',
                hintText: 'Price',
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(
                  borderRadius:
                      BorderRadius.circular(12),
                ),
              ),
            ),
          ],

          const SizedBox(height: 16),

          // ======================================================
          // CONTENT LABEL
          // ======================================================

          const Text(
            'Content',
            style: TextStyle(
              fontWeight: FontWeight.w600,
              color: Colors.black54,
              fontSize: 13,
            ),
          ),

          const SizedBox(height: 8),

          // ======================================================
          // QUILL EDITOR
          // ======================================================

          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius:
                  BorderRadius.circular(12),
              border: Border.all(
                color: purple.withOpacity(0.2),
              ),
            ),
            child: Column(
              children: [
                // =================================================
                // COMPACT TOOLBAR
                // =================================================

                SizedBox(
                  height: 40,
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    padding: EdgeInsets.zero,
                    child: QuillSimpleToolbar(
                      controller: _quillController,
                      config:
                          const QuillSimpleToolbarConfig(
                        // ------------------------------------------------
                        // Make buttons smaller and closer together
                        // ------------------------------------------------
                        buttonOptions:
                            QuillSimpleToolbarButtonOptions(
                          base:
                              QuillToolbarBaseButtonOptions(
                            iconSize: 17,
                            iconButtonFactor: 0.60,
                          ),
                        ),

                        // ------------------------------------------------
                        // BASIC FORMATTING
                        // ------------------------------------------------
                        showBoldButton: true,
                        showItalicButton: true,
                        showUnderLineButton: false,
                        showStrikeThrough: false,

                        // ------------------------------------------------
                        // HEADERS
                        // ------------------------------------------------
                        showHeaderStyle: true,

                        // ------------------------------------------------
                        // LISTS
                        // ------------------------------------------------
                        showListNumbers: true,
                        showListBullets: true,
                        showListCheck: false,

                        // ------------------------------------------------
                        // HISTORY
                        // ------------------------------------------------
                        showUndo: true,
                        showRedo: true,

                        // ------------------------------------------------
                        // HIDE UNNECESSARY BUTTONS
                        // ------------------------------------------------
                        showFontFamily: false,
                        showFontSize: false,
                        showSmallButton: false,
                        showInlineCode: false,
                        showColorButton: false,
                        showBackgroundColorButton: false,
                        showClearFormat: false,
                        showAlignmentButtons: false,
                        showCodeBlock: false,
                        showQuote: false,
                        showIndent: false,
                        showLink: false,
                        showDirection: false,
                        showSearchButton: false,
                        showSubscript: false,
                        showSuperscript: false,
                        showDividers: false,
                      ),
                    ),
                  ),
                ),

                const Divider(height: 1),

                // =================================================
                // EDITOR
                // =================================================

                Container(
                  constraints:
                      const BoxConstraints(
                    minHeight: 260,
                    maxHeight: 420,
                  ),
                  padding:
                      const EdgeInsets.all(10),
                  child: QuillEditor.basic(
                    controller: _quillController,
                    config:
                        const QuillEditorConfig(
                      placeholder:
                          'Write your notes here...',
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

// ================================================================
// VISIBILITY SELECTOR
// ================================================================

class _VisibilitySelector
    extends StatelessWidget {
  const _VisibilitySelector({
    required this.value,
    required this.onChanged,
  });

  final String value;
  final ValueChanged<String> onChanged;

  static const Color navy =
      Color(0xFF252A5A);

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
        final selected =
            value == entry.key;

        return ChoiceChip(
          label: Text(entry.value),
          selected: selected,
          onSelected: (_) =>
              onChanged(entry.key),
          selectedColor: navy,
          labelStyle: TextStyle(
            color: selected
                ? Colors.white
                : navy,
          ),
          backgroundColor: Colors.white,
          side: BorderSide(
            color: navy.withOpacity(0.4),
          ),
          visualDensity:
              VisualDensity.compact,
          materialTapTargetSize:
              MaterialTapTargetSize.shrinkWrap,
        );
      }).toList(),
    );
  }
}
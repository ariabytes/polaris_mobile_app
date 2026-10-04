import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'package:image_picker/image_picker.dart';
import 'package:markdown/markdown.dart' as md;
import 'package:markdown_quill/markdown_quill.dart';
import 'package:provider/provider.dart';

import '/controllers/auth_controller.dart';
import '/controllers/material_controller.dart';
import '/models/material_model.dart';
import 'material_details_sheet.dart';

import 'package:polaris_mobile_app/services/theme_service.dart';

/// Create / edit a text (Markdown) material.
///
/// Pass [readOnly] = true (with an [existingMaterial]) to open the material
/// as a read-only viewer: no editing, no toolbar, no save, no cover change.
/// Used by admins and by buyers opening purchased/saved text materials.
class CreateMaterialView extends StatefulWidget {
  const CreateMaterialView({
    super.key,
    this.existingMaterial,
    this.readOnly = false,
  }) : assert(
          !readOnly || existingMaterial != null,
          'readOnly mode needs an existingMaterial to display.',
        );

  final MaterialModel? existingMaterial;
  final bool readOnly;

  @override
  State<CreateMaterialView> createState() => _CreateMaterialViewState();
}

class _CreateMaterialViewState extends State<CreateMaterialView> {
  Color get navy => context.pc.ink;
  Color get purple => context.pc.accent;
  Color get cardColor => context.pc.card;
  Color get mutedColor => context.pc.muted;

  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  final ImagePicker _picker = ImagePicker();

  late final QuillController _quillController;

  File? _coverFile;
  String? _coverFilename;

  bool get _isEditing => widget.existingMaterial != null;
  bool get _readOnly => widget.readOnly;

  @override
  void initState() {
    super.initState();

    final existing = widget.existingMaterial;

    if (existing == null) {
      _quillController = QuillController.basic();
      return;
    }

    _titleController.text = existing.title;
    _descriptionController.text = existing.description ?? '';

    final mdDocument = md.Document(
      encodeHtml: false,
      extensionSet: md.ExtensionSet.gitHubFlavored,
    );

    final delta = MarkdownToDelta(
      markdownDocument: mdDocument,
    ).convert(existing.content);

    _quillController = QuillController(
      document: Document.fromDelta(delta),
      selection: const TextSelection.collapsed(offset: 0),
      readOnly: _readOnly,
    );
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _quillController.dispose();
    super.dispose();
  }

  Future<void> _pickCover() async {
    if (_readOnly) return;

    final picked = await _picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 1600,
      imageQuality: 85,
    );
    if (picked == null || !mounted) return;

    setState(() {
      _coverFile = File(picked.path);
      _coverFilename = picked.name;
    });
  }

  Future<void> _uploadCoverIfPicked(
    MaterialController controller,
    String materialId,
  ) async {
    if (_coverFile == null) return;

    final ok = await controller.uploadCoverImage(
      materialId,
      _coverFile!,
      _coverFilename ?? 'cover.jpg',
    );

    if (!ok && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            controller.errorMessage ?? 'Could not upload cover image.',
          ),
        ),
      );
    }
  }

  Future<void> _handleSave() async {
    if (_readOnly) return;

    final title = _titleController.text.trim();
    final plainText = _quillController.document.toPlainText().trim();

    if (title.isEmpty || plainText.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please add a title and some content first.'),
        ),
      );
      return;
    }

    final markdownContent = DeltaToMarkdown().convert(
      _quillController.document.toDelta(),
    );

    final description = _descriptionController.text.trim().isEmpty
        ? null
        : _descriptionController.text.trim();

    final materialController = context.read<MaterialController>();

    if (_isEditing) {
      final materialId = widget.existingMaterial!.materialId;

      final success = await materialController.updateMaterial(
        materialId,
        {
          'title': title,
          'description': description,
          'content': markdownContent,
        },
      );

      if (!mounted) return;

      if (success) {
        await _uploadCoverIfPicked(materialController, materialId);
        if (!mounted) return;
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

    final auth = context.read<AuthController>();
    final profile = auth.currentUserProfile;

    final details = await showModalBottomSheet<Map<String, String>>(
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

    final newMaterialId = await materialController.createTextMaterial(
      ownerId: uid,
      title: title,
      description: description,
      content: markdownContent,
      details: details,
      cover: _coverFile,
      coverFilename: _coverFilename,
    );

    if (!mounted) return;

    if (newMaterialId != null) {
      Navigator.of(context).pop();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            materialController.errorMessage ?? 'Could not save your material.',
          ),
        ),
      );
    }
  }

  Widget _buildCover() {
    final existingUrl =
        widget.existingMaterial?.coverImage?['url'] as String?;
    final hasExisting = existingUrl != null && existingUrl.isNotEmpty;
    final hasImage = _coverFile != null || hasExisting;

    return GestureDetector(
      onTap: _readOnly ? null : _pickCover,
      child: Container(
        height: 150,
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          color: cardColor,
          borderRadius: BorderRadius.circular(16),
        ),
        child: hasImage
            ? Stack(
                fit: StackFit.expand,
                children: [
                  if (_coverFile != null)
                    Image.file(_coverFile!, fit: BoxFit.cover)
                  else
                    Image.network(
                      existingUrl!,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => Center(
                        child: Icon(
                          Icons.broken_image_outlined,
                          color: mutedColor,
                        ),
                      ),
                    ),
                  if (!_readOnly)
                    Positioned(
                      right: 10,
                      bottom: 10,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.black54,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.edit, size: 14, color: Colors.white),
                            SizedBox(width: 6),
                            Text(
                              'Change cover',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              )
            : Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.add_photo_alternate_outlined,
                    size: 36,
                    color: purple,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Add a cover image',
                    style: TextStyle(
                      color: mutedColor,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
      ),
    );
  }

  /// Small summary line (course, school, term) shown in read-only mode.
  Widget _buildReadOnlyMeta() {
    final m = widget.existingMaterial!;

    final lines = <String>[
      if (m.course.isNotEmpty) m.course,
      [m.university, m.college].where((s) => s.isNotEmpty).join(' · '),
      [m.schoolYear, m.semester].where((s) => s.isNotEmpty).join(' · '),
      if ((m.professor ?? '').isNotEmpty) 'Prof. ${m.professor}',
    ].where((s) => s.isNotEmpty).toList();

    if (lines.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final line in lines)
            Padding(
              padding: const EdgeInsets.only(bottom: 2),
              child: Text(
                line,
                style: TextStyle(color: mutedColor, fontSize: 12),
              ),
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final materialController = context.watch<MaterialController>();
    final keyboardOpen = MediaQuery.of(context).viewInsets.bottom > 0;

    final existingUrl =
        widget.existingMaterial?.coverImage?['url'] as String?;
    final hasExistingCover = existingUrl != null && existingUrl.isNotEmpty;

    // In read-only mode, only show the cover if the material actually has one.
    final showCover = !keyboardOpen && (!_readOnly || hasExistingCover);

    final hasDescription = _descriptionController.text.trim().isNotEmpty;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          _readOnly
              ? 'View Material'
              : (_isEditing ? 'Edit Material' : 'Create Material'),
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        actions: [
          if (!_readOnly)
            TextButton(
              onPressed: materialController.isSaving ? null : _handleSave,
              child: materialController.isSaving
                  ? SizedBox(
                      height: 18,
                      width: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: purple,
                      ),
                    )
                  : Text(
                      'Save',
                      style: TextStyle(
                        color: purple,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
            ),
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (showCover) ...[
                _buildCover(),
                const SizedBox(height: 16),
              ],
              if (_readOnly) ...[
                Text(
                  _titleController.text,
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: navy,
                  ),
                ),
                if (hasDescription) ...[
                  const SizedBox(height: 6),
                  Text(
                    _descriptionController.text.trim(),
                    style: TextStyle(fontSize: 14, color: mutedColor),
                  ),
                ],
                _buildReadOnlyMeta(),
                const SizedBox(height: 14),
              ] else ...[
                TextField(
                  controller: _titleController,
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: navy,
                  ),
                  decoration: const InputDecoration(
                    hintText: 'Material title',
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _descriptionController,
                  maxLines: 2,
                  decoration: const InputDecoration(
                    hintText: 'Short description (optional)',
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'Content',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: mutedColor,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 8),
              ],
              Expanded(
                child: Container(
                  clipBehavior: Clip.antiAlias,
                  decoration: BoxDecoration(
                    color: cardColor,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    children: [
                      if (!_readOnly) ...[
                        QuillSimpleToolbar(
                          controller: _quillController,
                          config: QuillSimpleToolbarConfig(
                            color: cardColor,
                            multiRowsDisplay: false,
                            buttonOptions:
                                const QuillSimpleToolbarButtonOptions(
                              base: QuillToolbarBaseButtonOptions(
                                iconSize: 20,
                                iconButtonFactor: 1,
                              ),
                            ),
                            showUndo: true,
                            showRedo: true,
                            showBoldButton: true,
                            showItalicButton: true,
                            showHeaderStyle: true,
                            showListNumbers: true,
                            showListBullets: true,
                            showUnderLineButton: false,
                            showStrikeThrough: false,
                            showListCheck: false,
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
                        const Divider(height: 1),
                      ],
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.all(10),
                          child: QuillEditor.basic(
                            controller: _quillController,
                            config: QuillEditorConfig(
                              placeholder: _readOnly
                                  ? 'This material has no content.'
                                  : 'Write your notes here...',
                              showCursor: !_readOnly,
                            ),
                          ),
                        ),
                      ),
                    ],
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
import 'dart:io';
import 'package:cloudinary_public/cloudinary_public.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '/controllers/auth_controller.dart';
import '/controllers/material_controller.dart';
import '/models/material_model.dart';
import 'create_material.dart';
import 'document_viewer.dart';
import 'material_details_sheet.dart';

class MyMaterialsView extends StatefulWidget {
  const MyMaterialsView({super.key});

  @override
  State<MyMaterialsView> createState() => _MyMaterialsViewState();
}

class _MyMaterialsViewState extends State<MyMaterialsView> {
  static const Color cream = Color(0xFFFCF6F0);
  static const Color navy = Color(0xFF252A5A);
  static const Color purple = Color(0xFF7B5EA7);
  static const Color gold = Color(0xFFE8B94A);

  // "all" | "private" | "public_free" | "public_paid"
  String _filter = 'all';
  bool _uploading = false;

  static const Set<String> _imageExtensions = {
    'jpg', 'jpeg', 'png', 'gif', 'webp', // treated as Image on Cloudinary
  };

  // ---------- Upload-a-file flow (FAB) ----------

  Future<void> _pickAndUploadFile() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['pdf', 'doc', 'docx', 'ppt', 'pptx', 'jpg', 'jpeg', 'png'],
    );
    if (result == null || result.files.single.path == null) return;

    final pickedFile = result.files.single;
    final file = File(pickedFile.path!);
    final filename = pickedFile.name;
    final extension = (pickedFile.extension ?? '').toLowerCase();

    if (!mounted) return;

    final auth = context.read<AuthController>();
    final profile = auth.currentUserProfile;
    final uid = profile?.userId;
    if (uid == null) return;

    // Step 1: title + visibility + price (only what the FAB flow needs).
    final quickInfo = await showModalBottomSheet<Map<String, String>>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _QuickUploadInfoSheet(defaultTitle: _stripExtension(filename)),
    );
    if (quickInfo == null || !mounted) return;

    // Step 2: same academic details sheet the full Create form uses.
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
    if (details == null || !mounted) return;

    setState(() => _uploading = true);

    final materialController = context.read<MaterialController>();
    final visibility = quickInfo['visibility']!;

    // Create the material record first — content is just a short note since
    // the real content lives in the attached file, not typed markdown.
    final newMaterialId = await materialController.createMaterial(
      ownerId: uid,
      title: quickInfo['title']!,
      content: '_This material is an uploaded file — see the attachment below._',
      university: details['university']!,
      college: details['college']!,
      course: details['course']!,
      semester: details['semester']!,
      schoolYear: details['schoolYear']!,
      professor: (details['professor'] ?? '').isEmpty ? null : details['professor'],
      visibility: visibility,
      price: visibility == 'public_paid' ? double.tryParse(quickInfo['price'] ?? '') : null,
    );

    if (newMaterialId == null) {
      if (!mounted) return;
      setState(() => _uploading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(materialController.errorMessage ?? 'Could not create material.')),
      );
      return;
    }

    // Now attach the actual file to it.
    final isImage = _imageExtensions.contains(extension);
    final success = await materialController.uploadAttachment(
      materialId: newMaterialId,
      file: file,
      originalFilename: filename,
      visibility: visibility,
      resourceType: isImage ? CloudinaryResourceType.Image : CloudinaryResourceType.Raw,
    );

    if (!mounted) return;
    setState(() => _uploading = false);

    if (!success) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(materialController.errorMessage ?? 'Material saved, but file upload failed.')),
      );
    }
  }

  String _stripExtension(String filename) {
    final dotIndex = filename.lastIndexOf('.');
    return dotIndex == -1 ? filename : filename.substring(0, dotIndex);
  }

  @override
  Widget build(BuildContext context) {
    final uid = context.watch<AuthController>().currentUserProfile?.userId;
    final materialController = context.read<MaterialController>();

    return Scaffold(
      backgroundColor: cream,
      appBar: AppBar(
        backgroundColor: navy,
        foregroundColor: Colors.white,
        title: const Text('My Materials', style: TextStyle(fontWeight: FontWeight.bold)),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _FilterChip(label: 'All', value: 'all', current: _filter, onTap: (v) => setState(() => _filter = v)),
                  const SizedBox(width: 8),
                  _FilterChip(label: 'Private', value: 'private', current: _filter, onTap: (v) => setState(() => _filter = v)),
                  const SizedBox(width: 8),
                  _FilterChip(label: 'Public (Free)', value: 'public_free', current: _filter, onTap: (v) => setState(() => _filter = v)),
                  const SizedBox(width: 8),
                  _FilterChip(label: 'Public (Paid)', value: 'public_paid', current: _filter, onTap: (v) => setState(() => _filter = v)),
                ],
              ),
            ),
          ),
          Expanded(
            child: uid == null
                ? const Center(child: CircularProgressIndicator(color: navy))
                : StreamBuilder<List<MaterialModel>>(
                    stream: materialController.myMaterials(uid),
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const Center(child: CircularProgressIndicator(color: navy));
                      }

                      if (snapshot.hasError) {
                        // This is the important part — a Firestore error (like a
                        // missing composite index) was being silently swallowed
                        // into an empty list before. Now it shows up for real.
                        return Center(
                          child: Padding(
                            padding: const EdgeInsets.all(24),
                            child: Text(
                              'Could not load materials:\n${snapshot.error}',
                              textAlign: TextAlign.center,
                              style: const TextStyle(color: Colors.red, fontSize: 13),
                            ),
                          ),
                        );
                      }

                      final materials = snapshot.data ?? [];
                      final filtered = _filter == 'all'
                          ? materials
                          : materials.where((m) => m.visibility == _filter).toList();

                      if (filtered.isEmpty) {
                        return const Center(
                          child: Padding(
                            padding: EdgeInsets.all(24),
                            child: Text(
                              'No materials here yet.',
                              style: TextStyle(color: Colors.black54, fontSize: 15),
                            ),
                          ),
                        );
                      }

                      return ListView.builder(
                        padding: const EdgeInsets.fromLTRB(16, 4, 16, 90),
                        itemCount: filtered.length,
                        itemBuilder: (context, index) => _MaterialCard(material: filtered[index]),
                      );
                    },
                  ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: navy,
        onPressed: _uploading ? null : _pickAndUploadFile,
        child: _uploading
            ? const SizedBox(
                height: 22,
                width: 22,
                child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white),
              )
            : const Icon(Icons.upload_file, color: Colors.white),
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  const _FilterChip({
    required this.label,
    required this.value,
    required this.current,
    required this.onTap,
  });

  final String label;
  final String value;
  final String current;
  final ValueChanged<String> onTap;

  static const Color navy = Color(0xFF252A5A);

  @override
  Widget build(BuildContext context) {
    final selected = value == current;
    return ChoiceChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) => onTap(value),
      selectedColor: navy,
      labelStyle: TextStyle(color: selected ? Colors.white : navy),
      backgroundColor: Colors.white,
      side: BorderSide(color: navy.withOpacity(0.4)),
    );
  }
}

class _MaterialCard extends StatelessWidget {
  const _MaterialCard({required this.material});

  final MaterialModel material;

  static const Color navy = Color(0xFF252A5A);
  static const Color purple = Color(0xFF7B5EA7);
  static const Color gold = Color(0xFFE8B94A);

  String get _visibilityLabel {
    switch (material.visibility) {
      case 'public_free':
        return 'Public · Free';
      case 'public_paid':
        return 'Public · ₱${material.price?.toStringAsFixed(0) ?? '0'}';
      default:
        return 'Private';
    }
  }

  // ---------- Tap routing ----------
  // File-uploaded materials (has attachments) open the actual document in
  // its own window (browser / associated app) via url_launcher.
  // Typed-markdown materials (no attachments) still open the edit form.

  void _handleTap(BuildContext context) {
    if (material.attachments.isNotEmpty) {
      _openAttachments(context);
    } else {
      _openEditor(context);
    }
  }

  void _openEditor(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => CreateMaterialView(existingMaterial: material)),
    );
  }

  Future<void> _openAttachments(BuildContext context) async {
    if (material.attachments.length == 1) {
      await _launchAttachment(context, material.attachments.first);
      return;
    }

    final selected = await showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => _AttachmentPickerSheet(attachments: material.attachments),
    );
    if (selected != null && context.mounted) {
      await _launchAttachment(context, selected);
    }
  }

  Future<void> _launchAttachment(BuildContext context, Map<String, dynamic> attachment) async {
    final url = attachment['url'] as String?;
    if (url == null || url.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('This file has no viewable link.')),
      );
      return;
    }

    final filename = attachment['original_filename'] as String? ?? material.title;
    var format = (attachment['format'] as String?)?.trim() ?? '';
    if (format.isEmpty) {
      // Older attachments (uploaded before storage_service started filling
      // this in for raw files) may have an empty format — derive it from
      // the filename so the viewer still knows what it's looking at.
      final dotIndex = filename.lastIndexOf('.');
      if (dotIndex != -1 && dotIndex < filename.length - 1) {
        format = filename.substring(dotIndex + 1).toLowerCase();
      }
    }

    await DocumentViewer.open(context, fileUrl: url, format: format);
  }

  @override
  Widget build(BuildContext context) {
    final hasAttachments = material.attachments.isNotEmpty;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () => _handleTap(context),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: (hasAttachments ? gold : purple).withOpacity(0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  hasAttachments ? Icons.attach_file : Icons.notes,
                  color: hasAttachments ? gold : purple,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      material.title,
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: navy),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _visibilityLabel,
                      style: const TextStyle(color: Colors.black54, fontSize: 12),
                    ),
                    if (hasAttachments) ...[
                      const SizedBox(height: 4),
                      Text(
                        '${material.attachments.length} attached file${material.attachments.length > 1 ? 's' : ''} · tap to open',
                        style: const TextStyle(color: Colors.black45, fontSize: 12),
                      ),
                    ],
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        const Icon(Icons.visibility_outlined, size: 14, color: Colors.black38),
                        const SizedBox(width: 4),
                        Text('${material.viewCount}', style: const TextStyle(fontSize: 12, color: Colors.black45)),
                        const SizedBox(width: 12),
                        const Icon(Icons.shopping_bag_outlined, size: 14, color: Colors.black38),
                        const SizedBox(width: 4),
                        Text('${material.purchaseCount}', style: const TextStyle(fontSize: 12, color: Colors.black45)),
                      ],
                    ),
                  ],
                ),
              ),
              PopupMenuButton<String>(
                icon: const Icon(Icons.more_vert, color: Colors.black38),
                onSelected: (value) {
                  if (value == 'edit') _openEditor(context);
                },
                itemBuilder: (_) => const [
                  PopupMenuItem(value: 'edit', child: Text('Edit details')),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Bottom sheet listing every attachment on a material so the user can pick
/// which one to open when there's more than one.
class _AttachmentPickerSheet extends StatelessWidget {
  const _AttachmentPickerSheet({required this.attachments});

  final List<Map<String, dynamic>> attachments;

  static const Color cream = Color(0xFFFCF6F0);
  static const Color navy = Color(0xFF252A5A);

  IconData _iconFor(String format) {
    switch (format.toLowerCase()) {
      case 'pdf':
        return Icons.picture_as_pdf;
      case 'doc':
      case 'docx':
        return Icons.description;
      case 'ppt':
      case 'pptx':
        return Icons.slideshow;
      case 'jpg':
      case 'jpeg':
      case 'png':
      case 'gif':
      case 'webp':
        return Icons.image;
      default:
        return Icons.insert_drive_file;
    }
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Container(
        decoration: const BoxDecoration(
          color: cream,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
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
              'Open which file?',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: navy),
            ),
            const SizedBox(height: 8),
            ...attachments.map((a) {
              final name = a['original_filename'] as String? ?? 'Attachment';
              final format = a['format'] as String? ?? '';
              return ListTile(
                leading: Icon(_iconFor(format), color: navy),
                title: Text(name, maxLines: 1, overflow: TextOverflow.ellipsis),
                subtitle: format.isNotEmpty ? Text(format.toUpperCase()) : null,
                onTap: () => Navigator.of(context).pop(a),
              );
            }),
          ],
        ),
      ),
    );
  }
}

/// Quick title/visibility/price step shown before the full details sheet,
/// used only by the file-upload FAB (the full editor collects these inline
/// on its own form instead).
class _QuickUploadInfoSheet extends StatefulWidget {
  const _QuickUploadInfoSheet({required this.defaultTitle});

  final String defaultTitle;

  @override
  State<_QuickUploadInfoSheet> createState() => _QuickUploadInfoSheetState();
}

class _QuickUploadInfoSheetState extends State<_QuickUploadInfoSheet> {
  static const Color cream = Color(0xFFFCF6F0);
  static const Color navy = Color(0xFF252A5A);

  late final TextEditingController _titleController;
  final TextEditingController _priceController = TextEditingController();
  String _visibility = 'private';

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.defaultTitle);
  }

  @override
  void dispose() {
    _titleController.dispose();
    _priceController.dispose();
    super.dispose();
  }

  void _confirm() {
    if (_titleController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please add a title.')),
      );
      return;
    }
    if (_visibility == 'public_paid' && _priceController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please set a price.')),
      );
      return;
    }

    Navigator.of(context).pop({
      'title': _titleController.text.trim(),
      'visibility': _visibility,
      'price': _priceController.text.trim(),
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
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
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
              'Uploading a file',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: navy),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: _titleController,
              decoration: InputDecoration(
                labelText: 'Title',
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
            const SizedBox(height: 14),
            _VisibilityChips(
              value: _visibility,
              onChanged: (v) => setState(() => _visibility = v),
            ),
            if (_visibility == 'public_paid') ...[
              const SizedBox(height: 12),
              TextField(
                controller: _priceController,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: InputDecoration(
                  prefixText: '₱ ',
                  labelText: 'Price',
                  filled: true,
                  fillColor: Colors.white,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
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
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: const Text('Next', style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _VisibilityChips extends StatelessWidget {
  const _VisibilityChips({required this.value, required this.onChanged});

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
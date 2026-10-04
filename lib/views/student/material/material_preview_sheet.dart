import 'package:flutter/material.dart';

import '/models/material_model.dart';
import 'document_viewer.dart';

import 'package:polaris_mobile_app/services/theme_service.dart';

class MaterialPreviewSheet extends StatelessWidget {
  const MaterialPreviewSheet({super.key, required this.material});

  final MaterialModel material;

  static Future<void> show(BuildContext context, MaterialModel material) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => MaterialPreviewSheet(material: material),
    );
  }

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

  String _formatOf(Map<String, dynamic> file) {
    final format = (file['format'] as String?)?.trim() ?? '';
    if (format.isNotEmpty) return format;

    final filename = (file['original_filename'] as String?) ?? '';
    final dotIndex = filename.lastIndexOf('.');
    if (dotIndex != -1 && dotIndex < filename.length - 1) {
      return filename.substring(dotIndex + 1).toLowerCase();
    }
    return '';
  }

  Future<void> _open(BuildContext context, Map<String, dynamic> file) {
    return DocumentViewer.open(
      context,
      fileUrl: file['url'] as String,
      format: _formatOf(file),
    );
  }

  @override
  Widget build(BuildContext context) {
    final pc = context.pc;

    final coverUrl = material.coverImage?['url'] as String?;
    final hasCover = coverUrl != null && coverUrl.isNotEmpty;

    final files = material.attachments
        .where((a) => ((a['url'] as String?) ?? '').isNotEmpty)
        .toList();

    final term = [material.schoolYear, material.semester]
        .where((s) => s.isNotEmpty)
        .join(' · ');

    return SafeArea(
      child: Container(
        width: double.infinity,
        decoration: BoxDecoration(
          color: pc.card,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
        child: SingleChildScrollView(
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
                    color: pc.ink.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ),
              if (hasCover) ...[
                ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: SizedBox(
                    width: double.infinity,
                    height: 160,
                    child: Image.network(
                      coverUrl,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => Container(
                        color: pc.field,
                        child: Icon(
                          Icons.broken_image_outlined,
                          color: pc.muted,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
              ],
              Text(
                material.title,
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: pc.ink,
                ),
              ),
              if (material.course.isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(
                  material.course,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: pc.ink,
                  ),
                ),
              ],
              if (term.isNotEmpty) ...[
                const SizedBox(height: 2),
                Text(
                  term,
                  style: TextStyle(fontSize: 13, color: pc.muted),
                ),
              ],
              const SizedBox(height: 20),
              if (files.isEmpty)
                Text(
                  'No files attached.',
                  style: TextStyle(color: pc.muted),
                )
              else if (files.length == 1)
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton.icon(
                    onPressed: () => _open(context, files.first),
                    icon: const Icon(Icons.open_in_new, size: 18),
                    label: const Text(
                      'Open document',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                )
              else ...[
                Text(
                  'Files',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: pc.muted,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 4),
                for (final file in files)
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: Icon(
                      _iconFor(_formatOf(file)),
                      color: pc.ink,
                    ),
                    title: Text(
                      (file['original_filename'] as String?) ?? 'Attachment',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    subtitle: _formatOf(file).isNotEmpty
                        ? Text(_formatOf(file).toUpperCase())
                        : null,
                    trailing: Icon(Icons.open_in_new, size: 18, color: pc.muted),
                    onTap: () => _open(context, file),
                  ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
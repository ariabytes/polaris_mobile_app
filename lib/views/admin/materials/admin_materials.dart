import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../controllers/material_controller.dart';
import '../../../models/material_model.dart';
import '../../student/material/document_viewer.dart';

class AdminMaterialsView extends StatelessWidget {
  const AdminMaterialsView({super.key});

  static const Color cream = Color(0xFFFEEFDD);
  static const Color orange = Color(0xFFF87C4F);

  @override
  Widget build(BuildContext context) {
    final materialController = context.read<MaterialController>();

    return Scaffold(
      backgroundColor: cream,
      appBar: AppBar(
        backgroundColor: orange,
        foregroundColor: Colors.white,
        title: const Text('Materials', style: TextStyle(fontWeight: FontWeight.bold)),
      ),
      body: StreamBuilder<List<MaterialModel>>(
        stream: materialController.allMaterialsAdmin(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('Could not load materials.\n${snapshot.error}'));
          }

          final materials = snapshot.data ?? [];
          if (materials.isEmpty) {
            return const Center(child: Text('No materials yet.'));
          }

          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: materials.length,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (context, index) => _MaterialTile(material: materials[index]),
          );
        },
      ),
    );
  }
}

class _MaterialTile extends StatelessWidget {
  const _MaterialTile({required this.material});

  final MaterialModel material;

  Color _visibilityColor() {
    switch (material.visibility) {
      case 'private':
        return Colors.grey.shade600;
      case 'public_paid':
        return Colors.green.shade700;
      default: // public_free
        return Colors.blue.shade700;
    }
  }

  Future<void> _confirmDelete(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete this material?'),
        content: Text(
          'This permanently deletes "${material.title}" from Firestore.\n\n'
          'Its cover image and attachments stay in Cloudinary (not '
          'auto-deleted), and any past purchases of it will show as '
          '"no longer available" instead of losing their price/date history.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed != true || !context.mounted) return;

    final materialController = context.read<MaterialController>();
    final success = await materialController.deleteMaterialPermanently(material.materialId);

    if (!context.mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          success
              ? 'Material deleted.'
              : (materialController.errorMessage ?? 'Could not delete material.'),
        ),
      ),
    );
  }

  void _showAttachments(BuildContext context) {
    final attachments = material.attachments;

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) {
        if (attachments.isEmpty) {
          return const Padding(
            padding: EdgeInsets.all(24),
            child: Text('No files attached to this material.'),
          );
        }

        return SafeArea(
          child: ListView(
            shrinkWrap: true,
            padding: const EdgeInsets.symmetric(vertical: 8),
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
                child: Text(
                  material.title,
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
              ),
              ...attachments.map((attachment) {
                final filename =
                    attachment['original_filename'] as String? ?? 'Untitled file';
                final format = (attachment['format'] as String? ?? '').toUpperCase();
                final url = attachment['url'] as String?;

                return ListTile(
                  leading: const Icon(Icons.insert_drive_file_outlined),
                  title: Text(filename),
                  subtitle: format.isNotEmpty ? Text(format) : null,
                  onTap: () {
                    Navigator.of(sheetContext).pop();

                    if (url == null || url.isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('This file has no URL to open.')),
                      );
                      return;
                    }

                    DocumentViewer.open(context, fileUrl: url, format: format);
                  },
                );
              }),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final color = _visibilityColor();
    final priceLabel = material.isPublicPaid ? ' • ₱${(material.price ?? 0).toStringAsFixed(2)}' : '';
    final fileCount = material.attachments.length;

    return Card(
      elevation: 0,
      color: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ListTile(
        onTap: () => _showAttachments(context),
        leading: CircleAvatar(
          backgroundColor: color.withOpacity(0.15),
          child: Icon(Icons.description_outlined, color: color),
        ),
        title: Text(material.title, style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Text(
          '${material.course} • ${material.status}\n'
          '${material.visibility}$priceLabel • $fileCount file${fileCount == 1 ? '' : 's'}',
        ),
        isThreeLine: true,
        trailing: IconButton(
          icon: const Icon(Icons.delete_outline, color: Colors.red),
          onPressed: () => _confirmDelete(context),
        ),
      ),
    );
  }
}
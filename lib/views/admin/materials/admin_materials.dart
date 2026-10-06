import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../controllers/auth_controller.dart';
import '../../../controllers/material_controller.dart';
import '../../../models/material_model.dart';
import '../../../models/user_model.dart';
import '../../student/material/create_material.dart';
import '../../student/material/document_viewer.dart';

import 'package:polaris_mobile_app/services/theme_service.dart';

class AdminMaterialsView extends StatefulWidget {
  const AdminMaterialsView({super.key});

  @override
  State<AdminMaterialsView> createState() => _AdminMaterialsViewState();
}

class _AdminMaterialsViewState extends State<AdminMaterialsView> {
  final TextEditingController _searchController = TextEditingController();
  String _query = '';

  late final Stream<List<MaterialModel>> _materialsStream;
  late final Stream<List<UserModel>> _usersStream;

  @override
  void initState() {
    super.initState();
    _materialsStream = context.read<MaterialController>().allMaterialsAdmin();
    _usersStream = context.read<AuthController>().allUsers();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  bool _matches(MaterialModel m, String creatorName) {
    if (_query.isEmpty) return true;
    final haystack = [
      m.university, 
      m.college, 
      creatorName, // person who created it :p
      m.course, 
      m.title,
    ].join(' ').toLowerCase();

    return _query
        .split(RegExp(r'\s+'))
        .where((w) => w.isNotEmpty)
        .every(haystack.contains);
  }

  @override
  Widget build(BuildContext context) {
    final pc = context.pc;

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Materials',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            child: TextField(
              controller: _searchController,
              textInputAction: TextInputAction.search,
              onChanged: (v) => setState(() => _query = v.trim().toLowerCase()),
              decoration: InputDecoration(
                hintText: 'Search school, department, creator, or course',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _query.isEmpty
                    ? null
                    : IconButton(
                        tooltip: 'Clear',
                        icon: const Icon(Icons.close),
                        onPressed: () {
                          _searchController.clear();
                          setState(() => _query = '');
                        },
                      ),
              ),
            ),
          ),
          Expanded(
            child: StreamBuilder<List<UserModel>>(
              stream: _usersStream,
              builder: (context, userSnap) {
                final names = <String, String>{
                  for (final u in userSnap.data ?? const <UserModel>[])
                    u.userId: u.name,
                };

                return StreamBuilder<List<MaterialModel>>(
                  stream: _materialsStream,
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return Center(
                        child: CircularProgressIndicator(color: pc.accent),
                      );
                    }
                    if (snapshot.hasError) {
                      return Center(
                        child: Padding(
                          padding: const EdgeInsets.all(24),
                          child: Text(
                            'Could not load materials.\n${snapshot.error}',
                            textAlign: TextAlign.center,
                            style: TextStyle(color: pc.danger, fontSize: 13),
                          ),
                        ),
                      );
                    }

                    final all = snapshot.data ?? [];
                    final materials = all
                        .where((m) => _matches(m, names[m.ownerId] ?? ''))
                        .toList();

                    if (materials.isEmpty) {
                      return Center(
                        child: Padding(
                          padding: const EdgeInsets.all(24),
                          child: Text(
                            all.isEmpty
                                ? 'No materials yet.'
                                : 'No materials match your search.',
                            style: TextStyle(color: pc.muted, fontSize: 15),
                          ),
                        ),
                      );
                    }

                    return ListView.builder(
                      padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                      itemCount: materials.length,
                      itemBuilder: (context, index) {
                        final m = materials[index];
                        return _MaterialCard(
                          material: m,
                          creatorName: names[m.ownerId] ?? 'Unknown user',
                        );
                      },
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _MaterialCard extends StatelessWidget {
  const _MaterialCard({required this.material, required this.creatorName});

  final MaterialModel material;
  final String creatorName;

  Color _visibilityColor(BuildContext context) {
    final c = context.pc;
    switch (material.visibility) {
      case 'private':
        return c.muted;
      case 'public_paid':
        return c.success;
      default: // public_free
        return c.accent;
    }
  }

  String get _visibilityLabel {
    switch (material.visibility) {
      case 'public_free':
        return 'Public · Free';
      case 'public_paid':
        return 'Public · ₱${(material.price ?? 0).toStringAsFixed(2)}';
      default:
        return 'Private';
    }
  }

  Future<void> _confirmDelete(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete this material?'),
        content: Text(
          'This permanently deletes "${material.title}" from Firestore.\n\n'
          'Its cover image and attachments stay in Cloudinary (not '
          'auto-deleted), and any past purchases of it will show as '
          '"no longer available" instead of losing their price/date history.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            style: TextButton.styleFrom(foregroundColor: context.pc.danger),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed != true || !context.mounted) return;

    final materialController = context.read<MaterialController>();
    final success =
        await materialController.deleteMaterialPermanently(material.materialId);

    if (!context.mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          success
              ? 'Material deleted.'
              : (materialController.errorMessage ??
                  'Could not delete material.'),
        ),
      ),
    );
  }

  // Text (String) materials open in the read-only viewer file materials show the attachment list.
  void _open(BuildContext context) {
    if (material.attachments.isEmpty) {
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => CreateMaterialView(
            existingMaterial: material,
            readOnly: true,
          ),
        ),
      );
      return;
    }
    _showAttachments(context);
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
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
              ),
              ...attachments.map((attachment) {
                final filename =
                    attachment['original_filename'] as String? ??
                        'Untitled file';
                final format =
                    (attachment['format'] as String? ?? '').toUpperCase();
                final url = attachment['url'] as String?;

                return ListTile(
                  leading: const Icon(Icons.insert_drive_file_outlined),
                  title: Text(filename),
                  subtitle: format.isNotEmpty ? Text(format) : null,
                  onTap: () {
                    Navigator.of(sheetContext).pop();

                    if (url == null || url.isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('This file has no URL to open.'),
                        ),
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

  Widget _buildThumbnail(Color tint, bool hasAttachments) {
    final url = material.coverImage?['url'] as String?;

    final fallback = Container(
      color: tint.withOpacity(0.15),
      child: Center(
        child: Icon(
          hasAttachments ? Icons.attach_file : Icons.notes,
          color: tint,
          size: 28,
        ),
      ),
    );

    return ClipRRect(
      borderRadius: BorderRadius.circular(10),
      child: SizedBox(
        width: 84,
        height: 84,
        child: (url != null && url.isNotEmpty)
            ? Image.network(
                url,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => fallback,
              )
            : fallback,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final pc = context.pc;
    final tint = _visibilityColor(context);
    final fileCount = material.attachments.length;
    final removed = !material.isActive;

    final school = [material.university, material.college]
        .where((s) => s.isNotEmpty)
        .join(' · ');

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () => _open(context),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildThumbnail(tint, fileCount > 0),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      material.title,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                        color: pc.ink,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (material.course.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        material.course,
                        style: TextStyle(
                          color: pc.ink,
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                    if (school.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        school,
                        style: TextStyle(color: pc.muted, fontSize: 12),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        Icon(Icons.person_outline, size: 13, color: pc.muted),
                        const SizedBox(width: 3),
                        Expanded(
                          child: Text(
                            creatorName,
                            style: TextStyle(color: pc.muted, fontSize: 12),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      removed ? 'Removed · $_visibilityLabel' : _visibilityLabel,
                      style: TextStyle(
                        color: removed ? pc.danger : tint,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Icon(Icons.visibility_outlined,
                            size: 14, color: pc.muted),
                        const SizedBox(width: 4),
                        Text(
                          '${material.viewCount}',
                          style: TextStyle(fontSize: 12, color: pc.muted),
                        ),
                        const SizedBox(width: 12),
                        Icon(Icons.shopping_bag_outlined,
                            size: 14, color: pc.muted),
                        const SizedBox(width: 4),
                        Text(
                          '${material.purchaseCount}',
                          style: TextStyle(fontSize: 12, color: pc.muted),
                        ),
                        const SizedBox(width: 12),
                        Icon(Icons.attach_file, size: 14, color: pc.muted),
                        const SizedBox(width: 2),
                        Text(
                          '$fileCount',
                          style: TextStyle(fontSize: 12, color: pc.muted),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              IconButton(
                tooltip: 'Delete permanently',
                icon: Icon(Icons.delete_outline, color: pc.danger),
                onPressed: () => _confirmDelete(context),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
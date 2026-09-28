import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '/controllers/auth_controller.dart';
import '/controllers/material_controller.dart';
import '/controllers/transaction_controller.dart';
import '/models/material_model.dart';
import '../material/document_viewer.dart';
import '../material/material_details_sheet.dart';
import 'checkout_page.dart';

/// Material detail page — shown when a student taps a card from Discover,
/// My Materials, or My Purchases.
/// Lives at lib/views/student/discover/material_detail_page.dart, alongside
/// discover_page.dart and checkout_page.dart. document_viewer.dart and
/// materials_details_sheet.dart live one folder over, in material/.
///
/// ACCESS GATING mirrors MaterialService.canAccessContent (public_free is
/// always visible, the owner always sees their own, public_paid needs a
/// completed purchase). That method lives on the Service and isn't exposed
/// through MaterialController, so the same 3-line check is reproduced here
/// as `_canAccessContent`.
///
/// TRANSACTION-BACKED STATE: `hasTransacted` (from
/// TransactionController.hasPurchased) is checked for any non-owner viewer,
/// not just paid ones — it drives two different things depending on
/// visibility: for public_paid, it's the purchase gate; for public_free,
/// it's whether to show "Save to My Materials" vs "Saved". Same underlying
/// stream, two different UI meanings.
class MaterialDetailPage extends StatefulWidget {
  const MaterialDetailPage({super.key, required this.materialId});

  final String materialId;

  @override
  State<MaterialDetailPage> createState() => _MaterialDetailPageState();
}

class _MaterialDetailPageState extends State<MaterialDetailPage> {
  static const cream = Color(0xFFFCF6F0);
  static const navy = Color(0xFF252A5A);
  static const purple = Color(0xFF7B5EA7);
  static const gold = Color(0xFFE8B94A);

  bool _viewCounted = false;

  @override
  Widget build(BuildContext context) {
    final materialController = context.watch<MaterialController>();
    final authController = context.watch<AuthController>();
    final transactionController = context.watch<TransactionController>();

    final currentUserId = authController.currentUserProfile?.userId;

    return Scaffold(
      backgroundColor: cream,
      body: StreamBuilder<MaterialModel?>(
        stream: materialController.material(widget.materialId),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator(color: purple));
          }

          final material = snapshot.data;
          if (material == null || !material.isActive) {
            return _buildNotFound();
          }

          if (!_viewCounted) {
            _viewCounted = true;
            WidgetsBinding.instance.addPostFrameCallback((_) {
              materialController.registerView(widget.materialId);
            });
          }

          final isOwner = currentUserId != null && material.ownerId == currentUserId;
          final needsTransactionCheck =
              !isOwner && currentUserId != null && (material.isPublicPaid || material.isPublicFree);

          if (!needsTransactionCheck) {
            return _buildScaffoldBody(
              material: material,
              isOwner: isOwner,
              hasTransacted: false,
              currentUserId: currentUserId,
              materialController: materialController,
              transactionController: transactionController,
            );
          }

          return StreamBuilder<bool>(
            stream: transactionController.hasPurchased(
              buyerId: currentUserId!,
              materialId: material.materialId,
            ),
            builder: (context, txnSnap) {
              final hasTransacted = txnSnap.data ?? false;
              return _buildScaffoldBody(
                material: material,
                isOwner: isOwner,
                hasTransacted: hasTransacted,
                currentUserId: currentUserId,
                materialController: materialController,
                transactionController: transactionController,
              );
            },
          );
        },
      ),
    );
  }

  // ---------- ACCESS LOGIC (mirrors MaterialService.canAccessContent) ----------

  bool _canAccessContent(MaterialModel m, String? currentUserId, bool hasTransacted) {
    if (m.visibility == 'public_free') return true;
    if (currentUserId != null && m.ownerId == currentUserId) return true;
    if (m.visibility == 'public_paid' && hasTransacted) return true;
    return false;
  }

  // ---------- BODY ----------

  Widget _buildScaffoldBody({
    required MaterialModel material,
    required bool isOwner,
    required bool hasTransacted,
    required String? currentUserId,
    required MaterialController materialController,
    required TransactionController transactionController,
  }) {
    final canAccess = _canAccessContent(material, currentUserId, hasTransacted);
    final coverUrl = material.coverImage?['url'] as String?;

    return CustomScrollView(
      slivers: [
        SliverAppBar(
          backgroundColor: cream,
          expandedHeight: coverUrl != null ? 200 : 0,
          pinned: true,
          iconTheme: const IconThemeData(color: navy),
          flexibleSpace: coverUrl != null
              ? FlexibleSpaceBar(background: Image.network(coverUrl, fit: BoxFit.cover))
              : null,
          actions: isOwner
              ? [
                  IconButton(
                    icon: const Icon(Icons.edit_outlined, color: navy),
                    onPressed: () => _editMaterial(material, materialController),
                  ),
                  IconButton(
                    icon: const Icon(Icons.delete_outline, color: navy),
                    onPressed: () => _confirmRemove(material, materialController),
                  ),
                ]
              : null,
        ),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  material.title,
                  style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: navy),
                ),
                const SizedBox(height: 6),
                _buildVisibilityAndStats(material),
                const SizedBox(height: 14),
                _buildMetaSection(material),
                if (material.description != null && material.description!.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  Text(material.description!, style: TextStyle(color: navy.withOpacity(0.75))),
                ],
                const SizedBox(height: 20),
                const Divider(),
                const SizedBox(height: 16),
                if (!canAccess)
                  _buildPurchaseGate(material)
                else ...[
                  if (!isOwner && material.isPublicFree)
                    _buildSaveSection(material, currentUserId, hasTransacted, transactionController),
                  _buildContentSection(material),
                  if (material.attachments.isNotEmpty) ...[
                    const SizedBox(height: 24),
                    _buildAttachmentsSection(material),
                  ],
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildNotFound() {
    return SafeArea(
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.folder_off_outlined, size: 48, color: navy.withOpacity(0.3)),
              const SizedBox(height: 12),
              Text('This material is no longer available.', style: TextStyle(color: navy.withOpacity(0.6))),
              const SizedBox(height: 16),
              TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Go back')),
            ],
          ),
        ),
      ),
    );
  }

  // ---------- META / STATS ----------

  Widget _buildVisibilityAndStats(MaterialModel material) {
    final label = material.isPrivate
        ? 'Private'
        : material.isPublicFree
            ? 'Free'
            : 'Paid · ₱${material.price?.toStringAsFixed(0) ?? "0"}';

    final chipColor = material.isPrivate
        ? navy.withOpacity(0.5)
        : material.isPublicFree
            ? Colors.green
            : gold;

    return Row(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(color: chipColor.withOpacity(0.15), borderRadius: BorderRadius.circular(20)),
          child: Text(label, style: TextStyle(color: chipColor, fontSize: 12, fontWeight: FontWeight.w700)),
        ),
        const SizedBox(width: 12),
        Icon(Icons.remove_red_eye_outlined, size: 14, color: navy.withOpacity(0.4)),
        const SizedBox(width: 4),
        Text('${material.viewCount}', style: TextStyle(color: navy.withOpacity(0.5), fontSize: 12)),
        if (!material.isPrivate) ...[
          const SizedBox(width: 12),
          Icon(Icons.bookmark_added_outlined, size: 14, color: navy.withOpacity(0.4)),
          const SizedBox(width: 4),
          Text('${material.purchaseCount}', style: TextStyle(color: navy.withOpacity(0.5), fontSize: 12)),
        ],
      ],
    );
  }

  Widget _buildMetaSection(MaterialModel material) {
    final rows = <String>[
      material.university,
      '${material.college} · ${material.program}',
      material.course,
      '${material.semester} · ${material.schoolYear}',
      if (material.professor != null && material.professor!.isNotEmpty) 'Prof. ${material.professor}',
    ];

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: rows
            .map((r) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 2),
                  child: Text(r, style: TextStyle(color: navy.withOpacity(0.7), fontSize: 13)),
                ))
            .toList(),
      ),
    );
  }

  // ---------- CONTENT ----------

  Widget _buildContentSection(MaterialModel material) {
    if (material.content.trim().isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Notes', style: TextStyle(fontWeight: FontWeight.bold, color: navy, fontSize: 15)),
        const SizedBox(height: 8),
        SelectableText(material.content, style: TextStyle(color: navy.withOpacity(0.85), height: 1.5)),
      ],
    );
  }

  Widget _buildAttachmentsSection(MaterialModel material) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Attachments', style: TextStyle(fontWeight: FontWeight.bold, color: navy, fontSize: 15)),
        const SizedBox(height: 8),
        ...material.attachments.map((a) => _AttachmentTile(attachment: a)),
      ],
    );
  }

  // ---------- SAVE (free materials) ----------

  Widget _buildSaveSection(
    MaterialModel material,
    String? currentUserId,
    bool alreadySaved,
    TransactionController transactionController,
  ) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: SizedBox(
        width: double.infinity,
        child: OutlinedButton.icon(
          onPressed: currentUserId == null || alreadySaved || transactionController.isPurchasing
              ? null
              : () => _handleSaveFree(material, currentUserId, transactionController),
          icon: Icon(alreadySaved ? Icons.check_circle : Icons.bookmark_add_outlined),
          label: Text(alreadySaved ? 'Saved to My Materials' : 'Save to My Materials'),
          style: OutlinedButton.styleFrom(
            foregroundColor: alreadySaved ? Colors.green : navy,
            side: BorderSide(color: alreadySaved ? Colors.green : navy.withOpacity(0.4)),
            padding: const EdgeInsets.symmetric(vertical: 12),
          ),
        ),
      ),
    );
  }

  Future<void> _handleSaveFree(
    MaterialModel material,
    String buyerId,
    TransactionController transactionController,
  ) async {
    final success = await transactionController.saveFreeMaterial(
      materialId: material.materialId,
      buyerId: buyerId,
    );

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          success
              ? 'Saved! Find it under My Materials → Purchased.'
              : (transactionController.errorMessage ?? 'Could not save this material.'),
        ),
      ),
    );
  }

  // ---------- PURCHASE GATE (paid materials) ----------

  Widget _buildPurchaseGate(MaterialModel material) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: gold.withOpacity(0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.lock_outline, color: navy.withOpacity(0.6)),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  'Purchase this material to unlock the full notes and attachments.',
                  style: TextStyle(color: navy, fontSize: 13),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            '₱${material.price?.toStringAsFixed(2) ?? "0.00"}',
            style: const TextStyle(color: navy, fontSize: 22, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            height: 46,
            child: ElevatedButton(
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => CheckoutPage(material: material)),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: navy,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: const Text('Proceed to Checkout'),
            ),
          ),
        ],
      ),
    );
  }

  // ---------- OWNER ACTIONS ----------

  Future<void> _editMaterial(MaterialModel material, MaterialController materialController) async {
    final result = await showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => MaterialDetailsSheet(existingMaterial: material),
    );

    if (result == null || !mounted) return;

    final fields = _sheetResultToUpdateFields(result);
    final success = await materialController.updateMaterial(material.materialId, fields);

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(success ? 'Details updated.' : (materialController.errorMessage ?? 'Update failed.')),
      ),
    );
  }

  Map<String, dynamic> _sheetResultToUpdateFields(Map<String, dynamic> result) {
    final visibility = result['visibility'] as String;
    final priceText = (result['price'] as String? ?? '').trim();
    final professor = (result['professor'] as String? ?? '').trim();

    return {
      'university': result['university'],
      'college': result['college'],
      'program': result['program'],
      'course': result['course'],
      'semester': result['semester'],
      'school_year': result['schoolYear'],
      'professor': professor.isEmpty ? null : professor,
      'visibility': visibility,
      'price': visibility == 'public_paid' && priceText.isNotEmpty ? double.tryParse(priceText) : null,
    };
  }

  Future<void> _confirmRemove(MaterialModel material, MaterialController materialController) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Remove this material?'),
        content: const Text('It will no longer appear anywhere, but past transactions still reference it.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Remove', style: TextStyle(color: Colors.redAccent)),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    final success = await materialController.removeMaterial(material.materialId);
    if (!mounted) return;

    if (success) {
      Navigator.of(context).pop();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(materialController.errorMessage ?? 'Could not remove this material.')),
      );
    }
  }
}

/// One attachment row — tapping opens it via DocumentViewer, wrapping
/// Office formats in the Google Docs viewer, everything else opened as-is.
class _AttachmentTile extends StatelessWidget {
  const _AttachmentTile({required this.attachment});

  final Map<String, dynamic> attachment;

  static const navy = Color(0xFF252A5A);
  static const purple = Color(0xFF7B5EA7);

  @override
  Widget build(BuildContext context) {
    final format = (attachment['format'] as String? ?? '').toLowerCase();
    final filename = attachment['original_filename'] as String? ?? 'File';
    final url = attachment['url'] as String?;
    final sizeBytes = (attachment['size_bytes'] as num?)?.toInt() ?? 0;

    return Card(
      elevation: 0,
      color: Colors.white,
      margin: const EdgeInsets.only(bottom: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        leading: Icon(_iconForFormat(format), color: purple),
        title: Text(filename, maxLines: 1, overflow: TextOverflow.ellipsis),
        subtitle: Text('${format.toUpperCase()} · ${_formatBytes(sizeBytes)}'),
        trailing: const Icon(Icons.open_in_new, size: 18, color: navy),
        onTap: url == null ? null : () => DocumentViewer.open(context, fileUrl: url, format: format),
      ),
    );
  }

  IconData _iconForFormat(String format) {
    switch (format) {
      case 'pdf':
        return Icons.picture_as_pdf_outlined;
      case 'doc':
      case 'docx':
        return Icons.description_outlined;
      case 'ppt':
      case 'pptx':
        return Icons.slideshow_outlined;
      case 'xls':
      case 'xlsx':
        return Icons.table_chart_outlined;
      case 'jpg':
      case 'jpeg':
      case 'png':
      case 'gif':
      case 'webp':
        return Icons.image_outlined;
      default:
        return Icons.insert_drive_file_outlined;
    }
  }

  String _formatBytes(int bytes) {
    if (bytes <= 0) return '';
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(0)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
}
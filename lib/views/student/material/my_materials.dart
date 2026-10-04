import 'dart:async';
import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import '/controllers/auth_controller.dart';
import '/controllers/material_controller.dart';
import '/controllers/transaction_controller.dart';
import '/models/material_model.dart';
import '/models/transaction_model.dart';
import 'create_material.dart';
import 'document_viewer.dart';
import 'material_details_sheet.dart';

import 'package:polaris_mobile_app/services/theme_service.dart';

const List<String> _semesters = ['1st Semester', '2nd Semester', 'Summer'];

class _Entry {
  const _Entry(this.material, [this.transaction]);

  final MaterialModel material;
  final TransactionModel? transaction;

  bool get purchased => transaction != null;

  DateTime get date =>
      (purchased ? transaction!.purchasedAt : material.createdAt) ??
      DateTime.now();
}

class _AdvancedFilter {
  const _AdvancedFilter({this.schoolYear, this.semester});

  final String? schoolYear;
  final String? semester;

  bool get isActive => schoolYear != null || semester != null;
}

class MyMaterialsView extends StatefulWidget {
  const MyMaterialsView({super.key});

  @override
  State<MyMaterialsView> createState() => _MyMaterialsViewState();
}

class _MyMaterialsViewState extends State<MyMaterialsView> {
  Color get cream => context.pc.background;
  Color get navy => context.pc.ink;
  Color get mutedColor => context.pc.muted;
  Color get badColor => context.pc.danger;

  // "all" | "private" | "public_free" | "public_paid" | "purchased"
  String _filter = 'all';
  _AdvancedFilter _advanced = const _AdvancedFilter();
  bool _uploading = false;

  final TextEditingController _searchController = TextEditingController();
  String _query = '';

  String? _uid;
  StreamSubscription<List<MaterialModel>>? _ownedSub;
  StreamSubscription<List<TransactionModel>>? _txSub;
  final Map<String, StreamSubscription<MaterialModel?>> _purchasedSubs = {};
  final Map<String, MaterialModel?> _purchasedMaterials = {};

  List<MaterialModel> _owned = [];
  List<TransactionModel> _transactions = [];
  bool _ownedLoaded = false;
  bool _txLoaded = false;
  Object? _ownedError;
  Object? _txError;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    final uid =
        Provider.of<AuthController>(context).currentUserProfile?.userId;

    if (uid != null && uid != _uid) _subscribe(uid);
  }

  @override
  void dispose() {
    _cancelAll();
    _searchController.dispose();
    super.dispose();
  }

  void _cancelAll() {
    _ownedSub?.cancel();
    _txSub?.cancel();
    for (final sub in _purchasedSubs.values) {
      sub.cancel();
    }
    _purchasedSubs.clear();
    _purchasedMaterials.clear();
  }

  void _subscribe(String uid) {
    _uid = uid;
    _cancelAll();

    _owned = [];
    _transactions = [];
    _ownedLoaded = false;
    _txLoaded = false;
    _ownedError = null;
    _txError = null;

    final materials = context.read<MaterialController>();
    final transactions = context.read<TransactionController>();

    _ownedSub = materials.myMaterials(uid).listen(
      (list) {
        if (!mounted) return;
        setState(() {
          _owned = list;
          _ownedLoaded = true;
        });
      },
      onError: (Object e) {
        if (!mounted) return;
        setState(() {
          _ownedError = e;
          _ownedLoaded = true;
        });
      },
    );

    _txSub = transactions.myPurchases(uid).listen(
      (list) {
        if (!mounted) return;
        _syncPurchasedSubs(list, materials);
        setState(() {
          _transactions = list;
          _txLoaded = true;
        });
      },
      onError: (Object e) {
        if (!mounted) return;
        setState(() {
          _txError = e;
          _txLoaded = true;
        });
      },
    );
  }

  void _syncPurchasedSubs(
    List<TransactionModel> transactions,
    MaterialController materials,
  ) {
    final ids = transactions.map((t) => t.materialId).toSet();

    for (final id
        in _purchasedSubs.keys.where((id) => !ids.contains(id)).toList()) {
      _purchasedSubs.remove(id)?.cancel();
      _purchasedMaterials.remove(id);
    }

    for (final id in ids) {
      if (_purchasedSubs.containsKey(id)) continue;

      _purchasedSubs[id] = materials.material(id).listen(
        (m) {
          if (!mounted) return;
          setState(() => _purchasedMaterials[id] = m);
        },
        onError: (Object _) {
          if (!mounted) return;
          setState(() => _purchasedMaterials[id] = null);
        },
      );
    }
  }

  bool _matchesAdvanced(MaterialModel m) {
    if (_advanced.schoolYear != null && m.schoolYear != _advanced.schoolYear) {
      return false;
    }
    if (_advanced.semester != null && m.semester != _advanced.semester) {
      return false;
    }
    return true;
  }

  /// Matches the search text against the material title and course/subject.
  bool _matchesSearch(MaterialModel m) {
    if (_query.isEmpty) return true;
    final haystack = '${m.title} ${m.course}'.toLowerCase();
    return _query
        .split(RegExp(r'\s+'))
        .where((w) => w.isNotEmpty)
        .every(haystack.contains);
  }

  List<_Entry> _purchasedEntries() {
    final seen = <String>{};
    final entries = <_Entry>[];

    for (final t in _transactions) {
      final m = _purchasedMaterials[t.materialId];
      if (m == null || !seen.add(t.materialId)) continue;
      entries.add(_Entry(m, t));
    }

    return entries;
  }

  List<_Entry> _buildEntries() {
    final entries = <_Entry>[];

    if (_filter != 'purchased') {
      for (final m in _owned) {
        if (_filter == 'all' || m.visibility == _filter) {
          entries.add(_Entry(m));
        }
      }
    }

    if (_filter == 'all' || _filter == 'purchased') {
      entries.addAll(_purchasedEntries());
    }

    return entries
        .where((e) => _matchesAdvanced(e.material) && _matchesSearch(e.material))
        .toList()
      ..sort((a, b) => b.date.compareTo(a.date));
  }

  List<String> _availableSchoolYears() {
    final years = <String>{
      ..._owned.map((m) => m.schoolYear),
      ..._purchasedEntries().map((e) => e.material.schoolYear),
    }..removeWhere((y) => y.isEmpty);

    return years.toList()..sort((a, b) => b.compareTo(a));
  }

  Future<void> _openFilterSheet() async {
    final result = await showModalBottomSheet<_AdvancedFilter>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _FilterSheet(
        schoolYears: _availableSchoolYears(),
        initial: _advanced,
      ),
    );

    if (result == null || !mounted) return;
    setState(() => _advanced = result);
  }

  Future<void> _pickAndUploadFile() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: const [
        'pdf',
        'doc',
        'docx',
        'ppt',
        'pptx',
        'jpg',
        'jpeg',
        'png',
      ],
    );

    if (result == null || result.files.single.path == null) return;

    final pickedFile = result.files.single;
    final file = File(pickedFile.path!);
    final filename = pickedFile.name;

    if (!mounted) return;

    final auth = context.read<AuthController>();
    final profile = auth.currentUserProfile;
    final uid = profile?.userId;

    if (uid == null) return;

    final quickInfo = await showModalBottomSheet<Map<String, String>>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _QuickUploadInfoSheet(
        defaultTitle: _stripExtension(filename),
      ),
    );

    if (quickInfo == null || !mounted) return;

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

    setState(() => _uploading = true);

    final materialController = context.read<MaterialController>();
    final newId = await materialController.createFileMaterial(
      ownerId: uid,
      title: quickInfo['title']!,
      file: file,
      filename: filename,
      details: details,
    );

    if (!mounted) return;
    setState(() => _uploading = false);

    if (newId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            materialController.errorMessage ?? 'Could not upload your file.',
          ),
        ),
      );
    }
  }

  String _stripExtension(String filename) {
    final dotIndex = filename.lastIndexOf('.');
    return dotIndex == -1 ? filename : filename.substring(0, dotIndex);
  }

  Widget _buildBody() {
    final needsOwned = _filter != 'purchased';
    final needsTx = _filter == 'all' || _filter == 'purchased';

    final loading = _uid == null ||
        (needsOwned && !_ownedLoaded) ||
        (needsTx && !_txLoaded);

    if (loading) {
      return Center(child: CircularProgressIndicator(color: navy));
    }

    final error = needsOwned ? _ownedError : _txError;

    if (error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            'Could not load materials:\n$error',
            textAlign: TextAlign.center,
            style: TextStyle(color: badColor, fontSize: 13),
          ),
        ),
      );
    }

    final entries = _buildEntries();

    if (entries.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            (_advanced.isActive || _query.isNotEmpty)
                ? 'No materials match your search or filters.'
                : 'No materials here yet.',
            style: TextStyle(color: mutedColor, fontSize: 15),
          ),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 90),
      itemCount: entries.length,
      itemBuilder: (context, index) => _MaterialCard(entry: entries[index]),
    );
  }

  @override
  Widget build(BuildContext context) {
    void select(String v) => setState(() => _filter = v);

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'My Materials',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        actions: [
          IconButton(
            tooltip: 'Filter',
            onPressed: _openFilterSheet,
            icon: Badge(
              smallSize: 8,
              isLabelVisible: _advanced.isActive,
              child: const Icon(Icons.filter_list),
            ),
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: TextField(
              controller: _searchController,
              textInputAction: TextInputAction.search,
              onChanged: (v) => setState(() => _query = v.trim().toLowerCase()),
              decoration: InputDecoration(
                hintText: 'Search by title or course / subject',
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
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _FilterChip(
                    label: 'All',
                    value: 'all',
                    current: _filter,
                    onTap: select,
                  ),
                  const SizedBox(width: 8),
                  _FilterChip(
                    label: 'Private',
                    value: 'private',
                    current: _filter,
                    onTap: select,
                  ),
                  const SizedBox(width: 8),
                  _FilterChip(
                    label: 'Public (Free)',
                    value: 'public_free',
                    current: _filter,
                    onTap: select,
                  ),
                  const SizedBox(width: 8),
                  _FilterChip(
                    label: 'Public (Paid)',
                    value: 'public_paid',
                    current: _filter,
                    onTap: select,
                  ),
                  const SizedBox(width: 8),
                  _FilterChip(
                    label: 'Purchased / Saved',
                    value: 'purchased',
                    current: _filter,
                    onTap: select,
                  ),
                ],
              ),
            ),
          ),
          Expanded(child: _buildBody()),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _uploading ? null : _pickAndUploadFile,
        child: _uploading
            ? SizedBox(
                height: 22,
                width: 22,
                child: CircularProgressIndicator(
                  strokeWidth: 2.5,
                  color: cream,
                ),
              )
            : Icon(Icons.upload_file, color: cream),
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

  @override
  Widget build(BuildContext context) {
    final _pc = context.pc;
    final selected = value == current;

    return ChoiceChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) => onTap(value),
      selectedColor: _pc.accent,
      labelStyle: TextStyle(color: selected ? _pc.background : _pc.ink),
      backgroundColor: _pc.field,
      side: BorderSide.none,
    );
  }
}

class _FilterSheet extends StatefulWidget {
  const _FilterSheet({
    required this.schoolYears,
    required this.initial,
  });

  final List<String> schoolYears;
  final _AdvancedFilter initial;

  @override
  State<_FilterSheet> createState() => _FilterSheetState();
}

class _FilterSheetState extends State<_FilterSheet> {
  String? _schoolYear;
  String? _semester;

  @override
  void initState() {
    super.initState();
    _schoolYear = widget.initial.schoolYear;
    _semester = widget.initial.semester;
  }

  @override
  Widget build(BuildContext context) {
    final _pc = context.pc;

    Widget label(String text) => Padding(
          padding: const EdgeInsets.only(top: 18, bottom: 8),
          child: Text(
            text,
            style: TextStyle(
              fontWeight: FontWeight.w600,
              color: _pc.muted,
              fontSize: 13,
            ),
          ),
        );

    return SafeArea(
      child: Container(
        width: double.infinity,
        decoration: BoxDecoration(
          color: _pc.card,
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
                    color: _pc.ink.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ),
              Text(
                'Filter materials',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: _pc.ink,
                ),
              ),
              label('School year'),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _FilterChip(
                    label: 'Any',
                    value: '',
                    current: _schoolYear ?? '',
                    onTap: (_) => setState(() => _schoolYear = null),
                  ),
                  for (final year in widget.schoolYears)
                    _FilterChip(
                      label: year,
                      value: year,
                      current: _schoolYear ?? '',
                      onTap: (v) => setState(() => _schoolYear = v),
                    ),
                ],
              ),
              label('Semester'),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _FilterChip(
                    label: 'Any',
                    value: '',
                    current: _semester ?? '',
                    onTap: (_) => setState(() => _semester = null),
                  ),
                  for (final semester in _semesters)
                    _FilterChip(
                      label: semester,
                      value: semester,
                      current: _semester ?? '',
                      onTap: (v) => setState(() => _semester = v),
                    ),
                ],
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () =>
                          Navigator.of(context).pop(const _AdvancedFilter()),
                      child: const Text('Clear'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () => Navigator.of(context).pop(
                        _AdvancedFilter(
                          schoolYear: _schoolYear,
                          semester: _semester,
                        ),
                      ),
                      child: const Text(
                        'Apply',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MaterialCard extends StatelessWidget {
  const _MaterialCard({required this.entry});

  final _Entry entry;

  MaterialModel get material => entry.material;

  String get _statusLabel {
    if (entry.purchased) {
      return entry.transaction!.materialPrice > 0 ? 'Purchased' : 'Saved';
    }

    switch (material.visibility) {
      case 'public_free':
        return 'Public · Free';
      case 'public_paid':
        return 'Public · ₱${material.price?.toStringAsFixed(0) ?? '0'}';
      default:
        return 'Private';
    }
  }

  void _handleTap(BuildContext context) {
    // 1) Uploaded files (owned or purchased) -> file viewer.
    if (material.attachments.isNotEmpty) {
      _openAttachments(context);
      return;
    }

    // 2) Your own text material -> editable editor.
    if (!entry.purchased) {
      _openEditor(context);
      return;
    }

    // 3) Purchased / saved text (String) material -> read-only viewer.
    _openReadOnly(context);
  }

  void _openEditor(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => CreateMaterialView(existingMaterial: material),
      ),
    );
  }

  void _openReadOnly(BuildContext context) {
    if (material.content.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('This material has no content to open.')),
      );
      return;
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => CreateMaterialView(
          existingMaterial: material,
          readOnly: true,
        ),
      ),
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
      builder: (_) => _AttachmentPickerSheet(
        attachments: material.attachments,
      ),
    );

    if (selected != null && context.mounted) {
      await _launchAttachment(context, selected);
    }
  }

  Future<void> _launchAttachment(
    BuildContext context,
    Map<String, dynamic> attachment,
  ) async {
    final url = attachment['url'] as String?;

    if (url == null || url.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('This file has no viewable link.')),
      );
      return;
    }

    final filename =
        attachment['original_filename'] as String? ?? material.title;

    var format = (attachment['format'] as String?)?.trim() ?? '';

    if (format.isEmpty) {
      final dotIndex = filename.lastIndexOf('.');

      if (dotIndex != -1 && dotIndex < filename.length - 1) {
        format = filename.substring(dotIndex + 1).toLowerCase();
      }
    }

    await DocumentViewer.open(context, fileUrl: url, format: format);
  }

  Future<void> _editDetails(BuildContext context) async {
    final result = await showModalBottomSheet<Map<String, String>>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => MaterialDetailsSheet(existingMaterial: material),
    );

    if (result == null || !context.mounted) return;

    final materialController = context.read<MaterialController>();
    final success = await materialController.updateDetails(material, result);

    if (!context.mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          success
              ? 'Material details updated.'
              : materialController.errorMessage ?? 'Could not update material details.',
        ),
      ),
    );
  }

  Future<void> _uploadCover(BuildContext context) async {
    final picked = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      maxWidth: 1600,
      imageQuality: 85,
    );

    if (picked == null || !context.mounted) return;

    final materialController = context.read<MaterialController>();

    final success = await materialController.uploadCoverImage(
      material.materialId,
      File(picked.path),
      picked.name,
    );

    if (!context.mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          success
              ? 'Cover image updated.'
              : materialController.errorMessage ??
                  'Could not upload cover image.',
        ),
      ),
    );
  }

  Future<void> _deleteMaterial(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Delete Material?'),
          content: Text(
            'Are you sure you want to delete "${material.title}"?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: Text(
                'Delete',
                style: TextStyle(color: context.pc.danger),
              ),
            ),
          ],
        );
      },
    );

    if (confirmed != true || !context.mounted) return;

    final materialController = context.read<MaterialController>();

    final success =
        await materialController.removeMaterial(material.materialId);

    if (!context.mounted) return;

    if (!success) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            materialController.errorMessage ??
                'Could not remove this material.',
          ),
        ),
      );
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Material deleted.')),
    );
  }

  Widget _buildThumbnail({
    required Color tint,
    required IconData icon,
  }) {
    final url = material.coverImage?['url'] as String?;

    final fallback = Container(
      color: tint.withOpacity(0.15),
      child: Center(child: Icon(icon, color: tint, size: 28)),
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
    final _pc = context.pc;
    final navy = _pc.ink;
    final purple = _pc.accent;
    final gold = _pc.star;
    final mutedColor = _pc.muted;
    final badColor = _pc.danger;

    final hasAttachments = material.attachments.isNotEmpty;

    final term = [material.schoolYear, material.semester]
        .where((s) => s.isNotEmpty)
        .join(' · ');

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () => _handleTap(context),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildThumbnail(
                tint: hasAttachments ? gold : purple,
                icon: hasAttachments ? Icons.attach_file : Icons.notes,
              ),
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
                        color: navy,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (material.course.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        material.course,
                        style: TextStyle(
                          color: navy,
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                    if (term.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        term,
                        style: TextStyle(color: mutedColor, fontSize: 12),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                    const SizedBox(height: 4),
                    Text(
                      _statusLabel,
                      style: TextStyle(
                        color: entry.purchased ? gold : mutedColor,
                        fontSize: 12,
                        fontWeight:
                            entry.purchased ? FontWeight.w600 : FontWeight.w400,
                      ),
                    ),
                    if (!entry.purchased) ...[
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          Icon(
                            Icons.visibility_outlined,
                            size: 14,
                            color: mutedColor,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            '${material.viewCount}',
                            style: TextStyle(fontSize: 12, color: mutedColor),
                          ),
                          const SizedBox(width: 12),
                          Icon(
                            Icons.shopping_bag_outlined,
                            size: 14,
                            color: mutedColor,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            '${material.purchaseCount}',
                            style: TextStyle(fontSize: 12, color: mutedColor),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
              if (!entry.purchased)
                PopupMenuButton<String>(
                  icon: Icon(Icons.more_vert, color: mutedColor),
                  onSelected: (value) {
                    if (value == 'edit') {
                      _editDetails(context);
                    } else if (value == 'cover') {
                      _uploadCover(context);
                    } else if (value == 'delete') {
                      _deleteMaterial(context);
                    }
                  },
                  itemBuilder: (_) => [
                    PopupMenuItem(
                      value: 'edit',
                      child: Row(
                        children: [
                          Icon(Icons.edit_outlined, color: navy),
                          const SizedBox(width: 10),
                          const Text('Edit Details'),
                        ],
                      ),
                    ),
                    PopupMenuItem(
                      value: 'cover',
                      child: Row(
                        children: [
                          Icon(Icons.image_outlined, color: navy),
                          const SizedBox(width: 10),
                          Text(
                            material.coverImage == null
                                ? 'Upload cover image'
                                : 'Change cover image',
                          ),
                        ],
                      ),
                    ),
                    PopupMenuItem(
                      value: 'delete',
                      child: Row(
                        children: [
                          Icon(Icons.delete_outline, color: badColor),
                          const SizedBox(width: 10),
                          Text('Delete', style: TextStyle(color: badColor)),
                        ],
                      ),
                    ),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AttachmentPickerSheet extends StatelessWidget {
  const _AttachmentPickerSheet({required this.attachments});

  final List<Map<String, dynamic>> attachments;

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
    final _pc = context.pc;
    final navy = _pc.ink;
    final cardColor = _pc.card;

    return SafeArea(
      child: Container(
        decoration: BoxDecoration(
          color: cardColor,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
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
            Text(
              'Open which file?',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: navy,
              ),
            ),
            const SizedBox(height: 8),
            ...attachments.map((a) {
              final name = a['original_filename'] as String? ?? 'Attachment';
              final format = a['format'] as String? ?? '';

              return ListTile(
                leading: Icon(_iconFor(format), color: navy),
                title: Text(
                  name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
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

class _QuickUploadInfoSheet extends StatefulWidget {
  const _QuickUploadInfoSheet({required this.defaultTitle});

  final String defaultTitle;

  @override
  State<_QuickUploadInfoSheet> createState() => _QuickUploadInfoSheetState();
}

class _QuickUploadInfoSheetState extends State<_QuickUploadInfoSheet> {
  Color get navy => context.pc.ink;
  Color get cardColor => context.pc.card;

  late final TextEditingController _titleController;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.defaultTitle);
  }

  @override
  void dispose() {
    _titleController.dispose();
    super.dispose();
  }

  void _confirm() {
    if (_titleController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please add a title.')),
      );
      return;
    }

    Navigator.of(context).pop({'title': _titleController.text.trim()});
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
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
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
            Text(
              'Uploading a file',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: navy,
              ),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: _titleController,
              decoration: const InputDecoration(labelText: 'Title'),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                onPressed: _confirm,
                child: const Text(
                  'Next',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
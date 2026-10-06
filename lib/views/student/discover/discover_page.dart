import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '/controllers/auth_controller.dart';
import '/controllers/material_controller.dart';
import '/models/material_model.dart';
import '/models/user_model.dart';
import 'creator_info.dart';
import 'material_detail_page.dart';

import 'package:polaris_mobile_app/services/theme_service.dart';

class DiscoverPage extends StatefulWidget {
  const DiscoverPage({super.key});

  @override
  State<DiscoverPage> createState() => _DiscoverPageState();
}

class _DiscoverPageState extends State<DiscoverPage> {
  Color get cream => context.pc.background;
  Color get navy => context.pc.ink;
  Color get purple => context.pc.accent;
  Color get fieldColor => context.pc.field;


  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  String _selectedSchoolYear = 'All';

  bool _personalizedOn = true;

  Stream<List<MaterialModel>>? _stream;
  String? _streamKey;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Stream<List<MaterialModel>> _resolveStream(
    MaterialController materialController,
    UserModel? profile,
    bool hasProfileScope,
  ) {
    final wantsScope = _personalizedOn && hasProfileScope;
    final key = wantsScope ? '${profile!.university}|${profile.program}' : 'all';

    if (_stream != null && _streamKey == key) return _stream!;

    _streamKey = key;
    _stream = wantsScope
        ? materialController.publicMaterials(university: profile!.university, program: profile.program)
        : materialController.publicMaterials();
    return _stream!;
  }

  @override
  Widget build(BuildContext context) {
    final authController = context.watch<AuthController>();
    final materialController = context.read<MaterialController>();
    final profile = authController.currentUserProfile;

    final hasProfileScope = (profile?.university?.isNotEmpty ?? false) ||
        (profile?.program?.isNotEmpty ?? false);

    final stream = _resolveStream(materialController, profile, hasProfileScope);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Discover',
          style: TextStyle(color: navy, fontWeight: FontWeight.bold),
        ),
      ),
      body: Column(
        children: [
          _buildSearchBar(),
          if (hasProfileScope) _buildPersonalizationBanner(profile!),
          Expanded(
            child: StreamBuilder<List<MaterialModel>>(
              stream: stream,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return Center(child: CircularProgressIndicator(color: purple));
                }
                if (snapshot.hasError) {
                  return Center(
                    child: Text(
                      'Something went wrong loading materials.',
                      style: TextStyle(color: navy.withOpacity(0.7)),
                    ),
                  );
                }

                final materials = snapshot.data ?? [];
                final filtered = _applyFilters(materials);
                final schoolYears = _distinctSchoolYears(materials);

                return Column(
                  children: [
                    _buildSchoolYearFilter(schoolYears),
                    Expanded(
                      child: filtered.isEmpty
                          ? _buildEmptyState(hasProfileScope && _personalizedOn)
                          : _buildResultsGrid(filtered),
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  // ---------- FILTER LOGIC ----------

  List<MaterialModel> _applyFilters(List<MaterialModel> materials) {
    final query = _searchQuery.trim().toLowerCase();

    return materials.where((m) {
      if (_selectedSchoolYear != 'All' && m.schoolYear != _selectedSchoolYear) {
        return false;
      }
      if (query.isEmpty) return true;

      final haystack = [
        m.university,
        m.college,
        m.program,
        m.course,
        m.semester,
        m.professor ?? '',
        m.title,
        m.description ?? '',
      ].join(' ').toLowerCase();

      return haystack.contains(query);
    }).toList();
  }

  List<String> _distinctSchoolYears(List<MaterialModel> materials) {
    final years = materials.map((m) => m.schoolYear).where((y) => y.isNotEmpty).toSet().toList();
    years.sort((a, b) => b.compareTo(a));
    return ['All', ...years];
  }

  // ---------- UI PIECES ----------

  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      child: TextField(
        controller: _searchController,
        onChanged: (value) => setState(() => _searchQuery = value),
        decoration: InputDecoration(
          hintText: 'Search university, course, professor, semester...',
          prefixIcon: Icon(Icons.search, color: purple),
          suffixIcon: _searchQuery.isEmpty
              ? null
              : IconButton(
                  icon: Icon(Icons.close, color: navy),
                  onPressed: () {
                    _searchController.clear();
                    setState(() => _searchQuery = '');
                  },
                ),
          contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 16),
          ),
      ),
    );
  }

  Widget _buildPersonalizationBanner(UserModel profile) {
    final scopeLabel = [profile.program, profile.university]
        .where((s) => s != null && s.isNotEmpty)
        .join(' · ');

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Row(
        children: [
          Expanded(
            child: Text(
              _personalizedOn
                  ? 'Showing materials for $scopeLabel'
                  : 'Showing materials from everyone',
              style: TextStyle(
                color: navy.withOpacity(0.7),
                fontSize: 12.5,
                fontStyle: FontStyle.italic,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          TextButton(
            onPressed: () => setState(() => _personalizedOn = !_personalizedOn),
            style: TextButton.styleFrom(foregroundColor: purple, padding: EdgeInsets.zero),
            child: Text(_personalizedOn ? 'Browse all' : 'Back to my program'),
          ),
        ],
      ),
    );
  }

  Widget _buildSchoolYearFilter(List<String> schoolYears) {
    if (schoolYears.length <= 1) return const SizedBox.shrink();

    return SizedBox(
      height: 40,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: schoolYears.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final year = schoolYears[index];
          final selected = year == _selectedSchoolYear;
          return ChoiceChip(
            label: Text(year),
            selected: selected,
            onSelected: (_) => setState(() => _selectedSchoolYear = year),
            selectedColor: purple,
            backgroundColor: fieldColor,
            labelStyle: TextStyle(color: selected ? cream : navy, fontSize: 12.5),
            side: BorderSide.none,
          );
        },
      ),
    );
  }

  Widget _buildEmptyState(bool isPersonalized) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.search_off, size: 48, color: navy.withOpacity(0.3)),
            const SizedBox(height: 12),
            Text(
              isPersonalized
                  ? 'No materials found for your program yet.\nTry "Browse all" above.'
                  : 'No materials match your search.',
              textAlign: TextAlign.center,
              style: TextStyle(color: navy.withOpacity(0.6)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildResultsGrid(List<MaterialModel> materials) {
    return GridView.builder(
      padding: const EdgeInsets.all(16),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisSpacing: 14,
        crossAxisSpacing: 14,
        childAspectRatio: 0.67,
      ),
      itemCount: materials.length,
      itemBuilder: (context, index) => _MaterialCard(material: materials[index]),
    );
  }
}

/// Result card — tap navigates directly to the material detail page.
class _MaterialCard extends StatelessWidget {
  final MaterialModel material;

  const _MaterialCard({required this.material});


  @override
  Widget build(BuildContext context) {
    final _pc = context.pc;
    final navy = _pc.ink;
    final purple = _pc.accent;
    final gold = _pc.star;
    final cardColor = _pc.card;
    final goodColor = _pc.success;

    final coverUrl = material.coverImage?['url'] as String?;
    final isPaid = material.isPublicPaid;

    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => MaterialDetailPage(materialId: material.materialId),
          ),
        );
      },
      child: Container(
        decoration: BoxDecoration(
          color: cardColor,
          borderRadius: BorderRadius.circular(16),
          ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AspectRatio(
              aspectRatio: 1.4,
              child: coverUrl != null
                  ? Image.network(coverUrl, fit: BoxFit.cover)
                  : Container(
                      color: purple.withOpacity(0.08),
                      child: Icon(
                        Icons.auto_awesome,
                        color: purple.withOpacity(0.4),
                        size: 32,
                      ),
                    ),
            ),
            Padding(
              padding: const EdgeInsets.all(10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    material.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: navy,
                      fontSize: 13.5,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    '${material.course} · ${material.semester}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: navy.withOpacity(0.55), fontSize: 11.5),
                  ),
                  const SizedBox(height: 8),
                  CreatorInfo(ownerId: material.ownerId),
                  const SizedBox(height: 8),
                  if (isPaid)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: gold.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        '₱${material.price?.toStringAsFixed(0) ?? "0"}',
                        style: TextStyle(color: navy, fontSize: 11, fontWeight: FontWeight.w700),
                      ),
                    )
                  else
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: goodColor.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        'Free',
                        style: TextStyle(color: goodColor, fontSize: 11, fontWeight: FontWeight.w700),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
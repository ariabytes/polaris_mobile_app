import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '/controllers/auth_controller.dart';
import '/controllers/material_controller.dart';
import '/models/material_model.dart';
import '/models/user_model.dart';
import 'material_detail_page.dart';

/// Discover tab — browse/search public materials (public_free + public_paid).
/// Lives at lib/views/student/discover/discover_page.dart, alongside
/// material_detail_page.dart and checkout_page.dart.
///
/// PERSONALIZATION: if the logged-in user has filled in their academic
/// profile (university/program, set via My Profile edit), Discover opens
/// already scoped to "materials from my program" — a real Firestore query
/// (MaterialService.streamPublicMaterials(university:, program:)).
///
/// STREAM MEMOIZATION: the underlying Stream<List<MaterialModel>> is cached
/// in _stream and only recreated when the personalization scope actually
/// changes (_personalizedOn toggled, or profile scope changes). Search text
/// and the school year filter are applied client-side against whatever the
/// cached stream already returned, so typing in the search box does NOT
/// resubscribe to Firestore — building a fresh stream every keystroke was
/// tearing down and recreating the live listener constantly, which is what
/// caused the flicker / "Target id not found" churn in logcat.
class DiscoverPage extends StatefulWidget {
  const DiscoverPage({super.key});

  @override
  State<DiscoverPage> createState() => _DiscoverPageState();
}

class _DiscoverPageState extends State<DiscoverPage> {
  static const cream = Color(0xFFFCF6F0);
  static const navy = Color(0xFF252A5A);
  static const purple = Color(0xFF7B5EA7);
  static const gold = Color(0xFFE8B94A);

  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  String _selectedSchoolYear = 'All';

  bool _personalizedOn = true;

  // Memoized stream — only rebuilt when the scope it was built for changes.
  Stream<List<MaterialModel>>? _stream;
  bool? _streamScope;

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

    if (_stream != null && _streamScope == wantsScope) {
      return _stream!;
    }

    _streamScope = wantsScope;
    _stream = wantsScope
        ? materialController.publicMaterials(university: profile!.university, program: profile.program)
        : materialController.publicMaterials();
    return _stream!;
  }

  @override
  Widget build(BuildContext context) {
    final authController = context.watch<AuthController>();
    final materialController = context.watch<MaterialController>();
    final profile = authController.currentUserProfile;

    final hasProfileScope = (profile?.university?.isNotEmpty ?? false) ||
        (profile?.program?.isNotEmpty ?? false);

    final stream = _resolveStream(materialController, profile, hasProfileScope);

    return Scaffold(
      backgroundColor: cream,
      appBar: AppBar(
        backgroundColor: cream,
        elevation: 0,
        title: const Text(
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
                  return const Center(child: CircularProgressIndicator(color: purple));
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
          prefixIcon: const Icon(Icons.search, color: purple),
          suffixIcon: _searchQuery.isEmpty
              ? null
              : IconButton(
                  icon: const Icon(Icons.close, color: navy),
                  onPressed: () {
                    _searchController.clear();
                    setState(() => _searchQuery = '');
                  },
                ),
          filled: true,
          fillColor: Colors.white,
          contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 16),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide.none,
          ),
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
            backgroundColor: Colors.white,
            labelStyle: TextStyle(color: selected ? Colors.white : navy, fontSize: 12.5),
            side: BorderSide(color: purple.withOpacity(0.3)),
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
        childAspectRatio: 0.72,
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

  static const navy = Color(0xFF252A5A);
  static const purple = Color(0xFF7B5EA7);
  static const gold = Color(0xFFE8B94A);

  @override
  Widget build(BuildContext context) {
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
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(color: navy.withOpacity(0.06), blurRadius: 8, offset: const Offset(0, 3)),
          ],
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
                        Icons.description_outlined,
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
                    style: const TextStyle(
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
                  const SizedBox(height: 6),
                  if (isPaid)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: gold.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        '₱${material.price?.toStringAsFixed(0) ?? "0"}',
                        style: const TextStyle(color: navy, fontSize: 11, fontWeight: FontWeight.w700),
                      ),
                    )
                  else
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: Colors.green.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: const Text(
                        'Free',
                        style: TextStyle(color: Colors.green, fontSize: 11, fontWeight: FontWeight.w700),
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
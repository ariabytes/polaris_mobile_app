import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '/controllers/auth_controller.dart';
import '/controllers/material_controller.dart';
import '/controllers/transaction_controller.dart';
import '/models/user_model.dart';
import 'edit_profile.dart';


import 'package:polaris_mobile_app/services/theme_service.dart';
class StudentProfileView extends StatefulWidget {
  const StudentProfileView({super.key});

  @override
  State<StudentProfileView> createState() => _StudentProfileViewState();
}

class _StudentProfileViewState extends State<StudentProfileView> {
  Color get cream => context.pc.background;
  Color get navy => context.pc.ink;
  Color get purple => context.pc.accent;
  Color get gold => context.pc.star;
  Color get cardColor => context.pc.card;
  Color get mutedColor => context.pc.muted;


  bool _dialogShown = false;

  bool _isProfileIncomplete(UserModel profile) {
    return profile.university == null ||
        profile.university!.isEmpty ||
        profile.program == null ||
        profile.program!.isEmpty ||
        profile.yearLevel == null ||
        profile.yearLevel!.isEmpty;
  }

  void _maybeShowIncompleteDialog(UserModel profile) {
    if (_dialogShown) return;
    if (!_isProfileIncomplete(profile)) return;

    _dialogShown = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _showIncompleteProfileDialog(context);
    });
  }

  void _showIncompleteProfileDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (dialogContext) {
        return Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.symmetric(horizontal: 32),
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Container(
                padding: const EdgeInsets.fromLTRB(24, 40, 24, 24),
                decoration: BoxDecoration(
                  color: cardColor,
                  borderRadius: BorderRadius.circular(24),
                  ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(18),
                      decoration: BoxDecoration(
                        color: gold.withOpacity(0.15),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.person_search_rounded,
                        size: 56,
                        color: navy,
                      ),
                    ),
                    const SizedBox(height: 18),
                    Text(
                      'Oop! Nothing here.',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: navy,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Finish your profile now!',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 14,
                        color: mutedColor,
                      ),
                    ),
                    const SizedBox(height: 22),
                    SizedBox(
                      width: double.infinity,
                      height: 46,
                      child: ElevatedButton(
                        onPressed: () {
                          Navigator.of(dialogContext).pop();
                          _goToEditProfile(context);
                        },
                        child: const Text(
                          'Edit Profile',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Positioned(
                top: -12,
                right: -12,
                child: GestureDetector(
                  onTap: () => Navigator.of(dialogContext).pop(),
                  child: Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: navy,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(Icons.close, size: 18, color: cream),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _goToEditProfile(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const EditProfileView()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.read<AuthController>();
    final uid = auth.currentUserProfile?.userId;

    return Scaffold(
      appBar: AppBar(
        leading: const ThemeToggleButton(),
        title: const Text('My Profile', style: TextStyle(fontWeight: FontWeight.bold)),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () => auth.logout(),
          ),
        ],
      ),
      body: StreamBuilder<UserModel?>(
        stream: auth.currentUserProfileStream,
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return Center(child: CircularProgressIndicator(color: navy));
          }

          final profile = snapshot.data!;
          _maybeShowIncompleteDialog(profile);

          final photoUrl = profile.profilePhoto?['url'] as String?;

          return ListView(
            padding: const EdgeInsets.all(20),
            children: [
              Row(
                children: [
                  CircleAvatar(
                    radius: 44,
                    backgroundColor: purple.withOpacity(0.2),
                    backgroundImage: photoUrl != null ? NetworkImage(photoUrl) : null,
                    child: photoUrl == null
                        ? Icon(Icons.person, size: 44, color: navy)
                        : null,
                  ),
                  const SizedBox(width: 18),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          profile.name,
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 22,
                            color: navy,
                          ),
                        ),
                        const SizedBox(height: 4),
                        if (profile.program != null && profile.yearLevel != null)
                          Text(
                            '${profile.program} • ${profile.yearLevel}',
                            style: TextStyle(color: mutedColor, fontSize: 14),
                          ),
                        if (profile.bio != null && profile.bio!.isNotEmpty) ...[
                          const SizedBox(height: 6),
                          Text(
                            profile.bio!,
                            style: TextStyle(
                              color: mutedColor,
                              fontSize: 13,
                              fontStyle: FontStyle.italic,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 20),

              if (uid != null) _StatsStrip(uid: uid),

              const SizedBox(height: 20),

              Card(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                child: Column(
                  children: [
                    ListTile(
                      leading: Icon(Icons.email_outlined, color: navy),
                      title: const Text('Email'),
                      subtitle: Text(profile.email),
                    ),
                    ListTile(
                      leading: Icon(Icons.school_outlined, color: navy),
                      title: const Text('University'),
                      subtitle: Text(profile.university ?? 'Not set'),
                    ),
                    ListTile(
                      leading: Icon(Icons.apartment_outlined, color: navy),
                      title: const Text('Department'),
                      subtitle: Text(profile.college ?? 'Not set'),
                    ),
                    ListTile(
                      leading: Icon(Icons.menu_book_outlined, color: navy),
                      title: const Text('Program'),
                      subtitle: Text(profile.program ?? 'Not set'),
                    ),
                    ListTile(
                      leading: Icon(Icons.cake_outlined, color: navy),
                      title: const Text('Birthday'),
                      subtitle: Text(
                        profile.birthday != null
                            ? '${profile.birthday!.month}/${profile.birthday!.day}/${profile.birthday!.year}'
                            : 'Not set',
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 20),

              SizedBox(
                width: double.infinity,
                height: 48,
                child: OutlinedButton.icon(
                  onPressed: () => _goToEditProfile(context),
                  icon: Icon(Icons.edit_outlined, color: navy),
                  label: Text('Edit Profile', style: TextStyle(color: navy)),
                  ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _StatsStrip extends StatelessWidget {
  const _StatsStrip({required this.uid});

  final String uid;


  @override
  Widget build(BuildContext context) {
    final _pc = context.pc;
    final navy = _pc.ink;
    final purple = _pc.accent;
    final gold = _pc.star;

    final materialController = context.read<MaterialController>();
    final transactionController = context.read<TransactionController>();

    return StreamBuilder<List<dynamic>>(
      stream: materialController.myMaterials(uid),
      builder: (context, materialSnap) {
        final materials = materialSnap.data ?? [];
        final materialCount = materials.length;
        final totalViews = materials.fold<int>(
          0,
          (sum, m) => sum + (m.viewCount as int? ?? 0),
        );

        return StreamBuilder<double>(
          stream: transactionController.sellerTotalEarnings(uid),
          builder: (context, earningsSnap) {
            final earnings = earningsSnap.data ?? 0;
            final earningsDisplay = earningsSnap.hasError
                ? '⚠️'
                : '₱${earnings.toStringAsFixed(0)}';

            return Row(
              children: [
                Expanded(child: _StatCard(label: 'Materials', value: '$materialCount', color: navy)),
                const SizedBox(width: 10),
                Expanded(child: _StatCard(label: 'Views', value: '$totalViews', color: purple)),
                const SizedBox(width: 10),
                Expanded(
                  child: _StatCard(
                    label: 'Earnings',
                    value: earningsDisplay,
                    color: gold,
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({required this.label, required this.value, required this.color});

  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final _pc = context.pc;
    final cardColor = _pc.card;
    final mutedColor = _pc.muted;

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        children: [
          Text(
            value,
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: color),
          ),
          const SizedBox(height: 2),
          Text(label, style: TextStyle(fontSize: 12, color: mutedColor)),
        ],
      ),
    );
  }
}
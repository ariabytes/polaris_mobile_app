import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../controllers/auth_controller.dart';
import '../../../models/user_model.dart';

import 'package:polaris_mobile_app/services/theme_service.dart';
class AdminAccountsView extends StatelessWidget {
  const AdminAccountsView({super.key});


  @override
  Widget build(BuildContext context) {
    final authController = context.read<AuthController>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Accounts', style: TextStyle(fontWeight: FontWeight.bold)),
      ),
      body: StreamBuilder<List<UserModel>>(
        stream: authController.allUsers(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('Could not load users.\n${snapshot.error}'));
          }

          final users = snapshot.data ?? [];
          if (users.isEmpty) {
            return const Center(child: Text('No users yet.'));
          }

          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: users.length,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (context, index) => _UserTile(user: users[index]),
          );
        },
      ),
    );
  }
}

class _UserTile extends StatelessWidget {
  const _UserTile({required this.user});

  final UserModel user;


  Future<void> _confirmDelete(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete this user?'),
        content: Text(
          'This permanently deletes ${user.name}\'s profile and their materials '
          'from Firestore. Materials that other students already bought or '
          'saved stay available to those buyers. All transaction records are '
          'kept, so their purchase history and earnings total come back if '
          'they sign in again.\n\n'
          'Note: their login account itself is not deleted — that requires '
          'a Cloud Function this app doesn\'t have yet. They can still log in '
          '(they can\'t register again with the same email) and will get a '
          'blank student profile.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(foregroundColor: context.pc.danger),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed != true || !context.mounted) return;

    final authController = context.read<AuthController>();
    final success = await authController.deleteUser(user.userId);

    if (!context.mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          success ? 'User deleted.' : (authController.errorMessage ?? 'Could not delete user.'),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final pc = context.pc;

    final photoUrl = user.profilePhoto?['url'] as String?;
    final hasPhoto = photoUrl != null && photoUrl.isNotEmpty;

    final name = user.name.trim().isNotEmpty ? user.name.trim() : 'Unnamed user';

    final school = [user.university, user.program]
        .where((s) => s != null && s.trim().isNotEmpty)
        .map((s) => s!.trim())
        .join(' · ');

    final roleColor = user.isAdmin ? pc.star : pc.accent;

    return Card(
      color: pc.card,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 12, 6, 12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            CircleAvatar(
              radius: 24,
              backgroundColor: pc.ink.withOpacity(0.1),
              backgroundImage: hasPhoto ? NetworkImage(photoUrl) : null,
              child: hasPhoto
                  ? null
                  : Text(
                      name[0].toUpperCase(),
                      style: TextStyle(
                        color: pc.ink,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 15,
                            color: pc.ink,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: roleColor.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          user.role,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: roleColor,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    user.email,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 12.5, color: pc.muted),
                  ),
                  if (school.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      school,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 12, color: pc.muted),
                    ),
                  ],
                ],
              ),
            ),
            IconButton(
              tooltip: 'Delete user',
              icon: Icon(Icons.delete_outline, color: pc.danger),
              onPressed: () => _confirmDelete(context),
            ),
          ],
        ),
      ),
    );
  }
}
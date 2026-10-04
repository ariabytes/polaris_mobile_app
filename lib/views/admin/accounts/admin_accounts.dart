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
          'This permanently deletes ${user.name}\'s profile from Firestore.\n\n'
          'Note: their login account itself is not deleted — that requires '
          'a Cloud Function this app doesn\'t have yet, so they could still '
          'sign in afterwards.',
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
    final _pc = context.pc;
    final navy = _pc.ink;
    final cardColor = _pc.card;
    final badColor = _pc.danger;

    final photoUrl = user.profilePhoto?['url'] as String?;

    return Card(
      color: cardColor,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: navy.withOpacity(0.1),
          backgroundImage: photoUrl != null ? NetworkImage(photoUrl) : null,
          child: photoUrl == null
              ? Text(user.name.isNotEmpty ? user.name[0].toUpperCase() : '?')
              : null,
        ),
        title: Text(user.name, style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Text('${user.email}\n${user.role}'),
        isThreeLine: true,
        trailing: IconButton(
          icon: Icon(Icons.delete_outline, color: badColor),
          onPressed: () => _confirmDelete(context),
        ),
      ),
    );
  }
}
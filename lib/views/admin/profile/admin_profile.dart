import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../controllers/auth_controller.dart';
import 'admin_edit_profile.dart';

class AdminProfileView extends StatelessWidget {
  const AdminProfileView({super.key});

  static const Color cream = Color(0xFFFEEFDD);
  static const Color orange = Color(0xFFF87C4F);
  static const Color navy = Color(0xFF252A5A);

  @override
  Widget build(BuildContext context) {
    final authController = context.watch<AuthController>();
    final profile = authController.currentUserProfile;

    return Scaffold(
      backgroundColor: cream,
      appBar: AppBar(
        backgroundColor: orange,
        foregroundColor: Colors.white,
        title: const Text('Profile', style: TextStyle(fontWeight: FontWeight.bold)),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit_outlined),
            tooltip: 'Edit profile',
            onPressed: profile == null
                ? null
                : () {
                    Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const AdminEditProfileView()),
                    );
                  },
          ),
        ],
      ),
      body: profile == null
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(24),
              children: [
                Center(
                  child: CircleAvatar(
                    radius: 40,
                    backgroundColor: navy.withOpacity(0.1),
                    backgroundImage: profile.profilePhoto?['url'] != null
                        ? NetworkImage(profile.profilePhoto!['url'] as String)
                        : null,
                    child: profile.profilePhoto?['url'] == null
                        ? Text(
                            profile.name.isNotEmpty ? profile.name[0].toUpperCase() : '?',
                            style: const TextStyle(fontSize: 28),
                          )
                        : null,
                  ),
                ),
                const SizedBox(height: 16),
                Center(
                  child: Text(
                    profile.name,
                    style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                ),
                Center(
                  child: Text(profile.email, style: const TextStyle(color: Colors.black54)),
                ),
                const SizedBox(height: 8),
                Center(
                  child: Chip(
                    label: const Text('Admin'),
                    backgroundColor: orange.withOpacity(0.15),
                    labelStyle: const TextStyle(color: orange, fontWeight: FontWeight.bold),
                  ),
                ),
                const SizedBox(height: 32),
                OutlinedButton.icon(
                  onPressed: () => authController.logout(),
                  icon: const Icon(Icons.logout, color: Colors.red),
                  label: const Text('Log out', style: TextStyle(color: Colors.red)),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: Colors.red),
                    minimumSize: const Size.fromHeight(48),
                  ),
                ),
              ],
            ),
    );
  }
}
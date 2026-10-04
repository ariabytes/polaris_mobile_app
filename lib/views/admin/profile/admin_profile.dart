import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../controllers/auth_controller.dart';
import 'admin_edit_profile.dart';

import 'package:polaris_mobile_app/services/theme_service.dart';
class AdminProfileView extends StatelessWidget {
  const AdminProfileView({super.key});


  @override
  Widget build(BuildContext context) {
    final _pc = context.pc;
    final navy = _pc.ink;
    final orange = _pc.accent;
    final mutedColor = _pc.muted;
    final badColor = _pc.danger;

    final authController = context.watch<AuthController>();
    final profile = authController.currentUserProfile;

    return Scaffold(
      appBar: AppBar(
        leading: const ThemeToggleButton(),
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
                  child: Text(profile.email, style: TextStyle(color: mutedColor)),
                ),
                const SizedBox(height: 8),
                Center(
                  child: Chip(
                    label: const Text('Admin'),
                    backgroundColor: orange.withOpacity(0.15),
                    labelStyle: TextStyle(color: orange, fontWeight: FontWeight.bold),
                  ),
                ),
                const SizedBox(height: 32),
                OutlinedButton.icon(
                  onPressed: () => authController.logout(),
                  icon: Icon(Icons.logout, color: badColor),
                  label: Text('Log out', style: TextStyle(color: badColor)),
                  style: OutlinedButton.styleFrom(
                    side: BorderSide(color: badColor),
                    minimumSize: const Size.fromHeight(48),
                  ),
                ),
              ],
            ),
    );
  }
}
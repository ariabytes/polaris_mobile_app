import 'package:flutter/material.dart';
import 'package:polaris_mobile_app/controllers/auth_controller.dart';
import 'package:provider/provider.dart';

class StudentHomepage extends StatelessWidget {
  const StudentHomepage({super.key});

  static const Color cream = Color(0xFFFCF6F0);
  static const Color navy = Color(0xFF252A5A);
  static const Color purple = Color(0xFF7B5EA7);
  static const Color gold = Color(0xFFE8B94A);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: cream,
      appBar: AppBar(
        backgroundColor: navy,
        foregroundColor: Colors.white,
        title: const Text(
          'Student Home',
          style: TextStyle(
            fontWeight: FontWeight.bold,
          ),
        ),
        actions: [
          IconButton(
            onPressed: () async {
              await context.read<AuthController>().logout();
            },
            icon: const Icon(Icons.logout),
          ),
        ],
      ),
      body: const Center(
        child: Text(
          'Student Homepage',
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: navy,
          ),
        ),
      ),
    );
  }
}
import 'package:flutter/material.dart';
import 'package:polaris_mobile_app/controllers/auth_controller.dart';
import 'package:provider/provider.dart';

class StudentHomepage extends StatelessWidget {
  const StudentHomepage({super.key});

  static const Color cream = Color(0xFFFEEFDD);
  static const Color orange = Color(0xFFF87C4F);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: cream,
      appBar: AppBar(
        backgroundColor: orange,
        foregroundColor: Colors.white,
        title: const Text(
          'Student Home',
          style: TextStyle(
            fontWeight: FontWeight.bold,
          ),
        ),
        actions: [
          IconButton(onPressed: () async {
            await context.read<AuthController>().logout();
          }, icon: const Icon(Icons.logout))
        ],
      ),
      body: const Center(
        child: Text(
          'Student Homepage',
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }
}
import 'package:flutter/material.dart';

class AdminHomepage extends StatelessWidget {
  const AdminHomepage({super.key});

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
          'Admin Dashboard',
          style: TextStyle(
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: const Center(
        child: Text(
          'Admin Homepage',
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }
}
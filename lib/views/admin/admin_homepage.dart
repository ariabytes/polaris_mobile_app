import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../controllers/auth_controller.dart';
import '../../controllers/material_controller.dart';
import '../../controllers/transaction_controller.dart';
import 'transactions/admin_transactions.dart';

class AdminHomepage extends StatelessWidget {
  const AdminHomepage({super.key});

  static const Color cream = Color(0xFFFEEFDD);
  static const Color orange = Color(0xFFF87C4F);
  static const Color navy = Color(0xFF252A5A);

  @override
  Widget build(BuildContext context) {
    // read(), not watch() — we only need these controllers to hand us their
    // Streams below; we don't want this whole page rebuilding every time
    // e.g. isSaving flips on an unrelated screen sharing the same instance.
    final authController = context.read<AuthController>();
    final materialController = context.read<MaterialController>();
    final transactionController = context.read<TransactionController>();

    void openTransactions() {
      Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => const AdminTransactionsView()),
      );
    }

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
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _StatCard(
            icon: Icons.people_alt_outlined,
            label: 'Total Users',
            color: navy,
            stream: authController.allUsers().map((users) => users.length.toString()),
          ),
          const SizedBox(height: 12),
          _StatCard(
            icon: Icons.folder_outlined,
            label: 'Total Materials',
            color: navy,
            stream: materialController
                .allMaterialsAdmin()
                .map((materials) => materials.length.toString()),
          ),
          const SizedBox(height: 12),
          // Tappable — opens the full transactions list.
          _StatCard(
            icon: Icons.receipt_long_outlined,
            label: 'Total Transactions',
            color: navy,
            stream: transactionController.allTransactions().map((tx) => tx.length.toString()),
            onTap: openTransactions,
          ),
          const SizedBox(height: 12),
          // Also tappable — same destination, since "how much have we made"
          // and "show me the transactions" are the same follow-up question.
          _StatCard(
            icon: Icons.payments_outlined,
            label: 'Platform Earnings',
            color: orange,
            stream: transactionController
                .totalPlatformEarnings()
                .map((total) => '₱${total.toStringAsFixed(2)}'),
            onTap: openTransactions,
          ),
        ],
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.icon,
    required this.label,
    required this.color,
    required this.stream,
    this.onTap,
  });

  final IconData icon;
  final String label;
  final Color color;
  final Stream<String> stream;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      color: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              CircleAvatar(
                backgroundColor: color.withOpacity(0.12),
                child: Icon(icon, color: color),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Text(
                  label,
                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500),
                ),
              ),
              StreamBuilder<String>(
                stream: stream,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    );
                  }
                  if (snapshot.hasError) {
                    return const Text('—', style: TextStyle(fontSize: 18));
                  }
                  return Text(
                    snapshot.data ?? '—',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: color,
                    ),
                  );
                },
              ),
              if (onTap != null) ...[
                const SizedBox(width: 4),
                const Icon(Icons.chevron_right, color: Colors.black26),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
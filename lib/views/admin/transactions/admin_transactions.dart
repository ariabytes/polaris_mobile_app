import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../controllers/auth_controller.dart';
import '../../../controllers/transaction_controller.dart';
import '../../../models/transaction_model.dart';
import '../../../models/user_model.dart';

class AdminTransactionsView extends StatelessWidget {
  const AdminTransactionsView({super.key});

  static const Color cream = Color(0xFFFEEFDD);
  static const Color orange = Color(0xFFF87C4F);

  @override
  Widget build(BuildContext context) {
    final authController = context.read<AuthController>();
    final transactionController = context.read<TransactionController>();

    return Scaffold(
      backgroundColor: cream,
      appBar: AppBar(
        backgroundColor: orange,
        foregroundColor: Colors.white,
        title: const Text('Transactions', style: TextStyle(fontWeight: FontWeight.bold)),
      ),
      // Nested StreamBuilder: outer resolves buyer/seller names from the
      // users list, inner streams the transactions themselves. If the
      // users stream hasn't emitted yet, usersById is just empty and tiles
      // fall back to showing raw IDs until it catches up.
      body: StreamBuilder<List<UserModel>>(
        stream: authController.allUsers(),
        builder: (context, usersSnapshot) {
          final usersById = <String, UserModel>{
            for (final u in usersSnapshot.data ?? const <UserModel>[]) u.userId: u,
          };

          return StreamBuilder<List<TransactionModel>>(
            stream: transactionController.allTransactions(),
            builder: (context, txSnapshot) {
              if (txSnapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              if (txSnapshot.hasError) {
                return Center(child: Text('Could not load transactions.\n${txSnapshot.error}'));
              }

              final transactions = txSnapshot.data ?? [];
              if (transactions.isEmpty) {
                return const Center(child: Text('No transactions yet.'));
              }

              return ListView.separated(
                padding: const EdgeInsets.all(16),
                itemCount: transactions.length,
                separatorBuilder: (_, __) => const SizedBox(height: 8),
                itemBuilder: (context, index) => _TransactionTile(
                  transaction: transactions[index],
                  usersById: usersById,
                ),
              );
            },
          );
        },
      ),
    );
  }
}

class _TransactionTile extends StatelessWidget {
  const _TransactionTile({required this.transaction, required this.usersById});

  final TransactionModel transaction;
  final Map<String, UserModel> usersById;

  static const Color navy = Color(0xFF252A5A);

  String _nameFor(String uid) => usersById[uid]?.name ?? uid;

  String _formatDate(DateTime? dt) {
    if (dt == null) return 'Pending';
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    final hour12 = dt.hour % 12 == 0 ? 12 : dt.hour % 12;
    final period = dt.hour >= 12 ? 'PM' : 'AM';
    final minute = dt.minute.toString().padLeft(2, '0');
    return '${months[dt.month - 1]} ${dt.day}, ${dt.year} • $hour12:$minute $period';
  }

  @override
  Widget build(BuildContext context) {
    final isFree = transaction.paymentMethod == 'Free';
    final isCompleted = transaction.status == 'completed';

    return Card(
      elevation: 0,
      color: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    '${_nameFor(transaction.buyerId)} → ${_nameFor(transaction.sellerId)}',
                    style: const TextStyle(fontWeight: FontWeight.w600),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  isFree ? 'Free' : '₱${transaction.materialPrice.toStringAsFixed(2)}',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: isFree ? Colors.grey.shade600 : navy,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              _formatDate(transaction.purchasedAt),
              style: const TextStyle(fontSize: 12, color: Colors.black54),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 4,
              children: [
                Chip(
                  label: Text(transaction.status),
                  visualDensity: VisualDensity.compact,
                  backgroundColor: isCompleted
                      ? Colors.green.withOpacity(0.12)
                      : Colors.orange.withOpacity(0.12),
                  labelStyle: TextStyle(
                    fontSize: 12,
                    color: isCompleted ? Colors.green.shade800 : Colors.orange.shade800,
                  ),
                ),
                Chip(
                  label: Text(transaction.paymentMethod),
                  visualDensity: VisualDensity.compact,
                  backgroundColor: navy.withOpacity(0.08),
                  labelStyle: const TextStyle(fontSize: 12, color: navy),
                ),
                if (!isFree)
                  Chip(
                    label: Text('Fee ₱${transaction.platformFee.toStringAsFixed(2)}'),
                    visualDensity: VisualDensity.compact,
                    backgroundColor: Colors.grey.withOpacity(0.12),
                    labelStyle: const TextStyle(fontSize: 12, color: Colors.black87),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
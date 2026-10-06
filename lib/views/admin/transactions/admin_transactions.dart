import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../controllers/auth_controller.dart';
import '../../../controllers/transaction_controller.dart';
import '../../../models/transaction_model.dart';
import '../../../models/user_model.dart';

import 'package:polaris_mobile_app/services/theme_service.dart';
class AdminTransactionsView extends StatelessWidget {
  const AdminTransactionsView({super.key});


  @override
  Widget build(BuildContext context) {
    final authController = context.read<AuthController>();
    final transactionController = context.read<TransactionController>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Transactions', style: TextStyle(fontWeight: FontWeight.bold)),
      ),
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
    final _pc = context.pc;
    final navy = _pc.ink;
    final gold = _pc.star;
    final cardColor = _pc.card;
    final mutedColor = _pc.muted;
    final goodColor = _pc.success;

    final isFree = transaction.paymentMethod == 'Free';
    final isCompleted = transaction.status == 'completed';

    return Card(
      color: cardColor,
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
                    color: isFree ? mutedColor : navy,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              _formatDate(transaction.purchasedAt),
              style: TextStyle(fontSize: 12, color: mutedColor),
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
                      ? goodColor.withOpacity(0.12)
                      : gold.withOpacity(0.12),
                  labelStyle: TextStyle(
                    fontSize: 12,
                    color: isCompleted ? goodColor : gold,
                  ),
                ),
                Chip(
                  label: Text(transaction.paymentMethod),
                  visualDensity: VisualDensity.compact,
                  backgroundColor: navy.withOpacity(0.08),
                  labelStyle: TextStyle(fontSize: 12, color: navy),
                ),
                if (!isFree)
                  Chip(
                    label: Text('Fee ₱${transaction.platformFee.toStringAsFixed(2)}'),
                    visualDensity: VisualDensity.compact,
                    backgroundColor: mutedColor.withOpacity(0.12),
                    labelStyle: TextStyle(fontSize: 12, color: navy),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
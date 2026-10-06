import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '/controllers/auth_controller.dart';
import '/controllers/material_controller.dart';
import '/controllers/transaction_controller.dart';
import '/models/material_model.dart';
import '/models/transaction_model.dart';
import '/models/user_model.dart';
import 'material/create_material.dart';
import 'material/material_preview_sheet.dart';

import 'package:polaris_mobile_app/services/theme_service.dart';

const int _homeLimit = 4;

class StudentHomepage extends StatelessWidget {
  const StudentHomepage({super.key});

  @override
  Widget build(BuildContext context) {
    final _pc = context.pc;
    final navy = _pc.ink;
    final mutedColor = _pc.muted;

    final auth = context.read<AuthController>();

    return Scaffold(
      body: SafeArea(
        child: StreamBuilder<UserModel?>(
          stream: auth.currentUserProfileStream,
          builder: (context, snapshot) {
            final profile = snapshot.data;
            final firstName = (profile?.name.isNotEmpty ?? false)
                ? profile!.name.split(' ').first
                : 'there';

            return ListView(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Text(
                        'Hi, $firstName! 👋',
                        style: TextStyle(
                          fontSize: 26,
                          fontWeight: FontWeight.bold,
                          color: navy,
                        ),
                      ),
                    ),
                    const ThemeToggleButton(),
                  ],
                ),
                Text(
                  'Ready to catch up on your materials?',
                  style: TextStyle(fontSize: 14, color: mutedColor),
                ),
                const SizedBox(height: 24),
                if (profile != null) ...[
                  const _SectionHeader(title: 'My Materials'),
                  const SizedBox(height: 10),
                  _MyMaterialsGrid(ownerId: profile.userId),
                  const SizedBox(height: 26),
                  const _SectionHeader(title: 'Purchased Materials'),
                  const SizedBox(height: 10),
                  _PurchasedMaterialsGrid(buyerId: profile.userId),
                ] else
                  Padding(
                    padding: const EdgeInsets.only(top: 40),
                    child: Center(child: CircularProgressIndicator(color: navy)),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title});
  final String title;

  @override
  Widget build(BuildContext context) {
    final _pc = context.pc;
    final navy = _pc.ink;

    return Text(
      title,
      style: TextStyle(
        fontSize: 17,
        fontWeight: FontWeight.bold,
        color: navy,
      ),
    );
  }
}

const _gridDelegate = SliverGridDelegateWithFixedCrossAxisCount(
  crossAxisCount: 2,
  crossAxisSpacing: 12,
  mainAxisSpacing: 12,
  childAspectRatio: 0.82,
);

class _MyMaterialsGrid extends StatelessWidget {
  const _MyMaterialsGrid({required this.ownerId});
  final String ownerId;

  @override
  Widget build(BuildContext context) {
    final _pc = context.pc;
    final navy = _pc.ink;

    final materialController = context.read<MaterialController>();

    return StreamBuilder<List<MaterialModel>>(
      stream: materialController.myMaterials(ownerId),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 24),
            child: Center(child: CircularProgressIndicator(color: navy)),
          );
        }

        if (snapshot.hasError) {
          return const _EmptyRow(
            icon: Icons.error_outline,
            message: 'Could not load your materials right now.',
          );
        }

        final materials = (snapshot.data ?? []).take(_homeLimit).toList();

        if (materials.isEmpty) {
          return const _EmptyRow(
            icon: Icons.note_add_outlined,
            message: "You haven't added any materials yet.",
          );
        }

        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: _gridDelegate,
          itemCount: materials.length,
          itemBuilder: (context, index) {
            final m = materials[index];
            return _MaterialCard(
              title: m.title,
              subtitle: m.course,
              coverUrl: m.coverImage?['url'] as String?,
              trailingLabel: m.isPublicPaid
                  ? '₱${m.price?.toStringAsFixed(0) ?? '0'}'
                  : (m.isPublicFree ? 'Free' : 'Private'),
              onTap: () {
                if (m.attachments.isNotEmpty) {
                  MaterialPreviewSheet.show(context, m);
                } else {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => CreateMaterialView(existingMaterial: m),
                    ),
                  );
                }
              },
            );
          },
        );
      },
    );
  }
}

class _PurchasedMaterialsGrid extends StatelessWidget {
  const _PurchasedMaterialsGrid({required this.buyerId});
  final String buyerId;

  void _openPurchased(BuildContext context, MaterialModel m) {
    if (m.attachments.isNotEmpty) {
      MaterialPreviewSheet.show(context, m);
      return;
    }

    if (m.content.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('This material has no content to open.')),
      );
      return;
    }

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => CreateMaterialView(
          existingMaterial: m,
          readOnly: true,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final _pc = context.pc;
    final navy = _pc.ink;

    final transactionController = context.read<TransactionController>();
    final materialController = context.read<MaterialController>();

    return StreamBuilder<List<TransactionModel>>(
      stream: transactionController.myPurchases(buyerId),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 24),
            child: Center(child: CircularProgressIndicator(color: navy)),
          );
        }

        if (snapshot.hasError) {
          // Likely cause: missing Firestore composite index for
          // transactions(buyer_id, purchased_at). Check the debug console
          // for a "FAILED_PRECONDITION" error with a link to create it, or
          // add it manually in the Firestore console under Indexes.
          return const _EmptyRow(
            icon: Icons.error_outline,
            message: 'Could not load your purchases right now.',
          );
        }

        final purchases = (snapshot.data ?? []).take(_homeLimit).toList();

        if (purchases.isEmpty) {
          return const _EmptyRow(
            icon: Icons.shopping_bag_outlined,
            message: "You haven't purchased anything yet.",
          );
        }

        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: _gridDelegate,
          itemCount: purchases.length,
          itemBuilder: (context, index) {
            final t = purchases[index];
            return StreamBuilder<MaterialModel?>(
              stream: materialController.material(t.materialId),
              builder: (context, matSnap) {
                if (matSnap.connectionState == ConnectionState.waiting) {
                  return const _MaterialCardSkeleton();
                }

                final m = matSnap.data;

                if (m == null) {
                  return const _MaterialCard(
                    title: 'No longer available',
                    subtitle: null,
                    coverUrl: null,
                    trailingLabel: null,
                  );
                }

                return _MaterialCard(
                  title: m.title,
                  subtitle: m.course,
                  coverUrl: m.coverImage?['url'] as String?,
                  trailingLabel: t.materialPrice > 0
                      ? '₱${t.materialPrice.toStringAsFixed(0)}'
                      : 'Free',
                  onTap: () => _openPurchased(context, m),
                );
              },
            );
          },
        );
      },
    );
  }
}

class _MaterialCard extends StatelessWidget {
  const _MaterialCard({
    required this.title,
    required this.subtitle,
    required this.coverUrl,
    required this.trailingLabel,
    this.onTap,
  });

  final String title;
  final String? subtitle;
  final String? coverUrl;
  final String? trailingLabel;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final _pc = context.pc;
    final navy = _pc.ink;
    final purple = _pc.accent;
    final gold = _pc.star;
    final cardColor = _pc.card;
    final mutedColor = _pc.muted;

    return Material(
      color: cardColor,
      borderRadius: BorderRadius.circular(16),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: SizedBox(
                width: double.infinity,
                child: coverUrl != null
                    ? Image.network(coverUrl!, fit: BoxFit.cover)
                    : Container(
                        color: purple.withOpacity(0.15),
                        child: Icon(
                          Icons.auto_awesome,
                          color: navy,
                          size: 32,
                        ),
                      ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                      color: navy,
                    ),
                  ),
                  if (subtitle != null && subtitle!.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      subtitle!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 11, color: mutedColor),
                    ),
                  ],
                  if (trailingLabel != null) ...[
                    const SizedBox(height: 6),
                    Text(
                      trailingLabel!,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: gold,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MaterialCardSkeleton extends StatelessWidget {
  const _MaterialCardSkeleton();

  @override
  Widget build(BuildContext context) {
    final _pc = context.pc;
    final cardColor = _pc.card;

    return Container(
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(16),
      ),
    );
  }
}

class _EmptyRow extends StatelessWidget {
  const _EmptyRow({required this.icon, required this.message});
  final IconData icon;
  final String message;

  @override
  Widget build(BuildContext context) {
    final _pc = context.pc;
    final navy = _pc.ink;
    final purple = _pc.accent;
    final cardColor = _pc.card;
    final mutedColor = _pc.muted;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: navy.withOpacity(0.1)),
      ),
      child: Row(
        children: [
          Icon(icon, color: purple, size: 28),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              message,
              style: TextStyle(color: mutedColor, fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }
}
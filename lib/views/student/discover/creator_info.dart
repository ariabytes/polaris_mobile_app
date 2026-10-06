import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '/controllers/auth_controller.dart';
import '/models/user_model.dart';

import 'package:polaris_mobile_app/services/theme_service.dart';

class CreatorInfo extends StatefulWidget {
  const CreatorInfo({
    super.key,
    required this.ownerId,
    this.avatarRadius = 12,
    this.nameSize = 12,
    this.programSize = 10.5,
    this.showProgram = true,
  });

  final String ownerId;
  final double avatarRadius;
  final double nameSize;
  final double programSize;
  final bool showProgram;

  @override
  State<CreatorInfo> createState() => _CreatorInfoState();
}

class _CreatorInfoState extends State<CreatorInfo> {
  late Stream<UserModel?> _stream;

  @override
  void initState() {
    super.initState();
    _stream = context.read<AuthController>().userStream(widget.ownerId);
  }

  @override
  void didUpdateWidget(covariant CreatorInfo oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.ownerId != widget.ownerId) {
      _stream = context.read<AuthController>().userStream(widget.ownerId);
    }
  }

  @override
  Widget build(BuildContext context) {
    final pc = context.pc;

    return StreamBuilder<UserModel?>(
      stream: _stream,
      builder: (context, snapshot) {
        final user = snapshot.data;
        final loading =
            snapshot.connectionState == ConnectionState.waiting && user == null;

        final name = loading
            ? ''
            : ((user?.name.trim().isNotEmpty ?? false)
                ? user!.name.trim()
                : 'Unknown user');
        final program = user?.program?.trim() ?? '';
        final photoUrl = user?.profilePhoto?['url'] as String?;
        final hasPhoto = photoUrl != null && photoUrl.isNotEmpty;

        return Row(
          children: [
            CircleAvatar(
              radius: widget.avatarRadius,
              backgroundColor: pc.accent.withOpacity(0.2),
              backgroundImage: hasPhoto ? NetworkImage(photoUrl) : null,
              child: hasPhoto
                  ? null
                  : Icon(
                      Icons.person,
                      size: widget.avatarRadius * 1.2,
                      color: pc.ink,
                    ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: widget.nameSize,
                      fontWeight: FontWeight.w600,
                      color: pc.ink,
                    ),
                  ),
                  if (widget.showProgram && program.isNotEmpty)
                    Text(
                      program,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: widget.programSize,
                        color: pc.muted,
                      ),
                    ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}
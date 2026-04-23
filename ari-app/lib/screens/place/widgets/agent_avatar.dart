import 'package:flutter/material.dart';
import '../models/place_avatar.dart';
import '../../../l10n/app_localizations.dart';
import '../../agents/widgets/agent_profile_icon.dart';

class AgentAvatar extends StatelessWidget {
  final PlaceAvatar item;

  const AgentAvatar({super.key, required this.item});

  @override
  Widget build(BuildContext context) {
    final avatar = item.profile;
    final statusText = _localizeStatus(context, item.status);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 96,
          height: 96,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: const Color(0xFF13132B),
            border: Border.all(color: const Color(0xFF6C63FF), width: 3),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.5),
                blurRadius: 10,
                offset: const Offset(0, 5),
              ),
            ],
          ),
          child: ClipOval(child: _buildAvatarImage(avatar)),
        ),
        const SizedBox(height: 8),
        Container(
          constraints: const BoxConstraints(minWidth: 76, maxWidth: 116),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: const Color(0xCC13132B),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: const Color(0xFF6C63FF).withOpacity(0.35),
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                avatar.name.trim().isEmpty ? 'ARI' : avatar.name.trim(),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                statusText,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white.withOpacity(0.68),
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  String _localizeStatus(BuildContext context, String key) {
    final l10n = S.of(context);
    switch (key) {
      case 'working': return l10n.placeWorking;
      case 'idle': return l10n.placeIdle;
      case 'resting': return l10n.placeResting;
      default: return key;
    }
  }

  Widget _buildAvatarImage(dynamic avatar) {
    return AgentProfileIcon(
      imagePath: avatar.imagePath.toString(),
      size: 96,
    );
  }
}

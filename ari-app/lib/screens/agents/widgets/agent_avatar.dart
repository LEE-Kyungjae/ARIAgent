import 'dart:io';

import 'package:flutter/material.dart';

class AgentAvatar extends StatelessWidget {
  final String imagePath;

  const AgentAvatar({super.key, required this.imagePath});

  @override
  Widget build(BuildContext context) {
    final trimmed = imagePath.trim();
    final isAsset = trimmed.startsWith('assets/');
    final file = trimmed.isNotEmpty && !isAsset ? File(trimmed) : null;
    final hasImage = isAsset || (file != null && file.existsSync());

    return CircleAvatar(
      radius: 24,
      backgroundColor: const Color(0xFF1A1A2E),
      child: ClipOval(
        child: hasImage
            ? (isAsset
                  ? Image.asset(
                      trimmed,
                      width: 48,
                      height: 48,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => _fallback(),
                    )
                  : Image.file(
                      file!,
                      width: 48,
                      height: 48,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => _fallback(),
                    ))
            : _fallback(),
      ),
    );
  }

  Widget _fallback() => Image.asset(
    'assets/images/avatar.png',
    width: 48,
    height: 48,
    fit: BoxFit.cover,
  );
}

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:provider/provider.dart';
import 'package:ari_plugin/ari_plugin.dart';
import '../../../l10n/app_localizations.dart';
import '../../agents/widgets/agent_profile_icon.dart';

class ProfileTab extends StatefulWidget {
  const ProfileTab({super.key});

  @override
  State<ProfileTab> createState() => _ProfileTabState();
}

class _ProfileTabState extends State<ProfileTab> {
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _personaController = TextEditingController();
  String? _lastAvatarId;

  @override
  void initState() {
    super.initState();
    // 초기화 시점에는 provider를 사용할 수 없으므로, 빌드 시점에 동기화 처리를 합니다.
  }

  @override
  void dispose() {
    _nameController.dispose();
    _personaController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final avatar = context.watch<AgentProvider>();

    // 에이전트가 완벽하게 전환되었을 때(ID가 달라졌을 때) 컨트롤러 텍스트 동기화
    if (_lastAvatarId != avatar.currentAvatarId) {
      _nameController.text = avatar.name;
      _personaController.text = avatar.persona;
      _lastAvatarId = avatar.currentAvatarId;
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          GestureDetector(
            onTap: () async {
              FilePickerResult? result = await FilePicker.platform.pickFiles(
                type: FileType.image,
              );
              if (result != null && result.files.single.path != null) {
                await avatar.updateImagePath(result.files.single.path!);
                // 서버가 동일 경로에 덮어쓰는 경우 Flutter FileImage 캐시가
                // 경로 기준으로 유지되어 예전 디코드 이미지가 그대로 표시됨.
                // 새 파일 내용이 보이도록 캐시에서 evict.
                final path = avatar.imagePath;
                if (path.isNotEmpty && !path.startsWith('assets/')) {
                  final file = File(path);
                  if (file.existsSync()) {
                    await FileImage(file).evict();
                  }
                }
                if (mounted) setState(() {});
              }
            },
            child: Stack(
              alignment: Alignment.center,
              children: [
                Container(
                  width: 120,
                  height: 120,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: const Color(0xFF1A1A2E),
                    border: Border.all(
                      color: const Color(0xFF6C63FF),
                      width: 2,
                    ),
                  ),
                  child: AgentProfileIcon(
                    imagePath: avatar.imagePath,
                    size: 120,
                  ),
                ),
                Positioned(
                  bottom: 0,
                  right: 0,
                  child: CircleAvatar(
                    radius: 16,
                    backgroundColor: const Color(0xFF6C63FF),
                    child: const Icon(
                      Icons.edit,
                      size: 16,
                      color: Colors.white,
                    ),
                  ),
                ),
                if (avatar.imagePath.trim().isNotEmpty)
                  Positioned(
                    bottom: 0,
                    left: 0,
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () async {
                        final prevPath = avatar.imagePath.trim();
                        await avatar.updateImagePath('');
                        if (prevPath.isNotEmpty &&
                            !prevPath.startsWith('assets/')) {
                          final file = File(prevPath);
                          if (file.existsSync()) {
                            await FileImage(file).evict();
                          }
                        }
                        if (mounted) setState(() {});
                      },
                      child: const CircleAvatar(
                        radius: 16,
                        backgroundColor: Color(0xFFEF4444),
                        child: Icon(
                          Icons.delete_outline,
                          size: 16,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 32),
          TextField(
            controller: _nameController,
            style: const TextStyle(color: Colors.white, fontSize: 16),
            decoration: InputDecoration(
              labelText: 'Avatar Name',
              labelStyle: TextStyle(color: Colors.white.withOpacity(0.5)),
              filled: true,
              fillColor: const Color(0xFF1A1A2E),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(color: Colors.white.withOpacity(0.1)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: Color(0xFF6C63FF)),
              ),
            ),
            onChanged: (val) {
              avatar.updateName(val);
            },
          ),
          const SizedBox(height: 24),
          TextField(
            controller: _personaController,
            maxLines: 3,
            style: const TextStyle(color: Colors.white, fontSize: 13),
            decoration: InputDecoration(
              labelText: 'Persona / System Prompt',
              labelStyle: TextStyle(color: Colors.white.withOpacity(0.5)),
              hintText: S.of(context).profileSystemPromptHint,
              hintStyle: TextStyle(color: Colors.white.withOpacity(0.2)),
              filled: true,
              fillColor: const Color(0xFF1A1A2E),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(color: Colors.white.withOpacity(0.1)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: Color(0xFF6C63FF)),
              ),
            ),
            onChanged: (val) {
              avatar.updatePersona(val);
            },
          ),
          const SizedBox(height: 16),
          Text(
            S.of(context).profileDescription,
            style: const TextStyle(color: Colors.white54, fontSize: 12, height: 1.5),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

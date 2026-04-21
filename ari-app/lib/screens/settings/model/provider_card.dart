import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';
import 'models/provider_item.dart';
import 'models/provider_meta.dart';
import 'providers_notifier.dart';
import 'oauth/oauth_section.dart';
import 'apikey/api_key_section.dart';
import 'widgets/settings_dropdown.dart';

const _uuid = Uuid();

/// 카드 단위 위젯. 자기 [ProviderItem]을 ChangeNotifierProvider.value로 받아
/// `context.watch<ProviderItem>()`로 자체 구독한다.
/// 화살표/액션 가시성은 자기 item.isSaved + 전역 saveStatus로 자체 계산.
class ProviderCard extends StatelessWidget {
  final int index;
  final int totalCount;

  const ProviderCard({
    super.key,
    required this.index,
    required this.totalCount,
  });

  @override
  Widget build(BuildContext context) {
    final item = context.watch<ProviderItem>();
    final saveStatus = context.select<ProvidersNotifier, String>(
      (n) => n.saveStatus,
    );
    final notifier = context.read<ProvidersNotifier>();
    final meta = metaFor(item.provider);

    final canReorder = saveStatus != 'dirty' && item.isSaved;
    final canMoveUp = canReorder && index > 0;
    final canMoveDown = canReorder && index < totalCount - 1;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeader(
            canMoveUp: canMoveUp,
            canMoveDown: canMoveDown,
            onMoveUp: () => notifier.moveUp(index),
            onMoveDown: () => notifier.moveDown(index),
            onRemove: () => notifier.removeProvider(index),
          ),
          const SizedBox(height: 12),
          _buildDropdownRow(meta, item, notifier),
          const SizedBox(height: 8),
          if (meta.isOAuth)
            OAuthSection(item: item)
          else
            ApiKeySection(item: item),
        ],
      ),
    );
  }

  Widget _buildHeader({
    required bool canMoveUp,
    required bool canMoveDown,
    required VoidCallback onMoveUp,
    required VoidCallback onMoveDown,
    required VoidCallback onRemove,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          'Priority ${index + 1}',
          style: const TextStyle(
            color: Color(0xFF6C63FF),
            fontSize: 12,
            fontWeight: FontWeight.bold,
          ),
        ),
        Row(
          children: [
            if (canMoveUp)
              GestureDetector(
                onTap: onMoveUp,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 2.0),
                  child: Icon(
                    Icons.keyboard_arrow_up,
                    color: Colors.white.withValues(alpha: 0.6),
                    size: 22,
                  ),
                ),
              ),
            if (canMoveDown)
              GestureDetector(
                onTap: onMoveDown,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 2.0),
                  child: Icon(
                    Icons.keyboard_arrow_down,
                    color: Colors.white.withValues(alpha: 0.6),
                    size: 22,
                  ),
                ),
              ),
            if (totalCount > 1)
              GestureDetector(
                onTap: onRemove,
                child: Padding(
                  padding: const EdgeInsets.only(left: 8.0, right: 2.0),
                  child: Icon(
                    Icons.delete_outline,
                    color: Colors.redAccent.withValues(alpha: 0.8),
                    size: 18,
                  ),
                ),
              ),
          ],
        ),
      ],
    );
  }

  Widget _buildDropdownRow(
    ProviderMeta meta,
    ProviderItem item,
    ProvidersNotifier notifier,
  ) {
    final locked = meta.isOAuth && item.oauthLoggedIn;
    return Row(
      children: [
        Expanded(
          child: SettingsDropdown(
            value: item.provider,
            items: allProviders
                .map((m) => DropdownMenuItem(value: m.id, child: Text(m.label)))
                .toList(),
            onChanged: locked
                ? null
                : (v) {
                    if (v != null && v != item.provider) {
                      final newMeta = metaFor(v);
                      // 프로바이더 교체 = 7개 필드 일괄 변경. 알림은 1회로 묶음.
                      item.update(() {
                        item.provider = v;
                        item.authType = newMeta.isOAuth ? 'oauth' : 'apikey';
                        item.model = newMeta.models.firstOrNull?.id ?? '';
                        // accountId도 새로 발급 — 이전 OAuth 계정과 완전 분리.
                        item.accountId = _uuid.v4();
                        item.oauthLoggedIn = false;
                        item.hasApiKey = false;
                        item.apiKeyObscured = true;
                      });
                      item.apiKeyController.clear();
                      notifier.markDirty();
                    }
                  },
          ),
        ),
        const SizedBox(width: 8),
        Expanded(child: _buildModelDropdown(meta, item, notifier, locked: locked)),
      ],
    );
  }

  Widget _buildModelDropdown(
    ProviderMeta meta,
    ProviderItem item,
    ProvidersNotifier notifier, {
    bool locked = false,
  }) {
    final models = meta.models.isNotEmpty
        ? meta.models
        : [ModelItem(id: item.model, label: item.model)];
    final currentModel = models.any((m) => m.id == item.model)
        ? item.model
        : models.first.id;
    return SettingsDropdown(
      value: currentModel,
      items: models
          .map((m) => DropdownMenuItem(value: m.id, child: Text(m.label)))
          .toList(),
      onChanged: locked
          ? null
          : (v) {
              if (v != null) {
                item.model = v;
                notifier.markDirty();
              }
            },
    );
  }
}

import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import 'provider_meta.dart';
import 'oauth/oauth_section.dart';
import 'apikey/api_key_section.dart';
import 'widgets/settings_dropdown.dart';

const _uuid = Uuid();

class ProviderCard extends StatefulWidget {
  final ProviderItem item;
  final int index;
  final int totalCount;
  final VoidCallback onMoveUp;
  final VoidCallback onMoveDown;
  final VoidCallback onRemove;
  final VoidCallback onSave;
  final VoidCallback onLogoutSave;
  final VoidCallback onMarkDirty;

  const ProviderCard({
    super.key,
    required this.item,
    required this.index,
    required this.totalCount,
    required this.onMoveUp,
    required this.onMoveDown,
    required this.onRemove,
    required this.onSave,
    required this.onLogoutSave,
    required this.onMarkDirty,
  });

  @override
  State<ProviderCard> createState() => _ProviderCardState();
}

class _ProviderCardState extends State<ProviderCard> {
  ProviderItem get item => widget.item;

  @override
  Widget build(BuildContext context) {
    final meta = metaFor(item.provider);

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
          _buildHeader(),
          const SizedBox(height: 12),
          _buildDropdownRow(meta),
          const SizedBox(height: 8),
          if (meta.isOAuth)
            OAuthSection(
              item: item,
              onSave: widget.onSave,
              onLogoutSave: widget.onLogoutSave,
              onLockStateChanged: () {
                if (mounted) setState(() {});
              },
            )
          else
            ApiKeySection(
              item: item,
              onSave: widget.onSave,
              onMarkDirty: widget.onMarkDirty,
            ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          'Priority ${widget.index + 1}',
          style: const TextStyle(
            color: Color(0xFF6C63FF),
            fontSize: 12,
            fontWeight: FontWeight.bold,
          ),
        ),
        Row(
          children: [
            if (widget.index > 0)
              GestureDetector(
                onTap: widget.onMoveUp,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 2.0),
                  child: Icon(
                    Icons.keyboard_arrow_up,
                    color: Colors.white.withValues(alpha: 0.6),
                    size: 22,
                  ),
                ),
              ),
            if (widget.index < widget.totalCount - 1)
              GestureDetector(
                onTap: widget.onMoveDown,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 2.0),
                  child: Icon(
                    Icons.keyboard_arrow_down,
                    color: Colors.white.withValues(alpha: 0.6),
                    size: 22,
                  ),
                ),
              ),
            if (widget.totalCount > 1)
              GestureDetector(
                onTap: widget.onRemove,
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

  Widget _buildDropdownRow(ProviderMeta meta) {
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
                      setState(() {
                        item.provider = v;
                        item.authType = newMeta.isOAuth ? 'oauth' : 'apikey';
                        item.model = newMeta.models.firstOrNull?.id ?? '';
                        // 프로바이더가 바뀌면 이전 상태를 전부 비워준다.
                        // accountId도 새로 발급 — 이전 OAuth 계정과 완전 분리.
                        item.accountId = _uuid.v4();
                        item.oauthLoggedIn = false;
                        item.hasApiKey = false;
                        item.apiKeyController.clear();
                        item.apiKeyObscured = true;
                      });
                      widget.onMarkDirty();
                    }
                  },
          ),
        ),
        const SizedBox(width: 8),
        Expanded(child: _buildModelDropdown(meta, locked: locked)),
      ],
    );
  }

  Widget _buildModelDropdown(ProviderMeta meta, {bool locked = false}) {
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
                setState(() => item.model = v);
                widget.onMarkDirty();
              }
            },
    );
  }
}

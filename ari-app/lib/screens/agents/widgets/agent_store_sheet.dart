import 'dart:io';

import 'package:ari_plugin/ari_plugin.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../l10n/app_localizations.dart';
import '../../../services/agent_store_service.dart';

class AgentStoreSheet extends StatefulWidget {
  const AgentStoreSheet({super.key});

  @override
  State<AgentStoreSheet> createState() => _AgentStoreSheetState();
}

class _AgentStoreSheetState extends State<AgentStoreSheet> {
  static const Color _bg = Color(0xFF1A1A2E);
  static const Color _accent = Color(0xFF6C63FF);
  static const int _pageSize = 20;

  final _service = const AgentStoreService();
  final _scrollCtrl = ScrollController();

  final List<AgentStoreItem> _items = [];
  bool _loading = true;
  bool _loadingMore = false;
  bool _hasMore = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _scrollCtrl.addListener(_onScroll);
    _loadFirstPage();
  }

  @override
  void dispose() {
    _scrollCtrl.removeListener(_onScroll);
    _scrollCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadFirstPage() async {
    setState(() {
      _loading = true;
      _error = null;
      _items.clear();
      _hasMore = true;
    });
    try {
      final page = await _service.fetchApps(limit: _pageSize, offset: 0);
      if (!mounted) return;
      setState(() {
        _items.addAll(page);
        _hasMore = page.length >= _pageSize;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  Future<void> _loadMore() async {
    if (_loadingMore || !_hasMore || _loading) return;
    setState(() => _loadingMore = true);
    try {
      final page = await _service.fetchApps(
        limit: _pageSize,
        offset: _items.length,
      );
      if (!mounted) return;
      setState(() {
        _items.addAll(page);
        _hasMore = page.length >= _pageSize;
        _loadingMore = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loadingMore = false);
    }
  }

  void _onScroll() {
    if (!_scrollCtrl.hasClients) return;
    final pos = _scrollCtrl.position;
    if (pos.pixels >= pos.maxScrollExtent - 240) {
      _loadMore();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.9,
      decoration: const BoxDecoration(
        color: _bg,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(28),
          topRight: Radius.circular(28),
        ),
      ),
      child: Column(
        children: [
          Container(
            width: 40,
            height: 4,
            margin: const EdgeInsets.symmetric(vertical: 12),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(4),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 4, 12, 12),
            child: Row(
              children: [
                const Icon(
                  Icons.storefront_rounded,
                  color: _accent,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Text(
                  S.of(context).officeTitle,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const Spacer(),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: Icon(
                    Icons.close_rounded,
                    color: Colors.white.withValues(alpha: 0.6),
                    size: 22,
                  ),
                ),
              ],
            ),
          ),
          Expanded(child: _buildBody()),
        ],
      ),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator(color: _accent));
    }
    if (_error != null) {
      return _buildError(_error!);
    }
    if (_items.isEmpty) {
      return _buildEmpty();
    }

    final count = _items.length + (_hasMore ? 1 : 0);
    return ListView.separated(
      controller: _scrollCtrl,
      padding: const EdgeInsets.fromLTRB(12, 4, 12, 24),
      itemCount: count,
      separatorBuilder: (_, __) => const SizedBox(height: 4),
      itemBuilder: (_, i) {
        if (i >= _items.length) {
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: Center(
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: _accent.withValues(alpha: 0.7),
                ),
              ),
            ),
          );
        }
        return _AgentStoreTile(item: _items[i]);
      },
    );
  }

  Widget _buildError(String message) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.error_outline_rounded,
            color: Colors.white.withValues(alpha: 0.4),
            size: 32,
          ),
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.6),
                fontSize: 12.5,
              ),
            ),
          ),
          const SizedBox(height: 16),
          TextButton(
            onPressed: _loadFirstPage,
            style: TextButton.styleFrom(foregroundColor: _accent),
            child: Text(S.of(context).retry),
          ),
        ],
      ),
    );
  }

  Widget _buildEmpty() {
    return Center(
      child: Text(
        S.of(context).officeNoAgents,
        style: TextStyle(
          color: Colors.white.withValues(alpha: 0.5),
          fontSize: 13,
        ),
      ),
    );
  }
}

class _AgentStoreTile extends StatefulWidget {
  const _AgentStoreTile({required this.item});

  final AgentStoreItem item;

  @override
  State<_AgentStoreTile> createState() => _AgentStoreTileState();
}

class _AgentStoreTileState extends State<_AgentStoreTile> {
  bool _hover = false;

  String? get _downloadUrl => Platform.isWindows
      ? widget.item.winDownloadUrl
      : widget.item.macDownloadUrl;

  bool _isInstalled(AgentProvider prov) {
    return prov.currentAgent.installedApps.any(
      (a) => a['name']?.toString() == widget.item.appId,
    );
  }

  Future<void> _install() async {
    final url = _downloadUrl;
    final messenger = ScaffoldMessenger.of(context);
    final l10n = S.of(context);
    final appName = widget.item.name;

    if (url == null) {
      _showToast(
        messenger,
        icon: Icons.error_outline_rounded,
        color: const Color(0xFFF59E0B),
        text: l10n.officeNoPlatformBuild(appName),
      );
      return;
    }

    final agentProv = context.read<AgentProvider>();
    final appId = widget.item.appId;

    Navigator.of(context).pop();

    _showToast(
      messenger,
      icon: Icons.download_rounded,
      color: const Color(0xFF6C63FF),
      text: l10n.officeInvitingApp(appName),
      showSpinner: true,
      duration: const Duration(minutes: 2),
    );

    final result = await agentProv.installApp(url: url, appId: appId);
    final ok = result['ok'] == true;
    if (ok) {
      await agentProv.pinApp(appId);
      await agentProv.currentAgent.loadApps();
    }
    _showToast(
      messenger,
      icon: ok ? Icons.check_circle_rounded : Icons.error_rounded,
      color: ok ? const Color(0xFF4ADE80) : const Color(0xFFEF4444),
      text: ok
          ? l10n.officeInvitedApp(appName)
          : l10n.officeInviteFailed(result['error'] ?? 'unknown'),
    );
  }

  void _showToast(
    ScaffoldMessengerState messenger, {
    required IconData icon,
    required Color color,
    required String text,
    bool showSpinner = false,
    Duration duration = const Duration(seconds: 3),
  }) {
    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        backgroundColor: const Color(0xFF1A1A2E),
        elevation: 8,
        margin: const EdgeInsets.fromLTRB(20, 0, 20, 20),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: BorderSide(color: color.withValues(alpha: 0.4), width: 1),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        duration: duration,
        content: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 28,
              height: 28,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.18),
                borderRadius: BorderRadius.circular(8),
              ),
              child: showSpinner
                  ? SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: color,
                      ),
                    )
                  : Icon(icon, size: 16, color: color),
            ),
            const SizedBox(width: 12),
            Flexible(
              child: Text(
                text,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final item = widget.item;
    final installed = _isInstalled(context.watch<AgentProvider>());
    final bg = _hover
        ? Colors.white.withValues(alpha: 0.04)
        : Colors.transparent;

    return MouseRegion(
      cursor: SystemMouseCursors.basic,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildIcon(),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          item.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 13.5,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      if (item.category.isNotEmpty) ...[
                        const SizedBox(width: 8),
                        Text(
                          item.category.toUpperCase(),
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.35),
                            fontSize: 9.5,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.4,
                          ),
                        ),
                      ],
                    ],
                  ),
                  if (item.description.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      item.description,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.5),
                        fontSize: 11.5,
                        height: 1.35,
                      ),
                    ),
                  ],
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      _StatChip(
                        icon: Icons.download_rounded,
                        value: item.downloadCount,
                      ),
                      const SizedBox(width: 8),
                      _StatChip(
                        icon: Icons.favorite_rounded,
                        value: item.likeCount,
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            _buildInstallButton(installed: installed),
          ],
        ),
      ),
    );
  }

  Widget _buildIcon() {
    final url = widget.item.iconUrl;
    if (url != null) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(10),
        child: Image.network(
          url,
          width: 44,
          height: 44,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => _iconFallback(),
        ),
      );
    }
    return _iconFallback();
  }

  Widget _iconFallback() {
    return Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        color: const Color(0xFF6C63FF).withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Icon(
        Icons.extension_rounded,
        size: 20,
        color: const Color(0xFF6C63FF).withValues(alpha: 0.7),
      ),
    );
  }

  Widget _buildInstallButton({required bool installed}) {
    final hasBuild = _downloadUrl != null;

    if (installed) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: const Color(0xFF4ADE80).withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.check_rounded,
              size: 13,
              color: Color(0xFF4ADE80),
            ),
            const SizedBox(width: 4),
            Text(
              S.of(context).officeInvited,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: Color(0xFF4ADE80),
              ),
            ),
          ],
        ),
      );
    }

    return TextButton(
      onPressed: hasBuild ? _install : null,
      style: TextButton.styleFrom(
        backgroundColor: const Color(0xFF6C63FF).withValues(alpha: 0.15),
        foregroundColor: const Color(0xFF6C63FF),
        disabledForegroundColor: Colors.white.withValues(alpha: 0.3),
        disabledBackgroundColor: Colors.white.withValues(alpha: 0.04),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
        ),
        minimumSize: const Size(0, 32),
      ),
      child: Text(
        hasBuild ? S.of(context).officeInvite : 'N/A',
        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
      ),
    );
  }
}

class _StatChip extends StatelessWidget {
  const _StatChip({required this.icon, required this.value});

  final IconData icon;
  final int value;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 11, color: Colors.white.withValues(alpha: 0.35)),
        const SizedBox(width: 3),
        Text(
          '$value',
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.45),
            fontSize: 10.5,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

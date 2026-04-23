import 'dart:convert';

import 'package:http/http.dart' as http;

const String _kAgentStoreEndpoint = String.fromEnvironment(
  'ARI_AGENT_STORE_ENDPOINT',
  defaultValue: 'https://ariwith.me/api/list-apps',
);

class AgentStoreItem {
  const AgentStoreItem({
    required this.appId,
    required this.name,
    required this.category,
    required this.description,
    required this.iconUrl,
    required this.macDownloadUrl,
    required this.winDownloadUrl,
    required this.macVersion,
    required this.winVersion,
    required this.githubUrl,
    required this.downloadCount,
    required this.likeCount,
  });

  final String appId;
  final String name;
  final String category;
  final String description;
  final String? iconUrl;
  final String? macDownloadUrl;
  final String? winDownloadUrl;
  final String? macVersion;
  final String? winVersion;
  final String? githubUrl;
  final int downloadCount;
  final int likeCount;

  factory AgentStoreItem.fromJson(Map<String, dynamic> json) {
    return AgentStoreItem(
      appId: json['app_id']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      category: json['category']?.toString() ?? '',
      description: json['description']?.toString() ?? '',
      iconUrl: json['icon_url']?.toString(),
      macDownloadUrl: json['mac_download_url']?.toString(),
      winDownloadUrl: json['win_download_url']?.toString(),
      macVersion: json['mac_version']?.toString(),
      winVersion: json['win_version']?.toString(),
      githubUrl: json['github_url']?.toString(),
      downloadCount: (json['download_count'] as num?)?.toInt() ?? 0,
      likeCount: (json['like_count'] as num?)?.toInt() ?? 0,
    );
  }
}

class AgentStoreService {
  const AgentStoreService();

  Future<List<AgentStoreItem>> fetchApps({
    int limit = 40,
    int offset = 0,
  }) async {
    final uri = Uri.parse(
      '$_kAgentStoreEndpoint?limit=$limit&offset=$offset',
    );
    final response = await http.get(uri);

    if (response.statusCode != 200) {
      throw Exception(
        'Failed to fetch agent store (${response.statusCode})',
      );
    }

    final decoded = jsonDecode(response.body);
    final list = decoded is List
        ? decoded
        : (decoded is Map && decoded['data'] is List ? decoded['data'] : null);
    if (list is! List) {
      return const <AgentStoreItem>[];
    }
    return list
        .whereType<Map<String, dynamic>>()
        .map(AgentStoreItem.fromJson)
        .toList();
  }
}

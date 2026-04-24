import '../../chat/models/ari_chat_item.dart';
import 'ari_work_step.dart';

/// Work session status — 한 번의 작업 실행 전체 상태.
enum AriWorkStatus {
  running,
  completed,
  failed;

  String get value => name;

  static AriWorkStatus fromString(String? s) =>
      AriWorkStatus.values.firstWhere(
        (e) => e.name == s,
        orElse: () => AriWorkStatus.running,
      );
}

/// AI 가 수행한 멀티스텝 작업 한 번의 전체 기록.
///
/// 프로토콜:
/// - `WORK.START` { summary?, context? } → { id }
/// - `WORK.STEP`  { id, label, status, detail? }
/// - `WORK.END`   { id, status, summary? }
class AriWorkSession implements AriChatItem {
  AriWorkSession({
    required this.id,
    required this.appId,
    required this.startedAt,
    this.completedAt,
    required this.status,
    required this.steps,
    this.summary,
    this.context,
  });

  @override
  DateTime get timestamp => startedAt;

  final String id;
  final String appId;
  final DateTime startedAt;
  final DateTime? completedAt;
  final AriWorkStatus status;
  final List<AriWorkStep> steps;
  final String? summary;

  /// 앱 고유 메타데이터 (예: FloARI 의 `{symbol, topicTitle}`).
  /// 프레임워크는 저장/전달만 하고 해석하지 않는다.
  final Map<String, dynamic>? context;

  Duration? get duration => completedAt?.difference(startedAt);

  AriWorkSession copyWith({
    DateTime? completedAt,
    AriWorkStatus? status,
    List<AriWorkStep>? steps,
    String? summary,
  }) =>
      AriWorkSession(
        id: id,
        appId: appId,
        startedAt: startedAt,
        completedAt: completedAt ?? this.completedAt,
        status: status ?? this.status,
        steps: steps ?? this.steps,
        summary: summary ?? this.summary,
        context: context,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'appId': appId,
        'startedAt': startedAt.toIso8601String(),
        if (completedAt != null) 'completedAt': completedAt!.toIso8601String(),
        'status': status.value,
        'steps': steps.map((s) => s.toJson()).toList(),
        if (summary != null) 'summary': summary,
        if (context != null) 'context': context,
      };

  factory AriWorkSession.fromJson(Map<String, dynamic> json) {
    final completedRaw = json['completedAt'] as String?;
    return AriWorkSession(
      id: json['id'] as String? ??
          'work-${DateTime.now().microsecondsSinceEpoch}',
      appId: json['appId'] as String? ?? '',
      startedAt: DateTime.parse(
        json['startedAt'] as String? ?? DateTime.now().toIso8601String(),
      ),
      completedAt:
          completedRaw == null ? null : DateTime.tryParse(completedRaw),
      status: AriWorkStatus.fromString(json['status'] as String?),
      steps: (json['steps'] as List<dynamic>? ?? const <dynamic>[])
          .map((e) => AriWorkStep.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList(),
      summary: json['summary'] as String?,
      context: json['context'] != null
          ? Map<String, dynamic>.from(json['context'] as Map)
          : null,
    );
  }
}

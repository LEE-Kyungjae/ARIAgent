/// Work step status — 세션 내 개별 진행 단계의 상태.
enum AriStepStatus {
  pending,
  running,
  done,
  failed;

  String get value => name;

  static AriStepStatus fromString(String? s) =>
      AriStepStatus.values.firstWhere(
        (e) => e.name == s,
        orElse: () => AriStepStatus.done,
      );
}

/// 세션 내부의 한 스텝. AI 가 `WORK.STEP` 으로 append 한다.
class AriWorkStep {
  const AriWorkStep({
    required this.label,
    required this.status,
    this.detail,
    required this.createdAt,
  });

  final String label;
  final AriStepStatus status;
  final String? detail;
  final DateTime createdAt;

  Map<String, dynamic> toJson() => {
        'label': label,
        'status': status.value,
        if (detail != null) 'detail': detail,
        'createdAt': createdAt.toIso8601String(),
      };

  factory AriWorkStep.fromJson(Map<String, dynamic> json) => AriWorkStep(
        label: json['label'] as String? ?? '',
        status: AriStepStatus.fromString(json['status'] as String?),
        detail: json['detail'] as String?,
        createdAt: DateTime.parse(
          json['createdAt'] as String? ?? DateTime.now().toIso8601String(),
        ),
      );
}

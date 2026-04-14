/// 에이전트의 실시간 토큰 사용량.
/// /USAGE.UPDATED WS 이벤트로 누적되며, /USAGE.GET 응답으로 전체 교체된다.
class AgentTokenUsage {
  final int input;
  final int output;
  final int total;
  final Map<String, AgentModelUsage> byModel;
  final List<AgentDailyUsage> byDay;

  const AgentTokenUsage({
    this.input = 0,
    this.output = 0,
    this.total = 0,
    this.byModel = const {},
    this.byDay = const [],
  });

  bool get isEmpty => total == 0;

  /// 단일 응답 사용량 누적 (/USAGE.UPDATED 이벤트)
  /// byDay는 변경하지 않음 — 전체 조회(/USAGE.GET) 시점에만 갱신
  AgentTokenUsage accumulate({
    required int input,
    required int output,
    required int totalTokens,
    required String model,
  }) {
    final prev = byModel[model] ?? const AgentModelUsage();
    final newByModel = Map<String, AgentModelUsage>.from(byModel);
    newByModel[model] = AgentModelUsage(
      input: prev.input + input,
      output: prev.output + output,
      total: prev.total + totalTokens,
    );
    return AgentTokenUsage(
      input: this.input + input,
      output: this.output + output,
      total: this.total + totalTokens,
      byModel: newByModel,
      byDay: byDay, // 유지
    );
  }

  /// 서버 /USAGE.GET 전체 집계로 교체
  factory AgentTokenUsage.fromSummary(Map<String, dynamic> data) {
    final total = data['total'] as Map<String, dynamic>? ?? {};
    final byModelRaw = data['byModel'] as Map<String, dynamic>? ?? {};
    final byDayRaw = data['byDay'] as List<dynamic>? ?? [];

    return AgentTokenUsage(
      input: (total['input'] as num? ?? 0).toInt(),
      output: (total['output'] as num? ?? 0).toInt(),
      total: (total['totalTokens'] as num? ?? 0).toInt(),
      byModel: byModelRaw.map(
        (k, v) => MapEntry(
          k,
          AgentModelUsage(
            input: (v['input'] as num? ?? 0).toInt(),
            output: (v['output'] as num? ?? 0).toInt(),
            total: (v['totalTokens'] as num? ?? 0).toInt(),
          ),
        ),
      ),
      byDay: byDayRaw
          .whereType<Map>()
          .map((e) => AgentDailyUsage(
                date: e['date']?.toString() ?? '',
                input: (e['input'] as num? ?? 0).toInt(),
                output: (e['output'] as num? ?? 0).toInt(),
                total: (e['totalTokens'] as num? ?? 0).toInt(),
              ))
          .toList(),
    );
  }
}

class AgentModelUsage {
  final int input;
  final int output;
  final int total;
  const AgentModelUsage({this.input = 0, this.output = 0, this.total = 0});
}

class AgentDailyUsage {
  final String date;
  final int input;
  final int output;
  final int total;
  const AgentDailyUsage({
    required this.date,
    this.input = 0,
    this.output = 0,
    this.total = 0,
  });
}

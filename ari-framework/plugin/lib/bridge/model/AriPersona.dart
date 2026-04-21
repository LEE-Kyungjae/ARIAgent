/// 앱이 소유한 고정 정체성. 사용자 설정으로 변경 불가.
/// 앱 코드에 하드코드되어 서버에 첫 연결 시 전달된다.
class AriPersona {
  final String name;
  final String systemPrompt;

  const AriPersona({
    required this.name,
    required this.systemPrompt,
  });

  Map<String, dynamic> toJson() => {
        'name': name,
        'systemPrompt': systemPrompt,
      };
}

# services/agent

에이전트 서브시스템. 외부(라우터/툴/시스템)는 `index.ts` 퍼사드로만 접근한다.
내부 하위 폴더는 서로는 직접 import 가능하지만 외부에는 노출되지 않는다.

## 루트 파일

| 파일                     | 역할                                                                 |
| ------------------------ | -------------------------------------------------------------------- |
| `index.ts`               | 외부 진입점. `executeAgentRequest` + 하위 모듈 re-export.             |
| `bootstrap.ts`           | 프로세스 기동 시 런타임 초기화 (`initAgent`) — 설정·OAuth·캐시 채움.  |
| `control.ts`             | 세션 제어 (abort / clear / drop, origin-기반 소유권 검증).            |
| `execution_context.ts`   | AsyncLocalStorage 레일. 도구가 현재 agentId/appId/ttl 을 읽는 통로.  |
| `plugin_cache.ts`        | 도구/스킬/앱 목록 프로세스 캐시.                                      |

## session/ — 대화 세션 상태·턴 루프

| 파일                | 역할                                                                |
| ------------------- | ------------------------------------------------------------------- |
| `agent_session.ts`  | `AgentSession` 클래스. 세션 수명, 추론 루프, 요청 큐, 브로드캐스트. |
| `session_manager.ts`| 세션 레지스트리 (Map<agentId, AgentSession>) + 팩토리.               |
| `runtime_tools.ts`  | active skill 기반으로 세션별 런타임 도구 배열을 조립.                |
| `active_skills.ts`  | `ActiveSkill` 타입 + 클론/머지 헬퍼.                                 |
| `activity_state.ts` | 에이전트별 idle / working 상태 레지스트리.                           |

## pipeline/ — 요청 한 건의 가공·큐잉·실행

| 파일                  | 역할                                                              |
| --------------------- | ----------------------------------------------------------------- |
| `orchestrator.ts`     | 파이프라인 조립. `submitAgentRequest[AndWait]` 진입점.             |
| `request_builder.ts`  | 사용자 메시지 + 앱/시각/최근 로그 컨텍스트 조립.                   |
| `context_builder.ts`  | 시스템 프롬프트 템플릿 라우팅 + 대화 히스토리 프루닝.              |
| `response_parser.ts`  | `AgentMessage` 에서 최종 어시스턴트 텍스트 추출.                   |
| `request_queue.ts`    | 큐 분기 (follow-up vs 즉시 실행) + 잔존 요청 정리.                 |
| `progress_fanout.ts`  | 진행 메시지를 origin 소켓 + 대상 앱 소켓에 팬아웃.                 |
| `echo_mode.ts`        | 프로바이더 없을 때 에코 폴백 응답.                                 |
| `inter_agent.ts`      | 에이전트 간 라우팅 해석 + TTL + forward 응답 대기 레지스트리.      |

## provider/ — AI 프로바이더 상태·선택

| 파일          | 역할                                                               |
| ------------- | ------------------------------------------------------------------ |
| `state.ts`    | 프로세스-전역 `AIProviders` 인스턴스 (`agentState`).               |
| `selector.ts` | 프로바이더 선택, 모델 해석, OAuth 키 획득, 재시도 순서 계산.       |

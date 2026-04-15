# Installation & Distribution Guide (AI Only)

> [!IMPORTANT]
> 이 문서는 AI(코딩 에이전트)를 위한 설치 및 배포 가이드라인입니다.

---

## 앱 구성 파일

설치 전 아래 파일이 준비되어 있어야 합니다.

| 파일 | 필수 여부 | 설명 |
|------|----------|------|
| `SKILL.md` | **필수** | 에이전트가 앱 기능을 이해하기 위한 스킬 문서 |
| `app_info.json` | **필수** | 앱 ID, 버전 등 메타 정보 |
| 실행 바이너리 | 필수 (앱 종류에 따라) | 실행 가능한 앱 바이너리 |
| `icon.png` | 선택 | 앱 아이콘 |

---

### 1. 로컬에서 설치 및 테스트(코딩에이전트 활용)

코딩 에이전트는 아래 순서로 진행합니다.

1. 프로젝트를 빌드합니다.
2. `SKILL.md`, `app_info.json`, 바이너리를 준비합니다.
3. `~/.ari-agent/apps/<app_id>/` 디렉토리에 파일을 복사합니다.
4. `~/.ari-agent/agents.json` 을 열어 대상 에이전트의 `appIds` 배열에 `<app_id>` 를 추가합니다.
5. ARIAgent를 재실행합니다.

> [!NOTE]
> 파일 복사만으로는 부족합니다. `agents.json`에 등록되지 않으면 에이전트가 앱을 인식하지 못합니다.

**요청 예시:**
```text
이 프로젝트를 빌드해서 ~/.ari-agent/apps/sari/ 에 파일을 복사하고,
~/.ari-agent/agents.json 에서 현재 에이전트의 appIds에 "sari"를 추가한 뒤,
ARIAgent를 재실행해줘.
```

---

### 2. GitHub에서 설치(아리 에이전트 활용)

ARI 에이전트(빛나리 등)가 직접 설치할 경우 `install_app` 도구를 사용합니다.  
이 도구는 GitHub 저장소에서 .zip을 받아 압축 해제 후 `agents.json`에 자동 등록까지 처리합니다.

**코딩 에이전트가 ARI 에이전트에게 요청하는 예시:**
```text
https://github.com/owner/repo 저장소의 최신 릴리즈를 install_app 도구로 설치해줘.
```

---

### 3. 스토어 배포 (공식)

아래 주소에서 GitHub 저장소 주소를 입력하면 됩니다.

**https://ariwith.me/development/submit**

AI가 소스를 리뷰한 후 자동으로 스토어에 등록됩니다.

---

## 체크 포인트 (검증)

- `~/.ari-agent/apps/<app_id>/` 폴더가 생성되어 있어야 합니다.
- `SKILL.md`, `app_info.json`, 바이너리가 들어 있어야 합니다.
- `~/.ari-agent/agents.json` 의 해당 에이전트 `appIds`에 앱 ID가 포함되어 있어야 합니다.
- ARIAgent 재실행 후 에이전트가 앱을 인식해야 합니다.

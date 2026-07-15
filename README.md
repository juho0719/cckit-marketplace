# cckit-marketplace

Claude Code 스킬 마켓플레이스 — DDD + TDD 개발 워크플로우 스킬 모음

## 개요

이 레포는 Claude Code에서 사용할 수 있는 스킬(Skill) 플러그인 모음입니다. 구현 전 합의 → 도메인 설계 → 구현 계획 → TDD 구현 → 검증 → 문서화로 이어지는 **체계적인 개발 워크플로우**를 Claude Code 안에서 실행할 수 있게 합니다.

## 스킬 목록

| 스킬 | 명령어 | 설명 |
|------|--------|------|
| [consensus](#consensus) | `/consensus` | 소크라테스식 문답으로 구현 전 모호함 제거 및 방향 합의 |
| [domain-definition](#domain-definition) | `/domain-definition` | DDD 방법론으로 도메인 모델 체계적 정의 |
| [writing-plan](#writing-plan) | `/writing-plan` | 합의·도메인 정의를 검증 가능한 구현 계획으로 변환 |
| [implementation](#implementation) | `/implementation` | TDD Red→Green→Refactor 사이클 강제 구현 |
| [implementation-review](#implementation-review) | `/implementation-review` | 합의/도메인/계획 문서 대비 구현 적합성 점수 기반 검증 |
| [implementation-docs](#implementation-docs) | `/implementation-docs` | 구현 완료 후 개발자 가이드 문서화 |

## 권장 워크플로우

```
/consensus → /domain-definition → /writing-plan → /implementation → /implementation-review → /implementation-docs
```

각 스킬은 독립적으로 사용할 수 있으며, 이전 스킬의 결과물(`docs/.consensus/`, `docs/.domain/`, `docs/.plan/`)을 다음 스킬이 자동으로 읽어 컨텍스트로 활용합니다.

---

## 설치

### 1. 마켓플레이스 등록

```bash
claude plugins marketplace add juho0719/cckit-marketplace
```

로컬 경로로 추가하는 경우 (클론 후):

```bash
git clone https://github.com/juho0719/cckit-marketplace.git
claude plugins marketplace add ./cckit-marketplace
```

### 2. 플러그인 설치

전체 설치:

```bash
claude plugins install consensus@cckit-marketplace
claude plugins install domain-definition@cckit-marketplace
claude plugins install writing-plan@cckit-marketplace
claude plugins install implementation@cckit-marketplace
claude plugins install implementation-review@cckit-marketplace
claude plugins install implementation-docs@cckit-marketplace
```

특정 스킬만 설치할 수도 있습니다. 예를 들어 `implementation`만 필요하다면:

```bash
claude plugins install implementation@cckit-marketplace
```

### 3. 확인

```bash
claude plugins list
```

설치 후 Claude Code를 재시작하면 `/consensus`, `/domain-definition` 등의 명령어를 사용할 수 있습니다.

### 업데이트

```bash
claude plugins marketplace update cckit-marketplace
claude plugins update consensus
```

### 제거

```bash
claude plugins uninstall consensus
claude plugins marketplace remove cckit-marketplace
```

---

## 스킬 상세

### consensus

구현 전에 모호함을 제거하고 방향을 합의합니다.

- 소크라테스식 질문을 **한 번에 하나씩** 던지며 불명확한 부분을 좁혀나갑니다
- 매 질문마다 추천 답안과 트레이드오프를 제시합니다
- 합의 결과를 `docs/.consensus/{주제명}.md`에 저장합니다

```
/consensus 결제 취소 기능 구현 방향
```

### domain-definition

DDD 방법론으로 도메인을 분석하고 문서화합니다.

- Aggregate / Entity / Value Object / Domain Event / Repository 인터페이스 정의
- 비즈니스 규칙과 불변 조건(Invariant) 명세
- 결과를 `docs/.domain/{도메인명}.md`에 저장합니다

```
/domain-definition
```

### writing-plan

합의 문서와 도메인 정의를 실제로 실행할 수 있는 구현 계획으로 변환합니다.

- 관련 코드와 테스트를 먼저 조사하고 정확한 파일 경로를 기록합니다
- 태스크와 실행 단계를 체크박스로 나누고 각 단계에 검증 명령과 기대 결과를 명시합니다
- 결과를 `docs/.plan/YYYY-MM-DD-{주제명}.md`에 저장합니다

```
/writing-plan
```

### implementation

TDD(Red→Green→Refactor) 사이클로 계획을 구현합니다.

3가지 모드를 지원합니다:

| 모드 | 설명 |
|------|------|
| **Learning** | AI가 실패하는 테스트를 작성하면 사용자가 직접 구현 — 학습용 |
| **Subagent** | 태스크마다 독립 subagent가 TDD 사이클 완료 후 결과만 보고 — 컨텍스트 보존 |
| **In-process** | 현재 세션에서 AI가 직접 TDD 사이클 진행 — 빠른 실행 |

```
/implementation
```

### implementation-review

구현이 합의/도메인/계획 문서와 일치하는지 점수로 검증합니다.

5개 카테고리로 평가하며 **총점 85% 이상**이 통과 기준입니다:

| 카테고리 | 가중치 |
|---------|--------|
| 계획 적합성 (Plan Compliance) | 30% |
| 비즈니스 규칙 반영 (Business Rules) | 25% |
| 합의 사항 반영 (Consensus Alignment) | 20% |
| 테스트 커버리지 (Test Coverage) | 15% |
| 코딩 컨벤션 (Code Conventions) | 10% |

기준 미달 항목은 자동으로 수정을 시도하고 85% 달성까지 반복합니다.

```
/implementation-review
```

### implementation-docs

구현된 코드를 바탕으로 개발자 가이드 문서를 작성합니다.

- 아키텍처 다이어그램, 설정, 포트 인터페이스, 사용 예시, 주의사항 포함
- 실제 코드에서 직접 읽어 작성 — 추측하지 않습니다
- `docs/{도메인}/{기능명}.md`에 저장합니다

```
/implementation-docs
```

---

## 생성되는 문서 구조

각 스킬은 `docs/` 하위에 결과물을 저장합니다:

```
docs/
├── .consensus/          # consensus 스킬 결과 (합의 문서)
│   └── {주제명}.md
├── .domain/             # domain-definition 스킬 결과 (도메인 정의)
│   └── {도메인명}.md
├── .plan/               # writing-plan 스킬 결과 (구현 계획)
│   └── {계획명}.md
└── {도메인}/            # implementation-docs 스킬 결과 (가이드 문서)
    └── {기능명}.md
```

---

## 플러그인 구조

```
plugins/
├── consensus/
│   ├── .claude-plugin/plugin.json
│   └── skills/consensus/SKILL.md
├── domain-definition/
│   ├── .claude-plugin/plugin.json
│   └── skills/domain-definition/SKILL.md
├── writing-plan/
│   ├── .claude-plugin/plugin.json
│   └── skills/writing-plan/SKILL.md
├── implementation/
│   ├── .claude-plugin/plugin.json
│   └── skills/implementation/SKILL.md
├── implementation-review/
│   ├── .claude-plugin/plugin.json
│   └── skills/implementation-review/SKILL.md
└── implementation-docs/
    ├── .claude-plugin/plugin.json
    └── skills/implementation-docs/SKILL.md
```

---

## 라이선스

MIT

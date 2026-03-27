---
name: kotlin-spring-review
description: |
  Kotlin + Spring Boot PR 코드 리뷰 스킬. PR diff를 입력받아 Pn 룰(P1~P5)로 우선순위가 표시된
  구조적 코드 리뷰를 수행한다.

  다음 상황에서 반드시 이 스킬을 사용하라:
  - "PR 리뷰해줘", "코드 리뷰해줘", "이 diff 검토해줘"
  - "Kotlin 코드 리뷰", "Spring Boot 코드 리뷰", "Kotlin Spring 리뷰"
  - "PR diff 분석해줘", "변경사항 리뷰해줘"
  - "Pn 룰로 리뷰해줘", "우선순위 붙여서 리뷰해줘"
  - Kotlin + Spring Boot 프로젝트의 코드 변경사항을 검토하는 모든 상황
allowed-tools: Read, Glob, Grep
---

# Kotlin + Spring Boot PR 코드 리뷰

## 시작 전 컨텍스트 파악

리뷰 전에 다음 두 가지를 확인한다.

**1. PR diff 수집**
사용자가 diff를 붙여넣었으면 바로 진행한다. 파일 경로만 받았다면 Read로 읽는다.

**2. 팀 아키텍처 컨텍스트 확인**
사용자가 팀 규약을 언급하지 않았다면 먼저 질문한다:

> "팀에서 사용하는 아키텍처 스타일을 알려주세요. (레이어드 / DDD / 헥사고날 / 기타)
> 추가로 지켜야 할 팀 규약이 있으면 함께 알려주세요."

컨텍스트가 확인되면 리뷰를 시작한다.

---

## Pn 룰 (우선순위 레벨)

리뷰 코멘트마다 앞에 Pn 레이블을 붙인다. 이 레이블은 작성자가 어떻게 대응해야 하는지를 명확히 전달하기 위한 것이다.

| 레벨 | 의미 | GitHub Action | 작성자 대응 |
|------|------|---------------|------------|
| **P1** | 반드시 반영 — 장애·보안·데이터 손상 위험 | Request Changes | 수정하거나 리뷰어를 납득시켜야 함 |
| **P2** | 적극 고려 — 품질·일관성·유지보수성 | Request Changes | 반영 권장, 미반영 시 충분한 이유와 함께 논의 |
| **P3** | 가능하면 반영 — 선호하는 패턴·개선 아이디어 | Comment | 반영 또는 이유 설명 |
| **P4** | 선택적 제안 — 대안 제시 | Approve | 응답 불필요 |
| **P5** | 사소한 의견 — 스타일·가독성 | Approve | 무시 가능 |

---

## 리뷰 프로세스

diff를 받으면 다음 8개 영역을 순서대로 검토한다. 각 영역의 구체적인 패턴과 예시 코드는 `references/` 디렉토리를 참조한다.

해당 영역과 관련된 변경이 없으면 그 영역은 출력에서 생략한다.

### 영역 1: Kotlin 관용구 & 언어 기능

상세 패턴: `references/kotlin-idioms.md`

핵심 체크:
- `!!` (non-null assertion) — NPE 위험, 대부분 `?:`, `?.let`, `requireNotNull`로 대체 가능 → **P1**
- `var` — 불변성 선호, `val`로 충분한 경우 → **P2**
- Nullable vs 빈 컬렉션 반환 혼용 — 호출부 혼란 야기 → **P2**
- `data class`를 Entity에 사용 — equals/hashCode 오동작, Hibernate 프록시 문제 → **P2**
- 스코프 함수 의미 혼용 (`let`/`apply`/`run`/`also`/`with`) → **P3**
- `when` expression 미활용 (if-else 체인 대체 가능) → **P3**
- 확장 함수 위치 (관련 클래스 패키지에 배치) → **P4**

### 영역 2: Spring Boot 아키텍처 패턴

상세 패턴: `references/spring-patterns.md`

팀 아키텍처 컨텍스트를 반영하여 판단한다. 헥사고날/DDD 팀이라면 포트·어댑터 경계, 도메인 순수성 위반을 추가로 검토한다.

핵심 체크:
- 레이어 간 의존성 방향 위반 (예: Repository가 Service를 참조) → **P1**
- Entity를 API 응답으로 직접 반환 — 스펙 노출·보안 위험 → **P1**
- 필드 주입 (`@Autowired` on field) — 테스트 어렵고 순환 의존성 감지 불가 → **P2**
- DTO/Command/Response 미분리 → **P2**
- 도메인 로직이 Service/Controller에 산재 (DDD 팀 기준) → **P2**
- Bean 스코프 오용 (stateful한 Service에 prototype 미적용 등) → **P2**

### 영역 3: 트랜잭션 & 데이터 일관성

상세 패턴: `references/spring-patterns.md` (트랜잭션 섹션)

핵심 체크:
- Lazy 로딩을 트랜잭션 경계 밖에서 호출 — `LazyInitializationException` 위험 → **P1**
- `@Transactional`을 Controller 레이어에 직접 사용 → **P1**
- 조회 메서드에 `readOnly = true` 누락 — 불필요한 dirty checking 발생 → **P2**
- N+1 쿼리 패턴 (연관 엔티티를 루프 안에서 개별 조회) → **P2**
- 트랜잭션 롤백 조건 (`rollbackFor`) 미설정 (Checked Exception 처리 시) → **P2**

### 영역 4: 예외 처리 & 에러 응답

핵심 체크:
- 내부 오류 상세(스택트레이스, DB 오류 메시지)를 클라이언트에 노출 → **P1**
- 비즈니스 예외를 `RuntimeException` 그대로 던짐 (의미 있는 예외 타입 부재) → **P2**
- 예외 로그에 스택트레이스 누락 — `logger.error("message", e)` 패턴 사용 → **P2**
- `@ControllerAdvice` 없이 각 Controller에서 에러 응답 직접 처리 → **P2**
- 빈 catch 블록 (`catch (e: Exception) {}`) → **P2**

### 영역 5: 보안

핵심 체크:
- 입력값 검증(`@Valid`, `@Validated`) 누락 — Controller 진입점에서 검증 필수 → **P1**
- Native Query에서 문자열 직접 조합 (SQL Injection) → **P1**
- 비밀번호, 토큰, 개인정보를 로그에 출력 → **P1**
- Request Body를 Entity에 직접 바인딩 (Mass Assignment) → **P1**
- 권한 검증 누락 — 인증과 인가를 구분하여 검토 → **P1**
- IDOR(Insecure Direct Object Reference) — 다른 사용자 리소스 접근 가능 여부 → **P1**

### 영역 6: API 설계

핵심 체크:
- HTTP 메서드·상태 코드 부적절 (예: 생성 요청에 200 OK 반환) → **P2**
- 에러 응답 구조 불일치 (기존 API와 다른 형태) → **P2**
- 대용량 목록 조회에 페이지네이션 미적용 → **P2**
- API 경로 네이밍 불일치 (팀 컨벤션과 다른 경우) → **P3**
- 응답 필드명 일관성 (camelCase vs snake_case 혼용) → **P3**

### 영역 7: 테스트 품질

상세 패턴: `references/spring-patterns.md` (테스트 섹션)

핵심 체크:
- 핵심 비즈니스 로직 테스트 누락 — 변경된 로직에 대응하는 테스트가 없음 → **P1**
- 경계값·예외 케이스 미검증 (happy path만 테스트) → **P2**
- 구현 세부사항에 과의존 (private 메서드 테스트, 내부 호출 횟수 과도한 verify) → **P2**
- `@SpringBootTest` 과용 — 단위 테스트로 충분한 경우 컨텍스트 전체 로드는 낭비 → **P3**
- 테스트 이름이 행동을 설명하지 않음 (예: `test1`, `testCreate`) → **P3**
- 테스트 간 상태 공유 (공유 DB, static 상태) — 실행 순서에 따라 결과가 달라짐 → **P2**

### 영역 8: Coroutine 패턴

상세 패턴: `references/coroutine-patterns.md`

Coroutine 관련 코드(`suspend`, `launch`, `async`, `Flow`, `coroutineScope`)가 diff에 없으면 이 영역은 건너뛴다.

핵심 체크:
- `GlobalScope` 사용 — 수명 관리 불가, 누수 위험 → **P1**
- `suspend` 함수 안에서 블로킹 IO 호출 (`Thread.sleep`, JDBC 직접 호출 등) — `Dispatchers.IO` 없이 → **P1**
- Structured concurrency 위반 (scope 밖으로 Job 탈출) → **P1**
- `launch` vs `async` 혼용 — 결과값이 필요한 곳에 `launch` 사용 → **P2**
- `runBlocking`을 프로덕션 코드에서 사용 → **P2**
- `CoroutineExceptionHandler` 미설정 (예외 무시 위험) → **P2**
- `Flow` cold/hot 혼용 이해 부재 → **P3**

---

## 출력 형식

```markdown
## 코드 리뷰

> **아키텍처**: {팀 아키텍처 스타일}
> **리뷰 기준**: Pn 룰 (P1 필수 반영 ~ P5 사소한 의견)

---

### {파일명 또는 변경 영역}

**P1** `OrderController.kt:42` — Entity를 API 응답으로 직접 반환
> DB 구조 변경이 API Breaking Change로 이어지고, 민감 필드가 노출될 수 있습니다.
> `OrderResponse` DTO를 별도 생성하여 변환 레이어를 추가해 주세요.

**P2** `OrderService.kt:18` — readOnly = true 누락
> 조회 전용 메서드에 `@Transactional(readOnly = true)`를 명시하면
> dirty checking을 건너뛰어 성능이 개선됩니다.

---

### 요약

| 레벨 | 건수 | 주요 내용 |
|------|------|---------|
| P1 (필수) | 2 | Entity 직접 노출, 입력값 검증 누락 |
| P2 (권고) | 3 | readOnly 누락, 예외 타입, 테스트 경계값 |
| P3 이하 | 1 | 스코프 함수 개선 |
```

### 코멘트 작성 원칙

- **이유를 함께 쓴다** — "이렇게 바꿔주세요"가 아니라 "왜 문제인지"를 먼저 설명한다
- **수정 방향을 제시한다** — 정답을 주기보다 어떤 방향으로 개선할지 안내한다
- **개인 취향은 P4/P5로** — 팀 규약이 아닌 개인 선호는 낮은 우선순위로 표시한다
- **코멘트는 코드가 아닌 행동에 대한 것** — 작성자를 비판하지 않는다

---

## References

각 영역의 구체적인 코드 예시와 안티패턴은 아래를 참조한다:

- `references/kotlin-idioms.md` — Kotlin 관용구 상세 (영역 1)
- `references/spring-patterns.md` — Spring Boot 패턴 & 테스트 상세 (영역 2, 3, 7)
- `references/coroutine-patterns.md` — Coroutine 안티패턴 상세 (영역 8)

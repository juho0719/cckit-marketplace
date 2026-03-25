# Visual Guide — Plan Viewer

브라우저 기반 비주얼 뷰어 상세 가이드. 아키텍처 다이어그램, 플로우차트, 레이아웃 비교 등 시각 자료를 보여줄 때 참조한다.

## 동작 원리

서버가 `.plan-viewer/sessions/<session-id>` 디렉터리를 감시하고, 가장 최신 HTML 파일을 브라우저에 서빙한다. HTML 파일을 작성하면 사용자 브라우저에 자동 반영되고, 사용자의 클릭 이벤트는 `.events` 파일에 기록된다.

**콘텐츠 프래그먼트 vs 풀 도큐먼트:** HTML 파일이 `<!DOCTYPE` 또는 `<html`로 시작하면 그대로 서빙한다. 그렇지 않으면 프레임 템플릿으로 자동 래핑한다. **기본적으로 콘텐츠 프래그먼트만 작성한다.**

## 서버 시작

```bash
# 프로젝트 디렉터리에 영구 저장
scripts/start-server.sh --project-dir /path/to/project

# 반환 JSON:
# {"type":"server-started","port":52341,"url":"http://localhost:52341",
#  "screen_dir":"/path/to/project/.plan-viewer/sessions/12345-1706000000"}
```

`screen_dir`을 저장한다. 사용자에게 URL을 알려준다.

## 루프

1. **서버 활성 확인 후 HTML 작성** — `screen_dir`에 새 파일 작성
   - 매번 `$SCREEN_DIR/.server-info` 존재 확인. 없으면 (또는 `.server-stopped` 있으면) 서버 재시작
   - 시맨틱 파일명 사용: `architecture.html`, `data-flow.html`, `comparison.html`
   - **파일명 재사용 금지** — 매 화면마다 새 파일
   - Write 도구 사용 — cat/heredoc 금지
   - 서버가 자동으로 최신 파일을 서빙

2. **사용자에게 안내하고 턴 종료:**
   - URL을 매번 상기 (첫 번째뿐 아니라 매번)
   - 화면 내용을 간략히 텍스트로 요약
   - 예: "3가지 아키텍처 접근안을 브라우저에서 확인하세요. 선호하는 옵션을 클릭하세요."

3. **다음 턴** — 사용자 응답 후:
   - `$SCREEN_DIR/.events` 읽기 (있으면) — 클릭/선택 이벤트 JSON
   - 사용자의 터미널 텍스트와 병합
   - 터미널 메시지가 주 피드백, `.events`는 보조

4. **반복 또는 진행** — 피드백으로 현재 화면 수정 시 새 파일 작성 (예: `architecture-v2.html`)

5. **터미널 복귀 시 대기 화면 표시** — 다음 단계가 브라우저 불필요할 때:

   ```html
   <!-- filename: waiting.html -->
   <div style="display:flex;align-items:center;justify-content:center;min-height:60vh">
     <p class="subtitle">터미널에서 계속 진행 중...</p>
   </div>
   ```

6. 반복.

## 콘텐츠 프래그먼트 작성

프레임 안에 들어갈 콘텐츠만 작성한다. 서버가 자동으로 프레임 템플릿(헤더, CSS, 선택 인디케이터 등)을 감싸준다.

### 아키텍처 다이어그램 예시

```html
<h2>시스템 아키텍처</h2>
<p class="subtitle">제안하는 전체 아키텍처 구성</p>

<div class="mockup">
  <div class="mockup-header">Architecture Diagram</div>
  <div class="mockup-body">
    <div style="display:flex;gap:2rem;justify-content:center;flex-wrap:wrap;">
      <div class="placeholder" style="width:150px;padding:1.5rem;">
        <strong>API Gateway</strong><br><small>인증, 라우팅</small>
      </div>
      <div class="placeholder" style="width:150px;padding:1.5rem;">
        <strong>Service A</strong><br><small>비즈니스 로직</small>
      </div>
      <div class="placeholder" style="width:150px;padding:1.5rem;">
        <strong>Service B</strong><br><small>데이터 처리</small>
      </div>
    </div>
    <div style="text-align:center;margin:1rem 0;color:var(--text-secondary);">
      ↕ REST / gRPC
    </div>
    <div style="display:flex;gap:2rem;justify-content:center;">
      <div class="placeholder" style="width:150px;padding:1.5rem;">
        <strong>PostgreSQL</strong>
      </div>
      <div class="placeholder" style="width:150px;padding:1.5rem;">
        <strong>Redis</strong>
      </div>
    </div>
  </div>
</div>
```

### 접근안 비교 예시

```html
<h2>아키텍처 접근안 비교</h2>
<p class="subtitle">각 접근안의 장단점을 비교하세요</p>

<div class="options">
  <div class="option" data-choice="a" onclick="toggleSelect(this)">
    <div class="letter">A</div>
    <div class="content">
      <h3>모놀리스</h3>
      <p>단일 애플리케이션으로 빠른 개발, 단순한 배포</p>
      <div class="pros-cons" style="margin-top:0.5rem;">
        <div class="pros"><h4>Pros</h4><ul><li>빠른 초기 개발</li><li>단순한 인프라</li></ul></div>
        <div class="cons"><h4>Cons</h4><ul><li>스케일링 제한</li><li>결합도 높음</li></ul></div>
      </div>
    </div>
  </div>
  <div class="option" data-choice="b" onclick="toggleSelect(this)">
    <div class="letter">B</div>
    <div class="content">
      <h3>마이크로서비스</h3>
      <p>독립적 서비스로 유연한 스케일링</p>
      <div class="pros-cons" style="margin-top:0.5rem;">
        <div class="pros"><h4>Pros</h4><ul><li>독립 배포</li><li>기술 스택 자유</li></ul></div>
        <div class="cons"><h4>Cons</h4><ul><li>운영 복잡도</li><li>네트워크 오버헤드</li></ul></div>
      </div>
    </div>
  </div>
</div>
```

### 데이터 흐름 예시

```html
<h2>데이터 흐름</h2>
<p class="subtitle">요청부터 응답까지의 데이터 흐름</p>

<div class="mockup">
  <div class="mockup-header">Data Flow</div>
  <div class="mockup-body" style="font-family:monospace;font-size:0.85rem;line-height:2;">
    <div>Client → API Gateway → Auth Middleware</div>
    <div style="padding-left:2rem;">↓</div>
    <div style="padding-left:2rem;">Route Handler → Service Layer</div>
    <div style="padding-left:4rem;">↓</div>
    <div style="padding-left:4rem;">Repository → Database</div>
    <div style="padding-left:4rem;">↓</div>
    <div style="padding-left:4rem;">Cache (Redis) ← Response</div>
    <div style="padding-left:2rem;">↓</div>
    <div>Client ← Serialized Response</div>
  </div>
</div>
```

## CSS 클래스 레퍼런스

프레임 템플릿이 제공하는 CSS 클래스:

### Options (A/B/C 선택)
```html
<div class="options">
  <div class="option" data-choice="a" onclick="toggleSelect(this)">
    <div class="letter">A</div>
    <div class="content"><h3>제목</h3><p>설명</p></div>
  </div>
</div>
```

**다중 선택:** 컨테이너에 `data-multiselect` 추가.

### Cards (시각적 디자인)
```html
<div class="cards">
  <div class="card" data-choice="design1" onclick="toggleSelect(this)">
    <div class="card-image"><!-- 내용 --></div>
    <div class="card-body"><h3>이름</h3><p>설명</p></div>
  </div>
</div>
```

### Mockup 컨테이너
```html
<div class="mockup">
  <div class="mockup-header">제목</div>
  <div class="mockup-body"><!-- 내용 --></div>
</div>
```

### Split view (나란히 비교)
```html
<div class="split">
  <div class="mockup"><!-- 왼쪽 --></div>
  <div class="mockup"><!-- 오른쪽 --></div>
</div>
```

### Pros/Cons
```html
<div class="pros-cons">
  <div class="pros"><h4>Pros</h4><ul><li>장점</li></ul></div>
  <div class="cons"><h4>Cons</h4><ul><li>단점</li></ul></div>
</div>
```

### Placeholder (와이어프레임 블록)
```html
<div class="placeholder">영역 설명</div>
```

### Typography
- `h2` — 페이지 제목
- `h3` — 섹션 제목
- `.subtitle` — 부제
- `.section` — 콘텐츠 블록
- `.label` — 소문자 라벨

## 브라우저 이벤트 형식

`$SCREEN_DIR/.events`에 JSON 라인으로 기록:

```jsonl
{"type":"click","choice":"a","text":"Option A - 모놀리스","timestamp":1706000101}
{"type":"click","choice":"b","text":"Option B - 마이크로서비스","timestamp":1706000108}
```

마지막 이벤트가 최종 선택일 가능성이 높지만, 클릭 패턴에서 고민을 읽을 수 있다.

## 파일 네이밍

- 시맨틱 이름: `architecture.html`, `data-flow.html`, `comparison.html`
- 파일명 재사용 금지 — 매 화면 새 파일
- 반복 시: `architecture-v2.html`, `architecture-v3.html`

## 서버 종료

```bash
scripts/stop-server.sh $SCREEN_DIR
```

`--project-dir` 사용 시 `.plan-viewer/sessions/`에 파일이 유지된다.

---
name: web-presentation
description: |
  HTML + CSS + JavaScript만으로 로컬 실행 가능한 웹 프리젠테이션 단일 파일을 생성하는 스킬.
  외부 의존성 없이 브라우저에서 바로 열리는 완결형 .html 파일을 만든다.

  다음 상황에서 반드시 이 스킬을 사용하라:
  - "프리젠테이션 만들어줘", "슬라이드 만들어줘", "발표 자료 만들어줘"
  - "HTML로 PPT/슬라이드/발표자료 만들어줘"
  - "웹 프리젠테이션", "슬라이드쇼", "slide deck"
  - Reveal.js, Impress.js, Slidev 없이 순수 HTML로 프리젠테이션 요청 시
  - "단일 파일 프리젠테이션", "오프라인 발표자료"
  - 특정 주제(기술 소개, 프로젝트 발표, 팀 회의 자료 등)의 슬라이드 세트 요청 시
---

# 웹 프리젠테이션 스킬

외부 라이브러리 없이 HTML + CSS + JS 단일 파일로 완성되는 발표용 슬라이드를 만든다.
파일을 브라우저로 열면 즉시 동작하며, 서버나 빌드 도구가 필요 없다.

## 핵심 아키텍처 원칙

### 구조 (DOM 계층)

```
body
└── #stage          ← 전체 뷰포트, 레터박스 배경 (검정)
    └── #canvas     ← 고정 1920×1080px, JS scale() 적용
        └── .slide  ← position:absolute, inset:0 (레이어 스택)
            └── 콘텐츠
```

**왜 이 구조인가:** 1920×1080 고정 캔버스에 px 단위로 폰트/간격을 작성하면 어떤 화면에서도 동일하게 보인다. JS가 뷰포트에 맞게 scale()만 계산하면 되므로 반응형 계산이 필요 없다.

### CSS 핵심 패턴

```css
/* Stage: 뷰포트 전체 차지, 레터박스 */
#stage {
  width: 100vw; height: 100dvh;  /* dvh: iOS Safari 주소창 대응 */
  display: flex; align-items: center; justify-content: center;
  background: #000; overflow: hidden;
}

/* Canvas: 고정 해상도 */
#canvas {
  width: 1920px; height: 1080px;
  transform-origin: center center;
  position: relative; overflow: hidden;
}

/* 슬라이드: 동일 위치 레이어 스택 */
.slide {
  position: absolute; inset: 0;
  opacity: 0; transform: translateX(80px);
  pointer-events: none;
  transition: opacity 520ms cubic-bezier(0.25, 0.46, 0.45, 0.94),
              transform 520ms cubic-bezier(0.25, 0.46, 0.45, 0.94);
}
.slide.is-active { opacity: 1; transform: translateX(0); pointer-events: auto; z-index: 2; }
.slide.is-prev   { opacity: 0; transform: translateX(-60px) scale(0.97); z-index: 1; }
.slide.enter-from-left { transform: translateX(-80px); }

/* 접근성: 모션 감소 설정 */
@media (prefers-reduced-motion: reduce) {
  .slide { transition: opacity 200ms ease !important; transform: none !important; }
}
```

### JavaScript 핵심 패턴

```javascript
// ── 상태 ──────────────────────────────────────
const state = {
  current: 0,
  currentStep: 0,
  isAnimating: false,
  slides: [...document.querySelectorAll('.slide')],
};

// ── 스케일 계산 ────────────────────────────────
function scaleCanvas() {
  const s = Math.min(window.innerWidth / 1920, window.innerHeight / 1080);
  document.getElementById('canvas').style.transform = `scale(${s})`;
}
window.addEventListener('resize', scaleCanvas);
scaleCanvas();

// ── 슬라이드 이동 (모든 입력의 단일 진입점) ────
function goToSlide(nextIdx) {
  if (state.isAnimating) return;
  const clamped = Math.max(0, Math.min(nextIdx, state.slides.length - 1));
  if (clamped === state.current) return;

  state.isAnimating = true;
  const dir = clamped > state.current ? 'fwd' : 'bwd';
  const prev = state.slides[state.current];
  const next = state.slides[clamped];

  next.classList.add(dir === 'fwd' ? 'enter-from-right' : 'enter-from-left');
  next.getBoundingClientRect(); // 강제 reflow — 초기 위치 적용 필수

  prev.classList.remove('is-active');
  prev.classList.add('is-prev');
  next.classList.remove('enter-from-right', 'enter-from-left');
  next.classList.add('is-active');
  next.setAttribute('aria-hidden', 'false');
  prev.setAttribute('aria-hidden', 'true');

  state.current = clamped;
  state.currentStep = 0;
  history.replaceState(null, '', `#slide-${clamped + 1}`);
  updateHUD();

  // transitionend + setTimeout 이중 방어
  let done = false;
  const onDone = () => {
    if (done) return; done = true;
    prev.classList.remove('is-prev');
    state.isAnimating = false;
  };
  next.addEventListener('transitionend', e => {
    if (e.propertyName === 'opacity') onDone();
  }, { once: true });
  setTimeout(onDone, 580);
}

// ── 클릭 단계 제어 ─────────────────────────────
function nextAction() {
  const slide = state.slides[state.current];
  const steps = slide.querySelectorAll('[data-step]');
  const maxStep = steps.length ? Math.max(...[...steps].map(el => +el.dataset.step)) : 0;
  if (state.currentStep < maxStep) {
    state.currentStep++;
    slide.querySelectorAll(`[data-step="${state.currentStep}"]`)
         .forEach(el => el.classList.add('is-visible'));
  } else {
    goToSlide(state.current + 1);
  }
}
```

## 콘텐츠 패턴

### 빌드 애니메이션 (자동 순서)
슬라이드 활성화 시 자동으로 순차 등장:
```html
<p data-order="1" style="animation-delay:0ms">첫 번째</p>
<p data-order="2" style="animation-delay:200ms">두 번째</p>
```

### 클릭 제어 단계 (data-step)
스페이스/→ 키로 단계별 공개:
```html
<li class="fragment" data-step="1">첫 번째 포인트</li>
<li class="fragment" data-step="2">두 번째 포인트</li>
```

### 코드 하이라이트
순수 CSS span 토큰으로 외부 의존성 없이 구현:
```html
<pre class="code-block"><code>
<span class="kw">const</span> x <span class="op">=</span> <span class="num">42</span>;
</code></pre>
```

### 화자 노트
```html
<aside class="speaker-note" hidden>
  여기에 발표자 노트 작성. S 키로 사이드 패널에 표시됨.
</aside>
```

## 필수 HUD 요소

모든 프리젠테이션에 항상 포함:
- **진행 표시줄**: 상단에 role="progressbar"
- **슬라이드 카운터**: "1 / 5" 형식, aria-live="polite"
- **키보드 도움말**: ? 키로 토글되는 오버레이
- **전체화면 버튼**: F 키 또는 버튼 클릭

## 키보드/터치 네비게이션

```javascript
// 키보드
const keyMap = {
  'ArrowRight': nextAction, ' ': nextAction, 'Enter': nextAction,
  'ArrowLeft': () => goToSlide(state.current - 1),
  'Home': () => goToSlide(0),
  'End': () => goToSlide(state.slides.length - 1),
  'f': toggleFullscreen, 'F': toggleFullscreen,
  's': toggleNotes, 'S': toggleNotes,
  '?': toggleHelp,
};

// 스와이프 (Pointer Events — 마우스+터치 통합)
let ptrStart = null;
document.addEventListener('pointerdown', e => ptrStart = { x: e.clientX, t: Date.now() });
document.addEventListener('pointerup', e => {
  if (!ptrStart) return;
  const dx = e.clientX - ptrStart.x;
  const dt = Date.now() - ptrStart.t;
  ptrStart = null;
  if (dt > 500 || Math.abs(dx) < 50) return;
  dx < 0 ? nextAction() : goToSlide(state.current - 1);
});
```

## URL Hash 복원 (새로고침 위치 유지)

```javascript
// 초기 로드 시 hash에서 슬라이드 번호 복원
const hash = parseInt(location.hash.replace('#slide-', '')) - 1;
if (hash > 0 && hash < state.slides.length) {
  state.current = hash;
  state.slides[hash].classList.add('is-active');
  state.slides[hash].setAttribute('aria-hidden', 'false');
} else {
  state.slides[0].classList.add('is-active');
  state.slides[0].setAttribute('aria-hidden', 'false');
}
```

## 슬라이드 레이아웃 유형

각 슬라이드는 `display: grid; grid-template-rows: auto 1fr auto` 사용:
- **헤더 행**: `.slide-header` — 제목, 부제목
- **콘텐츠 행**: 자유 레이아웃
- **푸터 행**: `.slide-footer` — 페이지 번호, 태그, 메모

### 자주 쓰는 콘텐츠 레이아웃
```css
/* 2컬럼 */
.two-col { display: grid; grid-template-columns: 1fr 1fr; gap: 40px; }
/* 3컬럼 카드 */
.three-col { display: grid; grid-template-columns: repeat(3, 1fr); gap: 32px; }
/* 중앙 정렬 (커버 슬라이드) */
.center-layout { display: flex; flex-direction: column; justify-content: center; align-items: flex-start; }
```

## 디자인 토큰 (기본값)

```css
:root {
  --c-bg:      #0b0d14;    /* 배경 */
  --c-surface: #131621;    /* 카드/패널 배경 */
  --c-border:  rgba(255,255,255,0.08);
  --c-text:    #e2e8f4;    /* 본문 */
  --c-muted:   #6b7a99;    /* 보조 텍스트 */
  --c-primary: #7c6af7;    /* 주요 강조색 (보라) */
  --c-accent:  #06d6a0;    /* 보조 강조색 (청록) */
  --c-danger:  #f7564a;
  --c-warn:    #fbbf24;
  --transition: 520ms cubic-bezier(0.25, 0.46, 0.45, 0.94);
}
```

사용자가 다른 색상 테마(라이트, 브랜드 컬러 등)를 원하면 이 토큰만 교체하면 된다.

## 출력 형식

항상 **단일 .html 파일**로 출력한다. 구조:

```
<!DOCTYPE html>
<html lang="ko">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>제목</title>
  <style>
    /* 모든 CSS 인라인 */
  </style>
</head>
<body>
  <div id="stage">
    <div id="canvas">
      <section class="slide" id="slide-1" aria-roledescription="slide" aria-label="1번 슬라이드" aria-hidden="true">
        <!-- 슬라이드 콘텐츠 -->
      </section>
      <!-- 추가 슬라이드... -->
    </div>
  </div>
  <!-- HUD, 화자 노트 패널, 도움말 오버레이 -->
  <script>
    /* 모든 JS 인라인 */
  </script>
</body>
</html>
```

## 슬라이드 구성 가이드

사용자가 주제를 주면 이 순서로 슬라이드를 구성한다:
1. **커버** — 제목, 부제목, 발표자/날짜
2. **목차/개요** — 전체 흐름 한눈에 보기
3. **본문 슬라이드들** — 각 주제별 내용 (적당한 빌드 애니메이션 포함)
4. **요약/결론** — 핵심 메시지 강조
5. **Q&A / 감사 인사**

슬라이드 수는 사용자가 요청하지 않으면 내용에 맞게 **5~10장** 사이로 결정한다.

## 품질 체크리스트

파일 생성 전 확인:
- [ ] `scaleCanvas()` 호출로 뷰포트 적응
- [ ] 첫 슬라이드에만 `is-active` 클래스, 나머지는 `aria-hidden="true"`
- [ ] `isAnimating` 플래그로 중복 전환 방지
- [ ] `transitionend` + `setTimeout` 이중 방어 구현
- [ ] 키보드 네비게이션 (→, ←, Space, Home, End, F, S, ?)
- [ ] 진행 표시줄 + 슬라이드 카운터 HUD
- [ ] `prefers-reduced-motion` 미디어 쿼리 적용
- [ ] URL hash 동기화 (`history.replaceState`)

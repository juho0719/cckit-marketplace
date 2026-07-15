---
name: writing-plan
description: |
  합의된 요구사항과 도메인 정의를 작고 검증 가능한 구현 태스크와 TDD 계획으로 변환하는 스킬. docs/.consensus/와 docs/.domain/ 산출물을 읽고 docs/.plan/에 실행 계획을 저장한다.
  다음 상황에서 반드시 이 스킬을 사용하라:
  - "writing-plan", "구현 계획", "작업 계획", "계획 세워줘" 표현이 등장할 때
  - consensus 또는 domain-definition 완료 후 계획 작성 단계로 진행할 때
  - 여러 파일이나 단계에 걸친 변경을 구현 전에 구체화해야 할 때
  - 각 태스크에 파일 경로, TDD 순서, 검증 명령, 완료 기준이 필요할 때
---

# Writing Plan

Write a concrete implementation plan that another Claude instance or teammate can execute without rediscovering the context. Keep every work unit small, testable, and traceable to an agreed requirement.

## Hard Gate

Do not write the plan while the goal, scope, constraints, or completion criteria remain ambiguous. Clarify the missing decisions first, one focused question at a time.

Do not implement the plan as part of this skill. Finish with the saved plan and an explicit implementation handoff.

## Workflow

1. Announce that you are using this skill to write the implementation plan.
2. Inspect the repository, relevant source files, tests, documentation, package scripts, and recent changes. Do not ask the user for facts available locally.
3. Read matching artifacts under `docs/.consensus/` and `docs/.domain/`, plus any relevant specification, design artifact, or prior plan. If multiple artifacts could apply, show the candidates and ask the user to select one.
4. Confirm that the goal, scope, constraints, and acceptance criteria are concrete. If not, pause and clarify them.
5. Identify the smallest independently verifiable slices of work.
6. Save the plan under `docs/.plan/` in the target repository.
7. Run the quality gate before presenting the plan.

Use this filename format:

```text
docs/.plan/YYYY-MM-DD-<short-topic>.md
```

If the project root is not writable, return the complete plan in the response and state the intended path.

## Planning Principles

- Keep each task to one coherent change with one verification target.
- Prefer TDD ordering for behavior changes: failing test, implementation, passing test, regression check.
- Give every task and executable step a checkbox so progress can be recorded in the plan.
- Name exact files when known. Mark files that do not exist as `Create`.
- Follow existing repository patterns instead of inventing new architecture.
- Exclude speculative work and optional polish outside the agreed scope.
- Make changes across domain or module boundaries explicit.
- Preserve documented layout, visual style, interaction states, accessibility behavior, and responsive rules for UI work.
- Include enough detail for execution without pasting large code blocks unless exact code is necessary.

## Artifact Alignment

When earlier planning artifacts exist, carry their decisions into the plan:

- `docs/.consensus/`: map every agreed requirement to at least one task or acceptance criterion.
- `docs/.domain/`: add `Domain Alignment`; assign each task to one bounded context or mark it `Cross-context`.
- Design artifact: name the visual, interaction, responsive, and accessibility constraints affected by each UI task.

For domain-aware plans:

- Name the source-of-truth context for every shared model, API, event, schema, or migration.
- Follow documented ownership boundaries.
- Add coordination and verification steps for both sides of cross-context changes.
- Split or redesign any task that violates a documented boundary.

If the work clearly spans multiple domains but no boundaries are defined, stop and clarify ownership before finalizing the plan.

## Required Plan Shape

Use this structure:

```markdown
# <Feature or Change> Implementation Plan

**Date:** YYYY-MM-DD
**Status:** Draft
**Source:** requirements or specification, relevant artifacts, repository inspection

## Goal

<One-sentence outcome.>

## Requirements Summary

- <Agreed requirement>

## Domain Alignment

- <Include when domain boundaries are relevant; otherwise omit.>

## File Map

- Create: `path` - <responsibility>
- Modify: `path` - <reason>
- Test: `path` - <coverage>

## Tasks

- [ ] Task 1: <small work unit>
  **Context:** <bounded context or N/A>
  **Files:**
  - Modify: `path`
  - Test: `path`

  - [ ] Step 1: <single action>
    - Verify: `<exact command or check>`
    - Expected: <observable result>
  - [ ] Step 2: <single action>
    - Verify: `<exact command or check>`
    - Expected: <observable result>

## Acceptance Criteria

- <Concrete, testable criterion>

## Verification

- `<command>` - <expected result>

## Risks and Mitigations

- Risk: <specific risk>
  Mitigation: <specific mitigation>

## Execution Notes

- <Ownership, sequencing, or coordination notes>
```

Keep the task checkbox unchecked until all of its step-level checks pass.

## Task Granularity

Prefer tasks that take roughly 5-20 minutes. Split a task when it:

- Edits unrelated files or contexts.
- Mixes test setup, production code, and cleanup without checkpoints.
- Cannot be verified with one focused command or inspection.
- Requires multiple workers to coordinate inside the same file.
- Contains more than 5-7 executable steps.

Do not split a trivial one-file change into artificial tasks when one focused task remains clear and testable.

## Quality Gate

Before finalizing the plan, confirm:

- No `TODO`, `TBD`, "handle edge cases", "add tests", or similarly vague placeholders remain.
- Every requirement maps to tasks or acceptance criteria.
- Every task names exact files, or explains why paths are not yet knowable.
- Every executable task and step has a checkbox.
- Every task includes a verification check and expected result.
- Acceptance criteria are observable and testable.
- Existing domain boundaries and design decisions are preserved.
- The plan is saved under `docs/.plan/` when the repository is writable.

Fix all failures before presenting the plan.

## Handoff

After saving the plan, report:

- Plan path
- Goal
- Number of tasks
- Key files or contexts affected
- Verification commands
- Remaining assumptions

Then present these choices and wait for the user's selection:

```text
다음 단계를 선택해주세요:

A. /implementation ← 추천
저장된 계획을 읽고 실행 모드를 선택한 뒤 TDD로 구현합니다.

B. 종료
계획만 저장하고 구현은 나중에 진행합니다.
```

Run `/implementation` only when the user selects A or explicitly asks to implement the saved plan. Do not begin implementation on an ambiguous response.

## Output Language

Always write the plan and handoff in Korean. Keep code, commands, file paths, class names, and technical terms in their original form.

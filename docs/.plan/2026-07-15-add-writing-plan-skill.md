# Writing Plan Skill Plugin Implementation Plan

**Date:** 2026-07-15
**Status:** Complete
**Source:** User request, Codex `writing-plan` skill, repository inspection, cckit workflow skills, Claude Code plugin documentation

## Goal

Add a Claude Code-compatible `writing-plan` skill plugin to the cckit marketplace.

## Requirements Summary

- Preserve the Codex skill's plan structure, task granularity, and quality gate.
- Connect the plan to cckit's `consensus`, `domain-definition`, and `implementation` workflow.
- Follow the repository's existing one-skill-per-plugin layout.
- Register the plugin in the marketplace catalog.

## File Map

- Create: `plugins/writing-plan/.claude-plugin/plugin.json` - Claude Code plugin metadata.
- Create: `plugins/writing-plan/skills/writing-plan/SKILL.md` - Planning workflow and output contract.
- Modify: `.claude-plugin/marketplace.json` - Marketplace registration.
- Modify: `README.md` - Skill catalog, installation command, usage, and plugin layout.
- Create: `docs/.plan/2026-07-15-add-writing-plan-skill.md` - Implementation plan and progress record.

## Tasks

- [x] Task 1: Add the Claude Code plugin and skill
  **Context:** N/A
  **Files:**
  - Create: `plugins/writing-plan/.claude-plugin/plugin.json`
  - Create: `plugins/writing-plan/skills/writing-plan/SKILL.md`

  - [x] Step 1: Add plugin metadata matching existing cckit conventions.
    - Verify: Parse `plugin.json` as JSON.
    - Expected: Valid JSON with matching `writing-plan` name.
  - [x] Step 2: Port the Codex planning workflow and connect cckit's workflow artifacts and handoff.
    - Verify: Inspect frontmatter, artifact paths, and `/implementation` handoff instructions.
    - Expected: Valid Claude Code skill metadata that reads `docs/.consensus/` and `docs/.domain/` and hands off explicitly to `/implementation`.

- [x] Task 2: Register and validate the marketplace plugin
  **Context:** N/A
  **Files:**
  - Modify: `.claude-plugin/marketplace.json`
  - Modify: `README.md`

  - [x] Step 1: Append the `writing-plan` entry without reordering existing plugins.
    - Verify: Parse `.claude-plugin/marketplace.json` as JSON.
    - Expected: One entry points to `./plugins/writing-plan`.
  - [x] Step 2: Run Claude Code's plugin validator and inspect the final diff.
    - Verify: `claude plugin validate .` and `git diff --check`.
    - Expected: Both commands pass with no errors.

## Acceptance Criteria

- `writing-plan` is installable from the cckit marketplace as a Claude Code plugin.
- The skill writes concrete plans under `docs/.plan/` using task and step checkboxes.
- The skill preserves prior requirements, domain, and design decisions when artifacts exist.
- The skill hands the saved plan to cckit's `/implementation` workflow only after explicit user selection.
- The README documents discovery, installation, usage, and plugin structure for `writing-plan`.
- JSON and Claude Code plugin validation pass.

## Verification

- `python3 -m json.tool plugins/writing-plan/.claude-plugin/plugin.json` - plugin manifest parses.
- `python3 -m json.tool .claude-plugin/marketplace.json` - marketplace catalog parses.
- `claude plugin validate .` - Claude Code accepts the marketplace and plugin layout.
- `git diff --check` - changed files contain no whitespace errors.

## Risks and Mitigations

- Risk: A direct copy uses Codex-only skill names and misses cckit's workflow contracts.
  Mitigation: Read cckit's `docs/.consensus/` and `docs/.domain/` artifacts and hand off to `/implementation`.
- Risk: Restrictive tool frontmatter prevents repository inspection or plan writing.
  Mitigation: Do not set `allowed-tools`; inherit the session's configured tools and permissions.

## Execution Notes

- Keep the plugin documentation-only; no scripts, references, assets, or agents are required.
- Append the marketplace entry to preserve the current catalog order.

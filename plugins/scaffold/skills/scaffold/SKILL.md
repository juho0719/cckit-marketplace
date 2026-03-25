---
name: scaffold
description: Integrated project scaffolding launcher. Generates projects for various technology stacks based on presets. Use it when you receive requests such as “create a new project,” “initialize a project,” or “scaffold.”
argument-hint: <project-name> [--preset nextjs-fullstack|monorepo] [--db sqlite|postgres] [--ui shadcn|none] [--pm bun|npm|pnpm] [--packages pkg1 pkg2 ...]
allowed-tools: Bash, Read, Write, Edit, Glob
---

# scaffold

Integrated project scaffolding skill. When you select a preset, it automatically generates a project structure that matches the chosen stack.

---

## Usage Examples

```
/scaffold my-app
/scaffold my-app --preset nextjs-fullstack
/scaffold my-app --preset nextjs-fullstack --db postgres --ui none --pm pnpm
/scaffold my-mono --preset monorepo
/scaffold my-mono --preset monorepo --packages core utils api --pm pnpm
/scaffold .  --preset nextjs-fullstack
```

---

## How to Parse $ARGUMENTS

When this skill is invoked, Claude must:

1. Parse `$ARGUMENTS` to extract:
   - **Project name** — first positional argument (e.g., `my-app` or `.`)
   - `--preset` — which preset to use (`nextjs-fullstack` | `monorepo`)
   - `--db` — database choice (`sqlite` | `postgres`), only for nextjs-fullstack
   - `--ui` — UI library choice (`shadcn` | `none`), only for nextjs-fullstack
   - `--pm` — package manager (`bun` | `npm` | `pnpm`)
   - `--packages` — space-separated list of package names, only for monorepo

2. **If no arguments at all**: Ask the user:
   - Which preset they want (`nextjs-fullstack` or `monorepo`)
   - What the project name should be
   - Any non-default options they want

3. **If project name is given but no `--preset`**: Default to `nextjs-fullstack`.

4. **Validate** the project name is provided before running any script. If missing, ask for it.

---

## Preset: nextjs-fullstack

Full-stack Next.js app with TypeScript, Tailwind CSS, Drizzle ORM, and optionally shadcn/ui.

**Defaults**: `--db sqlite --ui shadcn --pm bun`

**Command to run**:
```bash
bash ~/.claude/skills/scaffold/scripts/nextjs-fullstack.sh <project-name> --db <db> --ui <ui> --pm <pm>
```

**Example**:
```bash
bash ~/.claude/skills/scaffold/scripts/nextjs-fullstack.sh my-app --db sqlite --ui shadcn --pm bun
```

**After-run guidance** (tell the user):
- `cd <project-name>` (unless initialized in-place)
- Run `<pm> run db:migrate` to apply the first migration
- Run `<pm> run dev` to start the development server
- Drizzle Studio available via `<pm> run db:studio`
- For postgres: make sure to set `DATABASE_URL` in `.env.local` before migrating

---

## Preset: monorepo

Turborepo monorepo with shared TypeScript config, shared ESLint config, Prettier, and optional extra packages.

**Defaults**: `--pm bun` (no extra packages)

**Command to run**:
```bash
bash ~/.claude/skills/scaffold/scripts/monorepo.sh <project-name> --pm <pm> [--packages pkg1 pkg2 ...]
```

**Example**:
```bash
bash ~/.claude/skills/scaffold/scripts/monorepo.sh my-mono --pm bun --packages core utils
```

**After-run guidance** (tell the user):
- `cd <project-name>` (unless initialized in-place)
- Run `<pm> run build` to build all packages
- Run `<pm> run dev` to start development mode across all packages
- Add new packages by creating a directory under `packages/` and following the pattern of existing packages
- For pnpm: workspace config lives in `pnpm-workspace.yaml`

---

## Option Reference

See `~/.claude/skills/scaffold/presets.md` for the full option matrix, DB-specific details, and planned future presets.

---

## Decision Flow

```
$ARGUMENTS empty?
  YES → Ask user for preset + project name + options
  NO  →
    project name present?
      NO  → Ask for project name
      YES →
        --preset specified?
          NO  → default to nextjs-fullstack
          YES → use specified preset
        Run the appropriate script with all parsed flags
```

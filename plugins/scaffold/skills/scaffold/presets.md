# Scaffold Presets

This document describes all available presets, their options, and which script powers them.

---

## nextjs-fullstack

**Description**: Full-stack Next.js app with TypeScript, Tailwind CSS, Drizzle ORM, and optionally shadcn/ui. Suitable for web applications that need a database and a modern component library out of the box.

**Script**: `~/.claude/skills/scaffold/scripts/nextjs-fullstack.sh`

**Default options**:
- `--db sqlite`
- `--ui shadcn`
- `--pm bun`

**Option matrix**:

| Flag | Values | Default | Description |
|------|--------|---------|-------------|
| `--db` | `sqlite`, `postgres` | `sqlite` | Database driver and Drizzle dialect |
| `--ui` | `shadcn`, `none` | `shadcn` | UI component library |
| `--pm` | `bun`, `npm`, `pnpm` | `bun` | Package manager |

**DB details**:

| | sqlite | postgres |
|-|--------|----------|
| Runtime dep | `drizzle-orm better-sqlite3` | `drizzle-orm pg` |
| Dev dep | `drizzle-kit @types/better-sqlite3` | `drizzle-kit @types/pg` |
| Schema import | `drizzle-orm/sqlite-core` | `drizzle-orm/pg-core` |
| Column types | `int`, `text`, `sqliteTable` | `serial`, `text`, `timestamp`, `pgTable` |
| DB connection | `drizzle-orm/better-sqlite3` | `drizzle-orm/node-postgres` with `Pool` |
| Dialect in config | `sqlite` | `postgresql` |
| `.env.local` | `DATABASE_URL=sqlite.db` | `DATABASE_URL=postgresql://localhost:5432/<name>` |
| `.gitignore` extras | `*.db`, `*.db-shm`, `*.db-wal` | (none) |

**Usage examples**:
```bash
# All defaults
bash ~/.claude/skills/scaffold/scripts/nextjs-fullstack.sh my-app

# Postgres + no UI
bash ~/.claude/skills/scaffold/scripts/nextjs-fullstack.sh my-app --db postgres --ui none

# npm + shadcn + sqlite
bash ~/.claude/skills/scaffold/scripts/nextjs-fullstack.sh my-app --pm npm

# In-place (current directory)
bash ~/.claude/skills/scaffold/scripts/nextjs-fullstack.sh .
```

---

## monorepo

**Description**: Bun (or npm/pnpm) + Turborepo monorepo with shared TypeScript config, shared ESLint config, Prettier, and optional extra packages scaffolded under `packages/`.

**Script**: `~/.claude/skills/scaffold/scripts/monorepo.sh`

**Default options**:
- `--pm bun`
- `--packages` (none — only shared config packages are created)

**Option matrix**:

| Flag | Values | Default | Description |
|------|--------|---------|-------------|
| `--pm` | `bun`, `npm`, `pnpm` | `bun` | Package manager |
| `--packages` | space-separated names | (empty) | Extra packages to scaffold under `packages/` |

**Usage examples**:
```bash
# Minimal monorepo
bash ~/.claude/skills/scaffold/scripts/monorepo.sh my-mono

# With extra packages
bash ~/.claude/skills/scaffold/scripts/monorepo.sh my-mono --packages core utils api

# pnpm with packages
bash ~/.claude/skills/scaffold/scripts/monorepo.sh my-mono --pm pnpm --packages sdk cli
```

---

## Planned Presets

The following presets are on the roadmap and will be added in future versions:

| Preset | Description |
|--------|-------------|
| `vite-react` | Vite + React + TypeScript + TailwindCSS, optionally with shadcn/ui |
| `api-only` | Lightweight REST/RPC API server (Hono or Fastify), TypeScript, Drizzle ORM |

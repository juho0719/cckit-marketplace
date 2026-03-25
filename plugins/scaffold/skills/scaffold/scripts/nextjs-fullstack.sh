#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/common.sh"

# ── Defaults ──────────────────────────────────────────────────────────────────
DB="sqlite"
UI="shadcn"
PM="bun"

# ── Usage ─────────────────────────────────────────────────────────────────────
usage() {
  error "사용법: bash nextjs-fullstack.sh <project-name> [--db sqlite|postgres] [--ui shadcn|none] [--pm bun|npm|pnpm]"
  exit 1
}

if [ $# -lt 1 ]; then
  usage
fi

PROJECT_ARG="$1"
shift

# ── Flag parsing ───────────────────────────────────────────────────────────────
while [ $# -gt 0 ]; do
  case "$1" in
    --db)
      DB="$2"; shift 2 ;;
    --ui)
      UI="$2"; shift 2 ;;
    --pm)
      PM="$2"; shift 2 ;;
    *)
      error "알 수 없는 옵션: $1"; usage ;;
  esac
done

# ── Package manager helpers ────────────────────────────────────────────────────
case "$PM" in
  bun)
    PKG_X="bunx"
    PKG_ADD="bun add"
    PKG_ADD_DEV="bun add -d"
    PKG_RUN="bun run"
    CREATE_FLAG="--use-bun"
    ;;
  npm)
    PKG_X="npx"
    PKG_ADD="npm install"
    PKG_ADD_DEV="npm install --save-dev"
    PKG_RUN="npm run"
    CREATE_FLAG="--use-npm"
    ;;
  pnpm)
    PKG_X="pnpm dlx"
    PKG_ADD="pnpm add"
    PKG_ADD_DEV="pnpm add -D"
    PKG_RUN="pnpm run"
    CREATE_FLAG="--use-pnpm"
    ;;
  *)
    error "지원하지 않는 패키지 매니저: $PM (bun|npm|pnpm)"; exit 1 ;;
esac

# ── Prerequisite check ─────────────────────────────────────────────────────────
step "사전 조건 확인"
check_command "$PM" "https://bun.sh / https://npmjs.com / https://pnpm.io"
check_command git "https://git-scm.com"
check_command node "https://nodejs.org"

# ── Resolve target directory ───────────────────────────────────────────────────
resolve_target_dir "$PROJECT_ARG"

# ── create-next-app ────────────────────────────────────────────────────────────
step "create-next-app 실행"
if [ "$INIT_IN_PLACE" = true ]; then
  $PKG_X create-next-app@latest . --typescript --tailwind --eslint --app --src-dir --import-alias "@/*" $CREATE_FLAG --yes
else
  $PKG_X create-next-app@latest "$PROJECT_NAME" --typescript --tailwind --eslint --app --src-dir --import-alias "@/*" $CREATE_FLAG --yes
fi
success "create-next-app 완료"

cd "$TARGET_DIR"

# ── Drizzle installation ───────────────────────────────────────────────────────
if [ "$DB" = "sqlite" ]; then
  step "Drizzle ORM + better-sqlite3 설치"
  $PKG_ADD drizzle-orm better-sqlite3
  $PKG_ADD_DEV drizzle-kit @types/better-sqlite3
  success "Drizzle (sqlite) 설치 완료"
elif [ "$DB" = "postgres" ]; then
  step "Drizzle ORM + pg 설치"
  $PKG_ADD drizzle-orm pg
  $PKG_ADD_DEV drizzle-kit @types/pg
  success "Drizzle (postgres) 설치 완료"
else
  error "지원하지 않는 DB: $DB (sqlite|postgres)"; exit 1
fi

# ── DB schema & index ─────────────────────────────────────────────────────────
step "DB 디렉토리 및 기본 스키마 생성"
mkdir -p src/lib/db
mkdir -p src/lib/db/migrations

if [ "$DB" = "sqlite" ]; then
  cat > src/lib/db/schema.ts <<'EOF'
import { int, sqliteTable, text } from 'drizzle-orm/sqlite-core'

export const users = sqliteTable('users', {
  id: int('id').primaryKey({ autoIncrement: true }),
  name: text('name').notNull(),
  email: text('email').notNull().unique(),
  createdAt: int('created_at', { mode: 'timestamp' })
    .$defaultFn(() => new Date())
    .notNull(),
})

export type User = typeof users.$inferSelect
export type NewUser = typeof users.$inferInsert
EOF

  cat > src/lib/db/index.ts <<'EOF'
import Database from 'better-sqlite3'
import { drizzle } from 'drizzle-orm/better-sqlite3'
import * as schema from './schema'

const sqlite = new Database(process.env.DATABASE_URL ?? 'sqlite.db')
sqlite.pragma('journal_mode = WAL')

export const db = drizzle(sqlite, { schema })
EOF

elif [ "$DB" = "postgres" ]; then
  cat > src/lib/db/schema.ts <<'EOF'
import { pgTable, serial, text, timestamp } from 'drizzle-orm/pg-core'

export const users = pgTable('users', {
  id: serial('id').primaryKey(),
  name: text('name').notNull(),
  email: text('email').notNull().unique(),
  createdAt: timestamp('created_at').defaultNow().notNull(),
})

export type User = typeof users.$inferSelect
export type NewUser = typeof users.$inferInsert
EOF

  cat > src/lib/db/index.ts <<EOF
import { Pool } from 'pg'
import { drizzle } from 'drizzle-orm/node-postgres'
import * as schema from './schema'

const pool = new Pool({
  connectionString: process.env.DATABASE_URL,
})

export const db = drizzle(pool, { schema })
EOF
fi

success "DB 파일 생성 완료"

# ── drizzle.config.ts ─────────────────────────────────────────────────────────
step "drizzle.config.ts 생성"
if [ "$DB" = "sqlite" ]; then
  cat > drizzle.config.ts <<'EOF'
import type { Config } from 'drizzle-kit'

export default {
  schema: './src/lib/db/schema.ts',
  out: './src/lib/db/migrations',
  dialect: 'sqlite',
  dbCredentials: {
    url: process.env.DATABASE_URL ?? 'sqlite.db',
  },
} satisfies Config
EOF
elif [ "$DB" = "postgres" ]; then
  cat > drizzle.config.ts <<'EOF'
import type { Config } from 'drizzle-kit'

export default {
  schema: './src/lib/db/schema.ts',
  out: './src/lib/db/migrations',
  dialect: 'postgresql',
  dbCredentials: {
    url: process.env.DATABASE_URL!,
  },
} satisfies Config
EOF
fi
success "drizzle.config.ts 생성 완료"

# ── .env.local ────────────────────────────────────────────────────────────────
step ".env.local 생성"
if [ "$DB" = "sqlite" ]; then
  ENV_DB_LINE="DATABASE_URL=sqlite.db"
elif [ "$DB" = "postgres" ]; then
  ENV_DB_LINE="DATABASE_URL=postgresql://localhost:5432/${PROJECT_NAME}"
fi

if [ ! -f ".env.local" ]; then
  echo "$ENV_DB_LINE" > .env.local
  success ".env.local 생성 완료"
else
  if ! grep -q "^DATABASE_URL=" .env.local; then
    echo "" >> .env.local
    echo "$ENV_DB_LINE" >> .env.local
    success ".env.local에 DATABASE_URL 추가 완료"
  else
    info ".env.local에 이미 DATABASE_URL 존재 — 건너뜀"
  fi
fi

# ── .gitignore ────────────────────────────────────────────────────────────────
step ".gitignore 업데이트"
if [ "$DB" = "sqlite" ]; then
  if ! grep -q "sqlite.db" .gitignore 2>/dev/null; then
    cat >> .gitignore <<'EOF'

# SQLite
*.db
*.db-shm
*.db-wal
EOF
    success ".gitignore에 sqlite.db 패턴 추가"
  else
    info ".gitignore에 이미 sqlite.db 패턴 존재 — 건너뜀"
  fi
fi

# ── package.json scripts ───────────────────────────────────────────────────────
step "package.json에 Drizzle 스크립트 추가"
node -e "
const fs = require('fs');
const pkg = JSON.parse(fs.readFileSync('package.json', 'utf8'));
pkg.scripts = {
  ...pkg.scripts,
  'db:generate': 'drizzle-kit generate',
  'db:migrate': 'drizzle-kit migrate',
  'db:push': 'drizzle-kit push',
  'db:studio': 'drizzle-kit studio',
};
fs.writeFileSync('package.json', JSON.stringify(pkg, null, 2) + '\n');
"
success "package.json 스크립트 추가 완료"

# ── shadcn/ui ─────────────────────────────────────────────────────────────────
if [ "$UI" = "shadcn" ]; then
  step "shadcn/ui 초기화"
  printf '\n' | $PKG_X shadcn@latest init --yes
  success "shadcn/ui 초기화 완료"

  step "기본 shadcn/ui 컴포넌트 설치 (button, input, card)"
  $PKG_X shadcn@latest add button input card --yes
  success "shadcn/ui 컴포넌트 설치 완료"
elif [ "$UI" = "none" ]; then
  info "UI 라이브러리 건너뜀 (--ui none)"
else
  error "지원하지 않는 UI: $UI (shadcn|none)"; exit 1
fi

# ── Initial DB migration ───────────────────────────────────────────────────────
step "초기 DB 마이그레이션 생성"
$PKG_RUN db:generate
success "마이그레이션 파일 생성 완료"

# ── Git commit ────────────────────────────────────────────────────────────────
step "Git 커밋"
COMMIT_MSG="chore: add"
[ "$UI" = "shadcn" ] && COMMIT_MSG="$COMMIT_MSG shadcn/ui +"
COMMIT_MSG="$COMMIT_MSG drizzle ${DB} setup"
git_init_commit "$COMMIT_MSG"

# ── Summary ───────────────────────────────────────────────────────────────────
echo ""
echo -e "${GREEN}${BOLD}✓ 프로젝트 초기화 완료: ${PROJECT_NAME}${RESET}"
echo ""
echo -e "  ${BOLD}옵션:${RESET}  DB=${DB}  UI=${UI}  PM=${PM}"
echo ""
echo -e "  ${BOLD}주요 구조:${RESET}"
echo -e "  src/"
echo -e "    app/              — Next.js App Router"
echo -e "    ${CYAN}lib/db/${RESET}           — Drizzle ORM"
echo -e "      index.ts        — DB 연결"
echo -e "      schema.ts       — 테이블 스키마"
echo -e "      migrations/     — 마이그레이션 파일"
if [ "$UI" = "shadcn" ]; then
  echo -e "    ${CYAN}components/ui/${RESET}    — shadcn/ui 컴포넌트"
fi
echo ""
echo -e "  ${BOLD}DB 명령어:${RESET}"
echo -e "    $PKG_RUN db:generate  — 스키마 변경 후 마이그레이션 생성"
echo -e "    $PKG_RUN db:migrate   — 마이그레이션 적용"
echo -e "    $PKG_RUN db:push      — 마이그레이션 없이 스키마 직접 적용"
echo -e "    $PKG_RUN db:studio    — Drizzle Studio (DB GUI)"
echo ""
echo -e "  ${BOLD}개발 시작:${RESET}"
if [ "$INIT_IN_PLACE" = false ]; then
  echo -e "    cd ${PROJECT_NAME}"
fi
echo -e "    $PKG_RUN db:migrate   — 첫 마이그레이션 적용"
echo -e "    $PKG_RUN dev          — 개발 서버 시작"
echo ""

#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/common.sh"

# ── Defaults ──────────────────────────────────────────────────────────────────
PM="bun"
PACKAGES=()

# ── Usage ─────────────────────────────────────────────────────────────────────
usage() {
  error "사용법: bash monorepo.sh <project-name> [--packages pkg1 pkg2 ...] [--pm bun|npm|pnpm]"
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
    --pm)
      PM="$2"; shift 2 ;;
    --packages)
      shift
      while [ $# -gt 0 ] && [[ "$1" != --* ]]; do
        PACKAGES+=("$1")
        shift
      done
      ;;
    *)
      error "알 수 없는 옵션: $1"; usage ;;
  esac
done

# ── Package manager helpers ────────────────────────────────────────────────────
case "$PM" in
  bun)
    PKG_INIT="bun init -y"
    PKG_EXEC="bun -e"
    PKG_INSTALL="bun install"
    PKG_RUN="bun run"
    ;;
  npm)
    PKG_INIT="npm init -y"
    PKG_EXEC="node -e"
    PKG_INSTALL="npm install"
    PKG_RUN="npm run"
    ;;
  pnpm)
    PKG_INIT="pnpm init"
    PKG_EXEC="node -e"
    PKG_INSTALL="pnpm install"
    PKG_RUN="pnpm run"
    ;;
  *)
    error "지원하지 않는 패키지 매니저: $PM (bun|npm|pnpm)"; exit 1 ;;
esac

# ── Prerequisite check ─────────────────────────────────────────────────────────
step "사전 조건 확인"
check_command "$PM" "https://bun.sh / https://npmjs.com / https://pnpm.io"
check_command git "https://git-scm.com"

# ── Resolve target directory ───────────────────────────────────────────────────
resolve_target_dir "$PROJECT_ARG"

cd "$TARGET_DIR"

ESCAPED_NAME=$(echo "$PROJECT_NAME" | sed "s/'/\\\\'/g")

# ── Root init ─────────────────────────────────────────────────────────────────
step "${PM} init — 루트 프로젝트 초기화"
$PKG_INIT 2>&1 | head -10
rm -f index.ts README.md
rm -rf .cursor
success "${PM} init 완료"

# ── Root package.json ─────────────────────────────────────────────────────────
step "루트 package.json — 모노레포 + Turborepo 설정"

if [ "$PM" = "bun" ]; then
  PM_VERSION=$(bun --version)
  PKG_MANAGER_FIELD="bun@${PM_VERSION}"
elif [ "$PM" = "npm" ]; then
  PM_VERSION=$(npm --version)
  PKG_MANAGER_FIELD="npm@${PM_VERSION}"
elif [ "$PM" = "pnpm" ]; then
  PM_VERSION=$(pnpm --version)
  PKG_MANAGER_FIELD="pnpm@${PM_VERSION}"
fi

# Determine workspace syntax based on PM
if [ "$PM" = "pnpm" ]; then
  # pnpm uses pnpm-workspace.yaml
  cat > pnpm-workspace.yaml <<'EOF'
packages:
  - 'packages/*'
EOF
  WORKSPACE_FIELD="null"
else
  WORKSPACE_FIELD='["packages/*"]'
fi

$PKG_EXEC "
const fs = require('fs');
const pkg = JSON.parse(fs.readFileSync('package.json', 'utf8'));
pkg.name = '${ESCAPED_NAME}';
pkg.private = true;
if ('${WORKSPACE_FIELD}' !== 'null') {
  pkg.workspaces = ${WORKSPACE_FIELD};
}
pkg.packageManager = '${PKG_MANAGER_FIELD}';
delete pkg.module;
delete pkg.peerDependencies;
pkg.scripts = {
  build: 'turbo run build',
  dev: 'turbo run dev',
  lint: 'turbo run lint',
  'check-types': 'turbo run check-types',
  test: 'turbo run test',
  clean: 'turbo run clean',
  format: 'prettier --write \"**/*.{ts,tsx,js,json,md}\"',
  'format:check': 'prettier --check \"**/*.{ts,tsx,js,json,md}\"',
};
pkg.devDependencies = {
  'turbo': '^2.5.3',
  'prettier': '^3.5.2',
  ...(pkg.devDependencies || {}),
};
fs.writeFileSync('package.json', JSON.stringify(pkg, null, 2) + '\n');
"
success "package.json 업데이트 완료"

# ── turbo.json ────────────────────────────────────────────────────────────────
step "turbo.json 생성"
cat > turbo.json <<'EOF'
{
  "$schema": "https://turborepo.dev/schema.json",
  "ui": "tui",
  "tasks": {
    "build": {
      "dependsOn": ["^build"],
      "inputs": ["$TURBO_DEFAULT$"],
      "outputs": ["dist/**"]
    },
    "dev": {
      "dependsOn": ["^build"],
      "cache": false,
      "persistent": true
    },
    "lint": {
      "dependsOn": ["^lint"]
    },
    "check-types": {
      "dependsOn": ["^check-types"]
    },
    "test": {
      "dependsOn": ["^build"],
      "inputs": ["$TURBO_DEFAULT$", "tests/**"],
      "outputs": []
    },
    "clean": {
      "cache": false
    }
  }
}
EOF
success "turbo.json 생성 완료"

# ── typescript-config ─────────────────────────────────────────────────────────
step "packages/typescript-config — 공유 tsconfig"
TS_CONFIG_DIR="packages/typescript-config"
mkdir -p "$TS_CONFIG_DIR"
(cd "$TS_CONFIG_DIR" && $PKG_INIT) >/dev/null 2>&1
rm -f "$TS_CONFIG_DIR/index.ts" "$TS_CONFIG_DIR/README.md" "$TS_CONFIG_DIR/tsconfig.json"
rm -rf "$TS_CONFIG_DIR/.cursor"

$PKG_EXEC "
const fs = require('fs');
const pkg = JSON.parse(fs.readFileSync('${TS_CONFIG_DIR}/package.json', 'utf8'));
pkg.name = '@${ESCAPED_NAME}/typescript-config';
pkg.version = '0.0.0';
pkg.private = true;
pkg.files = ['base.json', 'library.json'];
delete pkg.module;
delete pkg.type;
delete pkg.peerDependencies;
delete pkg.devDependencies;
fs.writeFileSync('${TS_CONFIG_DIR}/package.json', JSON.stringify(pkg, null, 2) + '\n');
"

cat > "$TS_CONFIG_DIR/base.json" <<'EOF'
{
  "$schema": "https://json.schemastore.org/tsconfig",
  "compilerOptions": {
    "target": "ES2022",
    "module": "ESNext",
    "moduleResolution": "bundler",
    "lib": ["ES2022"],
    "strict": true,
    "noUncheckedIndexedAccess": true,
    "noImplicitReturns": true,
    "noFallthroughCasesInSwitch": true,
    "verbatimModuleSyntax": true,
    "declaration": true,
    "declarationMap": true,
    "sourceMap": true,
    "esModuleInterop": true,
    "skipLibCheck": true,
    "isolatedModules": true
  },
  "exclude": ["node_modules", "dist"]
}
EOF

cat > "$TS_CONFIG_DIR/library.json" <<'EOF'
{
  "$schema": "https://json.schemastore.org/tsconfig",
  "extends": "./base.json",
  "compilerOptions": {
    "outDir": "./dist",
    "rootDir": "./src"
  }
}
EOF
success "typescript-config 생성 완료"

# ── eslint-config ─────────────────────────────────────────────────────────────
step "packages/eslint-config — 공유 ESLint 설정"
ESLINT_CONFIG_DIR="packages/eslint-config"
mkdir -p "$ESLINT_CONFIG_DIR"
(cd "$ESLINT_CONFIG_DIR" && $PKG_INIT) >/dev/null 2>&1
rm -f "$ESLINT_CONFIG_DIR/index.ts" "$ESLINT_CONFIG_DIR/README.md" "$ESLINT_CONFIG_DIR/tsconfig.json"
rm -rf "$ESLINT_CONFIG_DIR/.cursor"

$PKG_EXEC "
const fs = require('fs');
const pkg = JSON.parse(fs.readFileSync('${ESLINT_CONFIG_DIR}/package.json', 'utf8'));
pkg.name = '@${ESCAPED_NAME}/eslint-config';
pkg.version = '0.0.0';
pkg.private = true;
pkg.type = 'module';
pkg.files = ['base.js'];
delete pkg.module;
delete pkg.peerDependencies;
pkg.dependencies = {
  '@typescript-eslint/eslint-plugin': '^8.24.1',
  '@typescript-eslint/parser': '^8.24.1',
  'eslint': '^9.20.1',
};
pkg.devDependencies = {};
fs.writeFileSync('${ESLINT_CONFIG_DIR}/package.json', JSON.stringify(pkg, null, 2) + '\n');
"

cat > "$ESLINT_CONFIG_DIR/base.js" <<'EOF'
import tsParser from "@typescript-eslint/parser";
import tsPlugin from "@typescript-eslint/eslint-plugin";

export default [
  {
    ignores: ["**/dist/**", "**/node_modules/**", "**/.turbo/**"],
  },
  {
    files: ["**/*.ts", "**/*.tsx"],
    languageOptions: {
      parser: tsParser,
      parserOptions: {
        projectService: true,
      },
    },
    plugins: {
      "@typescript-eslint": tsPlugin,
    },
    rules: {
      ...tsPlugin.configs["recommended"].rules,
      "@typescript-eslint/no-unused-vars": [
        "error",
        { argsIgnorePattern: "^_" },
      ],
      "@typescript-eslint/no-explicit-any": "error",
      "@typescript-eslint/consistent-type-imports": [
        "error",
        { prefer: "type-imports" },
      ],
    },
  },
];
EOF
success "eslint-config 생성 완료"

# ── Prettier ──────────────────────────────────────────────────────────────────
step "Prettier 설정"
cat > .prettierrc <<'EOF'
{
  "semi": false,
  "singleQuote": true,
  "tabWidth": 2,
  "trailingComma": "all",
  "printWidth": 100,
  "arrowParens": "always"
}
EOF

cat > .prettierignore <<'EOF'
node_modules
dist
.turbo
*.lock
bun.lock
EOF
success "Prettier 설정 완료"

# ── .gitignore ────────────────────────────────────────────────────────────────
step ".gitignore 보강"
cat >> .gitignore <<'EOF'

# Turborepo
.turbo/

# Build
dist/
*.tsbuildinfo

# Environment
.env
.env.local
.env.*.local

# Editor
.vscode/
.idea/
.cursor/
EOF
success ".gitignore 업데이트 완료"

# ── Extra packages ────────────────────────────────────────────────────────────
if [ ${#PACKAGES[@]} -gt 0 ]; then
  step "패키지 스캐폴딩: ${PACKAGES[*]}"
  for PKG in "${PACKAGES[@]}"; do
    PKG_DIR="packages/$PKG"
    info "패키지 생성: $PKG"
    mkdir -p "$PKG_DIR/src"
    (cd "$PKG_DIR" && $PKG_INIT) >/dev/null 2>&1
    rm -f "$PKG_DIR/index.ts" "$PKG_DIR/README.md"
    rm -rf "$PKG_DIR/.cursor"

    if [ "$PM" = "bun" ]; then
      BUILD_SCRIPT="bun build ./src/index.ts --outdir ./dist --target bun --format esm --sourcemap=external"
      DEV_SCRIPT="bun --watch ./src/index.ts"
      TEST_SCRIPT="bun test"
      TYPES_DEP="'@types/bun': 'latest',"
    else
      BUILD_SCRIPT="tsc"
      DEV_SCRIPT="tsc --watch"
      TEST_SCRIPT="echo \"no test specified\" && exit 0"
      TYPES_DEP=""
    fi

    $PKG_EXEC "
const fs = require('fs');
const pkg = JSON.parse(fs.readFileSync('${PKG_DIR}/package.json', 'utf8'));
pkg.name = '@${ESCAPED_NAME}/${PKG}';
pkg.version = '0.0.0';
pkg.private = true;
pkg.type = 'module';
pkg.main = './dist/index.js';
pkg.types = './dist/index.d.ts';
delete pkg.module;
delete pkg.peerDependencies;
pkg.scripts = {
  build: '${BUILD_SCRIPT}',
  dev: '${DEV_SCRIPT}',
  'check-types': 'tsc --noEmit',
  lint: 'eslint ./src',
  test: '${TEST_SCRIPT}',
  clean: 'rm -rf dist',
};
pkg.devDependencies = {
  '@${ESCAPED_NAME}/typescript-config': 'workspace:*',
  '@${ESCAPED_NAME}/eslint-config': 'workspace:*',
  ${TYPES_DEP}
};
fs.writeFileSync('${PKG_DIR}/package.json', JSON.stringify(pkg, null, 2) + '\n');
"

    cat > "$PKG_DIR/tsconfig.json" <<TSCONFIG_EOF
{
  "extends": "@${PROJECT_NAME}/typescript-config/library.json",
  "compilerOptions": {
    "outDir": "./dist",
    "rootDir": "./src",
    "types": ["bun-types"]
  },
  "include": ["src/**/*.ts"],
  "exclude": ["node_modules", "dist"]
}
TSCONFIG_EOF

    cat > "$PKG_DIR/eslint.config.mjs" <<ESLINT_PKG_EOF
import baseConfig from '@${PROJECT_NAME}/eslint-config/base.js'

export default [...baseConfig]
ESLINT_PKG_EOF

    cat > "$PKG_DIR/src/index.ts" <<'SRC_EOF'
export {}
SRC_EOF

    success "  @${PROJECT_NAME}/${PKG} 생성 완료"
  done
else
  warn "추가 패키지 없음 — 나중에 수동으로 추가하세요"
fi

# ── Install dependencies ───────────────────────────────────────────────────────
step "의존성 설치 (${PM} install)"
$PKG_INSTALL 2>&1 | tail -5
success "의존성 설치 완료"

# ── Git commit ────────────────────────────────────────────────────────────────
step "Git 초기화 및 커밋"
git_init_commit "chore: initial monorepo setup (${PM} + TypeScript + Turborepo)"

# ── Summary ───────────────────────────────────────────────────────────────────
echo ""
echo -e "${GREEN}${BOLD}✓ 모노레포 초기화 완료: ${PROJECT_NAME}${RESET}"
echo ""
echo -e "  ${BOLD}구조:${RESET}"
echo -e "  packages/"
echo -e "    typescript-config/ — 공유 tsconfig"
echo -e "    eslint-config/     — 공유 ESLint 설정"
for PKG in "${PACKAGES[@]:-}"; do
  [ -n "$PKG" ] && echo -e "    ${CYAN}${PKG}/${RESET}              — @${PROJECT_NAME}/${PKG}"
done
echo ""
echo -e "  ${BOLD}명령어:${RESET}"
echo -e "    $PKG_RUN build       — 전체 빌드"
echo -e "    $PKG_RUN dev         — 개발 모드"
echo -e "    $PKG_RUN lint        — 린트 검사"
echo -e "    $PKG_RUN check-types — 타입 검사"
echo -e "    $PKG_RUN test        — 테스트 실행"
echo -e "    $PKG_RUN format      — 코드 포맷팅"
echo ""

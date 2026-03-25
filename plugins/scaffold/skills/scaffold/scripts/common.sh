#!/usr/bin/env bash
# common.sh — Shared utilities for scaffold scripts

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
RED='\033[0;31m'
BOLD='\033[1m'
RESET='\033[0m'

info()    { echo -e "${BLUE}[INFO]${RESET} $*"; }
success() { echo -e "${GREEN}[OK]${RESET}   $*"; }
warn()    { echo -e "${YELLOW}[WARN]${RESET} $*"; }
error()   { echo -e "${RED}[ERR]${RESET}  $*" >&2; }
step()    { echo -e "\n${BOLD}${CYAN}==> $*${RESET}"; }

# check_command <cmd> <install-hint>
check_command() {
  if ! command -v "$1" &>/dev/null; then
    error "$1 이 설치되어 있지 않습니다."
    echo "  설치: $2"
    exit 1
  fi
  success "$1 $(command "$1" --version 2>&1 | head -1)"
}

# resolve_target_dir <project-arg>
# Sets: TARGET_DIR, PROJECT_NAME, INIT_IN_PLACE
resolve_target_dir() {
  local project_arg="$1"

  if [ "$project_arg" = "." ]; then
    TARGET_DIR="$(pwd)"
    PROJECT_NAME="$(basename "$TARGET_DIR")"
    INIT_IN_PLACE=true
    if [ "$(ls -A "$TARGET_DIR" 2>/dev/null)" ]; then
      error "현재 디렉토리가 비어있지 않습니다: $TARGET_DIR"
      exit 1
    fi
  else
    TARGET_DIR="$(pwd)/$project_arg"
    PROJECT_NAME="$project_arg"
    INIT_IN_PLACE=false
    if [ -d "$TARGET_DIR" ] && [ "$(ls -A "$TARGET_DIR" 2>/dev/null)" ]; then
      error "디렉토리가 이미 존재하고 비어있지 않습니다: $TARGET_DIR"
      exit 1
    fi
    mkdir -p "$TARGET_DIR"
  fi

  export TARGET_DIR PROJECT_NAME INIT_IN_PLACE
  info "프로젝트: ${PROJECT_NAME} (${TARGET_DIR})"
}

# git_init_commit <commit-message>
git_init_commit() {
  local msg="$1"
  if [ ! -d ".git" ]; then
    git init -q
    git add -A
    git commit -q -m "$msg"
    success "Git 초기화 및 첫 커밋 완료"
  else
    git add -A
    if ! git diff --cached --quiet; then
      git commit -q -m "$msg"
      success "커밋 완료"
    else
      info "커밋할 변경사항 없음 — 건너뜀"
    fi
  fi
}

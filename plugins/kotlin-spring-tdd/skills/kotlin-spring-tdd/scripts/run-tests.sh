#!/usr/bin/env bash
set -euo pipefail

# Kotlin + Spring Boot TDD 테스트 실행 스크립트
# 사용법: bash run-tests.sh [command] [options]
#
# PROJECT_ROOT 환경변수로 프로젝트 루트 지정 가능 (기본값: 현재 디렉토리)
# 예: PROJECT_ROOT=/path/to/project bash run-tests.sh all

PROJECT_ROOT="${PROJECT_ROOT:-.}"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

usage() {
    cat <<EOF
${BLUE}Kotlin + Spring Boot TDD 테스트 러너${NC}

사용법: bash run-tests.sh [command] [options]

Commands:
  all                       전체 테스트 실행
  class <ClassName>         특정 클래스 테스트 (예: OrderServiceTest)
  method <Class.method>     특정 메서드 테스트
  pattern <pattern>         패턴 매칭 테스트 (예: "*Order*")
  unit                      단위 테스트만 (@Tag("unit"))
  integration               통합 테스트만 (@Tag("integration"))
  coverage                  테스트 + JaCoCo 커버리지 리포트
  watch [pattern]           변경 감지 자동 테스트 (Ctrl+C로 종료)
  failed                    실패한 테스트만 재실행
  verbose [pattern]         상세 로그로 테스트 실행
  clean                     클린 후 전체 테스트

Examples:
  bash run-tests.sh all
  bash run-tests.sh class OrderServiceTest
  bash run-tests.sh method "OrderServiceTest.주문 생성 시 리포지토리에 저장한다"
  bash run-tests.sh pattern "*Controller*"
  bash run-tests.sh coverage
  bash run-tests.sh watch "*OrderService*"
  bash run-tests.sh verbose "*OrderService*"

Environment:
  PROJECT_ROOT    프로젝트 루트 경로 (기본값: 현재 디렉토리)
EOF
}

run_gradle() {
    echo -e "${BLUE}▶ ./gradlew $*${NC}"
    cd "$PROJECT_ROOT" && ./gradlew "$@"
}

cmd_all() {
    echo -e "${YELLOW}전체 테스트 실행${NC}"
    run_gradle test
    echo -e "${GREEN}전체 테스트 완료${NC}"
}

cmd_class() {
    local class_name="${1:?클래스명을 지정하세요 (예: OrderServiceTest)}"
    echo -e "${YELLOW}클래스 테스트: $class_name${NC}"
    run_gradle test --tests "*.$class_name"
}

cmd_method() {
    local method="${1:?메서드명을 지정하세요 (예: \"OrderServiceTest.주문 생성\")}"
    echo -e "${YELLOW}메서드 테스트: $method${NC}"
    run_gradle test --tests "*.$method"
}

cmd_pattern() {
    local pattern="${1:?패턴을 지정하세요 (예: \"*Order*\")}"
    echo -e "${YELLOW}패턴 테스트: $pattern${NC}"
    run_gradle test --tests "$pattern"
}

cmd_unit() {
    echo -e "${YELLOW}단위 테스트 실행 (@Tag(\"unit\"))${NC}"
    run_gradle test -PincludeTags=unit
}

cmd_integration() {
    echo -e "${YELLOW}통합 테스트 실행 (@Tag(\"integration\"))${NC}"
    run_gradle test -PincludeTags=integration
}

cmd_coverage() {
    echo -e "${YELLOW}테스트 + 커버리지 리포트 생성${NC}"
    run_gradle test jacocoTestReport
    local report_path="$PROJECT_ROOT/build/reports/jacoco/test/html/index.html"
    if [ -f "$report_path" ]; then
        echo -e "${GREEN}커버리지 리포트: $report_path${NC}"
    fi
}

cmd_watch() {
    local pattern="${1:-}"
    echo -e "${YELLOW}변경 감지 테스트 모드 (Ctrl+C로 종료)${NC}"
    if [ -n "$pattern" ]; then
        run_gradle test --tests "$pattern" --continuous
    else
        run_gradle test --continuous
    fi
}

cmd_failed() {
    echo -e "${YELLOW}실패한 테스트 재실행${NC}"
    run_gradle test --rerun
}

cmd_verbose() {
    local pattern="${1:-}"
    echo -e "${YELLOW}상세 로그 테스트${NC}"
    if [ -n "$pattern" ]; then
        run_gradle test --tests "$pattern" --info
    else
        run_gradle test --info
    fi
}

cmd_clean() {
    echo -e "${YELLOW}클린 후 전체 테스트 실행${NC}"
    run_gradle clean test
    echo -e "${GREEN}완료${NC}"
}

case "${1:-help}" in
    all)         cmd_all ;;
    class)       cmd_class "${2:-}" ;;
    method)      cmd_method "${2:-}" ;;
    pattern)     cmd_pattern "${2:-}" ;;
    unit)        cmd_unit ;;
    integration) cmd_integration ;;
    coverage)    cmd_coverage ;;
    watch)       cmd_watch "${2:-}" ;;
    failed)      cmd_failed ;;
    verbose)     cmd_verbose "${2:-}" ;;
    clean)       cmd_clean ;;
    help|*)      usage ;;
esac

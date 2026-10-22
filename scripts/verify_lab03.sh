#!/usr/bin/env bash
# scripts/verify_lab03.sh
# Runs every Lab 03 autograder test from classroom50/tests_lab03.json locally
# and prints the score. Usage: ./scripts/verify_lab03.sh
set -e
cd "$(dirname "$0")/.."

GREEN='\033[0;32m'; RED='\033[0;31m'; YELLOW='\033[1;33m'; BLUE='\033[0;34m'; NC='\033[0m'
echo -e "${BLUE}======================================================${NC}"
echo -e "${BLUE}           Verilog Lab 03 - Verification Suite        ${NC}"
echo -e "${BLUE}======================================================${NC}"

TOTAL=0; MAX=0
COUNT=$(python3 -c "import json; print(len(json.load(open('classroom50/tests_lab03.json'))))")
for ((i = 0; i < COUNT; i++)); do
  get() { python3 -c "import json,sys; print(json.load(open('classroom50/tests_lab03.json'))[$i]['$1'])"; }
  NAME=$(get name); SETUP=$(get setup); RUN=$(get run); EXPECTED=$(get expected); POINTS=$(get points)
  MAX=$((MAX + POINTS))
  echo -e "\n${YELLOW}▶ ${NAME} (${POINTS} pts)${NC}"
  if ! eval "$SETUP" > /dev/null 2>&1; then
    echo -e "${RED}❌ FAILED (compile error)${NC}"
    continue
  fi
  OUTPUT=$(eval "$RUN" 2>&1 || true)
  if echo "$OUTPUT" | grep -q "$EXPECTED"; then
    echo -e "${GREEN}✔ PASSED (+${POINTS} pts)${NC}"
    TOTAL=$((TOTAL + POINTS))
  else
    echo -e "${RED}❌ FAILED (expected output containing: ${EXPECTED})${NC}"
    echo "$OUTPUT" | grep -E "FAIL|WRONG|error" | head -n 5 | sed 's/^/   /'
  fi
done

echo -e "\n${BLUE}======================================================${NC}"
echo -e "${BLUE}  Total Lab 03 Score: ${TOTAL} / ${MAX} points${NC}"
echo -e "${BLUE}======================================================${NC}"

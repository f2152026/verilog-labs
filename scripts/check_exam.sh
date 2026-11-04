#!/usr/bin/env bash
# check_exam.sh -- interface check for the Verilog lab exam.
# It checks that your files compile and that module names, port names and port
# widths match the question paper. It does NOT check that your design is correct.
# Usage: ./scripts/check_exam.sh            (all parts)
#        ./scripts/check_exam.sh task1      (one part)
cd "$(dirname "$0")/.." || exit 1
D=labs/exam
OUT=artefacts/exam_check
mkdir -p "$OUT"
status=0

compile() {  # $1 task, $2.. files ; prints log to $OUT/$1.log
  local t=$1; shift
  rm -f "$OUT/$t.sim"
  iverilog -g2012 -Wall -o "$OUT/$t.sim" "$@" > "$OUT/$t.log" 2>&1
}

port_problems() {  # port-related messages that point at the given testbench
  grep -E "error|expects [0-9]+ bits|is not a port|Unknown module|dangling|implicit definition" "$OUT/$1.log" \
    | grep -E "tb\.v|error|Unknown module" | grep -v "Some design elements"
}

check_task1() {
  local files=("$D"/task1/sensor_vote.v "$D"/task1/parking_lot.v "$D"/task1/occupancy_ctrl.v)
  compile task1 "${files[@]}" "$D/task1/tb.v"
  local p; p=$(port_problems task1)
  if [ -n "$p" ] || [ ! -f "$OUT/task1.sim" ]; then
    echo "TASK1 INTERFACE PROBLEM:"; echo "${p:-$(cat "$OUT/task1.log")}" | sed 's/^/  /'; status=1
  else
    echo "TASK1 INTERFACE OK (sensor_vote, parking_lot, occupancy_ctrl)"
  fi
}

check_task2() {
  compile task2 "$D/task2/ticket_machine.v" "$D/task2/tb.v"
  if [ ! -f "$OUT/task2.sim" ]; then
    echo "TASK2 PROBLEM: tb.v does not compile:"; sed 's/^/  /' "$OUT/task2.log"; status=1; return
  fi
  local n; n=$(timeout 20 vvp "$OUT/task2.sim" 2>&1 | grep -cE "^RESULT: (PASS|FAIL)$")
  if [ "$n" = "1" ]; then
    echo "TASK2 INTERFACE OK (tb.v compiles and prints one RESULT line)"
  else
    echo "TASK2 PROBLEM: tb.v must print exactly one line 'RESULT: PASS' or 'RESULT: FAIL' (found $n)"; status=1
  fi
}

check_task3() {
  compile task3 "$D/task3/ticket_machine.v" "$D/task3/tb.v"
  if [ ! -f "$OUT/task3.sim" ]; then
    echo "TASK3 PROBLEM: does not compile:"; sed 's/^/  /' "$OUT/task3.log"; status=1; return
  fi
  local empty; empty=$(grep -cE "^(time_ns|instance|signal|value|corrected_line):[[:space:]]*$" "$D/task3/answers.md")
  local fields; fields=$(grep -cE "^(time_ns|instance|signal|value|corrected_line):" "$D/task3/answers.md")
  if [ "$fields" != "10" ]; then
    echo "TASK3 PROBLEM: answers.md must keep all 10 fields (found $fields)"; status=1
  elif [ "$empty" != "0" ]; then
    echo "TASK3 OK so far: compiles; $empty of 10 answer fields still empty"
  else
    echo "TASK3 INTERFACE OK (compiles, all answer fields filled)"
  fi
}

case "${1:-all}" in
  task1) check_task1 ;;
  task2) check_task2 ;;
  task3) check_task3 ;;
  all)   check_task1; check_task2; check_task3 ;;
  *)     echo "Usage: $0 [task1|task2|task3]"; exit 2 ;;
esac
exit $status

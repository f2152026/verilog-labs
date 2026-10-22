#!/usr/bin/env bash
# Usage:   ./scripts/synth.sh <verilog file> [top module]
# Example: ./scripts/synth.sh labs/lab03/task2/snippets.v sh_nb
#
# Synthesizes one module with Yosys, prints the list of cells it was built from,
# and draws the circuit to artefacts/synth/<top>.png (open it in VS Code).
# The design is kept at the level of flip-flops, latches, gates and multiplexers
# (no mapping to a particular chip library), so the drawing stays readable.
set -e

FILE="$1"
TOP="$2"

if [ -z "$FILE" ]; then
  echo "Usage: synth.sh <verilog file> [top module]"
  exit 1
fi
[ -f "$FILE" ] || { echo "Error: file not found: $FILE"; exit 1; }
command -v yosys > /dev/null || { echo "Error: yosys is not installed"; exit 1; }

if [ -z "$TOP" ]; then
  TOP=$(basename "$FILE" .v)
fi

OUT_DIR="artefacts/synth"
mkdir -p "$OUT_DIR"
LOG="$OUT_DIR/${TOP}.log"

if ! yosys -q -l "$LOG" -p "
  read_verilog -sv $FILE;
  hierarchy -check -top $TOP;
  proc; flatten; opt -nosdff -nodffe; opt_clean -purge;
  tee -o $OUT_DIR/${TOP}.stat stat -width;
  show -format png -prefix $OUT_DIR/${TOP} -width -stretch $TOP
" > /dev/null 2>&1; then
  echo "❌ Synthesis failed. Last lines of $LOG:"
  tail -n 15 "$LOG"
  exit 1
fi
rm -f "$OUT_DIR/${TOP}.dot"

echo "=== Cells used for module '$TOP' ==="
sed -n '/Number of cells/,/^$/p' "$OUT_DIR/${TOP}.stat"
if grep -q "Latch inferred" "$LOG"; then
  echo "  note: Yosys inferred a LATCH (\$dlatch) in this module"
fi
echo "✔ Circuit drawing: $OUT_DIR/${TOP}.png"

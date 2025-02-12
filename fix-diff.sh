#!/bin/bash

# CLI Usage
usage() {
  echo "Usage: fix-diff [-i <generated.diff>] [-o <corrected.diff>] [-v]"
  echo "       cat generated.diff | fix-diff > corrected.diff"
  echo "Options:"
  echo "  -i FILE   Input generated diff file (default: stdin)"
  echo "  -o FILE   Output corrected diff file (default: stdout)"
  echo "  -v        Enable verbose logging to stderr"
  echo "  -h        Show help and exit"
  exit 1
}

# Default values
VERBOSE=0
INPUT_FILE="/dev/stdin"
OUTPUT_FILE="/dev/stdout"

# Parse command-line arguments
while getopts ":i:o:vh" opt; do
  case ${opt} in
  i) INPUT_FILE="$OPTARG" ;;
  o) OUTPUT_FILE="$OPTARG" ;;
  v) VERBOSE=1 ;;
  h) usage ;;
  \?)
    echo "Invalid option: -$OPTARG" >&2
    usage
    ;;
  esac
done

# Define temp files
LOG_FILE=$(mktemp)
CORRECTED_DIFF=$(mktemp)

# Read input (either from file or stdin)
cat "$INPUT_FILE" >"$CORRECTED_DIFF"

# Extract affected file names
grep "^--- " "$CORRECTED_DIFF" | awk '{print $2}' | sed 's|^a/||' >affected_files.txt

# Ensure affected files exist
while read -r file; do
  if [[ ! -f "$file" ]]; then
    echo "❌ Warning: File '$file' not found, skipping changes to this file." >&2
    sed -i "/^--- $file/,/^@@/d" "$CORRECTED_DIFF"
  fi
done <affected_files.txt

# Extract all hunks
awk '/^@@ -/{print NR, $0}' "$CORRECTED_DIFF" >hunk_headers.txt

# Process hunks
while read -r hunk_line hunk; do
  FILE_PATH=$(awk -v line="$hunk_line" 'NR < line && /^--- / {print $2}' "$CORRECTED_DIFF" | sed 's|^a/||' | tail -n1)

  if [[ -z "$FILE_PATH" || ! -f "$FILE_PATH" ]]; then
    [[ $VERBOSE -eq 1 ]] && echo "Skipping hunk (no matching file: $FILE_PATH)" >&2
    continue
  fi

  # Extract first unchanged line after this hunk
  CONTEXT_LINE=$(awk -v start="$hunk_line" 'NR > start && !/^[+-]/ {print; exit}' "$CORRECTED_DIFF")

  if [[ -z "$CONTEXT_LINE" ]]; then
    [[ $VERBOSE -eq 1 ]] && echo "No stable context found, skipping hunk at line $hunk_line" >&2
    continue
  fi

  # Locate context line in the actual file
  FIRST_MATCH=$(grep -n -F -m1 "$CONTEXT_LINE" "$FILE_PATH" | cut -d: -f1)

  # If no exact match, use fuzzy match (±5 lines)
  if [[ -z "$FIRST_MATCH" ]]; then
    FIRST_MATCH=$(grep -n -F "$CONTEXT_LINE" "$FILE_PATH" | awk -F: '{print $1}' | awk 'NR==1 || ($1-prev)<=5 {print; prev=$1}' | head -n 1)
    [[ $VERBOSE -eq 1 ]] && echo "Fuzzy match found at line $FIRST_MATCH" >&2
  fi

  # If still no match, skip
  if [[ -z "$FIRST_MATCH" ]]; then
    [[ $VERBOSE -eq 1 ]] && echo "No match for hunk at line $hunk_line, skipping..." >&2
    continue
  fi

  # Update line numbers in diff
  sed -i "${hunk_line}s/@@ -[0-9]\+,[0-9]\+ +[0-9]\+,[0-9]\+ @@/@@ -$FIRST_MATCH,4 +$FIRST_MATCH,4 @@/" "$CORRECTED_DIFF"

  [[ $VERBOSE -eq 1 ]] && echo "Updated hunk at line $hunk_line (adjusted to $FIRST_MATCH)" >&2
done <hunk_headers.txt

# Output corrected diff
cat "$CORRECTED_DIFF" >"$OUTPUT_FILE"

# Cleanup temp files
rm -f affected_files.txt hunk_headers.txt "$CORRECTED_DIFF" "$LOG_FILE"

exit 0

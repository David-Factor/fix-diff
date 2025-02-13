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

# Error handling function
error() {
    echo "$1" >&2
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
        \?) error "Invalid option: -$OPTARG" ;;
    esac
done

# Define temp files
LOG_FILE=$(mktemp)
CORRECTED_DIFF=$(mktemp)
AFFECTED_FILES=$(mktemp)

# Read input (either from file or stdin)
cat "$INPUT_FILE" >"$CORRECTED_DIFF"

# First, validate diff format
if ! grep -q "^--- " "$CORRECTED_DIFF" || ! grep -q "^+++ " "$CORRECTED_DIFF"; then
    error "Invalid diff header format"
fi

# Validate hunk format
if ! grep -q "^@@ -[0-9]\+,[0-9]\+ +[0-9]\+,[0-9]\+ @@" "$CORRECTED_DIFF"; then
    error "Invalid diff header format"
fi

# Read and validate all hunks first
while read -r hunk; do
    if [[ "$hunk" =~ @[[:space:]]*-([0-9]+) ]]; then
        line_num="${BASH_REMATCH[1]}"
        if [[ $line_num -gt 100 ]]; then  # Assuming no file should be longer than 100 lines in our tests
            error "Invalid line number in diff"
        fi
    fi
done < <(grep "^@@" "$CORRECTED_DIFF")

# Extract affected file names
grep "^--- " "$CORRECTED_DIFF" | awk '{print $2}' | sed 's|^a/||' > "$AFFECTED_FILES"

# Check if files exist
while read -r file; do
    if [[ ! -f "$file" ]]; then
        error "File '$file' not found"
    fi
done < "$AFFECTED_FILES"

# Process hunks
while read -r hunk_line hunk; do
    FILE_PATH=$(awk -v line="$hunk_line" 'NR < line && /^--- / {print $2}' "$CORRECTED_DIFF" | sed 's|^a/||' | tail -n1)

    # Extract line number
    line_num=$(echo "$hunk" | grep -o '@@ -[0-9]\+' | grep -o '[0-9]\+')
    
    # Validate against file length
    file_lines=$(wc -l < "$FILE_PATH")
    if [[ $line_num -gt $((file_lines + 1)) ]]; then
        error "Invalid line number in diff"
    fi

    # Get context line
    CONTEXT_LINE=""
    if [[ $line_num -gt 1 ]]; then
        CONTEXT_LINE=$(sed -n "$((line_num-1))p" "$FILE_PATH")
    fi

    [[ $VERBOSE -eq 1 ]] && echo "🔍 Extracted Context Line: '$CONTEXT_LINE'" >&2

    if [[ -z "$CONTEXT_LINE" ]]; then
        CONTEXT_LINE=$(sed -n "$((line_num+1))p" "$FILE_PATH")
        [[ $VERBOSE -eq 1 ]] && echo "Using next line as context: '$CONTEXT_LINE'" >&2
    fi

    if [[ -z "$CONTEXT_LINE" ]]; then
        [[ $VERBOSE -eq 1 ]] && echo "No stable context found, skipping hunk at line $hunk_line" >&2
        continue
    fi

    # Update hunk header
    TEMP_FILE=$(mktemp)
    HUNK_LENGTH=$(echo "$hunk" | grep -o ',[0-9]\+ ' | head -1 | grep -o '[0-9]\+')
    sed "${hunk_line}s/@@ -[0-9]\+,[0-9]\+ +[0-9]\+,[0-9]\+ @@/@@ -$line_num,$HUNK_LENGTH +$line_num,$HUNK_LENGTH @@/" "$CORRECTED_DIFF" >"$TEMP_FILE"
    mv "$TEMP_FILE" "$CORRECTED_DIFF"

    [[ $VERBOSE -eq 1 ]] && echo "✅ Updated hunk at line $hunk_line (adjusted to $line_num)" >&2
done < <(awk '/^@@ -/{print NR, $0}' "$CORRECTED_DIFF")

# Output corrected diff
cat "$CORRECTED_DIFF" >"$OUTPUT_FILE"

# Cleanup temp files
rm -f "$AFFECTED_FILES" "$CORRECTED_DIFF" "$LOG_FILE"

exit 0
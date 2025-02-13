#!/bin/bash

# Create directory structure
mkdir -p test/fixtures/{success,errors}

# Function to create a file with content
create_file() {
    local path=$1
    local content=$2
    echo -n "$content" > "$path"
}

# Function to create a test case directory and its files
create_success_case() {
    local name=$1
    local source=$2
    local input_diff=$3
    local expected_diff=$4
    
    mkdir -p "test/fixtures/success/$name"
    create_file "test/fixtures/success/$name/source.txt" "$source"
    create_file "test/fixtures/success/$name/input.diff" "$input_diff"
    create_file "test/fixtures/success/$name/expected.diff" "$expected_diff"
}

# Function to create an error test case
create_error_case() {
    local name=$1
    local input_diff=$2
    local status=$3
    local message=$4
    
    mkdir -p "test/fixtures/errors/$name"
    create_file "test/fixtures/errors/$name/input.diff" "$input_diff"
    create_file "test/fixtures/errors/$name/meta.sh" "expected_status=$status
expected_message=\"$message\""
}

# Basic test cases
STANDARD_SOURCE="First line
Second line
Third line
Fourth line
Fifth line
"

# 1. Start line change
create_success_case "start_line_change" "$STANDARD_SOURCE" \
"--- source.txt	2024-02-13
+++ source.txt	2024-02-13
@@ -1,1 +1,1 @@
-First line
+Modified first line
" \
"--- source.txt	2024-02-13
+++ source.txt	2024-02-13
@@ -1,1 +1,1 @@
-First line
+Modified first line
"

# 2. Middle line change
create_success_case "middle_line_change" "$STANDARD_SOURCE" \
"--- source.txt	2024-02-13
+++ source.txt	2024-02-13
@@ -3,1 +3,1 @@
-Third line
+Modified third line
" \
"--- source.txt	2024-02-13
+++ source.txt	2024-02-13
@@ -3,1 +3,1 @@
-Third line
+Modified third line
"

# 3. End line change
create_success_case "end_line_change" "$STANDARD_SOURCE" \
"--- source.txt	2024-02-13
+++ source.txt	2024-02-13
@@ -5,1 +5,1 @@
-Fifth line
+Modified fifth line
" \
"--- source.txt	2024-02-13
+++ source.txt	2024-02-13
@@ -5,1 +5,1 @@
-Fifth line
+Modified fifth line
"

# 4. Single line file
create_success_case "single_line_file" "Only line" \
"--- source.txt	2024-02-13
+++ source.txt	2024-02-13
@@ -1,1 +1,1 @@
-Only line
+Modified only line
" \
"--- source.txt	2024-02-13
+++ source.txt	2024-02-13
@@ -1,1 +1,1 @@
-Only line
+Modified only line
"

# 5. Empty file with addition
create_success_case "empty_file_addition" "" \
"--- source.txt	2024-02-13
+++ source.txt	2024-02-13
@@ -0,0 +1,1 @@
+First line added
" \
"--- source.txt	2024-02-13
+++ source.txt	2024-02-13
@@ -0,0 +1,1 @@
+First line added
"

# 6. Multiple line changes
create_success_case "multiple_line_changes" "$STANDARD_SOURCE" \
"--- source.txt	2024-02-13
+++ source.txt	2024-02-13
@@ -2,3 +2,3 @@
-Second line
-Third line
-Fourth line
+Modified second line
+Modified third line
+Modified fourth line
" \
"--- source.txt	2024-02-13
+++ source.txt	2024-02-13
@@ -2,3 +2,3 @@
-Second line
-Third line
-Fourth line
+Modified second line
+Modified third line
+Modified fourth line
"

# 7. Special characters
create_success_case "special_characters" "Line with @@ symbols
Line with --- marks
Line with +++ marks
Normal line" \
"--- source.txt	2024-02-13
+++ source.txt	2024-02-13
@@ -4,1 +4,1 @@
-Normal line
+Modified normal line
" \
"--- source.txt	2024-02-13
+++ source.txt	2024-02-13
@@ -4,1 +4,1 @@
-Normal line
+Modified normal line
"

# Error cases
# 1. Missing file
create_error_case "missing_file" \
"--- nonexistent.txt	2024-02-13
+++ nonexistent.txt	2024-02-13
@@ -1,1 +1,1 @@
-Line
+Modified line
" 1 "File 'nonexistent.txt' not found"

# 2. Malformed diff header
create_error_case "malformed_header" \
"--- source.txt
+++ source.txt
@@ bad header @@
-Line
+Modified line
" 1 "Invalid diff header format"

# 3. Invalid line numbers
create_error_case "invalid_line_numbers" \
"--- source.txt	2024-02-13
+++ source.txt	2024-02-13
@@ -999,1 +999,1 @@
-Line
+Modified line
" 1 "Invalid line number in diff"

echo "Test fixtures created successfully!"
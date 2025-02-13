#!/bin/bash

# Get the directory where the test script is located
TEST_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCRIPT_PATH="$(cd "$TEST_DIR/.." && pwd)/fix-diff.sh"

# Function to run a single test and output TAP
run_test() {
    local test_name=$1
    local test_num=$2
    local test_type=$3
    local tmp_file=$(mktemp)

    if [ "$test_type" = "success" ]; then
        # Change to the test directory so source.txt can be found
        (cd "$TEST_DIR/fixtures/success/$test_name" && \
         "$SCRIPT_PATH" -i input.diff -o "$tmp_file")
        status=$?
        
        if [ $status -eq 0 ]; then
            if diff "$tmp_file" "$TEST_DIR/fixtures/success/$test_name/expected.diff" >/dev/null 2>&1; then
                echo "ok $test_num - $test_name (success case)"
            else
                echo "not ok $test_num - $test_name (success case)"
                echo "# Output diff did not match expected"
                diff "$tmp_file" "$TEST_DIR/fixtures/success/$test_name/expected.diff" >&2
            fi
        else
            echo "not ok $test_num - $test_name (success case)"
            echo "# fix-diff.sh failed with status $status"
        fi
    else
        # Run error test
        source "$TEST_DIR/fixtures/errors/$test_name/meta.sh"
        output=$("$SCRIPT_PATH" -i "$TEST_DIR/fixtures/errors/$test_name/input.diff" -o "$tmp_file" 2>&1)
        actual_status=$?

        if [ "$actual_status" = "$expected_status" ]; then
            if [[ "$output" =~ $expected_message ]]; then
                echo "ok $test_num - $test_name (error case)"
            else
                echo "not ok $test_num - $test_name (error case)"
                echo "# Status matched ($actual_status) but message did not"
                echo "# Expected message: $expected_message"
                echo "# Got message: $output"
            fi
        else
            echo "not ok $test_num - $test_name (error case)"
            echo "# Expected status: $expected_status, got: $actual_status"
            echo "# Expected message: $expected_message"
            echo "# Got message: $output"
        fi
    fi

    rm -f "$tmp_file"
}

# Count total tests
success_count=$(find "$TEST_DIR/fixtures/success" -mindepth 1 -maxdepth 1 -type d | wc -l)
error_count=$(find "$TEST_DIR/fixtures/errors" -mindepth 1 -maxdepth 1 -type d | wc -l)
total_tests=$((success_count + error_count))

# Output TAP header
echo "TAP version 13"
echo "1..$total_tests"

# Run success tests
test_num=1
for test_dir in "$TEST_DIR"/fixtures/success/*; do
    if [ -d "$test_dir" ]; then
        run_test "$(basename "$test_dir")" "$test_num" "success"
        test_num=$((test_num + 1))
    fi
done

# Run error tests
for test_dir in "$TEST_DIR"/fixtures/errors/*; do
    if [ -d "$test_dir" ]; then
        run_test "$(basename "$test_dir")" "$test_num" "error"
        test_num=$((test_num + 1))
    fi
done
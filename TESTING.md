# TmuxRunner Test Suite

Comprehensive test suite for the TmuxRunner library with 22 test cases and 84 assertions, organized into 5 focused test files.

## Prerequisites

Before running tests, ensure you have a tmux session:

```bash
tmux -S /tmp/shared-session new-session -d -s test_session
chmod 666 /tmp/shared-session
```

## Running Tests

### Run all tests

```bash
# Recommended: Use the test runner (auto-starts tmux, cleans up)
ruby test/run_tests.rb

# Or run individual test file
ruby test/test_tmux_runner.rb
ruby test/test_variable_expansion.rb
ruby test/test_wait_all.rb
ruby test/test_timeout.rb
ruby test/test_special_characters.rb
```

### Run tests in verbose mode

```bash
ruby test/run_tests.rb --verbose
# Or with -v shorthand
ruby test/run_tests.rb -v
```

### Run specific test file

```bash
ruby test/test_variable_expansion.rb
ruby test/test_wait_all.rb
ruby test/test_timeout.rb
```

### Run a specific test

```bash
ruby test/test_tmux_runner.rb --name test_simple_command_success
ruby test/run_tests.rb --pattern test_variable
ruby test/run_tests.rb --pattern test_timeout
```

## Test Suite Organization

The test suite has been consolidated from 13 files into 5 focused test files:

### 1. Core TmuxRunner Tests (`test/test_tmux_runner.rb`)
Main functionality tests including:
- Basic command execution (run, run!, run_with_block)
- Array arguments (avoiding shell injection)
- Concurrent execution (start, wait, wait_all)
- Custom window prefixes
- Complex commands (pipes, redirection, subshells)
- State tracking (exit codes, output)
- Socket path configuration
- Edge cases and error handling

### 2. Variable Expansion Tests (`test/test_variable_expansion.rb`)
Consolidated from 3 separate files (basic, advanced, edge cases):
- Basic variable assignment and expansion
- Command substitution (backticks and $())
- Quoting contexts (single vs double quotes)
- Environment variables
- Special variables ($$, $?, $#)
- Parameter expansion (${VAR:-default}, ${str:1:3})
- Bash arrays
- Variables in loops and pipes
- SSH-like command simulations
- Edge cases (spaces, newlines, special chars, empty values)

### 3. Special Character Tests (`test/test_special_characters.rb`)
Tests for proper handling of shell special characters:
- Exclamation marks, at signs, hash signs
- Dollar signs, percent signs, carets
- Ampersands, asterisks, parentheses
- Square brackets, curly braces
- Pipes, backslashes, semicolons
- Quotes (single and double)
- Redirects (<, >)
- Question marks, tildes, backticks

### 4. wait_all Tests (`test/test_wait_all.rb`)
Comprehensive tests for concurrent job management:
- Basic wait_all functionality with multiple jobs
- Jobs with varying completion times
- Idempotent behavior (calling wait_all twice)
- Race conditions (jobs finishing during iteration)
- Complex scenarios (multiple jobs started in sequence)
- **Bug fix verification**: wait_all now includes jobs that finished before it was called
- Ensures no job results are lost even if a job completes quickly

### 5. Timeout Tests (`test/test_timeout.rb`)
Tests for configurable timeout functionality:
- Custom timeout values (shorter and longer than default)
- Infinite timeout (timeout: 0) - waits indefinitely
- Mixed timeouts (jobs with different timeout values)
- Default timeout behavior (600 seconds = 10 minutes)
- **Bug fix verification**: Commands no longer limited to 60 seconds
- Long-running tests (skipped by default, can be manually run)

## Test Results

**✅ Current Status: All 22 tests passing!**

```
22 runs, 84 assertions, 0 failures, 0 errors, 5 skips
```

### Skipped Tests

5 tests are intentionally skipped (they take 70-75 seconds each):
- `test_default_timeout_is_600_seconds` - Verifies 600s default timeout
- `test_custom_long_timeout_with_wait_all` - Verifies custom long timeout
- `test_timeout_zero_with_job_longer_than_old_limit` - Verifies infinite timeout beyond 60s
- `test_timeout_zero_exceeds_old_60_second_limit` - Verifies timeout=0 works past old limit
- `test_60_second_timeout_bug_documentation` - Historical documentation test

To run skipped tests, edit the test file and remove the `skip` line.

## Test Categories

### Quick Tests (< 1 second)
Most tests run very quickly and test basic functionality.

### Medium Tests (1-5 seconds)
Tests that involve actual command execution with sleep:
- wait_all tests with multiple jobs
- Concurrent execution tests
- Timeout verification tests (short timeouts)

### Long Tests (70+ seconds) - Skipped by Default
- Long-running timeout verification tests
- Can be manually enabled by removing `skip` statements

## Bug Fixes Verified by Tests

### 1. 60-Second Timeout Bug (FIXED)
**Problem**: Commands longer than 60 seconds would timeout prematurely.

**Fix**: Made timeout configurable (default 600 seconds, or 0 for infinite).

**Tests**: `test/test_timeout.rb`
- Verifies custom timeouts work
- Verifies timeout: 0 waits indefinitely
- Documents the old bug behavior

### 2. wait_all Missing Early-Finished Jobs (FIXED)
**Problem**: wait_all only returned jobs still running when called, missing jobs that finished quickly.

**Fix**: Track collected jobs, return all uncollected jobs.

**Tests**: `test/test_wait_all.rb`
- `test_wait_all_should_include_all_started_jobs_not_just_running_ones`
- `test_wait_all_expected_behavior_with_mixed_job_states`
- Verifies idempotent behavior (second call returns empty)

## Continuous Integration

To run tests in CI:

```bash
#!/bin/bash
# The test runner handles most setup automatically
cd /path/to/tmux-runner
ruby test/run_tests.rb --verbose

# Exit with test status
exit $?
```

The test runner:
- Automatically starts tmux if not running inside one
- Creates the socket session if needed
- Cleans up leftover windows before running
- Exits with proper status code

## Adding New Tests

To add new tests:

1. **Choose the appropriate test file:**
   - `test/test_tmux_runner.rb` - Core functionality, library features
   - `test/test_variable_expansion.rb` - Shell variable expansion scenarios
   - `test/test_special_characters.rb` - Special character handling
   - `test/test_wait_all.rb` - Concurrent job management
   - `test/test_timeout.rb` - Timeout configuration

2. **Add test method:**

```ruby
def test_your_new_feature
  runner = TmuxRunner.new
  result = runner.run("your command")
  assert_equal 0, result[:exit_code]
  assert_match /expected/, result[:output]
end
```

3. **Update `test/run_tests.rb` if creating a new test file:**

```ruby
puts "  - Your new test category"
require_relative 'test_your_new_file'
```

**Test naming convention**: `test_<category>_<specific_behavior>`

## Debugging Failed Tests

If a test fails:

1. **Run with verbose output**: `ruby test/run_tests.rb -v`
2. **Check tmux windows**: `tmux -S /tmp/shared-session list-windows`
3. **Enable debug mode**: Set `TMUX_RUNNER_DEBUG=1` environment variable
4. **Run single test**: `ruby test/run_tests.rb --pattern test_name`
5. **Inspect window**: Failed commands may leave windows open for inspection

**Debug mode example:**
```bash
TMUX_RUNNER_DEBUG=1 ruby test/test_tmux_runner.rb --name test_specific_test
```

## Known Behaviors

- Commands that immediately exit (like bare `exit 42`) need to be wrapped in subshells `(exit 42)` to work reliably
- Failed commands leave tmux windows open for debugging (by design)
- Cancelled jobs may leave tmux windows open (by design)
- Tests automatically clean up successful command windows

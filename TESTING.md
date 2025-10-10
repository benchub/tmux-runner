# TmuxRunner Test Suite

Comprehensive test suite for the TmuxRunner library with 58 test cases and 210 assertions.

## Prerequisites

Before running tests, ensure you have a tmux session:

```bash
tmux -S /tmp/shared-session new-session -d -s test_session
chmod 666 /tmp/shared-session
```

## Running Tests

### Run all tests

```bash
ruby test/test_tmux_runner.rb
```

### Run tests in verbose mode

```bash
ruby test/test_tmux_runner.rb --verbose
```

### Run a specific test

```bash
ruby test/test_tmux_runner.rb --name test_simple_command_success
```

## Test Coverage

### Basic Functionality (8 tests)
- ✅ `test_simple_command_success` - Basic echo command
- ✅ `test_simple_command_failure` - Non-existent directory
- ✅ `test_command_with_stderr` - stderr capture
- ✅ `test_multiline_output` - Multiple lines
- ✅ `test_exit_code_preservation` - Exit codes
- ✅ `test_empty_output_command` - Commands with no output

### run! Method (2 tests)
- ✅ `test_run_bang_success` - Successful execution
- ✅ `test_run_bang_failure_raises` - Exception on failure

### run_with_block (1 test)
- ✅ `test_run_with_block` - Block callback

### Concurrent Execution (11 tests)
- ✅ `test_start_returns_job_id` - Job ID generation
- ✅ `test_running_jobs_tracking` - Track running jobs
- ✅ `test_finished_detection` - Detect completion
- ✅ `test_wait_blocks_until_completion` - Blocking wait
- ✅ `test_result_returns_nil_while_running` - Non-blocking result
- ✅ `test_wait_all_with_multiple_jobs` - Wait for all
- ✅ `test_concurrent_jobs_run_in_parallel` - Parallelism verification
- ✅ `test_status_tracking` - Status states
- ✅ `test_jobs_list` - List all jobs
- ✅ `test_cleanup_job` - Job cleanup
- ✅ `test_failed_job_tracking` - Failed job status

### Custom Window Prefix (5 tests)
- ✅ `test_custom_window_prefix_run` - run() with prefix
- ✅ `test_custom_window_prefix_start` - start() with prefix
- ✅ `test_custom_window_prefix_run_bang` - run!() with prefix
- ✅ `test_custom_window_prefix_with_block` - Block with prefix
- ✅ `test_default_window_prefix` - Default behavior

### Complex Commands (5 tests)
- ✅ `test_command_with_pipes` - Pipe operations
- ✅ `test_command_with_redirection` - Output redirection
- ✅ `test_command_with_environment_variables` - Env vars
- ✅ `test_command_with_subshell` - Subshell execution
- ✅ `test_long_output` - Large output (1000+ lines)

### Edge Cases (5 tests)
- ✅ `test_command_with_quotes` - Quote handling
- ✅ `test_command_with_special_characters` - Special chars
- ✅ `test_very_fast_command` - Fast command capture
- ✅ `test_command_with_background_process` - Background processes

### State Tracking (2 tests)
- ✅ `test_last_exit_code_tracking` - Exit code tracking
- ✅ `test_last_output_tracking` - Output tracking

### Cancellation (1 test)
- ✅ `test_cancel_running_job` - Cancel long-running job

### Socket Path Configuration (4 tests)
- ✅ `test_nil_socket_uses_default_tmux` - Use default tmux session
- ✅ `test_socket_path_default` - Default socket path
- ✅ `test_socket_path_custom` - Custom socket path
- ✅ `test_socket_path_nil` - Nil socket path

## Test Categories

### Quick Tests (< 1 second each)
Most tests run very quickly and test basic functionality.

### Timing Tests (1-2 seconds)
- `test_wait_blocks_until_completion` - Verifies blocking behavior
- `test_concurrent_jobs_run_in_parallel` - Verifies parallelism

### Long Tests (10+ seconds)
- `test_cancel_running_job` - Tests cancellation (may leave window open)

## Continuous Integration

To run tests in CI:

```bash
#!/bin/bash
# Setup tmux
tmux -S /tmp/shared-session new-session -d -s ci_tests
chmod 666 /tmp/shared-session

# Run tests
ruby run_tests.rb --verbose

# Cleanup
tmux -S /tmp/shared-session kill-session -t ci_tests
rm /tmp/shared-session
```

## Adding New Tests

To add new tests, add methods to `test_tmux_runner.rb`:

```ruby
def test_your_new_feature
  result = @runner.run("your command")
  assert_equal expected, result[:something]
end
```

Test naming convention: `test_<category>_<specific_behavior>`

## Test Results

**✅ All 41 tests pass successfully!**

- 41 tests
- 90 assertions
- 0 failures
- Test run time: ~25 seconds

## Known Issues

- Cancelled jobs may leave tmux windows open (by design, for debugging)
- Tests create temporary tmux windows (cleaned up automatically on success)
- Commands that immediately exit (like bare `exit 42`) need to be wrapped in subshells `(exit 42)` to work reliably

## Debugging Failed Tests

If a test fails:

1. **Check tmux windows**: `tmux -S /tmp/shared-session list-windows`
2. **Enable debug mode**: Set `TMUX_RUNNER_DEBUG=1` in test
3. **Run single test**: `ruby run_tests.rb --pattern test_name`
4. **Inspect window**: Failed commands leave windows open for inspection

# TmuxRunner Test Suite

Comprehensive test suite for the TmuxRunner library with 145 test cases and 392 assertions.

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
```

### Run tests in verbose mode

```bash
ruby test/run_tests.rb --verbose
```

### Run specific test file

```bash
ruby test/test_variable_expansion_basic.rb
ruby test/test_variable_expansion_advanced.rb
ruby test/test_variable_expansion_edge_cases.rb
ruby test/test_special_characters.rb
```

### Run a specific test

```bash
ruby test/test_tmux_runner.rb --name test_simple_command_success
ruby test/run_tests.rb --pattern test_variable
```

## Test Coverage

### Core TmuxRunner Tests (test_tmux_runner.rb - 87 tests)

#### Basic Functionality (8 tests)
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

### Array Arguments (29 tests)
- ✅ `test_array_args_basic` - Basic array syntax
- ✅ `test_array_args_with_spaces` - Arguments with spaces
- ✅ `test_array_args_multiple_with_spaces` - Multiple space-containing args
- ✅ `test_array_args_with_special_characters` - Shell variables literal
- ✅ `test_array_args_with_quotes` - Quote handling
- ✅ `test_array_args_with_newlines` - Newline handling
- ✅ `test_array_args_ls_command` - Practical ls example
- ✅ `test_array_args_grep_command` - Practical grep example
- ✅ `test_array_args_command_not_found` - Error handling
- ✅ `test_array_args_with_flags` - Command flags
- ✅ `test_array_args_empty_string_argument` - Empty strings
- ✅ `test_array_args_with_glob_patterns` - Glob literals
- ✅ `test_array_args_start_method` - Async execution
- ✅ `test_array_args_start_with_spaces` - Async with spaces
- ✅ `test_array_args_run_bang` - run! with arrays
- ✅ `test_array_args_run_bang_with_spaces` - run! with spaces
- ✅ `test_array_args_run_bang_failure` - run! error handling
- ✅ `test_array_args_run_with_block` - Block with arrays
- ✅ `test_array_args_with_custom_window_prefix` - Custom prefix
- ✅ `test_array_args_explicit_array` - Explicit array syntax
- ✅ `test_array_args_backslash_escaping` - Backslash handling
- ✅ `test_array_args_pipe_character_literal` - Pipe as literal
- ✅ `test_array_args_ampersand_literal` - Ampersand as literal
- ✅ `test_array_args_semicolon_literal` - Semicolon as literal
- ✅ `test_array_args_redirect_character_literal` - Redirect as literal
- ✅ `test_array_args_parenthesis_literal` - Parenthesis as literal
- ✅ `test_array_args_backtick_literal` - Backtick as literal
- ✅ `test_backward_compat_string_still_allows_shell_features` - Backward compatibility
- ✅ `test_array_vs_string_behavior_difference` - String vs array comparison

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

### Variable Expansion Tests (58 tests)

#### Basic Variable Expansion (test_variable_expansion_basic.rb - 12 tests)
- ✅ `test_variable_assignment_and_expansion` - h=$(hostname) && echo $h
- ✅ `test_variable_with_echo_prefix` - Hostname: $h format
- ✅ `test_multiple_variables` - Multiple variable assignment
- ✅ `test_command_substitution_backticks` - Backtick substitution
- ✅ `test_command_substitution_dollar_paren` - $() substitution
- ✅ `test_nested_command_substitution` - Nested $(echo $(echo))
- ✅ `test_single_quotes_preserve_literal_dollar` - Literal $HOME
- ✅ `test_double_quotes_expand_variables` - Expanded $HOME
- ✅ `test_env_variable_preservation` - TEST_VAR preservation
- ✅ `test_path_variable_access` - $PATH access
- ✅ `test_simple_echo_still_works` - Simple echo compatibility
- ✅ `test_command_without_variables_still_works` - Non-variable commands

#### Advanced Variable Expansion (test_variable_expansion_advanced.rb - 13 tests)
- ✅ `test_bash_c_with_single_quotes` - bash -c 'h=$(hostname)'
- ✅ `test_bash_c_with_complex_command` - Arithmetic with variables
- ✅ `test_sh_c_with_single_quotes` - sh -c with variables
- ✅ `test_pid_variable` - $$ special variable
- ✅ `test_exit_code_variable` - $? special variable
- ✅ `test_argument_count_variable` - $# special variable
- ✅ `test_bash_array_variable` - Bash array access
- ✅ `test_parameter_expansion_default_value` - ${VAR:-default}
- ✅ `test_parameter_expansion_substring` - ${str:1:3}
- ✅ `test_for_loop_with_variable` - Loop with variable accumulator
- ✅ `test_variable_through_pipe` - Variable piped to grep
- ✅ `test_ssh_like_command_simulation` - SSH-style commands
- ✅ `test_multiple_ssh_like_commands` - Multiple SSH variables
- ✅ `test_complex_command_performance` - Performance verification

#### Edge Case Variable Expansion (test_variable_expansion_edge_cases.rb - 11 tests)
- ✅ `test_variable_with_spaces` - Variables containing spaces
- ✅ `test_variable_with_newlines` - Variables with \n
- ✅ `test_variable_with_special_chars` - Special characters @#$
- ✅ `test_variable_isolation_between_runs` - No variable leakage
- ✅ `test_empty_variable` - Empty string variables
- ✅ `test_undefined_variable` - Undefined variable behavior
- ✅ `test_variable_with_equals_sign` - Variables with = in value
- ✅ `test_variable_containing_delimiter_like_text` - Delimiter-like text
- ✅ `test_command_substitution_with_delimiter_like_output` - Delimiter in output
- ✅ `test_variable_with_backslashes` - Backslash handling

### Special Character Tests (test_special_characters.rb - 22 tests)
- ✅ `test_exclamation_mark` - ! character
- ✅ `test_at_sign` - @ character
- ✅ `test_hash_sign` - # character
- ✅ `test_dollar_sign` - $ character
- ✅ `test_percent_sign` - % character
- ✅ `test_caret_sign` - ^ character
- ✅ `test_ampersand_sign` - & character
- ✅ `test_asterisk_sign` - * character
- ✅ `test_parentheses` - () characters
- ✅ `test_square_brackets` - [] characters
- ✅ `test_curly_braces` - {} characters
- ✅ `test_pipe_sign` - | character
- ✅ `test_backslash` - \ character
- ✅ `test_semicolon` - ; character
- ✅ `test_single_quote` - ' character
- ✅ `test_double_quote` - " character
- ✅ `test_less_than` - < character
- ✅ `test_greater_than` - > character
- ✅ `test_question_mark` - ? character
- ✅ `test_tilde` - ~ character
- ✅ `test_backtick` - ` character
- ✅ `test_multiple_special_chars_combination` - Combined special chars

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
# The test runner handles most setup automatically
# Just ensure tmux is available
cd /path/to/tmux-runner
ruby test/run_tests.rb --verbose

# Cleanup (optional, test runner cleans up windows)
tmux -S /tmp/shared-session kill-session -t test_session 2>/dev/null
rm -f /tmp/shared-session
```

## Adding New Tests

To add new tests:

1. Choose the appropriate test file:
   - `test/test_tmux_runner.rb` - Core functionality, library features
   - `test/test_variable_expansion_basic.rb` - Basic variable expansion
   - `test/test_variable_expansion_advanced.rb` - Complex shell scenarios
   - `test/test_variable_expansion_edge_cases.rb` - Edge cases and special situations
   - `test/test_special_characters.rb` - Individual special character tests

2. Add test method:

```ruby
def test_your_new_feature
  result = run_command("your command")
  assert_equal 0, result[:exit_code]
  assert_match /expected/, result[:command_output]
end
```

3. Add to `test/run_tests.rb` if creating a new test file:

```ruby
require_relative 'test_your_new_file'
```

Test naming convention: `test_<category>_<specific_behavior>`

## Test Results

**✅ All 145 tests pass successfully!**

- 145 tests (87 core + 58 variable expansion + 22 special characters)
- 392 assertions
- 0 failures
- Test run time: ~100 seconds

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

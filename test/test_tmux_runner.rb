#!/usr/bin/env ruby

require_relative '../tmux_runner_lib'
require 'test/unit'

class TestTmuxRunner < Test::Unit::TestCase
  def setup
    # Use Ruby version (bash version was removed due to complexity)
    @runner = TmuxRunner.new
    @socket_path = '/tmp/shared-session'
  end

  def teardown
    # Clean up any leftover tmux_runner windows after each test
    # This handles windows left by intentionally failing commands
    windows = `tmux -S #{@socket_path} list-windows -F '\#{window_name}' 2>/dev/null`.split("\n")
    windows.each do |window_name|
      if window_name.start_with?('tmux_runner_') || window_name.start_with?('test') ||
         window_name.start_with?('web') || window_name.start_with?('db') ||
         window_name.start_with?('cache') || window_name.start_with?('api') ||
         window_name.start_with?('myapp') || window_name.start_with?('custom') ||
         window_name.start_with?('testblock') || window_name.start_with?('filecheck')
        `tmux -S #{@socket_path} kill-window -t '=#{window_name}' 2>/dev/null`
      end
    end
  end

  # Basic functionality tests

  def test_simple_command_success
    result = @runner.run("echo 'Hello World'")
    assert_equal true, result[:success]
    assert_equal 0, result[:exit_code]
    assert_match /Hello World/, result[:output]
  end

  def test_simple_command_failure
    result = @runner.run("ls /nonexistent_directory_12345")
    assert_equal false, result[:success]
    assert_not_equal 0, result[:exit_code]
    assert_match /No such file or directory/, result[:output]
  end

  def test_command_with_stderr
    result = @runner.run("echo 'stdout'; echo 'stderr' >&2")
    assert_equal true, result[:success]
    assert_match /stdout/, result[:output]
    assert_match /stderr/, result[:output]
  end

  def test_multiline_output
    result = @runner.run("echo 'line1'; echo 'line2'; echo 'line3'")
    assert_equal true, result[:success]
    assert_match /line1/, result[:output]
    assert_match /line2/, result[:output]
    assert_match /line3/, result[:output]
  end

  def test_exit_code_preservation
    result = @runner.run("(exit 42)")
    assert_equal false, result[:success]
    assert_equal 42, result[:exit_code]
  end

  def test_empty_output_command
    result = @runner.run("true")
    assert_equal true, result[:success]
    assert_equal 0, result[:exit_code]
    assert_equal "", result[:output].strip
  end

  # run! method tests

  def test_run_bang_success
    output = @runner.run!("echo 'test output'")
    assert_match /test output/, output
  end

  def test_run_bang_failure_raises
    assert_raise(RuntimeError) do
      @runner.run!("(exit 1)")
    end
  end

  # run_with_block tests

  def test_run_with_block
    called = false
    captured_output = nil
    captured_exit_code = nil

    result = @runner.run_with_block("echo 'block test'") do |output, exit_code|
      called = true
      captured_output = output
      captured_exit_code = exit_code
    end

    # Verify block was called with correct parameters
    assert_equal true, called
    assert_match /block test/, captured_output
    assert_equal 0, captured_exit_code

    # Verify method also returns the result hash
    assert_equal true, result[:success]
    assert_match /block test/, result[:output]
    assert_equal 0, result[:exit_code]
  end

  # Concurrent execution tests

  def test_start_returns_job_id
    job_id = @runner.start("sleep 0.1")
    assert_not_nil job_id
    assert_match /job_/, job_id
    @runner.wait(job_id)
  end

  def test_running_jobs_tracking
    job1 = @runner.start("sleep 1")
    job2 = @runner.start("sleep 1")

    # Should be running immediately after start
    assert_equal true, @runner.running?(job1)
    assert_equal true, @runner.running?(job2)
    assert_equal 2, @runner.running_jobs.length

    @runner.wait_all

    # Should not be running after completion
    assert_equal false, @runner.running?(job1)
    assert_equal false, @runner.running?(job2)
    assert_equal 0, @runner.running_jobs.length
  end

  def test_finished_detection
    job_id = @runner.start("echo 'quick task'")

    # Wait for it to finish (with timeout)
    max_wait = 5
    start = Time.now
    until @runner.finished?(job_id) || (Time.now - start) > max_wait
      sleep 0.1
    end

    assert_equal true, @runner.finished?(job_id), "Job should be finished after #{Time.now - start}s"
    assert_equal false, @runner.running?(job_id)
  end

  def test_wait_blocks_until_completion
    start_time = Time.now
    job_id = @runner.start("sleep 1")
    result = @runner.wait(job_id)
    end_time = Time.now

    assert_equal true, result[:success]
    assert (end_time - start_time) >= 0.9, "wait() should block for at least 1 second"
  end

  def test_result_returns_nil_while_running
    job_id = @runner.start("sleep 1")
    result = @runner.result(job_id)

    assert_nil result, "result() should return nil for running job"

    @runner.wait(job_id)
    result = @runner.result(job_id)

    assert_not_nil result, "result() should return hash after completion"
  end

  def test_wait_all_with_multiple_jobs
    job1 = @runner.start("echo 'job1'")
    job2 = @runner.start("echo 'job2'")
    job3 = @runner.start("echo 'job3'")

    results = @runner.wait_all

    assert_equal 3, results.length
    assert_equal true, results[job1][:success]
    assert_equal true, results[job2][:success]
    assert_equal true, results[job3][:success]
  end

  def test_concurrent_jobs_run_in_parallel
    # 3 jobs each sleeping 1 second should complete in ~1 second, not 3
    start_time = Time.now

    job1 = @runner.start("sleep 1")
    job2 = @runner.start("sleep 1")
    job3 = @runner.start("sleep 1")

    @runner.wait_all

    end_time = Time.now
    duration = end_time - start_time

    assert duration < 2.0, "Concurrent jobs should complete in ~1 second, not 3+ (took #{duration}s)"
  end

  def test_status_tracking
    job_id = @runner.start("echo 'status test'")

    # Check status while running or just after
    status = @runner.status(job_id)
    assert [:running, :completed].include?(status)

    @runner.wait(job_id)

    # Should be completed after wait
    status = @runner.status(job_id)
    assert_equal :completed, status
  end

  def test_jobs_list
    initial_count = @runner.jobs.length

    job1 = @runner.start("echo 'job1'")
    job2 = @runner.start("echo 'job2'")

    all_jobs = @runner.jobs
    assert_equal initial_count + 2, all_jobs.length
    assert all_jobs.include?(job1)
    assert all_jobs.include?(job2)

    @runner.wait_all
  end

  def test_cleanup_job
    job_id = @runner.start("echo 'cleanup test'")
    @runner.wait(job_id)

    assert @runner.jobs.include?(job_id)

    @runner.cleanup_job(job_id)

    assert_equal false, @runner.jobs.include?(job_id)
  end

  def test_failed_job_tracking
    job_id = @runner.start("(exit 1)")
    @runner.wait(job_id)

    status = @runner.status(job_id)
    # Failed jobs are marked as :completed, check result instead
    result = @runner.result(job_id)

    assert_equal false, result[:success]
    assert_equal 1, result[:exit_code]
  end

  # Custom window prefix tests

  def test_custom_window_prefix_run
    result = @runner.run("echo 'custom prefix test'", window_prefix: 'test_prefix')
    assert_equal true, result[:success]
    assert_match /custom prefix test/, result[:output]
  end

  def test_custom_window_prefix_start
    job_id = @runner.start("echo 'concurrent custom prefix'", window_prefix: 'custom')
    result = @runner.wait(job_id)

    assert_equal true, result[:success]
    assert_match /concurrent custom prefix/, result[:output]
  end

  def test_custom_window_prefix_run_bang
    output = @runner.run!("echo 'run bang prefix'", window_prefix: 'test')
    assert_match /run bang prefix/, output
  end

  def test_custom_window_prefix_with_block
    called = false

    result = @runner.run_with_block("echo 'block prefix'", window_prefix: 'testblock') do |output, exit_code|
      called = true
      assert_match /block prefix/, output
      assert_equal 0, exit_code
    end

    assert_equal true, called
    assert_equal true, result[:success]
    assert_match /block prefix/, result[:output]
  end

  def test_default_window_prefix
    # Default should work without specifying prefix
    result = @runner.run("echo 'default prefix'")
    assert_equal true, result[:success]
  end

  # Complex command tests

  def test_command_with_pipes
    result = @runner.run("echo 'test' | grep 'test'")
    assert_equal true, result[:success]
    assert_match /test/, result[:output]
  end

  def test_command_with_redirection
    result = @runner.run("echo 'error message' >&2 2>&1")
    assert_equal true, result[:success]
    assert_match /error message/, result[:output]
  end

  def test_command_with_environment_variables
    result = @runner.run("TEST_VAR=hello; echo $TEST_VAR")
    assert_equal true, result[:success]
    assert_match /hello/, result[:output]
  end

  def test_command_with_subshell
    result = @runner.run("(echo 'subshell'; echo 'test')")
    assert_equal true, result[:success]
    assert_match /subshell/, result[:output]
    assert_match /test/, result[:output]
  end

  def test_long_output
    # Generate ~1000 lines of output
    result = @runner.run("seq 1 1000")
    assert_equal true, result[:success]
    lines = result[:output].split("\n")
    assert lines.length >= 1000, "Should capture all 1000 lines"
  end

  # Edge cases

  def test_command_with_quotes
    result = @runner.run("echo \"Hello 'World'\"")
    assert_equal true, result[:success]
    assert_match /Hello 'World'/, result[:output]
  end

  def test_command_with_special_characters
    result = @runner.run("echo 'Special: !@#$%^&*()'")
    assert_equal true, result[:success]
    assert_match /Special:/, result[:output]
  end

  def test_very_fast_command
    # Test that very fast commands are captured correctly
    result = @runner.run("true")
    assert_equal true, result[:success]
    assert_equal 0, result[:exit_code]
  end

  def test_command_with_background_process
    # Test that background processes don't interfere
    result = @runner.run("sleep 0.1 & echo 'foreground'")
    assert_equal true, result[:success]
    assert_match /foreground/, result[:output]
  end

  # State tracking tests

  def test_last_exit_code_tracking
    @runner.run("(exit 42)")
    assert_equal 42, @runner.last_exit_code

    @runner.run("echo 'success'")
    assert_equal 0, @runner.last_exit_code
  end

  def test_last_output_tracking
    @runner.run("echo 'first command'")
    assert_match /first command/, @runner.last_output

    @runner.run("echo 'second command'")
    assert_match /second command/, @runner.last_output
  end

  # Cancel test (might leave tmux window open)

  def test_cancel_running_job
    job_id = @runner.start("sleep 10")
    sleep 0.2  # Let it start

    assert_equal true, @runner.running?(job_id)

    result = @runner.cancel(job_id)
    assert_equal true, result

    status = @runner.status(job_id)
    assert_equal :cancelled, status
  end

  # Socket path configuration tests

  def test_nil_socket_uses_default_tmux
    # This test uses the default tmux session (no -S flag)
    # It will only work if running inside a tmux session
    runner_no_socket = TmuxRunner.new(socket_path: nil)

    result = runner_no_socket.run("echo 'no socket test'")
    assert_equal true, result[:success]
    assert_match /no socket test/, result[:output]
  end

  def test_socket_path_default
    # Verify that default socket path is /tmp/shared-session
    runner = TmuxRunner.new
    assert_equal '/tmp/shared-session', runner.socket_path
  end

  def test_socket_path_custom
    # Verify that custom socket path can be set
    custom_runner = TmuxRunner.new(socket_path: '/tmp/custom-socket')
    assert_equal '/tmp/custom-socket', custom_runner.socket_path
  end

  def test_socket_path_nil
    # Verify that nil socket path can be set
    runner = TmuxRunner.new(socket_path: nil)
    assert_nil runner.socket_path
  end

  # Tests for delimiter parsing robustness

  def test_command_with_custom_ps1_prompt
    # Test that commands work even with complex PS1 prompts
    result = @runner.run("echo 'prompt test'")
    assert_equal true, result[:success]
    assert_match /prompt test/, result[:output]
  end

  def test_multiline_with_wrapped_output
    # Test commands that produce output longer than terminal width
    # tmux will wrap lines at terminal boundaries, inserting newlines
    long_string = "x" * 200
    result = @runner.run("echo '#{long_string}'")
    assert_equal true, result[:success]
    # Remove newlines from output to account for tmux line wrapping
    output_without_newlines = result[:output].gsub("\n", "")
    assert_match /#{long_string}/, output_without_newlines
  end

  def test_command_without_trailing_newline
    # Test commands that don't output a trailing newline (printf, echo -n)
    result = @runner.run("printf 'no newline'")
    assert_equal true, result[:success]
    assert_equal 0, result[:exit_code]
    assert_equal "no newline", result[:output]
  end

  def test_echo_dash_n
    # Test echo -n which also doesn't output a trailing newline
    result = @runner.run("echo -n 'test output'")
    assert_equal true, result[:success]
    assert_equal 0, result[:exit_code]
    assert_equal "test output", result[:output]
  end

  # Race condition tests
  # These tests verify that the synchronization mechanism (delimiter detection + wait-for)
  # correctly handles various timing scenarios

  def test_race_condition_very_fast_commands
    # Very fast commands complete almost instantly, which can cause race conditions
    # where the delimiter appears before we start polling
    10.times do |i|
      result = @runner.run("true")  # Fastest possible command
      assert_equal true, result[:success], "Iteration #{i}: fast command should succeed"
      assert_equal 0, result[:exit_code], "Iteration #{i}: fast command should have exit code 0"
    end
  end

  def test_race_condition_commands_without_trailing_newline
    # Commands without trailing newlines can cause parsing issues if delimiter
    # appears on the same line as output
    result1 = @runner.run("printf 'no newline'")
    assert_equal true, result1[:success]
    assert_equal 0, result1[:exit_code]
    assert_equal "no newline", result1[:output]

    result2 = @runner.run("echo -n 'also no newline'")
    assert_equal true, result2[:success]
    assert_equal 0, result2[:exit_code]
    assert_equal "also no newline", result2[:output]

    # Verify this works consistently
    5.times do |i|
      result = @runner.run("printf 'iteration #{i}'")
      assert_equal true, result[:success], "Iteration #{i} should succeed"
      assert_match /iteration #{i}/, result[:output], "Iteration #{i} output should be correct"
    end
  end

  def test_race_condition_long_running_commands
    # Long-running commands test that polling continues until completion
    # and that the wait-for signal is properly received
    start_time = Time.now
    result = @runner.run("sleep 2; echo 'done'")
    end_time = Time.now

    assert_equal true, result[:success], "Long command should succeed"
    assert_equal 0, result[:exit_code], "Long command should have exit code 0"
    assert_match /done/, result[:output], "Long command output should be captured"
    assert (end_time - start_time) >= 1.9, "Should actually wait for command to complete"
  end

  def test_race_condition_rapid_sequential_commands
    # Test that running many commands rapidly in sequence doesn't cause
    # delimiter confusion or signal handling issues
    results = []
    10.times do |i|
      results << @runner.run("echo 'command #{i}'")
    end

    results.each_with_index do |result, i|
      assert_equal true, result[:success], "Command #{i} should succeed"
      assert_match /command #{i}/, result[:output], "Command #{i} output should match"
    end
  end

  def test_race_condition_mixed_timing_commands
    # Mix of fast, medium, and slow commands to test robustness
    fast_result = @runner.run("echo 'fast'")
    medium_result = @runner.run("sleep 0.5; echo 'medium'")
    slow_result = @runner.run("sleep 1.5; echo 'slow'")
    another_fast = @runner.run("true")

    assert_equal true, fast_result[:success]
    assert_match /fast/, fast_result[:output]

    assert_equal true, medium_result[:success]
    assert_match /medium/, medium_result[:output]

    assert_equal true, slow_result[:success]
    assert_match /slow/, slow_result[:output]

    assert_equal true, another_fast[:success]
  end

  # Tests for delimiter detection and parsing edge cases
  # These tests validate specific issues encountered during bash implementation debugging

  def test_delimiter_not_confused_with_command_echo
    # Verify that the delimiter in the command echo line doesn't cause false positives
    # The command echo shows: "ubuntu@host$ echo '===START==='; cmd; echo ===END===$EXIT_CODE"
    # The actual delimiter should only be detected when it appears as output
    result = @runner.run("sleep 0.1; echo 'output'")
    assert_equal true, result[:success]
    assert_match /output/, result[:output]
    # If delimiter detection was broken, this would timeout or return early
  end

  def test_prompt_detection_waits_for_final_prompt
    # Verify that prompt detection waits for the FINAL prompt, not the command echo prompt
    # The command echo line has a prompt: "ubuntu@host$ echo..."
    # But we need to wait for the prompt AFTER the command completes
    start_time = Time.now
    result = @runner.run("sleep 0.5; echo 'done'")
    elapsed = Time.now - start_time

    assert_equal true, result[:success]
    assert_match /done/, result[:output]
    # Should take at least 0.5 seconds (not return immediately due to false prompt match)
    assert elapsed >= 0.4, "Should wait for command to complete, not return early (took #{elapsed}s)"
  end

  def test_blank_lines_in_tmux_pane_dont_break_prompt_detection
    # Tmux panes have fixed height (e.g., 24 lines), with trailing blank lines
    # Verify that blank lines don't prevent prompt detection
    # This tests the "last 5 non-blank lines" logic
    result = @runner.run("echo 'test'")
    assert_equal true, result[:success]
    assert_match /test/, result[:output]
  end

  def test_delimiter_with_exit_code_parsed_correctly
    # The end delimiter has the exit code immediately after: ===END_123===0
    # Verify this is parsed correctly and not confused with delimiter in command string
    result = @runner.run("echo 'testing'; (exit 0)")
    assert_equal true, result[:success]
    assert_equal 0, result[:exit_code]
  end

  def test_wrapped_command_lines_dont_break_delimiter_detection
    # Tmux wraps long command lines, which can break delimiter detection
    # Verify that wrapped lines are handled correctly
    # Use a long string in the output rather than the command itself
    result = @runner.run("echo '#{"x" * 200}'")
    assert_equal true, result[:success]
    # Output may have newlines inserted by tmux wrapping, so check for x's presence
    assert result[:output].gsub("\n", "").include?("x" * 200), "Output should contain long string (possibly wrapped)"
  end

  def test_multiple_prompts_in_buffer_uses_last_one
    # The buffer contains multiple prompts: one from command echo, one final
    # Verify that we're checking the final prompt (after delimiter), not the first
    result = @runner.run("sleep 0.3; echo 'completed'")
    assert_equal true, result[:success]
    assert_match /completed/, result[:output]
  end

  def test_wait_for_signal_completes_before_prompt_check
    # The wait-for -S signal should complete quickly (non-blocking)
    # Verify that prompt detection correctly waits for it
    result = @runner.run("echo 'signal test'")
    assert_equal true, result[:success]
    assert_match /signal test/, result[:output]
  end

  # Array argument tests

  def test_array_args_basic
    # Test basic array argument syntax
    result = @runner.run("echo", "hello")
    assert_equal true, result[:success]
    assert_match /hello/, result[:output]
  end

  def test_array_args_with_spaces
    # Test that arguments with spaces are properly handled
    result = @runner.run("echo", "hello world")
    assert_equal true, result[:success]
    assert_equal "hello world", result[:output].strip
  end

  def test_array_args_multiple_with_spaces
    # Test multiple arguments containing spaces
    result = @runner.run("printf", "%s\\n%s\\n", "first line", "second line")
    assert_equal true, result[:success]
    assert_match /first line/, result[:output]
    assert_match /second line/, result[:output]
  end

  def test_array_args_with_special_characters
    # Test arguments with special shell characters
    result = @runner.run("echo", "test$VAR")
    assert_equal true, result[:success]
    # Should be literal, not expanded
    assert_equal "test$VAR", result[:output].strip
  end

  def test_array_args_with_quotes
    # Test arguments containing quotes
    result = @runner.run("echo", "it's \"quoted\"")
    assert_equal true, result[:success]
    assert_match /it's "quoted"/, result[:output]
  end

  def test_array_args_with_newlines
    # Test arguments containing newlines
    result = @runner.run("printf", "%s", "line1\nline2")
    assert_equal true, result[:success]
    assert_match /line1/, result[:output]
    assert_match /line2/, result[:output]
  end

  def test_array_args_ls_command
    # Test practical example: ls with path containing spaces
    # Create a test directory structure (in /tmp to avoid permission issues)
    test_dir = "/tmp/tmux_runner_test_#{Process.pid}"
    `mkdir -p "#{test_dir}/dir with spaces"`
    `touch "#{test_dir}/dir with spaces/file.txt"`

    begin
      result = @runner.run("ls", "-la", "#{test_dir}/dir with spaces")
      assert_equal true, result[:success]
      assert_match /file.txt/, result[:output]
    ensure
      `rm -rf "#{test_dir}"`
    end
  end

  def test_array_args_grep_command
    # Test grep with pattern and file containing spaces
    test_file = "/tmp/test file #{Process.pid}.txt"
    `echo "test content" > "#{test_file}"`

    begin
      result = @runner.run("grep", "content", test_file)
      assert_equal true, result[:success]
      assert_match /test content/, result[:output]
    ensure
      `rm -f "#{test_file}"`
    end
  end

  def test_array_args_command_not_found
    # Test that array syntax works with failed commands
    result = @runner.run("nonexistent_command_xyz", "arg1", "arg2")
    assert_equal false, result[:success]
    assert_not_equal 0, result[:exit_code]
  end

  def test_array_args_with_flags
    # Test command with multiple flags and arguments
    result = @runner.run("echo", "-n", "no newline")
    assert_equal true, result[:success]
    assert_equal "no newline", result[:output]
  end

  def test_array_args_empty_string_argument
    # Test that empty strings are preserved
    result = @runner.run("sh", "-c", "echo \"arg1: '$1', arg2: '$2'\"", "--", "", "value")
    assert_equal true, result[:success]
    # Empty first arg should be preserved
    assert_match /arg1: ''/, result[:output]
    assert_match /arg2: 'value'/, result[:output]
  end

  def test_array_args_with_glob_patterns
    # Test that glob patterns are NOT expanded (literal strings)
    result = @runner.run("echo", "*.txt")
    assert_equal true, result[:success]
    # Should be literal, not expanded
    assert_equal "*.txt", result[:output].strip
  end

  def test_array_args_start_method
    # Test array args with start() method
    job_id = @runner.start("echo", "async test")
    result = @runner.wait(job_id)
    assert_equal true, result[:success]
    assert_match /async test/, result[:output]
  end

  def test_array_args_start_with_spaces
    # Test array args with start() and spaces
    job_id = @runner.start("echo", "hello world from async")
    result = @runner.wait(job_id)
    assert_equal true, result[:success]
    assert_match /hello world from async/, result[:output]
  end

  def test_array_args_run_bang
    # Test array args with run! method
    output = @runner.run!("echo", "run bang array")
    assert_match /run bang array/, output
  end

  def test_array_args_run_bang_with_spaces
    # Test array args with run! and spaces
    output = @runner.run!("echo", "spaces in run!")
    assert_equal "spaces in run!", output.strip
  end

  def test_array_args_run_bang_failure
    # Test array args with run! raising exception on failure
    assert_raise(RuntimeError) do
      @runner.run!("ls", "/nonexistent_dir_xyz")
    end
  end

  def test_array_args_run_with_block
    # Test array args with run_with_block method
    called = false
    captured_output = nil

    result = @runner.run_with_block("echo", "block array test") do |output, exit_code|
      called = true
      captured_output = output
      assert_equal 0, exit_code
    end

    assert_equal true, called
    assert_match /block array test/, captured_output
    assert_equal true, result[:success]
  end

  def test_array_args_with_custom_window_prefix
    # Test array args with custom window prefix
    result = @runner.run("echo", "custom prefix", window_prefix: "filecheck")
    assert_equal true, result[:success]
    assert_match /custom prefix/, result[:output]
  end

  def test_array_args_explicit_array
    # Test passing an explicit array as a single argument
    result = @runner.run(["echo", "explicit array"])
    assert_equal true, result[:success]
    assert_match /explicit array/, result[:output]
  end

  def test_array_args_backslash_escaping
    # Test that backslashes are preserved
    result = @runner.run("echo", "path\\to\\file")
    assert_equal true, result[:success]
    assert_match /path.*to.*file/, result[:output]
  end

  def test_array_args_pipe_character_literal
    # Test that pipe characters are literal, not shell operators
    result = @runner.run("echo", "a|b")
    assert_equal true, result[:success]
    assert_equal "a|b", result[:output].strip
  end

  def test_array_args_ampersand_literal
    # Test that ampersands are literal, not background operators
    result = @runner.run("echo", "a&b")
    assert_equal true, result[:success]
    assert_equal "a&b", result[:output].strip
  end

  def test_array_args_semicolon_literal
    # Test that semicolons are literal, not command separators
    result = @runner.run("echo", "cmd1;cmd2")
    assert_equal true, result[:success]
    assert_equal "cmd1;cmd2", result[:output].strip
  end

  def test_array_args_redirect_character_literal
    # Test that redirect characters are literal
    result = @runner.run("echo", "input>output")
    assert_equal true, result[:success]
    assert_equal "input>output", result[:output].strip
  end

  def test_array_args_parenthesis_literal
    # Test that parentheses are literal, not subshells
    result = @runner.run("echo", "(subshell)")
    assert_equal true, result[:success]
    assert_equal "(subshell)", result[:output].strip
  end

  def test_array_args_backtick_literal
    # Test that backticks are literal, not command substitution
    result = @runner.run("echo", "`command`")
    assert_equal true, result[:success]
    assert_equal "`command`", result[:output].strip
  end

  def test_backward_compat_string_still_allows_shell_features
    # Verify that string form still allows shell features (backward compatibility)
    result = @runner.run("echo 'a' | cat")
    assert_equal true, result[:success]
    assert_equal "a", result[:output].strip
  end

  def test_array_vs_string_behavior_difference
    # Demonstrate the difference: array form escapes, string form doesn't

    # String form allows shell expansion
    result_string = @runner.run("echo $HOME")
    # Will show the actual HOME value
    assert_equal true, result_string[:success]

    # Array form treats it literally
    result_array = @runner.run("echo", "$HOME")
    assert_equal true, result_array[:success]
    assert_equal "$HOME", result_array[:output].strip
  end

  # Test for false positive prompt detection (GitHub issue fix)
  # This test verifies that command output containing $, #, or > characters
  # doesn't cause premature loop exit due to false positive prompt matches

  def test_false_positive_prompt_with_enumerator_output
    # Simulate Ruby command that outputs an Enumerator object ending with >
    # This previously caused false positive matches with the shell prompt regex /[$#>]\s*$/
    result = @runner.run("echo 'Progress: |===================================================Failed to restart 5 servers'; echo '#<Enumerator:0x0000e683d8644888>'")
    assert_equal true, result[:success], "Command should complete successfully"
    assert_equal 0, result[:exit_code], "Exit code should be 0"
    assert_match /Enumerator/, result[:output], "Output should contain Enumerator line"
    assert_match /Failed to restart/, result[:output], "Output should contain failure message"
  end

  def test_false_positive_prompt_with_hash_at_line_end
    # Test output lines ending with # don't cause false prompt detection
    result = @runner.run("echo 'Line ending with hash#'; echo 'another line'")
    assert_equal true, result[:success]
    assert_equal 0, result[:exit_code]
    assert_match /hash#/, result[:output]
    assert_match /another line/, result[:output]
  end

  def test_false_positive_prompt_with_dollar_at_line_end
    # Test output lines ending with $ don't cause false prompt detection
    result = @runner.run("echo 'Price: 100$'; echo 'next line'")
    assert_equal true, result[:success]
    assert_equal 0, result[:exit_code]
    assert_match /100\$/, result[:output]
    assert_match /next line/, result[:output]
  end

  def test_false_positive_prompt_with_greater_than_at_line_end
    # Test output lines ending with > don't cause false prompt detection
    result = @runner.run("echo 'Comparison: 5 > 3'; echo 'result'")
    assert_equal true, result[:success]
    assert_equal 0, result[:exit_code]
    assert_match /5 > 3/, result[:output]
    assert_match /result/, result[:output]
  end

  def test_false_positive_prompt_with_multiple_special_chars
    # Test complex output with multiple lines containing prompt-like characters
    result = @runner.run("echo 'Object#method>'; echo 'Price: $50'; echo 'root@host#'; echo 'done'")
    assert_equal true, result[:success]
    assert_equal 0, result[:exit_code]
    assert_match /Object#method>/, result[:output]
    assert_match /Price: \$50/, result[:output]
    assert_match /root@host#/, result[:output]
    assert_match /done/, result[:output]
  end

  def test_false_positive_prompt_with_ruby_object_inspection
    # Test actual Ruby object inspection output that triggered the original bug
    # Ruby's inspect method on various objects can produce output ending with >
    result = @runner.run("ruby -e \"puts '#<Object:0x00007f8b1c8d3e80>'\"")
    assert_equal true, result[:success]
    assert_equal 0, result[:exit_code]
    assert_match /Object:0x/, result[:output]
  end

  def test_real_prompt_still_detected_correctly
    # Verify that actual shell prompts are still properly detected
    # This ensures our fix doesn't break normal operation
    result = @runner.run("sleep 0.5; echo 'command completed'")
    assert_equal true, result[:success]
    assert_equal 0, result[:exit_code]
    assert_match /command completed/, result[:output]
    # Window should close automatically (exit code 0), which proves prompt was detected
  end

  def test_false_positive_with_ssh_style_output
    # Test output similar to the SSH command that triggered the original bug report
    # The command outputs progress bars, Ruby objects, and ends with exit code 0
    result = @runner.run("echo 'Progress: |=============================='; echo '#<Enumerator:0x000>'; echo 'Done'")
    assert_equal true, result[:success]
    assert_equal 0, result[:exit_code]
    assert_match /Progress:/, result[:output]
    assert_match /Enumerator/, result[:output]
    assert_match /Done/, result[:output]
  end

  # Multiple sequential commands test

  def test_multiple_sequential_commands
    # Test that a single TmuxRunner instance can execute multiple commands
    # in sequence and return correct results for each command

    # Command 1: Simple echo
    result1 = @runner.run("echo 'first command'")
    assert_equal true, result1[:success]
    assert_equal 0, result1[:exit_code]
    assert_match /first command/, result1[:output]

    # Command 2: Math operation
    result2 = @runner.run("expr 5 + 3")
    assert_equal true, result2[:success]
    assert_equal 0, result2[:exit_code]
    assert_match /8/, result2[:output]

    # Command 3: Failed command
    result3 = @runner.run("ls /nonexistent_path_xyz")
    assert_equal false, result3[:success]
    assert_not_equal 0, result3[:exit_code]
    assert_match /No such file or directory/, result3[:output]

    # Command 4: Another successful command after failure
    result4 = @runner.run("echo 'fourth command' && echo 'still works'")
    assert_equal true, result4[:success]
    assert_equal 0, result4[:exit_code]
    assert_match /fourth command/, result4[:output]
    assert_match /still works/, result4[:output]

    # Command 5: Command with specific exit code
    result5 = @runner.run("(exit 7)")
    assert_equal false, result5[:success]
    assert_equal 7, result5[:exit_code]

    # Verify last_exit_code and last_output track the most recent command
    assert_equal 7, @runner.last_exit_code
    assert_equal "", @runner.last_output.strip

    # Command 6: Final successful command
    result6 = @runner.run("echo 'final command'")
    assert_equal true, result6[:success]
    assert_equal 0, result6[:exit_code]
    assert_match /final command/, result6[:output]

    # Verify tracking updated
    assert_equal 0, @runner.last_exit_code
    assert_match /final command/, @runner.last_output
  end
end

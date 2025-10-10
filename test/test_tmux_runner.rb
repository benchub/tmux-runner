#!/usr/bin/env ruby

require_relative '../tmux_runner_lib'
require 'test/unit'

class TestTmuxRunner < Test::Unit::TestCase
  def setup
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
end

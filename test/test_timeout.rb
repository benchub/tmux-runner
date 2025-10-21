#!/usr/bin/env ruby
# frozen_string_literal: true

require 'minitest/autorun'
require_relative '../tmux_runner_lib'

# Consolidated timeout tests
# Tests for configurable timeout and infinite timeout (timeout=0) functionality
class TestTimeout < Minitest::Test
  def setup
    @runner = TmuxRunner.new
  end

  # ==================== BASIC TIMEOUT FUNCTIONALITY ====================

  def test_custom_short_timeout
    # A 10-second job with 5-second timeout should fail
    start_time = Time.now
    result = @runner.run("echo 'Starting 10s job'; sleep 10; echo 'Done'", timeout: 5)
    elapsed = Time.now - start_time

    # Should timeout at ~5 seconds
    assert elapsed < 7, "Should timeout after ~5s, but waited #{elapsed.round(2)}s"
    refute result[:success], "Should fail due to timeout"
  end

  def test_timeout_parameter_works_with_short_command
    # A 2-second job with 10-second timeout should succeed
    result = @runner.run("echo 'Quick job'; sleep 2; echo 'Done'", timeout: 10)

    assert result[:success], "Short job should succeed with custom timeout"
    assert result[:output].include?("Done"), "Should have completed successfully"
  end

  def test_wait_all_with_different_job_timeouts
    # Job 1: 3 seconds with 5s timeout (should succeed)
    job1 = @runner.start("echo 'Job 1'; sleep 3; echo 'Done 1'", timeout: 5)

    # Job 2: 3 seconds with 10s timeout (should succeed)
    job2 = @runner.start("echo 'Job 2'; sleep 3; echo 'Done 2'", timeout: 10)

    results = @runner.wait_all

    assert_equal 2, results.length, "Should return both results"
    assert results[job1][:success], "Job 1 should succeed"
    assert results[job2][:success], "Job 2 should succeed"
  end

  # ==================== INFINITE TIMEOUT (timeout=0) ====================

  def test_timeout_zero_waits_indefinitely
    # A 5-second job with timeout=0 should complete successfully
    start_time = Time.now
    result = @runner.run("echo 'Starting 5s job'; sleep 5; echo 'Done'", timeout: 0)
    elapsed = Time.now - start_time

    # Should complete successfully without timing out
    assert result[:success], "Job should succeed with infinite timeout"
    assert elapsed >= 4.8, "Should wait full ~5s"
    assert elapsed < 7, "Should not take too long"
    assert result[:output].include?("Done"), "Should have completed"
  end

  def test_wait_all_with_infinite_timeout_jobs
    # Start two jobs with infinite timeout
    job1 = @runner.start("echo 'Job 1 (3s)'; sleep 3; echo 'Job 1 done'", timeout: 0)
    job2 = @runner.start("echo 'Job 2 (4s)'; sleep 4; echo 'Job 2 done'", timeout: 0)

    start_time = Time.now
    results = @runner.wait_all
    elapsed = Time.now - start_time

    # Both should succeed
    assert_equal 2, results.length, "Should return 2 results"
    assert results[job1][:success], "Job 1 should succeed"
    assert results[job2][:success], "Job 2 should succeed"

    # Should have waited for the longer job
    assert elapsed >= 3.8, "Should wait ~4s for longer job"

    # Both should be finished
    assert @runner.finished?(job1), "Job 1 should be finished"
    assert @runner.finished?(job2), "Job 2 should be finished"
  end

  def test_wait_all_with_mixed_timeouts
    # Job 1: 2 seconds with 10s timeout
    job1 = @runner.start("sleep 2; echo 'Done1'", timeout: 10)

    # Job 2: 3 seconds with infinite timeout
    job2 = @runner.start("sleep 3; echo 'Done2'", timeout: 0)

    # Job 3: 2 seconds with 5s timeout
    job3 = @runner.start("sleep 2; echo 'Done3'", timeout: 5)

    results = @runner.wait_all

    # Debug output if failures occur
    results.each do |job_id, result|
      unless result[:success]
        puts "FAILED: #{job_id}"
        puts "  Exit code: #{result[:exit_code]}"
        puts "  Output: #{result[:output]}"
      end
    end

    assert_equal 3, results.length, "Should return 3 results"
    assert results[job1][:success], "Job 1 should succeed"
    assert results[job2][:success], "Job 2 should succeed"
    assert results[job3][:success], "Job 3 should succeed"
  end

  def test_infinite_timeout_with_instant_command
    result = @runner.run("echo 'Quick test'", timeout: 0)

    assert result[:success], "Quick command should succeed"
    assert result[:output].include?("Quick test"), "Should have correct output"
  end

  # ==================== LONG-RUNNING TIMEOUT TESTS (SKIPPED BY DEFAULT) ====================

  # These tests take a long time to run - unskip to manually verify timeout behavior

  def test_default_timeout_is_600_seconds
    skip "Takes 70s - unskip to verify default timeout behavior"

    # A 70-second job should complete fine with default 600s timeout
    start_time = Time.now
    result = @runner.run("echo 'Starting 70s job'; sleep 70; echo 'Done'")
    elapsed = Time.now - start_time

    assert result[:success], "70s job should succeed with 600s timeout"
    assert elapsed >= 69, "Should wait full 70s"
    assert elapsed < 75, "Should not timeout early"
  end

  def test_custom_long_timeout_with_wait_all
    skip "Takes 75s - unskip to verify long timeout works"

    # Start two jobs that take longer than 60s (old timeout)
    # but less than 120s (new timeout)
    job1 = @runner.start("echo 'Job 1 (70s)'; sleep 70; echo 'Job 1 done'", timeout: 120)
    job2 = @runner.start("echo 'Job 2 (75s)'; sleep 75; echo 'Job 2 done'", timeout: 120)

    start_time = Time.now
    results = @runner.wait_all
    elapsed = Time.now - start_time

    # Both should succeed
    assert results[job1][:success], "Job 1 should succeed with 120s timeout"
    assert results[job2][:success], "Job 2 should succeed with 120s timeout"

    # Should have waited ~75s (not timed out at 60s)
    assert elapsed >= 74, "Should wait full ~75s, but only waited #{elapsed.round(2)}s"
    assert elapsed < 80, "Should not timeout"

    # Both should be finished
    assert @runner.finished?(job1), "Job 1 should be finished"
    assert @runner.finished?(job2), "Job 2 should be finished"
  end

  def test_timeout_zero_with_job_longer_than_old_limit
    skip "Takes 75s - unskip to manually verify infinite timeout"

    # Run a 75-second job with infinite timeout
    # This would have failed with the old hardcoded 60s timeout
    start_time = Time.now
    result = @runner.run("echo 'Starting 75s job'; sleep 75; echo 'Done'", timeout: 0)
    elapsed = Time.now - start_time

    # Should complete successfully, not timeout
    assert result[:success], "Job should succeed with infinite timeout"
    assert elapsed >= 74, "Should wait full ~75s"
    assert result[:output].include?("Done"), "Should have completed"
  end

  def test_timeout_zero_exceeds_old_60_second_limit
    skip "Takes 70s - unskip to verify timeout=0 works beyond old limit"

    # Run a 70-second job with infinite timeout
    # This would have failed with the old hardcoded 60s timeout
    start_time = Time.now
    result = @runner.run("echo 'Testing 70s with infinite timeout'; sleep 70; echo 'Success!'", timeout: 0)
    elapsed = Time.now - start_time

    # Should succeed, proving timeout=0 waits indefinitely
    assert result[:success], "70s job should succeed with timeout=0"
    assert elapsed >= 69, "Should wait full 70s"
    assert result[:output].include?("Success!"), "Should complete successfully"
  end

  # ==================== TIMEOUT BUG DOCUMENTATION ====================

  # These tests document the original 60-second timeout bug

  def test_60_second_timeout_bug_documentation
    skip "Historical test - documents the original bug that was fixed"

    # This test documents the original bug where commands longer than 60 seconds
    # would timeout because the timeout was hardcoded to 60 seconds.
    # With the fix, you can now set timeout: 120 or timeout: 0 to handle long jobs.

    # Original behavior (before fix):
    # job = @runner.start("sleep 70; echo 'Done'")
    # results = @runner.wait_all
    # # Would timeout at ~60s, command still running in tmux

    # Fixed behavior:
    job = @runner.start("sleep 2; echo 'Done'", timeout: 120)
    results = @runner.wait_all
    assert results[job][:success], "Job completes successfully with configurable timeout"
  end
end

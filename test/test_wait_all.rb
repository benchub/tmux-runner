#!/usr/bin/env ruby
# frozen_string_literal: true

require 'minitest/autorun'
require_relative '../tmux_runner_lib'

# Consolidated wait_all tests
# Tests various scenarios and edge cases for the wait_all method
class TestWaitAll < Minitest::Test
  def setup
    @runner = TmuxRunner.new
  end

  # ==================== BASIC FUNCTIONALITY ====================

  def test_wait_all_waits_for_all_jobs
    job1 = @runner.start("echo 'Job 1 starting'; sleep 2; echo 'Job 1 done'")
    job2 = @runner.start("echo 'Job 2 starting'; sleep 3; echo 'Job 2 done'")

    start_time = Time.now
    results = @runner.wait_all
    elapsed = Time.now - start_time

    # Should return results for both jobs
    assert_equal 2, results.length, "wait_all should return results for both jobs"

    # Should have waited for the longer job (3 seconds)
    assert elapsed >= 2.8, "wait_all should have waited ~3 seconds for all jobs"

    # Both jobs should have succeeded
    assert results[job1][:success], "Job 1 should have succeeded"
    assert results[job2][:success], "Job 2 should have succeeded"

    # Both jobs should be finished
    assert @runner.finished?(job1), "Job 1 should be finished"
    assert @runner.finished?(job2), "Job 2 should be finished"
  end

  def test_wait_all_with_multiple_jobs_of_varying_lengths
    jobs = []
    jobs << @runner.start("echo 'Job 1'; sleep 1; echo 'Done 1'")
    jobs << @runner.start("echo 'Job 2'; sleep 2; echo 'Done 2'")
    jobs << @runner.start("echo 'Job 3'; sleep 3; echo 'Done 3'")
    jobs << @runner.start("echo 'Job 4'; sleep 4; echo 'Done 4'")

    start_time = Time.now
    results = @runner.wait_all
    elapsed = Time.now - start_time

    # All 4 jobs should be in the results
    assert_equal 4, results.length, "wait_all should return all 4 jobs"

    # Should have waited for the longest job (4 seconds)
    assert elapsed >= 3.8, "wait_all should have waited ~4 seconds"

    # All jobs should be finished
    jobs.each_with_index do |job_id, i|
      assert @runner.finished?(job_id), "Job #{i+1} should be finished"
      assert results[job_id][:success], "Job #{i+1} should have succeeded"
    end
  end

  def test_wait_all_called_twice_should_be_idempotent
    job1 = @runner.start("echo 'Job 1'; sleep 1; echo 'Job 1 done'")
    job2 = @runner.start("echo 'Job 2'; sleep 1; echo 'Job 2 done'")

    # First wait_all should wait for all jobs
    results1 = @runner.wait_all
    assert_equal 2, results1.length, "First wait_all should return 2 results"

    # Second wait_all should return empty hash (no new jobs started)
    results2 = @runner.wait_all
    assert_equal 0, results2.length, "Second wait_all should return 0 results (no new jobs)"
  end

  # ==================== TIMING AND RACE CONDITIONS ====================

  def test_wait_all_no_jobs_running_after_return
    job1 = @runner.start("echo 'Job 1 start'; sleep 2; echo 'Job 1 done'")
    job2 = @runner.start("echo 'Job 2 start'; sleep 4; echo 'Job 2 done'")

    results = @runner.wait_all
    elapsed = Time.now - Time.now

    # After wait_all returns, NO jobs should still be running
    refute @runner.running?(job1), "Job 1 should not be running after wait_all returns"
    refute @runner.running?(job2), "Job 2 should not be running after wait_all returns"

    # Both should be finished
    assert @runner.finished?(job1), "Job 1 should be finished"
    assert @runner.finished?(job2), "Job 2 should be finished"
  end

  def test_wait_all_when_first_job_completes_during_iteration
    # Job 1: very short (0.5 seconds)
    # Job 2: longer (3 seconds)
    job1 = @runner.start("echo 'Job 1'; sleep 0.5; echo 'Job 1 done'")
    job2 = @runner.start("echo 'Job 2'; sleep 3; echo 'Job 2 done'")

    sleep 0.1  # Give them a moment to register as running

    start_time = Time.now
    results = @runner.wait_all
    elapsed = Time.now - start_time

    # Both should be finished
    assert @runner.finished?(job1), "Job 1 should be finished"
    assert @runner.finished?(job2), "Job 2 should be finished"

    # Should have waited for the longer job
    assert elapsed >= 2.8, "Should wait ~3s, but only waited #{elapsed.round(2)}s"

    # Should return both results
    assert_equal 2, results.length, "Should return both job results"
  end

  def test_wait_all_iterates_through_all_jobs_even_if_one_finishes_first
    jobs = []
    # Create multiple jobs with staggered times
    jobs << @runner.start("echo '1'; sleep 0.5; echo 'Done 1'")
    jobs << @runner.start("echo '2'; sleep 2; echo 'Done 2'")
    jobs << @runner.start("echo '3'; sleep 1; echo 'Done 3'")

    start_time = Time.now
    results = @runner.wait_all
    elapsed = Time.now - start_time

    # Should wait for the longest (2s)
    assert elapsed >= 1.8, "Should wait ~2s for longest job"

    # Should return all 3
    assert_equal 3, results.length, "Should return all 3 job results"

    # All should be finished
    jobs.each { |job_id| assert @runner.finished?(job_id), "Job #{job_id} should be finished" }
  end

  # ==================== COMPLEX SCENARIOS ====================

  def test_wait_all_after_starting_multiple_jobs_in_sequence
    # Start first job
    job1 = @runner.start("echo 'App restart starting'; sleep 2; echo 'App restart done'")

    # Start multiple jobs in a loop (simulating user's code pattern)
    jobs = []
    ["21", "22", "23"].each do |queue|
      job_id = @runner.start("echo 'Jobs#{queue} starting'; sleep 3; echo 'Jobs#{queue} done'")
      jobs << job_id
    end

    # wait_all should wait for ALL 4 jobs
    start_time = Time.now
    results = @runner.wait_all
    elapsed = Time.now - start_time

    # All 4 jobs should be in results
    assert_equal 4, results.length, "wait_all should return 4 results (1 app + 3 jobs)"

    # Should have waited for the longer jobs (3 seconds)
    assert elapsed >= 2.8, "wait_all should wait ~3s"

    # All should be finished
    assert @runner.finished?(job1), "App restart job should be finished"
    jobs.each_with_index do |j, i|
      assert @runner.finished?(j), "Jobs2#{i+1} should be finished"
    end
  end

  def test_wait_all_called_immediately_after_last_start
    job1 = @runner.start("echo 'Job 1'; sleep 2; echo 'Done 1'")
    job2 = @runner.start("echo 'Job 2'; sleep 3; echo 'Done 2'")

    # Call wait_all IMMEDIATELY without any sleep
    results = @runner.wait_all

    assert_equal 2, results.length, "Should return 2 results"
    assert @runner.finished?(job1), "Job 1 should be finished"
    assert @runner.finished?(job2), "Job 2 should be finished"
  end

  # ==================== BUG FIX VERIFICATION ====================

  # This test verifies that wait_all returns ALL jobs started since last wait_all,
  # including jobs that finished before wait_all was called
  def test_wait_all_should_include_all_started_jobs_not_just_running_ones
    # Start 3 jobs with different durations
    job1 = @runner.start("echo 'Job 1'; sleep 0.1; echo 'Job 1 done'")  # Fast job
    job2 = @runner.start("echo 'Job 2'; sleep 2; echo 'Job 2 done'")     # Slow job
    job3 = @runner.start("echo 'Job 3'; sleep 2; echo 'Job 3 done'")     # Slow job

    # Give the fast job time to complete
    sleep 1

    # At this point, job1 should be finished, but job2 and job3 should still be running
    assert @runner.finished?(job1), "Job 1 should be finished"
    assert @runner.running?(job2), "Job 2 should still be running"
    assert @runner.running?(job3), "Job 3 should still be running"

    # Now call wait_all - it should return ALL 3 jobs, including the already-finished job1
    results = @runner.wait_all

    # FIXED: wait_all now returns results for ALL jobs started since last wait_all
    assert_equal 3, results.length,
      "wait_all should return results for all 3 jobs (including already-finished jobs)"

    assert results.key?(job1), "Results should include job1 (even though it finished early)"
    assert results.key?(job2), "Results should include job2"
    assert results.key?(job3), "Results should include job3"

    # All results should be successful
    assert results[job1][:success], "Job 1 should have succeeded"
    assert results[job2][:success], "Job 2 should have succeeded"
    assert results[job3][:success], "Job 3 should have succeeded"
  end

  def test_wait_all_expected_behavior_with_mixed_job_states
    jobs = []

    # Start 5 jobs with varying durations
    jobs << @runner.start("echo 'Quick 1'; sleep 0.1; echo 'Done'")
    jobs << @runner.start("echo 'Quick 2'; sleep 0.1; echo 'Done'")
    jobs << @runner.start("echo 'Slow 1'; sleep 2; echo 'Done'")
    jobs << @runner.start("echo 'Slow 2'; sleep 2; echo 'Done'")
    jobs << @runner.start("echo 'Slow 3'; sleep 2; echo 'Done'")

    # Wait a bit so some jobs finish
    sleep 0.5

    # wait_all should return ALL 5 jobs, not just the 3 that are still running
    results = @runner.wait_all

    # FIXED: Now returns all jobs started since last wait_all
    assert_equal 5, results.length, "wait_all should return results for all 5 jobs"

    # All should have succeeded
    jobs.each_with_index do |job_id, i|
      assert results.key?(job_id), "Results should include job #{i+1}"
      assert results[job_id][:success], "Job #{i+1} should have succeeded"
    end
  end
end

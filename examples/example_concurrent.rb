#!/usr/bin/env ruby

require_relative '../tmux_runner_lib'

puts "=" * 70
puts "Concurrent TmuxRunner Examples"
puts "=" * 70
puts

# Example 1: Start multiple jobs concurrently
puts "Example 1: Running multiple commands concurrently"
puts "-" * 70

runner = TmuxRunner.new

# Start several jobs that take different amounts of time
job1 = runner.start("echo 'Job 1 starting'; sleep 2; echo 'Job 1 done'")
job2 = runner.start("echo 'Job 2 starting'; sleep 1; echo 'Job 2 done'")
job3 = runner.start("echo 'Job 3 starting'; sleep 3; echo 'Job 3 done'")

puts "Started 3 jobs: #{job1}, #{job2}, #{job3}"
puts "All jobs running concurrently..."
puts

# Poll until all are done
until runner.running_jobs.empty?
  running = runner.running_jobs
  puts "  Still running: #{running.length} jobs (#{running.join(', ')})"
  sleep 0.5
end

puts "All jobs completed!"
puts

# Get results
result1 = runner.result(job1)
result2 = runner.result(job2)
result3 = runner.result(job3)

puts "Job 1 output: #{result1[:output].inspect}"
puts "Job 2 output: #{result2[:output].inspect}"
puts "Job 3 output: #{result3[:output].inspect}"
puts

# Example 2: Using finished? to check completion
puts "Example 2: Using finished? to check job status"
puts "-" * 70

job = runner.start("echo 'Processing...'; sleep 2; echo 'Complete!'")
puts "Started job: #{job}"

while !runner.finished?(job)
  puts "  Job #{job} is still running..."
  sleep 0.5
end

puts "Job #{job} has finished!"
result = runner.result(job)
puts "Output: #{result[:output].inspect}"
puts

# Example 3: Wait for specific job
puts "Example 3: Using wait() to block until completion"
puts "-" * 70

job = runner.start("echo 'Long task'; sleep 1; hostname")
puts "Started job: #{job}, now waiting for it..."

result = runner.wait(job)
puts "Job completed!"
puts "Success: #{result[:success]}"
puts "Output: #{result[:output]}"
puts

# Example 4: Start jobs and wait for all
puts "Example 4: Start multiple jobs and wait_all()"
puts "-" * 70

jobs = []
jobs << runner.start("echo 'Server 1'; sleep 1; hostname")
jobs << runner.start("echo 'Server 2'; sleep 2; date")
jobs << runner.start("echo 'Server 3'; sleep 1; uptime")

puts "Started #{jobs.length} jobs"
puts "Waiting for all to complete..."

results = runner.wait_all
puts "All jobs completed!"

results.each do |job_id, result|
  puts "\n#{job_id}:"
  puts "  Success: #{result[:success]}"
  puts "  Output: #{result[:output].strip}"
end
puts

# Example 5: Check status of jobs
puts "Example 5: Checking job status"
puts "-" * 70

job1 = runner.start("sleep 1; echo 'done'")
job2 = runner.start("sleep 2; echo 'done'")

sleep 0.5

puts "Job 1 status: #{runner.status(job1)}"  # :running
puts "Job 1 running?: #{runner.running?(job1)}"  # true
puts "Job 1 finished?: #{runner.finished?(job1)}"  # false

sleep 1

puts "\nAfter 1.5 seconds:"
puts "Job 1 status: #{runner.status(job1)}"  # :completed
puts "Job 1 running?: #{runner.running?(job1)}"  # false
puts "Job 1 finished?: #{runner.finished?(job1)}"  # true
puts "Job 2 status: #{runner.status(job2)}"  # :running

runner.wait_all
puts

# Example 6: Handle failures in concurrent jobs
puts "Example 6: Handling failures in concurrent jobs"
puts "-" * 70

good_job = runner.start("echo 'This works'")
bad_job = runner.start("ls /nonexistent")

runner.wait_all

good_result = runner.result(good_job)
bad_result = runner.result(bad_job)

puts "Good job - Success: #{good_result[:success]}, Output: #{good_result[:output].inspect}"
puts "Bad job - Success: #{bad_result[:success]}, Exit code: #{bad_result[:exit_code]}"
puts "Bad job output: #{bad_result[:output].inspect}"
puts

# Example 7: Running many jobs in parallel
puts "Example 7: Running 5 jobs in parallel"
puts "-" * 70

start_time = Time.now
jobs = []

5.times do |i|
  jobs << runner.start("echo 'Job #{i+1}'; sleep 1; echo 'Job #{i+1} done'")
end

puts "Started #{jobs.length} jobs at #{start_time.strftime('%H:%M:%S')}"

results = runner.wait_all
end_time = Time.now

puts "All jobs completed at #{end_time.strftime('%H:%M:%S')}"
puts "Total time: #{(end_time - start_time).round(2)} seconds (would be 5+ seconds if sequential)"
puts

# Example 8: Using result() vs wait()
puts "Example 8: Difference between result() and wait()"
puts "-" * 70

job = runner.start("sleep 2; echo 'finished'")

puts "Immediately after start:"
puts "  result(job): #{runner.result(job).inspect}"  # nil (not finished yet)

puts "\nCalling wait(job) - this blocks..."
result = runner.wait(job)
puts "  wait(job) returned: #{result[:output].inspect}"

puts "\nNow calling result(job) again:"
puts "  result(job): #{runner.result(job)[:output].inspect}"  # now available
puts

# Example 9: List all jobs
puts "Example 9: Tracking all jobs"
puts "-" * 70

runner.start("sleep 1; echo 'a'")
runner.start("sleep 2; echo 'b'")
runner.start("sleep 1; echo 'c'")

sleep 0.5

puts "All jobs: #{runner.jobs.inspect}"
puts "Running jobs: #{runner.running_jobs.inspect}"

runner.wait_all

puts "After wait_all:"
puts "All jobs: #{runner.jobs.inspect}"
puts "Running jobs: #{runner.running_jobs.inspect}"

puts "\n" + "=" * 70
puts "Concurrent examples completed!"
puts "=" * 70

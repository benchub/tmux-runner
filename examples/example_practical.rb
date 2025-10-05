#!/usr/bin/env ruby

require_relative '../tmux_runner_lib'

# Practical Example: Check multiple servers concurrently
# This simulates checking the status of multiple servers in parallel

puts "=" * 70
puts "Practical Example: Multi-Server Health Check"
puts "=" * 70
puts

runner = TmuxRunner.new

# List of servers to check (simulated with local commands)
servers = {
  "web-1" => "hostname && uptime",
  "web-2" => "hostname && df -h / | tail -1",
  "db-1" => "hostname && echo 'DB Status: OK'",
  "cache-1" => "hostname && free -h | grep Mem",
  "api-1" => "hostname && ps aux | wc -l"
}

puts "Checking #{servers.length} servers concurrently..."
puts

# Start all checks concurrently
start_time = Time.now
jobs = {}

servers.each do |server_name, command|
  job_id = runner.start(command)
  jobs[server_name] = job_id
  puts "Started check for #{server_name} (#{job_id})"
end

puts
puts "All checks started. Waiting for completion..."
puts

# Poll and show progress
until runner.running_jobs.empty?
  running_count = runner.running_jobs.length
  completed_count = jobs.length - running_count

  print "\r  Progress: #{completed_count}/#{jobs.length} completed"
  STDOUT.flush
  sleep 0.2
end

puts "\r  Progress: #{jobs.length}/#{jobs.length} completed"
puts

end_time = Time.now
duration = (end_time - start_time).round(2)

puts "All checks completed in #{duration} seconds"
puts
puts "=" * 70
puts "Results:"
puts "=" * 70
puts

# Display results
jobs.each do |server_name, job_id|
  result = runner.result(job_id)

  puts "#{server_name}:"
  if result[:success]
    puts "  ✓ Status: OK"
    puts "  Output:"
    result[:output].split("\n").each do |line|
      puts "    #{line}"
    end
  else
    puts "  ✗ Status: FAILED (exit code: #{result[:exit_code]})"
    puts "  Error:"
    result[:output].split("\n").each do |line|
      puts "    #{line}"
    end
  end
  puts

  # Clean up job
  runner.cleanup_job(job_id)
end

puts "=" * 70
puts

# Example 2: Process a queue of tasks with limited concurrency
puts "=" * 70
puts "Example 2: Task Queue with Concurrency Limit"
puts "=" * 70
puts

MAX_CONCURRENT = 3
tasks = (1..10).map { |i| "echo 'Task #{i}'; sleep #{rand(1..2)}; echo 'Task #{i} complete'" }

puts "Processing #{tasks.length} tasks with max #{MAX_CONCURRENT} concurrent jobs"
puts

completed_tasks = 0
active_jobs = {}
task_queue = tasks.dup

# Process queue
while !task_queue.empty? || !active_jobs.empty?
  # Start new jobs if under limit
  while active_jobs.length < MAX_CONCURRENT && !task_queue.empty?
    task = task_queue.shift
    task_num = tasks.index(task) + 1
    job_id = runner.start(task)
    active_jobs[job_id] = task_num
    puts "Started Task #{task_num} (#{active_jobs.length} running)"
  end

  # Check for completed jobs
  active_jobs.keys.each do |job_id|
    if runner.finished?(job_id)
      result = runner.result(job_id)
      task_num = active_jobs[job_id]

      if result[:success]
        completed_tasks += 1
        puts "✓ Task #{task_num} completed (#{completed_tasks}/#{tasks.length})"
      else
        puts "✗ Task #{task_num} failed"
      end

      active_jobs.delete(job_id)
      runner.cleanup_job(job_id)
    end
  end

  sleep 0.1
end

puts
puts "All tasks completed!"
puts

# Example 3: Timeout handling
puts "=" * 70
puts "Example 3: Handling Long-Running Jobs"
puts "=" * 70
puts

TIMEOUT_SECONDS = 3

job_id = runner.start("echo 'Starting long task'; sleep 5; echo 'Should not see this'")
puts "Started job with #{TIMEOUT_SECONDS}s timeout"

start = Time.now
while runner.running?(job_id)
  elapsed = Time.now - start

  if elapsed > TIMEOUT_SECONDS
    puts "Job exceeded timeout (#{elapsed.round(1)}s), cancelling..."
    runner.cancel(job_id)
    puts "Job cancelled"
    break
  end

  print "\r  Waiting... #{elapsed.round(1)}s / #{TIMEOUT_SECONDS}s"
  STDOUT.flush
  sleep 0.1
end

puts
puts

puts "=" * 70
puts "Examples completed!"
puts "=" * 70

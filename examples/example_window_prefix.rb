#!/usr/bin/env ruby

require_relative '../tmux_runner_lib'

puts "=" * 70
puts "Custom Window Prefix Examples"
puts "=" * 70
puts

runner = TmuxRunner.new

# Example 1: Default prefix (tmux_runner)
puts "Example 1: Using default prefix 'tmux_runner'"
puts "-" * 70
result = runner.run("echo 'Using default prefix'; sleep 1; hostname")
puts "Output: #{result[:output]}"
puts

# Example 2: Custom prefix for blocking run
puts "Example 2: Custom prefix 'myapp'"
puts "-" * 70
result = runner.run("echo 'Using myapp prefix'; sleep 1; date", window_prefix: 'myapp')
puts "Output: #{result[:output]}"
puts

# Example 3: Custom prefix for concurrent jobs
puts "Example 3: Multiple concurrent jobs with different prefixes"
puts "-" * 70

web_job = runner.start("echo 'Web server check'; sleep 1; hostname", window_prefix: 'web')
db_job = runner.start("echo 'Database check'; sleep 1; uptime", window_prefix: 'db')
cache_job = runner.start("echo 'Cache check'; sleep 1; date", window_prefix: 'cache')

puts "Started 3 jobs with custom prefixes:"
puts "  - #{web_job} (prefix: web)"
puts "  - #{db_job} (prefix: db)"
puts "  - #{cache_job} (prefix: cache)"
puts

puts "Waiting for all jobs to complete..."
runner.wait_all

web_result = runner.result(web_job)
db_result = runner.result(db_job)
cache_result = runner.result(cache_job)

puts "\nWeb job output: #{web_result[:output]}"
puts "DB job output: #{db_result[:output]}"
puts "Cache job output: #{cache_result[:output]}"
puts

# Example 4: Using run! with custom prefix
puts "Example 4: Using run!() with custom prefix"
puts "-" * 70

output = runner.run!("echo 'API health check'; hostname", window_prefix: 'api')
puts "Output: #{output}"
puts

# Example 5: Using run_with_block with custom prefix
puts "Example 5: Using run_with_block() with custom prefix"
puts "-" * 70

runner.run_with_block("ls -l", window_prefix: 'filecheck') do |output, exit_code|
  lines = output.split("\n")
  puts "Found #{lines.length} lines in output"
  puts "Exit code: #{exit_code}"
end
puts

puts "=" * 70
puts "Custom window prefix examples completed!"
puts "=" * 70

#!/usr/bin/env ruby

require_relative '../tmux_runner_lib'

# Example 1: Basic usage
puts "Example 1: Basic command execution"
puts "=" * 50

runner = TmuxRunner.new
result = runner.run("echo 'Hello from tmux!' && date")

if result[:success]
  puts "Command succeeded!"
  puts "Output:"
  puts result[:output]
else
  puts "Command failed with exit code #{result[:exit_code]}"
  puts "Output:"
  puts result[:output]
end

puts "\n"

# Example 2: Running a command that fails
puts "Example 2: Handling failures"
puts "=" * 50

result = runner.run("ls /nonexistent")
puts "Exit code: #{result[:exit_code]}"
puts "Success: #{result[:success]}"
puts "Output:"
puts result[:output]

puts "\n"

# Example 3: Using run! which raises on failure
puts "Example 3: Using run! (raises on failure)"
puts "=" * 50

begin
  output = runner.run!("hostname")
  puts "Hostname: #{output.strip}"
rescue => e
  puts "Error: #{e.message}"
end

puts "\n"

# Example 4: Using a block
puts "Example 4: Using a block"
puts "=" * 50

runner.run_with_block("echo 'Line 1' && echo 'Line 2' && echo 'Line 3'") do |output, exit_code|
  puts "Command finished with exit code: #{exit_code}"
  lines = output.split("\n")
  puts "Captured #{lines.length} lines:"
  lines.each_with_index do |line, i|
    puts "  #{i+1}. #{line}"
  end
end

puts "\n"

# Example 5: SSH command (if configured)
puts "Example 5: Complex command with pipes"
puts "=" * 50

result = runner.run("ps aux | grep ruby | head -3")
if result[:success]
  puts "Process list:"
  puts result[:output]
end

puts "\n"

# Example 6: Checking last result
puts "Example 6: Accessing last result"
puts "=" * 50

runner.run("echo 'test'")
puts "Last exit code: #{runner.last_exit_code}"
puts "Last output: #{runner.last_output.inspect}"

puts "\n"

# Example 7: Long-running command with progress
puts "Example 7: Command with progress bar simulation"
puts "=" * 50

result = runner.run("printf 'Processing'; sleep 0.5; printf '.'; sleep 0.5; printf '.'; sleep 0.5; printf '.\n'; echo 'Done!'")
puts "Final output:"
puts result[:output]

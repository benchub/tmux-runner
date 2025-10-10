#!/usr/bin/env ruby

# Simple test runner with options
require 'optparse'

options = {
  verbose: false,
  pattern: nil
}

OptionParser.new do |opts|
  opts.banner = "Usage: ruby run_tests.rb [options]"

  opts.on("-v", "--verbose", "Run tests in verbose mode") do
    options[:verbose] = true
  end

  opts.on("-p", "--pattern PATTERN", "Run only tests matching pattern") do |pattern|
    options[:pattern] = pattern
  end

  opts.on("-h", "--help", "Show this help message") do
    puts opts
    exit
  end
end.parse!

# Set verbose mode for Test::Unit
ARGV.clear
ARGV << "--verbose" if options[:verbose]
ARGV << "--name=/#{options[:pattern]}/" if options[:pattern]

puts "=" * 70
puts "Running TmuxRunner Tests"
puts "=" * 70
puts

# Check if we're inside tmux
inside_tmux = ENV['TMUX']

# If not inside tmux, re-exec this script inside a tmux session
unless inside_tmux
  puts "Not running inside tmux. Starting tmux session..."
  puts

  # Build the command to run this script with all original arguments
  args = ARGV.map { |arg| "'#{arg.gsub("'", "'\\''")}'" }.join(' ')
  script_path = File.expand_path(__FILE__)

  # Start a tmux session and run this script inside it
  # Exit automatically on success, stay open on failure for inspection
  system("tmux new-session 'ruby #{script_path} #{args}; TEST_EXIT_CODE=$?; echo; if [ $TEST_EXIT_CODE -eq 0 ]; then exit 0; else echo \"Tests FAILED! Session will remain open for inspection.\"; echo \"Press Enter to exit...\"; read; exit $TEST_EXIT_CODE; fi'")
  exit_code = $?.exitstatus

  # Print result message after tmux exits
  puts
  if exit_code == 0
    puts "=" * 70
    puts "  ✓ All tests succeeded!"
    puts "=" * 70
  else
    puts "=" * 70
    puts "  ✗ Tests failed with exit code #{exit_code}"
    puts "=" * 70
  end
  puts

  exit exit_code
end

puts "Running inside tmux session"
puts

# Check prerequisites
socket_path = '/tmp/shared-session'

# Create socket session if it doesn't exist
unless File.exist?(socket_path)
  puts "Creating tmux socket at #{socket_path}..."
  system("tmux -S #{socket_path} new-session -d -s test_session")
  system("chmod 666 #{socket_path}") if File.exist?(socket_path)
end

unless File.exist?(socket_path) && File.writable?(socket_path)
  puts "ERROR: Cannot access tmux socket at #{socket_path}"
  puts "Please ensure:"
  puts "  1. Tmux is installed"
  puts "  2. You have permissions to create files in /tmp/"
  exit 1
end

# Verify tmux session exists on socket
session_check = `tmux -S #{socket_path} list-sessions 2>&1`
unless $?.success?
  puts "Creating tmux session on socket #{socket_path}..."
  system("tmux -S #{socket_path} new-session -d -s test_session")
  session_check = `tmux -S #{socket_path} list-sessions 2>&1`
  unless $?.success?
    puts "ERROR: Failed to create tmux session"
    exit 1
  end
end

puts "Prerequisites OK:"
puts "  - Running inside tmux: YES"
puts "  - Tmux socket: #{socket_path}"
puts "  - Session on socket: #{session_check.split("\n").first.split(':').first}"
puts

# Run the tests
require_relative 'test_tmux_runner'

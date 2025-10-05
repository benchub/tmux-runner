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

# Check prerequisites
socket_path = '/tmp/shared-session'
unless File.exist?(socket_path) && File.writable?(socket_path)
  puts "ERROR: Cannot access tmux socket at #{socket_path}"
  puts "Please ensure:"
  puts "  1. A tmux session exists: tmux -S /tmp/shared-session new-session -d -s test_session"
  puts "  2. Socket has correct permissions: chmod 666 /tmp/shared-session"
  exit 1
end

# Verify tmux session exists
session_check = `tmux -S #{socket_path} list-sessions 2>&1`
unless $?.success?
  puts "ERROR: No tmux sessions found on socket #{socket_path}"
  puts "Create one with: tmux -S /tmp/shared-session new-session -d -s test_session"
  exit 1
end

puts "Prerequisites OK:"
puts "  - Tmux socket: #{socket_path}"
puts "  - Session: #{session_check.split("\n").first.split(':').first}"
puts

# Run the tests
require_relative 'test_tmux_runner'

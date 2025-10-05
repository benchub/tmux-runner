#!/usr/bin/env ruby

require_relative '../tmux_runner_lib'

puts "=" * 60
puts "Socket Options Example"
puts "=" * 60

# Example 1: Default shared socket (most common)
puts "\n1. Using default shared socket (/tmp/shared-session):"
runner_default = TmuxRunner.new
result = runner_default.run("echo 'Using shared socket'")
puts "   Output: #{result[:output]}"
puts "   Socket: #{runner_default.socket_path}"

# Example 2: Custom socket path
puts "\n2. Using custom socket path:"
# Note: This would require a session on /tmp/custom-socket
# runner_custom = TmuxRunner.new(socket_path: '/tmp/custom-socket')
# result = runner_custom.run("echo 'Using custom socket'")
# puts "   Output: #{result[:output]}"
puts "   (Skipped - requires custom socket setup)"

# Example 3: No socket - use current tmux session
puts "\n3. Using current tmux session (no socket):"
runner_no_socket = TmuxRunner.new(socket_path: nil)
result = runner_no_socket.run("echo 'Using default tmux session'")
puts "   Output: #{result[:output]}"
puts "   Socket: #{runner_no_socket.socket_path.inspect}"

# Example 4: Demonstrating the flexibility
puts "\n4. Multiple runners with different configurations:"
runners = [
  { name: "Shared Socket", runner: TmuxRunner.new },
  { name: "Current Session", runner: TmuxRunner.new(socket_path: nil) }
]

runners.each do |config|
  result = config[:runner].run("hostname")
  puts "   #{config[:name]}: #{result[:output].strip}"
end

puts "\n" + "=" * 60
puts "All examples completed successfully!"
puts "=" * 60

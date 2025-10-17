#!/usr/bin/env ruby

require_relative '../tmux_runner_lib'

# Example demonstrating the array argument feature
# This makes it much easier to work with arguments containing spaces,
# special characters, or shell metacharacters

runner = TmuxRunner.new

puts "=" * 60
puts "Array Arguments Example"
puts "=" * 60
puts

# Example 1: Arguments with spaces (no complex quoting needed!)
puts "1. Arguments with spaces:"
puts "   OLD WAY: run('ls -l \"file with spaces.txt\"')"
puts "   NEW WAY: run('ls', '-l', 'file with spaces.txt')"
result = runner.run("echo", "hello world")
puts "   Output: #{result[:output]}"
puts

# Example 2: Arguments with special shell characters
puts "2. Arguments with shell metacharacters are literal:"
result = runner.run("echo", "test$VAR")
puts "   run('echo', 'test$VAR')"
puts "   Output: #{result[:output]} (not expanded!)"
puts

# Example 3: Practical example - grep with pattern and filename containing spaces
puts "3. Practical example with grep:"
test_file = "/tmp/test file #{Process.pid}.txt"
File.write(test_file, "line 1: content\nline 2: content\nline 3: other")

result = runner.run("grep", "content", test_file)
puts "   run('grep', 'content', '#{test_file}')"
puts "   Output:"
result[:output].lines.each { |line| puts "     #{line}" }
File.delete(test_file)
puts

# Example 4: Arguments with various special characters
puts "4. Special characters are literal (not shell operators):"
[
  ["echo", "a|b", "Pipe: a|b"],
  ["echo", "a&b", "Ampersand: a&b"],
  ["echo", "cmd1;cmd2", "Semicolon: cmd1;cmd2"],
  ["echo", "input>output", "Redirect: input>output"],
  ["echo", "`command`", "Backtick: `command`"]
].each do |cmd, arg, desc|
  result = runner.run(cmd, arg)
  puts "   #{desc} => #{result[:output]}"
end
puts

# Example 5: Compare string vs array behavior
puts "5. Difference between string and array forms:"
puts "   String form (allows shell features):"
result_string = runner.run("echo 'a' | cat")
puts "     run(\"echo 'a' | cat\") => #{result_string[:output]}"

puts "   Array form (literal arguments):"
result_array = runner.run("echo", "a|b")
puts "     run('echo', 'a|b') => #{result_array[:output]}"
puts

# Example 6: Works with all methods
puts "6. Array syntax works with all methods:"

# run!
output = runner.run!("printf", "%s", "from run!")
puts "   run!('printf', '%s', 'from run!') => #{output}"

# start/wait (async)
job_id = runner.start("echo", "async message")
result = runner.wait(job_id)
puts "   start('echo', 'async message') => #{result[:output]}"

# run_with_block
runner.run_with_block("echo", "block message") do |output, exit_code|
  puts "   run_with_block('echo', 'block message') => #{output}"
end
puts

puts "=" * 60
puts "All examples completed successfully!"
puts "=" * 60

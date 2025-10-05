#!/usr/bin/env ruby

require 'shellwords'

# Debug mode - set TMUX_RUNNER_DEBUG=1 to enable
DEBUG = ENV['TMUX_RUNNER_DEBUG'] == '1'

# --- Helper Function for running tmux commands ---
# This wrapper executes a tmux command, checks for errors, and exits if it fails.
def run_tmux_command(command, socket_path = nil)
  # Execute the command with the specified socket (or default tmux), redirecting stderr to stdout to capture any errors.
  socket_arg = socket_path ? "-S #{socket_path}" : ""
  output = `tmux #{socket_arg} #{command} 2>&1`
  status = $?.exitstatus

  # If the command failed (non-zero exit status), print the error and exit.
  unless status == 0
    STDERR.puts "--- TMUX COMMAND FAILED ---"
    STDERR.puts "COMMAND: tmux #{socket_arg} #{command}"
    STDERR.puts "EXIT CODE: #{status}"
    STDERR.puts "OUTPUT:\n#{output}"
    STDERR.puts "---------------------------"
    # Try to clean up the window if it was created before a later command failed.
    if command.include?('-t')
      window_name = command.split('-t').last.strip.split.first
      `tmux #{socket_arg} kill-window -t #{window_name}`
    end
    exit 1
  end

  # Return the command's output on success.
  output
end

# Non-failing version for commands that might legitimately fail
def try_tmux_command(command, socket_path = nil)
  socket_arg = socket_path ? "-S #{socket_path}" : ""
  output = `tmux #{socket_arg} #{command} 2>&1`
  return nil unless $?.success?
  output
end

# Find a delimiter in buffer, handling tmux line wrapping
# Tmux may wrap long lines, breaking delimiters across multiple lines
# Returns [start_pos, end_pos] or nil if not found
# IMPORTANT: Only matches delimiters that appear as their own line (after newline or start of buffer)
def find_delimiter_with_wrapping(buffer, delimiter)
  # First try exact match with rindex (finds last occurrence)
  # But only if it's at start of line
  idx = buffer.rindex(delimiter)
  if idx
    # Check if it's at start of buffer or after a newline
    if idx == 0 || buffer[idx - 1] == "\n"
      return [idx, idx + delimiter.length]
    end
  end

  # If not found, try with possible line breaks inserted
  # Split delimiter into parts (text + newline), handle each separately
  parts = delimiter.split(/(\n)/)

  pattern_parts = parts.map do |part|
    if part == "\n"
      # For newlines, just match them directly (they shouldn't be wrapped)
      '\n'
    else
      # For text parts, escape and allow optional newlines between characters
      escaped = Regexp.escape(part)
      # Allow line break + optional space after each character
      escaped.chars.join('(?:\n ?)?')
    end
  end

  # Prepend pattern to match start of line (after newline or start of buffer)
  pattern_str = '(?:^|\n)' + pattern_parts.join('')

  begin
    pattern = Regexp.new(pattern_str, Regexp::MULTILINE)
  rescue RegexpError => e
    # If regex fails, return nil
    return nil
  end

  # Find all matches and return the last one
  last_match_pos = nil
  last_match_end = nil

  buffer.scan(pattern) do
    match = Regexp.last_match
    # Skip the leading newline in the match
    actual_start = match.begin(0)
    actual_start += 1 if buffer[actual_start] == "\n"
    last_match_pos = actual_start
    last_match_end = match.end(0)
  end

  return nil if last_match_pos.nil?

  # Return [start position, end position]
  [last_match_pos, last_match_end]
end


# --- 1. Validate Environment ---
# Get socket path from environment variable or use default
socket_path = ENV['TMUX_SOCKET_PATH'] || '/tmp/shared-session'

# If socket path is explicitly set to empty string, use default tmux behavior (no socket)
if socket_path.empty?
  socket_path = nil
end

# Validate socket access if a socket path is specified
if socket_path
  unless File.exist?(socket_path) && File.writable?(socket_path)
    STDERR.puts "Error: Cannot access tmux socket at #{socket_path}."
    STDERR.puts "Please ensure the socket exists and you have write permissions."
    exit 1
  end
end

# Get the current session name or use the first available session
socket_arg = socket_path ? "-S #{socket_path}" : ""
session_list = `tmux #{socket_arg} list-sessions 2>&1`
unless $?.success?
  socket_msg = socket_path ? "on socket #{socket_path}" : "using default tmux session"
  STDERR.puts "Error: Cannot list tmux sessions #{socket_msg}"
  STDERR.puts session_list
  exit 1
end
session_name = session_list.split("\n").first.split(':').first
if session_name.nil? || session_name.empty?
  socket_msg = socket_path ? "on socket #{socket_path}" : "using default tmux session"
  STDERR.puts "Error: No tmux sessions found #{socket_msg}"
  exit 1
end

# --- 2. Get Command from Arguments ---
# The command to be executed is passed as arguments to this script.
# Optional: Set TMUX_WINDOW_PREFIX environment variable to customize window name
window_prefix = ENV['TMUX_WINDOW_PREFIX'] || 'tmux_runner'

command_to_run = ARGV.join(' ')
if command_to_run.empty?
  STDERR.puts "Usage: #{$0} <command to run in new window>"
  STDERR.puts "Example: #{$0} 'ls -l && echo Done.'"
  STDERR.puts "\nOptional: Set TMUX_WINDOW_PREFIX env var to customize window name"
  STDERR.puts "Example: TMUX_WINDOW_PREFIX=myapp #{$0} 'command'"
  exit 1
end

# --- 3. Create a New Tmux Window ---
# Generate a unique name for the new window to avoid conflicts.
# The window is created in the background (-d) so focus doesn't switch.
window_name = "#{window_prefix}_#{Process.pid}_#{Time.now.to_i}"
# Use =window_name syntax to target by exact window name
window_target = "#{session_name}:=#{window_name}"
puts "Creating new tmux window: #{window_target}"
run_tmux_command("new-window -d -t #{session_name}: -n #{window_name}", socket_path)
sleep 0.2  # Give tmux a moment to create the window

# --- 4. Send Command and Wait for Signal ---
# We create unique start and end delimiters to bookend the command's output.
# Use shorter delimiters to avoid line wrapping issues
unique_id = "#{Process.pid}_#{Time.now.to_i}"
channel_name = "tmux_runner_chan_#{unique_id}"
start_delimiter = "===START_#{unique_id}==="
end_delimiter = "===END_#{unique_id}==="

# We'll prepend an echo of the start delimiter, and append the end delimiter,
# exit code, and the wait-for signal. This makes parsing very reliable.
# Redirect stderr to stdout to capture all output, and save exit code before echoing delimiter.
# Don't exit at the end - let the window stay open so we can capture output
# Run command directly without subshell to avoid I/O issues with SSH and interactive programs
tmux_wait_cmd = socket_path ? "tmux -S #{socket_path} wait-for -S #{channel_name}" : "tmux wait-for -S #{channel_name}"
full_command = "echo '#{start_delimiter}'; #{command_to_run} 2>&1; EXIT_CODE=$?; echo #{end_delimiter}$EXIT_CODE; #{tmux_wait_cmd}"

# Send the full command sequence to the new window.
# Note: We need to escape the command for shell, but send-keys needs it quoted properly
escaped_command = full_command.gsub("'", "'\\\\''")  # Escape single quotes for shell
run_tmux_command("send-keys -t #{window_target} '#{escaped_command}' C-m", socket_path)

# Now, wait for the command to complete before capturing output
puts "Running command and waiting for completion..."
STDOUT.flush  # Ensure output is visible immediately

# Poll the pane content until we see the end delimiter
# Give the command a moment to start producing output
sleep 0.2

pane_content = ""
max_retries = 600  # 60 seconds timeout
retries = 0
found_end_once = false

loop do
  # Capture the pane content with full history (use try_ version since window might not be ready yet)
  pane_content = try_tmux_command("capture-pane -p -J -S - -E - -t #{window_target}", socket_path)

  # If capture failed, window might not be ready yet
  if pane_content.nil?
    retries += 1
    if retries >= max_retries
      STDERR.puts "Error: Command timed out after 60 seconds"
      break
    end
    sleep 0.1
    next
  end

  # Look for the end delimiter to know when command is complete
  # Handle tmux line wrapping by using flexible delimiter search
  end_result = find_delimiter_with_wrapping(pane_content, end_delimiter)

  # Debug: Report when we first see delimiter
  if DEBUG && end_result && !found_end_once
    STDERR.puts "DEBUG: Found end delimiter at position #{end_result[0]}"
    found_end_once = true
  end

  # Check if the command has finished
  break if end_result

  retries += 1
  if retries >= max_retries
    STDERR.puts "Error: Command timed out after 60 seconds"
    break
  end

  sleep 0.1
end

# Debug summary
if DEBUG
  STDERR.puts "DEBUG: Loop finished after #{retries} iterations"
  STDERR.puts "DEBUG: End delimiter was #{found_end_once ? 'found' : 'NOT FOUND'}"
end

# Wait for the signal to ensure everything is complete
run_tmux_command("wait-for #{channel_name}", socket_path) if retries < max_retries


# --- 5. Retrieve Output and Exit Code ---
# Since wait-for returned, the command is guaranteed to be finished.
# Capture the entire pane history with full scrollback.
pane_content = run_tmux_command("capture-pane -p -J -S - -E - -t #{window_target}", socket_path)

output = ""
exit_code = -1 # Default to a script error code.

# Parse output by finding content between start and end delimiters
# Handle tmux line wrapping using flexible delimiter search
start_result = find_delimiter_with_wrapping(pane_content, start_delimiter)
end_result = find_delimiter_with_wrapping(pane_content, end_delimiter)

# Adjust start_result to include the newline after the delimiter
if start_result
  delimiter_end_pos = start_result[1]
  # Find the next newline after the delimiter
  newline_pos = pane_content.index("\n", delimiter_end_pos)
  if newline_pos
    # Update start_result to point after the newline
    start_result = [start_result[0], newline_pos + 1]
  else
    STDERR.puts "Warning: Start delimiter found but no newline after it"
    start_result = nil
  end
end

if start_result && end_result
  start_index, start_end_pos = start_result
  end_index, end_end_pos = end_result

  # Verify the delimiters are in the right order
  if start_index >= end_index
    STDERR.puts "\nError: Start delimiter found after end delimiter. This shouldn't happen."
    STDERR.puts "Start index: #{start_index}, End index: #{end_index}"
    STDERR.puts "\nDumping buffer:"
    STDERR.puts pane_content
    exit_code = -1
    output = pane_content
  else
    # The output is the text between the start marker and the end delimiter.
    output_start_pos = start_end_pos
    output = pane_content[output_start_pos...end_index].strip

    # The exit code immediately follows the end delimiter.
    status_part = pane_content[end_end_pos..-1]
    # Extract just the number (first sequence of digits)
    exit_code_match = status_part[/^\d+/]
    if exit_code_match
      exit_code = exit_code_match.to_i
    else
      STDERR.puts "\nWarning: Could not parse exit code from: #{status_part[0..50].inspect}"
      exit_code = -1
    end

    # If output is empty, show a note and dump buffer for debugging
    if output.empty?
      if DEBUG
        STDERR.puts "\nNote: Command completed but produced no output between delimiters."
        STDERR.puts "This usually means the command ran successfully but had no stdout/stderr."
        STDERR.puts "\nFull buffer dump for debugging:"
        STDERR.puts "=" * 80
        STDERR.puts pane_content
        STDERR.puts "=" * 80
        STDERR.puts "\nDelimiter positions:"
        STDERR.puts "  Start delimiter at: #{start_index} to #{start_end_pos}"
        STDERR.puts "  End delimiter at: #{end_index} to #{end_end_pos}"
        STDERR.puts "  Content between should be from #{start_end_pos} to #{end_index}"
        STDERR.puts "  Length of content: #{end_index - start_end_pos} characters"
      end
    end
  end
else
  # This is a safety net; it shouldn't be reached if wait-for worked correctly.
  STDERR.puts "\nError: Command finished, but could not parse output. Delimiters not found."
  STDERR.puts "Expected start marker: #{start_delimiter}"
  STDERR.puts "Expected end marker: #{end_delimiter}"
  STDERR.puts "Start marker found: #{start_result ? 'YES' : 'NO'}"
  STDERR.puts "End marker found: #{end_result ? 'YES' : 'NO'}"
  STDERR.puts "\nDumping the entire buffer for debugging:"
  STDERR.puts pane_content
  output = pane_content
end


# --- 6. Display Results ---
puts "\n----------- COMMAND OUTPUT -----------"
puts output unless output.empty?
puts "------------------------------------"
puts "Exit Code: #{exit_code}"
puts "------------------------------------"


# --- 7. Clean Up ---
# If the command returned a success code (0), kill the temporary window.
if exit_code == 0
  puts "Command succeeded. Closing window '#{window_target}'."
  run_tmux_command("kill-window -t #{window_target}", socket_path)
else
  puts "Command failed or script error occurred. Leaving window '#{window_target}' open for inspection."
  close_cmd = socket_path ? "tmux -S #{socket_path} kill-window -t #{window_target}" : "tmux kill-window -t #{window_target}"
  puts "To close it manually, run: #{close_cmd}"
end


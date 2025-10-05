# Tmux Runner

Run commands in tmux windows and reliably capture their output, including stderr and commands with progress bars or cursor manipulation.

## Features

- ✅ Runs commands in isolated tmux windows
- ✅ Captures both stdout and stderr
- ✅ Handles commands with progress bars/cursor manipulation (captures final state)
- ✅ Works across different terminal widths with line wrapping
- ✅ Returns proper exit codes
- ✅ Can be used as standalone script or Ruby library
- ✅ Automatic window cleanup on success (configurable)

## Prerequisites

- Ruby
- tmux
- A tmux session (either on a shared socket or the default session)

## But why?

If you're wondering why this and not just threads or background jobs or whatever, here are some niche reasons this fills a unique niche:

### Identity and Context Preservation
- **SSH Agent Forwarding**: Run commands as different users while preserving the original user's ssh-agent socket. Example: connect as userX, sudo to userY, but still use userX's SSH keys for remote connections.
- **Environment Inheritance**: Commands run in tmux windows inherit the session's environment, including forwarded SSH agents, display settings, and authentication tokens that wouldn't survive process boundaries.

### True Output Capture
- **Progress Bars and TUIs**: Unlike pipes or redirects that break progress bars, this captures the *final rendered state* of commands with cursor manipulation (npm install, wget, apt, docker pull, etc.).
- **ANSI and Terminal Features**: Preserves full terminal output including colors, cursor positioning, and control sequences as they actually appeared.

### Cross-Language Parallel Execution
- **Shell Script Parallelism**: Add quick-and-dirty parallel execution to bash/shell scripts without rewriting in a language with threading.
- **Process-Based Concurrency**: Useful when Ruby threads won't work (blocking C extensions, MRI GIL constraints, external process management).

### Debugging and Inspection
- **Persistent Windows on Failure**: Failed commands leave their tmux windows open for manual inspection—you can attach to the session and see exactly what happened.
- **Live Monitoring**: While jobs run, you can attach to the tmux session and watch them in real-time across multiple windows.

### Privilege Boundary Crossing
- **Sudo Context Switching**: Start a process as root that needs to execute commands as the original user with that user's credentials and environment.
- **User Impersonation**: Run commands as service users while maintaining access to the invoking user's authentication context.


Also, because I was curious what this "vibe coding" thing is all about. 

## Setup

### Option 1: Shared Socket (Default)

Create a tmux session on the shared socket:

```bash
tmux -S /tmp/shared-session new-session -d -s my_session
chmod 666 /tmp/shared-session
```

With newer tmux you might need to grant access to this socket, beyond filesystem permissions, if you will be using tmux-runner not as the socket owner.

```bash
tmux server-access -a anotherUser
```

### Option 2: Use Default Tmux Session

If you're already inside a tmux session, you can use the runner without a shared socket by passing `socket_path: nil` to the library, or by setting `TMUX_SOCKET_PATH=''` for the standalone script.

## Usage

### As a Standalone Script

The standalone script is available in two versions:
- **`tmux_runner.sh`** (Bash) - Default, faster startup, no Ruby dependency for CLI usage
- **`tmux_runner.rb`** (Ruby) - Fallback for systems without Bash 4+

Both scripts have identical functionality and command-line interfaces.

```bash
# Basic usage with bash version (recommended)
./tmux_runner.sh "echo 'Hello World'"

# Or use the Ruby version
ruby tmux_runner.rb "echo 'Hello World'"

# Use a custom socket
TMUX_SOCKET_PATH=/tmp/my-socket ./tmux_runner.sh "echo 'Custom socket'"

# Use the current tmux session (no socket)
TMUX_SOCKET_PATH='' ./tmux_runner.sh "echo 'Default session'"

# Command with errors
./tmux_runner.sh "ls /nonexistent"

# Complex command
./tmux_runner.sh "ssh -J jumphost target-host hostname"

# Enable debug output
TMUX_RUNNER_DEBUG=1 ./tmux_runner.sh "your command"
```

### As a Ruby Library

The library automatically detects and uses the best available script:
1. Prefers `tmux_runner.sh` (bash) if available (~6% faster)
2. Falls back to `tmux_runner.rb` (ruby) if bash version not found
3. Can be overridden by passing `script_path:` parameter

```ruby
require_relative 'tmux_runner_lib'

# Create a runner instance (auto-detects bash or ruby script)
runner = TmuxRunner.new

# Create a runner that uses the current tmux session
runner_no_socket = TmuxRunner.new(socket_path: nil)

# Create a runner with a custom socket
runner_custom = TmuxRunner.new(socket_path: '/tmp/my-socket')

# Force using a specific script version (optional)
runner_bash = TmuxRunner.new(script_path: './tmux_runner.sh')
runner_ruby = TmuxRunner.new(script_path: './tmux_runner.rb')

# Run a command and get results
result = runner.run("echo 'Hello'")
if result[:success]
  puts "Output: #{result[:output]}"
  puts "Exit code: #{result[:exit_code]}"
end

# Run and raise on failure
begin
  output = runner.run!("hostname")
  puts "Hostname: #{output.strip}"
rescue => e
  puts "Command failed: #{e.message}"
end

# Use a block for custom handling
runner.run_with_block("ls -l") do |output, exit_code|
  lines = output.split("\n")
  puts "Found #{lines.length} files"
end

# Access last result
runner.run("date")
puts "Last exit code: #{runner.last_exit_code}"
puts "Last output: #{runner.last_output}"
```

## API Reference

### TmuxRunner Class

#### `initialize(socket_path: '/tmp/shared-session', script_path: nil)`
Creates a new runner instance.

**Parameters:**
- `socket_path` - Path to tmux socket (default: `'/tmp/shared-session'`). Pass `nil` to use the current tmux session without a socket.
- `script_path` - Path to the standalone script (default: auto-detects `tmux_runner.sh` or `tmux_runner.rb`). The library prefers the bash version if available for better performance.

### Blocking Methods

#### `run(command, window_prefix: 'tmux_runner')` → Hash
Runs a command and returns:
- `:success` - Boolean, true if exit code was 0
- `:output` - String, the command's stdout/stderr output
- `:exit_code` - Integer, the command's exit code
- `:error` - String or nil, error message if any
- `:full_output` - String, complete output including headers

Optional `window_prefix` parameter customizes the tmux window name (default: 'tmux_runner').

#### `run!(command, window_prefix: 'tmux_runner')` → String
Runs a command and returns just the output string. Raises an exception if the command fails.

Optional `window_prefix` parameter customizes the tmux window name (default: 'tmux_runner').

#### `run_with_block(command, window_prefix: 'tmux_runner') { |output, exit_code| ... }` → Hash
Runs a command and yields the output and exit code to the block, then returns the result hash.

Optional `window_prefix` parameter customizes the tmux window name (default: 'tmux_runner').

### Concurrent/Non-Blocking Methods

#### `start(command, window_prefix: 'tmux_runner')` → String (job_id)
Starts a command asynchronously and immediately returns a job ID. The command runs in the background.

Optional `window_prefix` parameter customizes the tmux window name (default: 'tmux_runner').

#### `finished?(job_id)` → Boolean
Returns true if the job has completed (successfully or with error).

#### `running?(job_id)` → Boolean
Returns true if the job is still running.

#### `wait(job_id)` → Hash
Blocks until the job completes and returns its result hash (same format as `run()`).

#### `result(job_id)` → Hash or nil
Returns the result hash if the job is finished, or nil if still running. Non-blocking.

#### `status(job_id)` → Symbol
Returns `:running`, `:completed`, `:failed`, `:cancelled`, or nil if job doesn't exist.

#### `jobs()` → Array<String>
Returns all job IDs (running and completed).

#### `running_jobs()` → Array<String>
Returns only the IDs of currently running jobs.

#### `wait_all()` → Hash
Blocks until all running jobs complete. Returns a hash of `job_id => result`.

#### `cancel(job_id)` → Boolean
Attempts to cancel a running job. Returns true if cancelled, false otherwise.

#### `cleanup_job(job_id)` → nil
Removes a job from the internal jobs list.

#### Attributes
- `last_exit_code` - Exit code of the most recent command
- `last_output` - Output of the most recent command
- `socket_path` - Path to the tmux socket
- `script_path` - Path to the script being used (`.sh` or `.rb`)

## Implementation Details

### Script Versions

Two functionally identical implementations are provided:

**Bash Version (`tmux_runner.sh`)**
- Pure bash script requiring Bash 4+
- ~6% faster than Ruby version (498ms vs 530ms average)
- No Ruby interpreter needed for CLI usage
- Passes shellcheck with zero warnings
- **Default choice** - Used automatically by the library

**Ruby Version (`tmux_runner.rb`)**
- Pure Ruby requiring only stdlib
- Better for systems without Bash 4+ (older macOS, Alpine, embedded)
- Easier to extend with complex parsing logic
- **Fallback option** - Used when bash version unavailable

Both versions:
- Have identical command-line interfaces
- Pass the same 41-test suite with 96 assertions
- Support all features: debug mode, custom prefixes, socket options
- Handle edge cases identically (empty output, errors, Unicode, etc.)

### How It Works

1. Creates a uniquely-named tmux window
2. Sends the command with special delimiters to mark start/end
3. Polls the pane until the end delimiter appears
4. Captures the final pane content (after any cursor manipulation)
5. Parses output between delimiters
6. Extracts exit code
7. Cleans up the window (if successful)

## Debug Mode

Enable debug output by setting the `TMUX_RUNNER_DEBUG` environment variable:

```bash
# With bash version
TMUX_RUNNER_DEBUG=1 ./tmux_runner.sh "your command"

# With Ruby version
TMUX_RUNNER_DEBUG=1 ruby tmux_runner.rb "your command"
```

Debug output includes:
- Delimiter positions in buffer
- Buffer dumps when issues occur
- Loop iteration counts
- Line capture statistics

## Troubleshooting

### "Cannot access tmux socket"
Ensure the tmux session exists and you have permissions:
```bash
ls -l /tmp/shared-session
# Should show read/write permissions
```

### "No tmux sessions found"
Create a session first:
```bash
tmux -S /tmp/shared-session new-session -d -s my_session
```

### Commands hang or timeout
- Check if the command requires interactive input
- Ensure the command completes within 60 seconds
- Enable debug mode to see what's happening

## Concurrent Usage

Run multiple commands in parallel:

```ruby
runner = TmuxRunner.new

# Start multiple jobs
job1 = runner.start("ssh server1 hostname")
job2 = runner.start("ssh server2 hostname")
job3 = runner.start("ssh server3 hostname")

# Check status
while runner.running_jobs.any?
  puts "Still running: #{runner.running_jobs.length} jobs"
  sleep 1
end

# Get results
result1 = runner.result(job1)
result2 = runner.result(job2)
result3 = runner.result(job3)

# Or wait for specific job
result = runner.wait(job1)  # Blocks until job1 completes

# Or wait for all
results = runner.wait_all  # Hash of job_id => result
```

## Custom Window Prefixes

You can customize the tmux window name prefix for better organization:

```ruby
runner = TmuxRunner.new

# Use custom prefix for blocking execution
result = runner.run("hostname", window_prefix: 'myapp')

# Use custom prefix for concurrent jobs
web_job = runner.start("check_web_server", window_prefix: 'web')
db_job = runner.start("check_database", window_prefix: 'db')
cache_job = runner.start("check_cache", window_prefix: 'cache')

# Works with all run methods
output = runner.run!("command", window_prefix: 'api')
runner.run_with_block("command", window_prefix: 'worker') { |out, code| ... }
```

Window names will be: `{prefix}_{pid}_{timestamp}` (e.g., `web_12345_1234567890`)

## Testing

Comprehensive test suite with 50+ test cases covering all functionality:

```bash
# Run all tests
ruby run_tests.rb

# Run specific tests
ruby run_tests.rb --pattern concurrent
ruby run_tests.rb --pattern window_prefix

# Verbose output
ruby run_tests.rb --verbose
```

See `TESTING.md` for detailed test documentation.

## Examples

- `example_usage.rb` - Basic command execution, error handling, blocks, long-running commands, progress bars, complex pipes and SSH
- `example_concurrent.rb` - Running multiple commands concurrently, polling job status, waiting for specific or all jobs
- `example_window_prefix.rb` - Using custom window prefixes for better organization
- `example_practical.rb` - Real-world patterns: multi-server health checks, task queues with concurrency limits, timeout handling

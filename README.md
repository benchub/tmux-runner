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
- ✅ Preserves shell variables and special characters correctly
- ✅ Supports complex SSH commands with variable expansion

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

```bash
# Basic usage
ruby tmux_runner.rb "echo 'Hello World'"

# Use a custom socket
TMUX_SOCKET_PATH=/tmp/my-socket ruby tmux_runner.rb "echo 'Custom socket'"

# Use the current tmux session (no socket)
TMUX_SOCKET_PATH='' ruby tmux_runner.rb "echo 'Default session'"

# Command with errors
ruby tmux_runner.rb "ls /nonexistent"

# Complex SSH command with variables
ruby tmux_runner.rb "ssh -J jumphost target-host 'h=\$(hostname) && echo \$h'"

# SSH command with array arguments (alternative)
./tmux_runner.rb ssh -J jumphost target-host 'h=$(hostname) && echo $h'

# Enable debug output
TMUX_RUNNER_DEBUG=1 ruby tmux_runner.rb "your command"
```

### As a Ruby Library

```ruby
require_relative 'tmux_runner_lib'

# Create a runner instance
runner = TmuxRunner.new

# Create a runner that uses the current tmux session
runner_no_socket = TmuxRunner.new(socket_path: nil)

# Create a runner with a custom socket
runner_custom = TmuxRunner.new(socket_path: '/tmp/my-socket')

# Run a command and get results
result = runner.run("echo 'Hello'")
if result[:success]
  puts "Output: #{result[:output]}"
  puts "Exit code: #{result[:exit_code]}"
end

# Array arguments (avoids complex quoting for arguments with spaces)
result = runner.run("ls", "-l", "file with spaces.txt")
result = runner.run("grep", "pattern", "/path/to/file with spaces.txt")

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
- `script_path` - Path to the standalone script (default: auto-detects `tmux_runner.rb`). Can be overridden to use a custom script path.

### Array Arguments

All command execution methods (`run`, `run!`, `run_with_block`, `start`) support two forms:

**String form** - Single command string with shell features:
```ruby
runner.run("echo 'a' | cat")  # Pipes work
runner.run("echo $HOME")       # Variables expand
```

**Array form** - Command and arguments as separate strings (no shell processing):
```ruby
runner.run("echo", "a|b")           # Literal: a|b (not a pipe)
runner.run("echo", "$HOME")         # Literal: $HOME (not expanded)
runner.run("ls", "-l", "file.txt")  # No quoting needed for spaces
```

**Benefits of array form:**
- No complex quoting for arguments with spaces
- Shell metacharacters are literal (safe from injection)
- Arguments with `$`, `|`, `&`, `;`, `>`, `` ` ``, quotes, etc. are treated as literal strings

**When to use each:**
- Use **string form** when you need shell features (pipes, redirection, variable expansion)
- Use **array form** when you have literal arguments (especially with spaces or special characters)

### Blocking Methods

#### `run(command, window_prefix: 'tmux_runner')` → Hash
#### `run(*args, window_prefix: 'tmux_runner')` → Hash
Runs a command and returns:
- `:success` - Boolean, true if exit code was 0
- `:output` - String, the command's stdout/stderr output
- `:exit_code` - Integer, the command's exit code
- `:error` - String or nil, error message if any
- `:full_output` - String, complete output including headers

Optional `window_prefix` parameter customizes the tmux window name (default: 'tmux_runner').

**Examples:**
```ruby
result = runner.run("echo 'hello'")
result = runner.run("ls", "-l", "file with spaces.txt")
result = runner.run(["grep", "pattern", "file.txt"])
```

#### `run!(command, window_prefix: 'tmux_runner')` → String
#### `run!(*args, window_prefix: 'tmux_runner')` → String
Runs a command and returns just the output string. Raises an exception if the command fails.

Optional `window_prefix` parameter customizes the tmux window name (default: 'tmux_runner').

**Examples:**
```ruby
output = runner.run!("hostname")
output = runner.run!("cat", "file with spaces.txt")
```

#### `run_with_block(command, window_prefix: 'tmux_runner') { |output, exit_code| ... }` → Hash
#### `run_with_block(*args, window_prefix: 'tmux_runner') { |output, exit_code| ... }` → Hash
Runs a command and yields the output and exit code to the block, then returns the result hash.

Optional `window_prefix` parameter customizes the tmux window name (default: 'tmux_runner').

**Examples:**
```ruby
runner.run_with_block("ls -l") { |output, code| puts output }
runner.run_with_block("grep", "pattern", "file.txt") { |output, code| puts output }
```

### Concurrent/Non-Blocking Methods

#### `start(command, window_prefix: 'tmux_runner')` → String (job_id)
#### `start(*args, window_prefix: 'tmux_runner')` → String (job_id)
Starts a command asynchronously and immediately returns a job ID. The command runs in the background.

Optional `window_prefix` parameter customizes the tmux window name (default: 'tmux_runner').

**Examples:**
```ruby
job_id = runner.start("sleep 5")
job_id = runner.start("grep", "pattern", "file with spaces.txt")
```

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
- `script_path` - Path to the script being used

## Implementation Details

### Ruby Implementation

The tmux runner is implemented in pure Ruby requiring only stdlib:
- Robust prompt detection using shell prompt patterns
- Handles tmux line wrapping and trailing blank lines
- Comprehensive delimiter detection to avoid false positives
- Wait-for signal mechanism for reliable synchronization
- Array-based command execution to prevent premature variable expansion
- Proper handling of shell quoting for multi-argument commands
- Passes comprehensive 145-test suite with 392 assertions

### Race Condition Handling

The implementation carefully handles timing issues:
- **Delimiter Detection**: Distinguishes between delimiter in command echo vs actual output
- **Prompt Detection**: Checks last 5 non-blank lines for shell prompt after command completion
- **Signal Synchronization**: Uses tmux wait-for signals (non-blocking) to coordinate timing
- **Blank Line Handling**: Properly handles tmux's fixed-height panes with trailing blanks

See test suite for detailed edge case coverage including:
- Commands without trailing newlines
- Very fast commands
- Long-running commands
- Wrapped command lines
- Multiple prompts in buffer

### How It Works

1. Creates a uniquely-named tmux window
2. Sends the command with special delimiters to mark start/end
3. Polls the pane until the end delimiter appears on its own line (not in command echo)
4. Waits for shell prompt to return (confirms wait-for signal completed)
5. Captures the final pane content (after any cursor manipulation)
6. Parses output between delimiters
7. Extracts exit code from delimiter line
8. Cleans up the window (if successful)

## Debug Mode

Enable debug output by setting the `TMUX_RUNNER_DEBUG` environment variable:

```bash
TMUX_RUNNER_DEBUG=1 ruby tmux_runner.rb "your command"
```

Debug output includes:
- Delimiter positions in buffer
- Buffer dumps when issues occur
- Loop iteration counts
- Line capture statistics

## Special Character Handling

The tmux runner preserves most special characters correctly. However, some characters require special attention:

### Exclamation Mark (!)

The `!` character can trigger shell history expansion in interactive shells. To safely use `!` in commands:

**Option 1: Use bash -c with proper quoting (recommended)**
```bash
ruby tmux_runner.rb 'bash -c '"'"'msg="test!" && echo "$msg"'"'"''
```

**Option 2: Use single quotes in the variable assignment**
```bash
ruby tmux_runner.rb "msg='test!' && echo \"\$msg\""
```

**Why this matters**: When you run a command like `msg="test!" && echo "$msg"`, the shell may expand `!` before tmux even sees it, especially if history expansion is enabled (`set +H` to disable in bash).

### Other Special Characters

All other common special characters work correctly with proper shell quoting:
- `@`, `#`, `$`, `%`, `^`, `&`, `*` - Work in double quotes
- `(`, `)`, `[`, `]`, `{`, `}` - Work in double quotes
- `|`, `\`, `;`, `'`, `"`, `<`, `>`, `?`, `~`, `` ` `` - Work with standard shell escaping

See the test suite (`test/test_special_characters.rb`) for working examples of each character.

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

Comprehensive test suite with 145 test cases (392 assertions) covering all functionality:

```bash
# Run all tests (automatically starts tmux if needed)
ruby test/run_tests.rb

# Run specific test file
ruby test/test_variable_expansion_basic.rb

# Run specific test pattern
ruby test/run_tests.rb --pattern test_simple_command_success

# With verbose output
ruby test/run_tests.rb --verbose

# Or run directly (requires being inside tmux)
ruby test/test_tmux_runner.rb --name test_simple_command_success
```

The test runner (`run_tests.rb`) will automatically:
- Start a tmux session if you're not already inside one
- Create the required shared socket at `/tmp/shared-session`
- Set up proper permissions
- Clean up leftover test windows before running
- Validate session exists and recreate if needed
- Run all tests and display results

Test coverage includes:
- **Basic Functionality**: Simple commands, error handling, exit codes, multiline output
- **Array Arguments**: Space handling, special characters, shell metacharacters, backward compatibility (29 tests)
- **Concurrent Execution**: Start/wait/cancel jobs, job status tracking, parallel execution
- **Race Conditions**: Fast commands, slow commands, rapid sequential execution, mixed timing
- **Edge Cases**: Delimiter detection, prompt detection, blank lines, line wrapping, no trailing newlines
- **Custom Configuration**: Window prefixes, socket paths, custom commands
- **Variable Expansion** (58 tests):
  - Basic: Variable assignment, command substitution, quoting contexts, environment variables
  - Advanced: bash -c, sh -c, special variables ($$, $?, $#), arrays, parameter expansion, loops, pipes, SSH-like scenarios
  - Edge Cases: Variables with spaces/newlines/special chars, variable isolation, empty/undefined variables
- **Special Characters** (22 tests): Individual tests for !, @, #, $, %, ^, &, *, (, ), [, ], {, }, |, \, ;, ', ", <, >, ?, ~, `

All tests pass with 100% success rate.

## Examples

- `example_usage.rb` - Basic command execution, error handling, blocks, long-running commands, progress bars, complex pipes and SSH
- `example_array_args.rb` - Using array arguments to handle spaces and special characters without complex quoting
- `example_concurrent.rb` - Running multiple commands concurrently, polling job status, waiting for specific or all jobs
- `example_window_prefix.rb` - Using custom window prefixes for better organization
- `example_practical.rb` - Real-world patterns: multi-server health checks, task queues with concurrency limits, timeout handling

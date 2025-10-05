# TmuxRunner Project Structure

```
tmux_runner/
├── README.md                      # Main documentation
├── TESTING.md                     # Test suite documentation
├── PROJECT_STRUCTURE.md           # This file
│
├── tmux_runner.sh                 # Standalone bash script (default, ~6% faster)
├── tmux_runner.rb                 # Standalone Ruby script (fallback)
├── tmux_runner_lib.rb             # Ruby library wrapper (auto-detects .sh or .rb)
│
├── examples/                      # Usage examples
│   ├── example_usage.rb           # Basic usage (7 examples)
│   ├── example_concurrent.rb      # Concurrent execution (9 examples)
│   ├── example_window_prefix.rb   # Custom window prefixes (5 examples)
│   ├── example_practical.rb       # Real-world patterns (3 examples)
│   └── example_socket_options.rb  # Socket configuration examples
│
└── test/                          # Test suite
    ├── run_tests.rb               # Test runner with options
    └── test_tmux_runner.rb        # 41 test cases, 96 assertions
```

## File Descriptions

### Core Files

**`tmux_runner.sh`** (Primary Implementation)
- Standalone bash script that runs commands in tmux windows
- Can be used directly: `./tmux_runner.sh "command"`
- Requires Bash 4+ (uses arrays, parameter expansion)
- ~6% faster than Ruby version (498ms vs 530ms average)
- Passes shellcheck with zero warnings
- Pure bash with no external dependencies beyond tmux
- Handles delimiter-based output parsing
- Configurable via environment variables:
  - `TMUX_RUNNER_DEBUG=1` - Enable debug output
  - `TMUX_WINDOW_PREFIX=name` - Set window name prefix
  - `TMUX_SOCKET_PATH=/path` - Custom socket location
- Exit codes preserved from executed commands
- ~330 lines

**`tmux_runner.rb`** (Fallback Implementation)
- Standalone Ruby script with identical functionality to bash version
- Can be used directly: `ruby tmux_runner.rb "command"`
- Better portability for systems without Bash 4+ (older macOS, Alpine)
- Easier to extend with complex parsing logic
- Pure Ruby requiring only stdlib
- Same environment variables and interface as bash version
- Exit codes preserved from executed commands
- ~346 lines

**`tmux_runner_lib.rb`**
- Object-oriented Ruby library wrapper
- Auto-detects and uses best available script (prefers .sh, falls back to .rb)
- Can override with `script_path:` parameter
- Provides both blocking and non-blocking execution methods
- Thread-safe concurrent job management
- API methods: run(), run!(), start(), wait(), result(), status(), etc.
- Works identically regardless of underlying script
- ~253 lines

### Examples

**`examples/example_usage.rb`**
- Basic command execution
- Error handling
- Using blocks
- Long-running commands
- Commands with progress bars
- Complex pipes and SSH commands
- 7 comprehensive examples

**`examples/example_concurrent.rb`**
- Starting multiple jobs concurrently
- Checking job status with finished?() and running?()
- Waiting for specific jobs with wait()
- Waiting for all jobs with wait_all()
- Handling failures in concurrent jobs
- Performance demonstration (parallelism)
- 9 detailed examples

**`examples/example_window_prefix.rb`**
- Using default window prefix
- Custom prefix with run()
- Custom prefix with start()
- Custom prefix with run!()
- Custom prefix with run_with_block()
- 5 practical examples

**`examples/example_practical.rb`**
- Multi-server health checks (concurrent)
- Task queue with concurrency limits
- Timeout handling and job cancellation
- 3 real-world patterns

### Tests

**`test/test_tmux_runner.rb`**
- Comprehensive test suite: 41 test cases, 96 assertions
- Tests both bash and Ruby script implementations
- Categories:
  - Basic functionality (8 tests)
  - run! method (2 tests)
  - run_with_block (2 tests - improved to verify return values)
  - Concurrent execution (11 tests)
  - Custom window prefix (5 tests)
  - Complex commands (5 tests)
  - Edge cases (5 tests)
  - State tracking (2 tests)
  - Cancellation (1 test)
- Uses Ruby's Test::Unit framework
- 100% pass rate with both script implementations

**`test/run_tests.rb`**
- Test runner with options:
  - `--verbose` - Detailed output
  - `--pattern PATTERN` - Run specific tests
  - `--help` - Show help
- Validates prerequisites (tmux socket)
- ~60 lines

### Documentation

**`README.md`**
- Complete usage guide
- API reference
- Prerequisites and setup
- Troubleshooting
- Examples overview

**`TESTING.md`**
- Test suite documentation
- Running tests
- Test coverage details
- Adding new tests
- CI integration

**`PROJECT_STRUCTURE.md`**
- This file
- Project organization
- File descriptions
- Usage patterns

## Quick Start

### 1. Setup
```bash
cd tmux_runner
tmux -S /tmp/shared-session new-session -d -s my_session
chmod 666 /tmp/shared-session
```

### 2. Try Standalone Scripts
```bash
# Bash version (recommended)
./tmux_runner.sh "echo 'Hello from bash'"

# Ruby version
ruby tmux_runner.rb "echo 'Hello from Ruby'"
```

### 3. Try Examples
```bash
ruby examples/example_usage.rb
ruby examples/example_concurrent.rb
ruby examples/example_window_prefix.rb
ruby examples/example_practical.rb
```

### 4. Run Tests
```bash
# Tests work with both bash and Ruby implementations
ruby test/run_tests.rb
```

### 5. Use in Your Code
```ruby
require_relative 'tmux_runner/tmux_runner_lib'

# Auto-detects and uses bash version if available
runner = TmuxRunner.new

# Blocking
result = runner.run("hostname")
puts result[:output]

# Non-blocking
job = runner.start("long_command")
# ... do other work ...
result = runner.wait(job)
```

## Development

### Adding Features
1. Decide if feature needs both implementations:
   - Core functionality → Update both `tmux_runner.sh` AND `tmux_runner.rb`
   - Library-only features → Update `tmux_runner_lib.rb` only
2. Add tests to `test/test_tmux_runner.rb`
3. Verify tests pass with both bash and Ruby implementations
4. Add examples to appropriate example file
5. Update documentation (README.md, PROJECT_STRUCTURE.md)

### Testing Strategy
- Unit tests in `test/test_tmux_runner.rb` (41 tests, 96 assertions)
- Tests automatically use auto-detected script (bash by default)
- Integration examples in `examples/`
- Manual testing: `./tmux_runner.sh "command"` or `ruby tmux_runner.rb "command"`
- Shellcheck validation for bash version: `shellcheck tmux_runner.sh`

### Implementation Consistency
- Both `tmux_runner.sh` and `tmux_runner.rb` must:
  - Accept identical command-line arguments
  - Support same environment variables
  - Produce identical output format
  - Handle edge cases the same way
  - Pass all 41 test cases
- Library (`tmux_runner_lib.rb`) works transparently with either

### Key Design Principles
- Dual implementation for flexibility (bash speed, Ruby portability)
- Standalone scripts work independently
- Library wraps scripts, doesn't duplicate logic
- Auto-detection prefers performance (bash) over portability
- Thread-safe concurrent execution
- Reliable output capture with delimiter parsing
- Line wrapping awareness for various terminal widths
- Progress bar final state capture
- Customizable window naming

## File Sizes
- Core scripts: ~930 lines total
  - `tmux_runner.sh`: ~330 lines (bash)
  - `tmux_runner.rb`: ~346 lines (ruby)
  - `tmux_runner_lib.rb`: ~253 lines (library wrapper)
- Examples: ~500 lines total
- Tests: ~450 lines total (41 tests, 96 assertions)
- Docs: ~600+ lines total

## Dependencies

### For CLI Usage (Standalone Scripts)
**Bash version (`tmux_runner.sh`):**
- Bash 4+ (uses arrays, parameter expansion)
- tmux
- A tmux session (on `/tmp/shared-session` by default)

**Ruby version (`tmux_runner.rb`):**
- Ruby (standard library only)
- tmux
- A tmux session (on `/tmp/shared-session` by default)

### For Library Usage
- Ruby (standard library only)
- tmux
- A tmux session (on `/tmp/shared-session` by default)
- Either `tmux_runner.sh` (preferred) or `tmux_runner.rb` (fallback)

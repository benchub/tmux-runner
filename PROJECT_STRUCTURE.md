# TmuxRunner Project Structure

```
tmux_runner/
├── README.md                      # Main documentation
├── TESTING.md                     # Test suite documentation
├── PROJECT_STRUCTURE.md           # This file
│
├── tmux_runner.rb                 # Standalone script (core)
├── tmux_runner_lib.rb             # Ruby library wrapper
│
├── examples/                      # Usage examples
│   ├── example_usage.rb           # Basic usage (7 examples)
│   ├── example_concurrent.rb      # Concurrent execution (9 examples)
│   ├── example_window_prefix.rb   # Custom window prefixes (5 examples)
│   └── example_practical.rb       # Real-world patterns (3 examples)
│
└── test/                          # Test suite
    ├── run_tests.rb               # Test runner with options
    └── test_tmux_runner.rb        # 50+ test cases
```

## File Descriptions

### Core Files

**`tmux_runner.rb`**
- Standalone Ruby script that runs commands in tmux windows
- Can be used directly: `ruby tmux_runner.rb "command"`
- Handles delimiter-based output parsing with line wrapping support
- Configurable via environment variables:
  - `TMUX_RUNNER_DEBUG=1` - Enable debug output
  - `TMUX_WINDOW_PREFIX=name` - Set window name prefix
- Exit codes preserved from executed commands
- ~335 lines

**`tmux_runner_lib.rb`**
- Object-oriented Ruby library wrapper around tmux_runner.rb
- Provides both blocking and non-blocking execution methods
- Thread-safe concurrent job management
- API methods: run(), run!(), start(), wait(), result(), status(), etc.
- ~227 lines

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
- Comprehensive test suite with 50+ test cases
- Categories:
  - Basic functionality (8 tests)
  - run! method (2 tests)
  - run_with_block (1 test)
  - Concurrent execution (11 tests)
  - Custom window prefix (5 tests)
  - Complex commands (5 tests)
  - Edge cases (5 tests)
  - State tracking (2 tests)
  - Cancellation (1 test)
- Uses Ruby's Test::Unit framework

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

### 2. Try Examples
```bash
ruby examples/example_usage.rb
ruby examples/example_concurrent.rb
ruby examples/example_window_prefix.rb
ruby examples/example_practical.rb
```

### 3. Run Tests
```bash
ruby test/run_tests.rb
```

### 4. Use in Your Code
```ruby
require_relative 'tmux_runner/tmux_runner_lib'

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
1. Modify `tmux_runner.rb` for core functionality
2. Extend `tmux_runner_lib.rb` for API changes
3. Add tests to `test/test_tmux_runner.rb`
4. Add examples to appropriate example file
5. Update documentation

### Testing Strategy
- Unit tests in `test/test_tmux_runner.rb`
- Integration examples in `examples/`
- Manual testing with `tmux_runner.rb` standalone

### Key Design Principles
- Standalone script works independently
- Library wraps script, doesn't duplicate logic
- Thread-safe concurrent execution
- Reliable output capture with delimiter parsing
- Line wrapping awareness for various terminal widths
- Progress bar final state capture
- Customizable window naming

## File Sizes
- Core: ~562 lines total
- Examples: ~470 lines total
- Tests: ~450 lines total
- Docs: ~500+ lines total

## Dependencies
- Ruby (standard library only)
- tmux
- A tmux session on `/tmp/shared-session`

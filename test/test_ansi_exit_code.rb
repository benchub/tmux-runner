#!/usr/bin/env ruby
# frozen_string_literal: true

require 'test/unit'

# Unit tests specifically for ANSI codes in the exit code extraction path
# These tests directly test the parsing logic without requiring tmux
class TestAnsiExitCodeParsing < Test::Unit::TestCase
  def setup
    @runner_script = File.join(__dir__, '..', 'tmux_runner.rb')

    # Extract the find_delimiter_with_wrapping function from the script
    script_content = File.read(@runner_script)
    if script_content =~ /(def find_delimiter_with_wrapping.*?^end)/m
      @find_delimiter_func = $1
      eval(@find_delimiter_func, binding, __FILE__, __LINE__)
    end
  end

  # Helper to simulate exit code extraction as done in tmux_runner.rb (with ANSI fix)
  def extract_exit_code(pane_content, end_delimiter)
    end_result = find_delimiter_with_wrapping(pane_content, end_delimiter, require_own_line: false)
    return nil unless end_result

    end_end_pos = end_result[1]
    status_part = pane_content[end_end_pos..]

    # Strip ANSI codes before extracting (this matches the fixed tmux_runner.rb)
    status_part_clean = status_part.gsub(/\e\[[0-9;]*[A-Za-z]/, "")
    exit_code_match = status_part_clean[/^\d+/]
    exit_code_match ? exit_code_match.to_i : -1
  end

  # Test normal case without ANSI codes
  def test_exit_code_extraction_normal
    end_delimiter = "===END_123==="
    pane_content = <<~PANE
      ===START_123===
      Command output
      ===END_123===0
      user@host$
    PANE

    exit_code = extract_exit_code(pane_content, end_delimiter)
    assert_equal 0, exit_code, "Should extract exit code 0"
  end

  # Test exit code 127
  def test_exit_code_extraction_127
    end_delimiter = "===END_123==="
    pane_content = "===START_123===\nError\n===END_123===127\nuser@host$"

    exit_code = extract_exit_code(pane_content, end_delimiter)
    assert_equal 127, exit_code, "Should extract exit code 127"
  end

  # Test with ANSI reset code between delimiter and exit code
  # This simulates what might happen with SSH terminals
  def test_exit_code_with_ansi_reset_between
    end_delimiter = "===END_123==="
    # ANSI reset code \e[0m appears between delimiter and exit code
    pane_content = "===START_123===\nOutput\n===END_123===\e[0m0\nuser@host$"

    exit_code = extract_exit_code(pane_content, end_delimiter)
    # After fix: should correctly extract exit code despite ANSI codes
    assert_equal 0, exit_code, "Should extract exit code 0 even with ANSI reset code"
  end

  # Test with color code between delimiter and exit code
  def test_exit_code_with_color_code_between
    end_delimiter = "===END_123==="
    # Color code \e[32m (green) appears between delimiter and exit code
    pane_content = "===START_123===\nOutput\n===END_123===\e[32m0\nuser@host$"

    exit_code = extract_exit_code(pane_content, end_delimiter)
    assert_equal 0, exit_code, "Should extract exit code 0 even with color codes"
  end

  # Test with multiple ANSI codes
  def test_exit_code_with_multiple_ansi_codes
    end_delimiter = "===END_123==="
    # Multiple ANSI codes
    pane_content = "===START_123===\nOutput\n===END_123===\e[0m\e[K\e[39m42\nuser@host$"

    exit_code = extract_exit_code(pane_content, end_delimiter)
    assert_equal 42, exit_code, "Should extract exit code 42 through multiple ANSI codes"
  end

  # Test clear line code
  def test_exit_code_with_clear_line_code
    end_delimiter = "===END_123==="
    # \e[K clears to end of line
    pane_content = "===START_123===\nOutput\n===END_123===\e[K3\nuser@host$"

    exit_code = extract_exit_code(pane_content, end_delimiter)
    assert_equal 3, exit_code, "Should extract exit code 3 even with clear line code"
  end

  # Test cursor movement code
  def test_exit_code_with_cursor_code
    end_delimiter = "===END_123==="
    # \e[H moves cursor to home
    pane_content = "===START_123===\nOutput\n===END_123===\e[H5\nuser@host$"

    exit_code = extract_exit_code(pane_content, end_delimiter)
    assert_equal 5, exit_code, "Should extract exit code 5 even with cursor codes"
  end
end

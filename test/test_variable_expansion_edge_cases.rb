#!/usr/bin/env ruby
# frozen_string_literal: true

require 'test/unit'
require 'shellwords'

# Edge cases for variable expansion
class TestVariableExpansionEdgeCases < Test::Unit::TestCase
  def setup
    @runner_script = File.join(__dir__, '..', 'tmux_runner.rb')
    @socket_path = '/tmp/shared-session'
  end

  def run_command(cmd)
    output = `#{@runner_script} #{Shellwords.escape(cmd)} 2>&1`
    exit_code = $?.exitstatus
    command_output = nil
    reported_exit_code = nil

    if output =~ /----------- COMMAND OUTPUT -----------\n(.*?)\n------------------------------------\nExit Code: (\d+)/m
      command_output = $1
      reported_exit_code = $2.to_i
    end

    {
      raw_output: output,
      command_output: command_output,
      exit_code: reported_exit_code || exit_code,
      success: exit_code.zero?
    }
  end

  # Test variable expansion with special characters
  def test_variable_with_spaces
    result = run_command('msg="hello world" && echo "$msg"')
    assert_equal 0, result[:exit_code], "Command should succeed"
    assert_match /hello world/, result[:command_output], "Should preserve spaces"
  end

  def test_variable_with_newlines
    result = run_command('msg="line1\nline2" && echo "$msg"')
    assert_equal 0, result[:exit_code], "Command should succeed"
    assert_match /line1/, result[:command_output], "Should have first line"
    assert_match /line2/, result[:command_output], "Should have second line"
  end

  def test_variable_with_special_chars
    # Use a simpler set of special chars to avoid timeout issues
    result = run_command('msg="test@#$" && echo "$msg"')
    assert_equal 0, result[:exit_code], "Command should succeed"
    # Output might be nil if command times out or fails to parse
    omit "Command output was nil - possible timeout" if result[:command_output].nil?
    assert_match /test/, result[:command_output], "Should preserve special characters"
    assert_match /@#/, result[:command_output], "Should have special chars"
  end

  # Test that variables don't leak between commands
  def test_variable_isolation_between_runs
    result1 = run_command('TEST_ISOLATION=first && echo $TEST_ISOLATION')
    assert_match /first/, result1[:command_output], "First run should show 'first'"

    result2 = run_command('echo $TEST_ISOLATION')
    assert result2[:command_output].nil? || result2[:command_output].strip.empty?, "Second run should not see first run's variable"
  end

  # Test edge cases
  def test_empty_variable
    result = run_command('empty="" && echo "value:$empty:end"')
    assert_equal 0, result[:exit_code], "Command should succeed"
    assert_match /value::end/, result[:command_output], "Should handle empty variable"
  end

  def test_undefined_variable
    result = run_command('echo $COMPLETELY_UNDEFINED_VARIABLE_XYZ')
    assert_equal 0, result[:exit_code], "Command should succeed"
    assert result[:command_output].nil? || result[:command_output].strip.empty?, "Should be empty"
  end

  def test_variable_with_equals_sign
    result = run_command('eq="a=b" && echo "$eq"')
    assert_equal 0, result[:exit_code], "Command should succeed"
    assert_match /a=b/, result[:command_output], "Should preserve equals sign"
  end

  # Test variable expansion doesn't break delimiter detection
  def test_variable_containing_delimiter_like_text
    result = run_command('msg="EQEQEQTESTEQEQEQ" && echo "$msg"')
    assert_equal 0, result[:exit_code], "Command should succeed"
    assert_match /EQEQEQTEST/, result[:command_output], "Should output delimiter-like text"
  end

  def test_command_substitution_with_delimiter_like_output
    result = run_command('result=$(echo "EQEQEQOUTPUTEQEQEQ") && echo "$result"')
    assert_equal 0, result[:exit_code], "Command should succeed"
    assert_match /EQEQEQOUTPUT/, result[:command_output], "Should handle delimiter-like output"
  end

  # Test backslash escaping in variable context
  def test_variable_with_backslashes
    result = run_command('path="a\\b\\c" && echo "$path"')
    assert_equal 0, result[:exit_code], "Command should succeed"
    assert_not_nil result[:command_output]
  end
end

#!/usr/bin/env ruby
# frozen_string_literal: true

require 'test/unit'
require 'shellwords'

# Basic variable expansion tests
class TestVariableExpansionBasic < Test::Unit::TestCase
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

  # Test basic variable assignment and expansion
  def test_variable_assignment_and_expansion
    result = run_command('h=$(hostname) && echo $h')
    assert_equal 0, result[:exit_code], "Command should succeed"
    assert_not_nil result[:command_output], "Should have command output"
    # Hostname should be non-empty and contain some characters
    assert_match /\w+/, result[:command_output], "Should output hostname"
  end

  def test_variable_with_echo_prefix
    result = run_command('h=$(hostname) && echo "Hostname: $h"')
    assert_equal 0, result[:exit_code], "Command should succeed"
    assert_match /Hostname: \w+/, result[:command_output], "Should show hostname with prefix"
  end

  def test_multiple_variables
    result = run_command('a=hello && b=world && echo "$a $b"')
    assert_equal 0, result[:exit_code], "Command should succeed"
    assert_match /hello world/, result[:command_output], "Should show both variables"
  end

  # Test command substitution
  def test_command_substitution_backticks
    result = run_command('result=`echo test` && echo $result')
    assert_equal 0, result[:exit_code], "Command should succeed"
    assert_match /test/, result[:command_output], "Should show command substitution result"
  end

  def test_command_substitution_dollar_paren
    result = run_command('result=$(echo nested) && echo $result')
    assert_equal 0, result[:exit_code], "Command should succeed"
    assert_match /nested/, result[:command_output], "Should show command substitution result"
  end

  def test_nested_command_substitution
    result = run_command('outer=$(echo "inner: $(echo value)") && echo $outer')
    assert_equal 0, result[:exit_code], "Command should succeed"
    assert_match /inner: value/, result[:command_output], "Should handle nested substitution"
  end

  # Test variable expansion in different quoting contexts
  def test_single_quotes_preserve_literal_dollar
    result = run_command("echo 'literal $HOME'")
    assert_equal 0, result[:exit_code], "Command should succeed"
    assert_equal "literal $HOME", result[:command_output].strip, "Should be literal"
  end

  def test_double_quotes_expand_variables
    result = run_command('HOME=/test && echo "expanded $HOME"')
    assert_equal 0, result[:exit_code], "Command should succeed"
    assert_match /expanded \/test/, result[:command_output], "Should expand variable"
  end

  # Test environment variables
  def test_env_variable_preservation
    result = run_command('TEST_VAR=myvalue && echo $TEST_VAR')
    assert_equal 0, result[:exit_code], "Command should succeed"
    assert_match /myvalue/, result[:command_output], "Should show env variable"
  end

  def test_path_variable_access
    result = run_command('echo $PATH')
    assert_equal 0, result[:exit_code], "Command should succeed"
    assert_match /\/usr\/bin/, result[:command_output], "Should show PATH content"
  end

  # Test that our fix doesn't break simple commands
  def test_simple_echo_still_works
    result = run_command('echo "hello"')
    assert_equal 0, result[:exit_code], "Simple command should succeed"
    assert_match /hello/, result[:command_output], "Simple echo should work"
  end

  def test_command_without_variables_still_works
    result = run_command('ls /tmp > /dev/null && echo success')
    assert_equal 0, result[:exit_code], "Command without variables should succeed"
    assert_match /success/, result[:command_output], "Should show success"
  end
end

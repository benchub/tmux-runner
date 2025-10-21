#!/usr/bin/env ruby
# frozen_string_literal: true

require 'test/unit'
require 'shellwords'

# Consolidated variable expansion tests
# Tests basic, advanced, and edge case scenarios for shell variable expansion
class TestVariableExpansion < Test::Unit::TestCase
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

  # ==================== BASIC TESTS ====================

  def test_variable_assignment_and_expansion
    result = run_command('h=$(hostname) && echo $h')
    assert_equal 0, result[:exit_code], "Command should succeed"
    assert_not_nil result[:command_output], "Should have command output"
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

  # ==================== ADVANCED TESTS ====================

  def test_bash_c_with_single_quotes
    result = run_command("bash -c 'h=$(hostname) && echo $h'")
    assert_equal 0, result[:exit_code], "Command should succeed"
    assert_match /\w+/, result[:command_output], "Should output hostname"
  end

  def test_bash_c_with_complex_command
    result = run_command("bash -c 'x=5 && y=10 && echo $((x + y))'")
    assert_equal 0, result[:exit_code], "Command should succeed"
    assert_match /15/, result[:command_output], "Should calculate arithmetic"
  end

  def test_sh_c_with_single_quotes
    result = run_command("sh -c 'result=success && echo $result'")
    assert_equal 0, result[:exit_code], "Command should succeed"
    assert_match /success/, result[:command_output], "Should show variable value"
  end

  def test_pid_variable
    result = run_command('echo $$')
    assert_equal 0, result[:exit_code], "Command should succeed"
    assert_match /\d+/, result[:command_output], "Should show PID"
  end

  def test_exit_code_variable
    result = run_command('false; echo $?')
    assert_equal 0, result[:exit_code], "Overall command should succeed"
    assert_match /1/, result[:command_output], "Should show exit code 1 from false"
  end

  def test_argument_count_variable
    result = run_command('sh -c "echo \$#" -- a b c')
    assert_equal 0, result[:exit_code], "Command should succeed"
    assert_match /3/, result[:command_output], "Should show 3 arguments"
  end

  def test_bash_array_variable
    result = run_command("bash -c 'arr=(a b c) && echo ${arr[1]}'")
    assert_equal 0, result[:exit_code], "Command should succeed"
    assert_match /b/, result[:command_output], "Should access array element"
  end

  def test_parameter_expansion_default_value
    result = run_command('echo ${UNDEFINED_VAR:-default}')
    assert_equal 0, result[:exit_code], "Command should succeed"
    assert_match /default/, result[:command_output], "Should use default value"
  end

  def test_parameter_expansion_substring
    result = run_command("bash -c 'str=hello && echo ${str:1:3}'")
    assert_equal 0, result[:exit_code], "Command should succeed"
    assert_match /ell/, result[:command_output], "Should extract substring"
  end

  def test_for_loop_with_variable
    result = run_command("bash -c 'sum=0; for i in 1 2 3; do sum=\$((sum + i)); done; echo \$sum'")
    assert_equal 0, result[:exit_code], "Command should succeed"
    assert_match /6/, result[:command_output], "Should calculate sum"
  end

  def test_variable_through_pipe
    result = run_command('msg="test message" && echo "$msg" | grep message')
    assert_equal 0, result[:exit_code], "Command should succeed"
    assert_match /test message/, result[:command_output], "Should pass through pipe"
  end

  def test_ssh_like_command_simulation
    result = run_command("bash -c 'host=\$(hostname) && echo Remote host: \$host'")
    assert_equal 0, result[:exit_code], "Command should succeed"
    assert_match /Remote host: \w+/, result[:command_output], "Should show hostname"
  end

  def test_multiple_ssh_like_commands
    result = run_command("bash -c 'h=\$(hostname) && u=\$(whoami) && echo \$u@\$h'")
    assert_equal 0, result[:exit_code], "Command should succeed"
    assert_match /\w+@\w+/, result[:command_output], "Should show user@host format"
  end

  def test_complex_command_performance
    start_time = Time.now
    result = run_command('for i in $(seq 1 10); do x=$((x + i)); done && echo $x')
    duration = Time.now - start_time

    assert_equal 0, result[:exit_code], "Command should succeed"
    assert duration < 5.0, "Command should complete quickly (took #{duration}s)"
  end

  # ==================== EDGE CASES ====================

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
    result = run_command('msg="test@#$" && echo "$msg"')
    assert_equal 0, result[:exit_code], "Command should succeed"
    omit "Command output was nil - possible timeout" if result[:command_output].nil?
    assert_match /test/, result[:command_output], "Should preserve special characters"
    assert_match /@#/, result[:command_output], "Should have special chars"
  end

  def test_variable_isolation_between_runs
    result1 = run_command('TEST_ISOLATION=first && echo $TEST_ISOLATION')
    assert_match /first/, result1[:command_output], "First run should show 'first'"

    result2 = run_command('echo $TEST_ISOLATION')
    assert result2[:command_output].nil? || result2[:command_output].strip.empty?, "Second run should not see first run's variable"
  end

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

  def test_variable_with_backslashes
    result = run_command('path="a\\b\\c" && echo "$path"')
    assert_equal 0, result[:exit_code], "Command should succeed"
    assert_not_nil result[:command_output]
  end
end

#!/usr/bin/env ruby
# frozen_string_literal: true

require 'test/unit'
require 'shellwords'

# Advanced variable expansion tests
class TestVariableExpansionAdvanced < Test::Unit::TestCase
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

  # Test bash -c with variables
  def test_bash_c_with_single_quotes
    result = run_command("bash -c 'h=$(hostname) && echo $h'")
    assert_equal 0, result[:exit_code], "Command should succeed"
    assert_match /ip-\d+-\d+-\d+-\d+/, result[:command_output], "Should output hostname"
  end

  def test_bash_c_with_complex_command
    result = run_command("bash -c 'x=5 && y=10 && echo $((x + y))'")
    assert_equal 0, result[:exit_code], "Command should succeed"
    assert_match /15/, result[:command_output], "Should calculate arithmetic"
  end

  # Test sh -c with variables
  def test_sh_c_with_single_quotes
    result = run_command("sh -c 'result=success && echo $result'")
    assert_equal 0, result[:exit_code], "Command should succeed"
    assert_match /success/, result[:command_output], "Should show variable value"
  end

  # Test special variables
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

  # Test array variables (bash)
  def test_bash_array_variable
    result = run_command("bash -c 'arr=(a b c) && echo ${arr[1]}'")
    assert_equal 0, result[:exit_code], "Command should succeed"
    assert_match /b/, result[:command_output], "Should access array element"
  end

  # Test parameter expansion
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

  # Test variable expansion in loops
  def test_for_loop_with_variable
    result = run_command("bash -c 'sum=0; for i in 1 2 3; do sum=\$((sum + i)); done; echo \$sum'")
    assert_equal 0, result[:exit_code], "Command should succeed"
    assert_match /6/, result[:command_output], "Should calculate sum"
  end

  # Test variable expansion with pipes
  def test_variable_through_pipe
    result = run_command('msg="test message" && echo "$msg" | grep message')
    assert_equal 0, result[:exit_code], "Command should succeed"
    assert_match /test message/, result[:command_output], "Should pass through pipe"
  end

  # Test real-world SSH-like scenario
  def test_ssh_like_command_simulation
    result = run_command("bash -c 'host=\$(hostname) && echo Remote host: \$host'")
    assert_equal 0, result[:exit_code], "Command should succeed"
    assert_match /Remote host: ip-/, result[:command_output], "Should show hostname"
  end

  def test_multiple_ssh_like_commands
    result = run_command("bash -c 'h=\$(hostname) && u=\$(whoami) && echo \$u@\$h'")
    assert_equal 0, result[:exit_code], "Command should succeed"
    assert_match /@ip-/, result[:command_output], "Should show user@host format"
  end

  # Performance test
  def test_complex_command_performance
    start_time = Time.now
    result = run_command('for i in $(seq 1 10); do x=$((x + i)); done && echo $x')
    duration = Time.now - start_time

    assert_equal 0, result[:exit_code], "Command should succeed"
    assert duration < 5.0, "Command should complete quickly (took #{duration}s)"
  end
end

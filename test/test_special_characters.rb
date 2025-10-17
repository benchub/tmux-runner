#!/usr/bin/env ruby
# frozen_string_literal: true

require 'test/unit'
require 'shellwords'

# Test each special character individually to isolate issues
class TestSpecialCharacters < Test::Unit::TestCase
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

  # Test exclamation mark (!)
  def test_exclamation_mark
    result = run_command('msg="test!" && echo "$msg"')
    assert_equal 0, result[:exit_code], "Command should succeed"
    omit "Command output was nil" if result[:command_output].nil?
    assert_match /test!/, result[:command_output], "Should preserve !"
  end

  # Test at sign (@)
  def test_at_sign
    result = run_command('msg="test@example" && echo "$msg"')
    assert_equal 0, result[:exit_code], "Command should succeed"
    assert_match /test@example/, result[:command_output], "Should preserve @"
  end

  # Test hash/pound (#)
  def test_hash_sign
    result = run_command('msg="test#123" && echo "$msg"')
    assert_equal 0, result[:exit_code], "Command should succeed"
    assert_match /test#123/, result[:command_output], "Should preserve #"
  end

  # Test dollar sign ($) - needs careful escaping
  def test_dollar_sign
    result = run_command('msg="test\\$value" && echo "$msg"')
    assert_equal 0, result[:exit_code], "Command should succeed"
    assert_match /test\$value/, result[:command_output], "Should preserve $"
  end

  # Test percent (%)
  def test_percent_sign
    result = run_command('msg="test%100" && echo "$msg"')
    assert_equal 0, result[:exit_code], "Command should succeed"
    assert_match /test%100/, result[:command_output], "Should preserve %"
  end

  # Test caret (^)
  def test_caret_sign
    result = run_command('msg="test^value" && echo "$msg"')
    assert_equal 0, result[:exit_code], "Command should succeed"
    assert_match /test\^value/, result[:command_output], "Should preserve ^"
  end

  # Test ampersand (&)
  def test_ampersand_sign
    result = run_command('msg="test&value" && echo "$msg"')
    assert_equal 0, result[:exit_code], "Command should succeed"
    assert_match /test&value/, result[:command_output], "Should preserve &"
  end

  # Test asterisk (*)
  def test_asterisk_sign
    result = run_command('msg="test*value" && echo "$msg"')
    assert_equal 0, result[:exit_code], "Command should succeed"
    assert_match /test\*value/, result[:command_output], "Should preserve *"
  end

  # Test parentheses ()
  def test_parentheses
    result = run_command('msg="test(value)" && echo "$msg"')
    assert_equal 0, result[:exit_code], "Command should succeed"
    assert_match /test\(value\)/, result[:command_output], "Should preserve ()"
  end

  # Test square brackets []
  def test_square_brackets
    result = run_command('msg="test[value]" && echo "$msg"')
    assert_equal 0, result[:exit_code], "Command should succeed"
    assert_match /test\[value\]/, result[:command_output], "Should preserve []"
  end

  # Test curly braces {}
  def test_curly_braces
    result = run_command('msg="test{value}" && echo "$msg"')
    assert_equal 0, result[:exit_code], "Command should succeed"
    assert_match /test\{value\}/, result[:command_output], "Should preserve {}"
  end

  # Test pipe (|)
  def test_pipe_sign
    result = run_command('msg="test|value" && echo "$msg"')
    assert_equal 0, result[:exit_code], "Command should succeed"
    assert_match /test\|value/, result[:command_output], "Should preserve |"
  end

  # Test backslash (\)
  def test_backslash
    result = run_command('msg="test\\\\value" && echo "$msg"')
    assert_equal 0, result[:exit_code], "Command should succeed"
    omit "Command output was nil" if result[:command_output].nil?
    assert_not_nil result[:command_output], "Should have output"
  end

  # Test semicolon (;)
  def test_semicolon
    result = run_command('msg="test;value" && echo "$msg"')
    assert_equal 0, result[:exit_code], "Command should succeed"
    assert_match /test;value/, result[:command_output], "Should preserve ;"
  end

  # Test single quote (')
  def test_single_quote
    result = run_command('msg="test'"'"'value" && echo "$msg"')
    assert_equal 0, result[:exit_code], "Command should succeed"
    assert_match /test'value/, result[:command_output], "Should preserve '"
  end

  # Test double quote (")
  def test_double_quote
    result = run_command('msg="test\\"value" && echo "$msg"')
    assert_equal 0, result[:exit_code], "Command should succeed"
    assert_match /test"value/, result[:command_output], "Should preserve \""
  end

  # Test less than (<)
  def test_less_than
    result = run_command('msg="test<value" && echo "$msg"')
    assert_equal 0, result[:exit_code], "Command should succeed"
    assert_match /test<value/, result[:command_output], "Should preserve <"
  end

  # Test greater than (>)
  def test_greater_than
    result = run_command('msg="test>value" && echo "$msg"')
    assert_equal 0, result[:exit_code], "Command should succeed"
    assert_match /test>value/, result[:command_output], "Should preserve >"
  end

  # Test question mark (?)
  def test_question_mark
    result = run_command('msg="test?value" && echo "$msg"')
    assert_equal 0, result[:exit_code], "Command should succeed"
    assert_match /test\?value/, result[:command_output], "Should preserve ?"
  end

  # Test tilde (~)
  def test_tilde
    result = run_command('msg="test~value" && echo "$msg"')
    assert_equal 0, result[:exit_code], "Command should succeed"
    assert_match /test~value/, result[:command_output], "Should preserve ~"
  end

  # Test backtick (`)
  def test_backtick
    result = run_command('msg="test\`value" && echo "$msg"')
    assert_equal 0, result[:exit_code], "Command should succeed"
    omit "Command output was nil" if result[:command_output].nil?
    assert_match /test/, result[:command_output], "Should have output"
  end

  # Test combination of multiple special characters
  def test_multiple_special_chars_combination
    result = run_command('msg="@#$%^&*()" && echo "$msg"')
    assert_equal 0, result[:exit_code], "Command should succeed"
    omit "Command output was nil" if result[:command_output].nil?
    assert_match /@/, result[:command_output], "Should have @"
    assert_match /#/, result[:command_output], "Should have #"
    assert_match /\$/, result[:command_output], "Should have $"
  end
end

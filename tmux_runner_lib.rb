#!/usr/bin/env ruby
# frozen_string_literal: true

require "shellwords"

# TmuxRunner - Run commands in tmux windows and capture output
# This is a library wrapper around the tmux_runner.rb standalone script
class TmuxRunner
  attr_reader :socket_path, :script_path, :last_exit_code, :last_output

  # Initialize TmuxRunner
  # @param socket_path [String, nil] Path to tmux socket. Use '/tmp/shared-session' (default) for shared socket,
  #                                   or nil to use the current tmux session (no -S flag)
  # @param script_path [String] Path to the tmux_runner script (defaults to bash version, falls back to Ruby)
  def initialize(socket_path: "/tmp/shared-session", script_path: nil)
    @socket_path = socket_path
    @last_exit_code = nil
    @last_output = nil
    @jobs = {}
    @jobs_mutex = Mutex.new

    # Auto-detect script path - use Ruby version
    if script_path
      @script_path = script_path
    elsif File.exist?(File.join(File.dirname(__FILE__), "tmux_runner.rb"))
      @script_path = File.join(File.dirname(__FILE__), "tmux_runner.rb")
    else
      raise "Cannot find tmux_runner.rb script"
    end

    return if File.exist?(@script_path)

    raise "Cannot find tmux_runner script at #{@script_path}"
  end

  # Run a command and return a result hash (blocking)
  # Returns: { success: true/false, output: "...", exit_code: 0, error: nil }
  def run(command, window_prefix: "tmux_runner")
    # Run the standalone script and capture output
    env_vars = "TMUX_WINDOW_PREFIX=#{Shellwords.escape(window_prefix)}"
    # Only set TMUX_SOCKET_PATH if socket_path is non-nil
    # If nil, the script will use default tmux behavior (no -S flag)
    env_vars += if @socket_path
                  " TMUX_SOCKET_PATH=#{Shellwords.escape(@socket_path)}"
                else
                  " TMUX_SOCKET_PATH=''"
                end

    # Determine how to run the script based on its extension
    script_runner = @script_path.end_with?(".sh") ? "" : "ruby "
    full_output = `#{env_vars} #{script_runner}#{Shellwords.escape(@script_path)} #{Shellwords.escape(command)} 2>&1`

    # Parse the output to extract command output and exit code
    result = parse_output(full_output)

    @last_output = result[:output]
    @last_exit_code = result[:exit_code]

    result
  end

  # Start a command asynchronously and return a job handle
  # Returns: job_id (String)
  def start(command, window_prefix: "tmux_runner")
    job_id = generate_job_id

    thread = Thread.new do
      result = run(command, window_prefix: window_prefix)
      @jobs_mutex.synchronize do
        @jobs[job_id][:result] = result
        @jobs[job_id][:status] = :completed
      end
    rescue => e
      @jobs_mutex.synchronize do
        @jobs[job_id][:result] = {
          success: false,
          output: "",
          exit_code: -1,
          error: e.message
        }
        @jobs[job_id][:status] = :failed
        @jobs[job_id][:exception] = e
      end
    end

    @jobs_mutex.synchronize do
      @jobs[job_id] = {
        command: command,
        window_prefix: window_prefix,
        thread: thread,
        status: :running,
        started_at: Time.now,
        result: nil
      }
    end

    job_id
  end

  # Check if a job has finished
  def finished?(job_id)
    @jobs_mutex.synchronize do
      job = @jobs[job_id]
      return false unless job

      %i[completed failed].include?(job[:status])
    end
  end

  # Check if a job is still running
  def running?(job_id)
    @jobs_mutex.synchronize do
      job = @jobs[job_id]
      return false unless job

      job[:status] == :running
    end
  end

  # Wait for a job to complete and return its result
  # Blocks until the job finishes
  def wait(job_id)
    job = nil
    @jobs_mutex.synchronize { job = @jobs[job_id] }

    raise "Unknown job ID: #{job_id}" unless job

    job[:thread].join

    @jobs_mutex.synchronize do
      result = @jobs[job_id][:result]
      raise @jobs[job_id][:exception] if @jobs[job_id][:exception]

      result
    end
  end

  # Get the result of a finished job without waiting
  # Returns nil if job isn't finished yet
  def result(job_id)
    @jobs_mutex.synchronize do
      job = @jobs[job_id]
      return nil unless job
      return nil unless %i[completed failed].include?(job[:status])

      job[:result]
    end
  end

  # Get status of a job
  # Returns: :running, :completed, :failed, or nil if job doesn't exist
  def status(job_id)
    @jobs_mutex.synchronize do
      job = @jobs[job_id]
      return nil unless job

      job[:status]
    end
  end

  # Get all job IDs
  def jobs
    @jobs_mutex.synchronize { @jobs.keys }
  end

  # Get all running job IDs
  def running_jobs
    @jobs_mutex.synchronize do
      @jobs.select { |_, job| job[:status] == :running }.keys
    end
  end

  # Wait for all running jobs to complete
  # Returns a hash of job_id => result
  def wait_all
    job_ids = running_jobs
    results = {}

    job_ids.each do |job_id|
      results[job_id] = wait(job_id)
    end

    results
  end

  # Cancel a running job (kills the thread, but tmux window may remain)
  def cancel(job_id)
    @jobs_mutex.synchronize do
      job = @jobs[job_id]
      return false unless job
      return false unless job[:status] == :running

      job[:thread].kill
      job[:status] = :cancelled
      true
    end
  end

  # Clean up a job from the jobs list
  def cleanup_job(job_id)
    @jobs_mutex.synchronize do
      @jobs.delete(job_id)
    end
  end

  # Run a command and return just the output string
  # Raises an exception if the command fails
  def run!(command, window_prefix: "tmux_runner")
    result = run(command, window_prefix: window_prefix)
    raise "Command failed with exit code #{result[:exit_code]}: #{result[:output]}" unless result[:success]

    result[:output]
  end

  # Run a command and yield output and exit code to a block
  def run_with_block(command, window_prefix: "tmux_runner")
    result = run(command, window_prefix: window_prefix)
    yield(result[:output], result[:exit_code])
    result
  end

  private

  def generate_job_id
    "job_#{Time.now.to_i}_#{rand(100_000)}"
  end

  def parse_output(full_output)
    # Extract the exit code from the output
    exit_code_match = full_output.match(/^Exit Code: (\d+)$/m)
    exit_code = exit_code_match ? exit_code_match[1].to_i : -1

    # Extract command output (between the header and exit code line)
    # Use non-greedy match and look for the final separator before Exit Code
    # rubocop:disable Layout/LineLength
    output_match = full_output.match(/----------- COMMAND OUTPUT -----------\n(.*?)\n------------------------------------\nExit Code:/m)
    # rubocop:enable Layout/LineLength
    output = output_match ? output_match[1] : ""

    # Check if there was an error
    error = full_output.include?("Error:") ? full_output : nil

    {
      success: exit_code.zero?,
      output: output,
      exit_code: exit_code,
      error: error,
      full_output: full_output
    }
  end
end

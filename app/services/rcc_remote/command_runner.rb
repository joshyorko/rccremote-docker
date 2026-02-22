# frozen_string_literal: true

require "open3"

module RccRemote
  class CommandRunner
    Result = Struct.new(:success, :stdout, :stderr, :exit_code, :timed_out, keyword_init: true) do
      def success?
        success
      end

      def timed_out?
        timed_out
      end
    end

    def run(*command, timeout: 30, chdir: nil)
      stdout = +""
      stderr = +""
      status = nil
      timed_out = false
      popen_options = { pgroup: true }
      popen_options[:chdir] = chdir if chdir

      Open3.popen3(*command.flatten, **popen_options) do |stdin, out, err, wait_thread|
        stdin.close

        stdout_reader = Thread.new { out.read }
        stderr_reader = Thread.new { err.read }

        if wait_thread.join(timeout)
          status = wait_thread.value
        else
          timed_out = true
          terminate(wait_thread)
        end

        stdout = stdout_reader.value.to_s
        stderr = stderr_reader.value.to_s
      end

      Result.new(
        success: !timed_out && status&.success?,
        stdout:,
        stderr:,
        exit_code: status&.exitstatus || -1,
        timed_out:
      )
    rescue StandardError => e
      Result.new(success: false, stdout: "", stderr: e.message, exit_code: -1, timed_out: false)
    end

    private

    def terminate(wait_thread)
      pgid = Process.getpgid(wait_thread.pid)
      Process.kill("TERM", -pgid)
      return if wait_thread.join(2)

      Process.kill("KILL", -pgid)
      wait_thread.join(2)
    rescue Errno::ESRCH, Errno::EPERM
      nil
    end
  end
end

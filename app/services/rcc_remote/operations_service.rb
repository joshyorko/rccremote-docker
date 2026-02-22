# frozen_string_literal: true

require "shellwords"

module RccRemote
  class OperationsService
    CATALOG_PREFIX_EXCLUSIONS = [ "=", "Holotree", "---", "Blueprint", "OK." ].freeze

    def initialize(config: Configuration.new, command_runner: CommandRunner.new)
      @config = config
      @command_runner = command_runner
    end

    def rcc_info
      version_result = rcc_exec("--version", timeout: 5)
      catalogs_result = rcc_exec("holotree", "catalogs", timeout: 10)

      catalogs = catalogs_result.success? ? parse_catalogs(preferred_output(catalogs_result)) : []

      {
        version: version_result.success? ? preferred_output(version_result).strip.presence || "unknown" : "unknown",
        available: version_result.success?,
        catalog_count: catalogs.length
      }
    end

    def fetch_catalogs
      result = rcc_exec("holotree", "catalogs", timeout: 10)
      output = preferred_output(result)

      if result.success?
        catalogs = parse_catalogs(output)

        {
          success: true,
          catalogs:,
          count: catalogs.length,
          raw_output: output
        }
      else
        {
          success: false,
          error: "Failed to retrieve catalogs",
          details: result.stderr.presence || result.stdout
        }
      end
    end

    def rebuild_catalogs
      script = local_mode? ? local_rebuild_script : container_rebuild_script
      result = local_mode? ? command_runner.run("/bin/sh", "-lc", script, timeout: 300) : docker_exec("/bin/sh", "-lc", script, timeout: 300)
      output = preferred_output(result)

      if result.timed_out?
        {
          success: false,
          timed_out: true,
          message: "Catalog rebuild timed out (exceeded 5 minutes)",
          error: "Operation took too long"
        }
      elsif result.success?
        {
          success: true,
          message: "Catalogs rebuilt successfully",
          output:
        }
      else
        {
          success: false,
          message: "Catalog rebuild failed",
          output:,
          error: result.stderr.presence || output
        }
      end
    end

    def import_zip(filename)
      zip_path = local_mode? ? config.hololib_zip_path.join(filename).to_s : File.join(config.hololib_zip_path_in_container, filename)
      result = rcc_exec("holotree", "import", zip_path, timeout: 120)
      output = preferred_output(result)

      if result.timed_out?
        {
          success: false,
          timed_out: true,
          error: "Import operation exceeded 2 minutes"
        }
      elsif result.success?
        {
          success: true,
          output:
        }
      else
        {
          success: false,
          error: output.presence || result.stderr.presence || "Import failed"
        }
      end
    end

    private

    attr_reader :config, :command_runner

    def rcc_exec(*args, timeout:)
      if local_mode?
        command_runner.run(config.rcc_binary, *args, timeout:)
      else
        docker_exec("rcc", *args, timeout:)
      end
    end

    def local_mode?
      config.rcc_execution_mode == "local"
    end

    def docker_exec(*args, timeout:)
      container = config.rcc_container_name.to_s.strip
      if container.empty?
        return unavailable_result("RCC container is not configured. Set RCC_CONTAINER_NAME or use RCC_EXECUTION_MODE=local.")
      end

      result = command_runner.run("docker", "exec", container, *args, timeout:)
      if result.stderr.to_s.include?("No such container")
        return unavailable_result("RCC container '#{container}' not found. Use RCC_EXECUTION_MODE=local for Kamal Rails app runtime, or run the RCC container.")
      end

      result
    end

    def preferred_output(result)
      result.stderr.presence || result.stdout.to_s
    end

    def parse_catalogs(output)
      output.to_s.each_line.map(&:strip).reject do |line|
        line.blank? || CATALOG_PREFIX_EXCLUSIONS.any? { |prefix| line.start_with?(prefix) }
      end
    end

    def container_rebuild_script
      robots_path = Shellwords.escape(config.robots_path_in_container)
      internal_zip_path = Shellwords.escape(config.hololib_zip_internal_path)
      build_rebuild_script(robots_path:, zip_path: internal_zip_path)
    end

    def local_rebuild_script
      robots_path = Shellwords.escape(config.robots_path.to_s)
      zip_path = Shellwords.escape(config.hololib_zip_path.to_s)
      build_rebuild_script(robots_path:, zip_path:)
    end

    def build_rebuild_script(robots_path:, zip_path:)
      <<~SH
        HOLOLIB_ZIP_PATH_INT=#{zip_path}
        ROBOTS_PATH=#{robots_path}

        echo "=== Rebuilding catalogs from robot definitions ==="
        mkdir -p "$HOLOLIB_ZIP_PATH_INT"

        find "$ROBOTS_PATH" -type f -name "robot.yaml" | while read -r robot_yaml; do
          robot=$(dirname "$robot_yaml")
          robot_name=$(basename "$robot")
          echo "Processing robot: $robot_name"

          if [ -f "$robot/conda.yaml" ]; then
            if [ -f "$robot/.env" ]; then
              saved_env=$(mktemp)
              export -p >"$saved_env"
              set -a
              . "$robot/.env"
              set +a
            fi

            rcc ht vars -r "$robot_yaml"
            rcc ht export -r "$robot_yaml" -z "$HOLOLIB_ZIP_PATH_INT/$robot_name.zip"
            rcc holotree import "$HOLOLIB_ZIP_PATH_INT/$robot_name.zip"

            if [ -f "$saved_env" ]; then
              unset ROBOCORP_HOME
              . "$saved_env" && rm "$saved_env"
            fi

            echo "✓ Catalog built for $robot_name"
          else
            echo "✗ Skipping $robot_name: conda.yaml not found"
          fi
        done

        echo "=== Catalog rebuild complete ==="
        rcc ht catalogs
      SH
    end

    def unavailable_result(message)
      CommandRunner::Result.new(
        success: false,
        stdout: "",
        stderr: message,
        exit_code: -1,
        timed_out: false
      )
    end
  end
end

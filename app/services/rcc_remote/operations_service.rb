# frozen_string_literal: true

require "json"
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
      catalogs_json_result = rcc_exec("holotree", "catalogs", "--json", timeout: 10)
      spaces_json_result = rcc_exec("holotree", "list", "--json", timeout: 10)
      config_json_result = rcc_exec("config", "settings", "--json", timeout: 10)

      catalog_details = catalogs_json_result.success? ? parse_catalog_details(preferred_output(catalogs_json_result)) : []
      space_details = spaces_json_result.success? ? parse_space_details(preferred_output(spaces_json_result)) : []
      config_details = config_json_result.success? ? parse_config_details(preferred_output(config_json_result)) : {}
      most_used_space = space_details.max_by { |space| space[:use_count].to_i }
      catalog_count = if catalog_details.any?
        catalog_details.length
      else
        fetch_catalog_count_fallback
      end
      space_count = if space_details.any?
        space_details.length
      else
        fetch_space_count_fallback
      end

      {
        version: version_result.success? ? preferred_output(version_result).strip.presence || "unknown" : "unknown",
        available: version_result.success?,
        catalog_count: catalog_count,
        catalog_total_bytes: catalog_details.sum { |catalog| catalog[:bytes].to_i },
        newest_catalog_age_days: catalog_details.map { |catalog| catalog[:age_in_days] }.compact.min,
        space_count: space_count,
        active_blueprints: space_details.map { |space| space[:blueprint] }.compact.uniq.length,
        most_used_space:,
        settings_profile: config_details[:profile_name],
        settings_version: config_details[:profile_version],
        ssl_verify: config_details[:ssl_verify],
        diagnostics_hosts_count: config_details.fetch(:diagnostics_hosts_count, 0),
        rcc_index_url: config_details[:rcc_index_url]
      }
    end

    def fetch_catalogs
      json_result = rcc_exec("holotree", "catalogs", "--json", timeout: 10)
      if json_result.success?
        json_output = preferred_output(json_result)
        json_payload = parse_json_payload(json_output)

        if json_payload.is_a?(Hash)
          catalogs = parse_catalog_details(json_output)
          return {
            success: true,
            catalogs: catalogs.sort_by { |catalog| catalog[:blueprint].to_s },
            count: catalogs.length,
            source: "json",
            snapshot_at: Time.current.utc.iso8601
          }
        end
      end

      fallback_result = rcc_exec("holotree", "catalogs", timeout: 10)
      output = preferred_output(fallback_result)
      return {
        success: false,
        error: "Failed to retrieve catalogs",
        details: output
      } unless fallback_result.success?

      catalogs = parse_catalogs(output).map do |blueprint|
        {
          blueprint: blueprint,
          platform: nil,
          directories: nil,
          files: nil,
          bytes: nil,
          relocations: nil,
          age_in_days: nil,
          days_since_last_use: nil,
          identity_yaml: nil,
          holotree: nil
        }
      end

      {
        success: true,
        catalogs:,
        count: catalogs.length,
        source: "text",
        snapshot_at: Time.current.utc.iso8601
      }
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
      stdout = result.stdout.to_s
      stderr = result.stderr.to_s

      if result.success?
        stdout.presence || stderr
      else
        stderr.presence || stdout
      end
    end

    def parse_catalogs(output)
      output.to_s.each_line.filter_map do |line|
        stripped = line.strip
        next if stripped.blank?
        next if CATALOG_PREFIX_EXCLUSIONS.any? { |prefix| stripped.start_with?(prefix) }

        stripped.split(/\s+/).find { |token| token.match?(/\A[0-9a-f]{16,}\z/i) }
      end.uniq
    end

    def parse_catalog_details(output)
      payload = parse_json_payload(output)
      return [] unless payload.is_a?(Hash)

      payload.filter_map do |blueprint_key, row|
        next unless row.is_a?(Hash)

        blueprint = row["blueprint"].to_s.presence || blueprint_key.to_s
        next if blueprint.blank?

        {
          blueprint:,
          platform: row["platform"].to_s.presence,
          directories: integer_or_nil(row["directories"]),
          files: integer_or_nil(row["files"]),
          bytes: row["bytes"].to_i,
          relocations: integer_or_nil(row["relocations"]),
          age_in_days: integer_or_nil(row["age_in_days"]),
          days_since_last_use: integer_or_nil(row["days_since_last_use"]),
          identity_yaml: row["identity.yaml"].to_s.presence,
          holotree: row["holotree"].to_s.presence
        }
      end
    end

    def parse_space_details(output)
      payload = parse_json_payload(output)
      return [] unless payload.is_a?(Hash)

      payload.values.filter_map do |row|
        id = row["id"].to_s
        next if id.blank?

        {
          id:,
          blueprint: row["blueprint"].to_s.presence,
          last_used: row["last-used"].to_s.presence,
          idle_days: integer_or_nil(row["idle-days"]),
          use_count: parse_use_count(row["use-count"])
        }
      end
    end

    def parse_json_payload(output)
      text = output.to_s
      start_index = text.index("{")
      end_index = text.rindex("}")
      return nil unless start_index && end_index && end_index >= start_index

      JSON.parse(text[start_index..end_index])
    rescue JSON::ParserError
      nil
    end

    def parse_use_count(value)
      match = value.to_s.match(/\d+/)
      match ? match[0].to_i : 0
    end

    def parse_config_details(output)
      payload = parse_json_payload(output)
      return {} unless payload.is_a?(Hash)

      meta = payload["meta"].is_a?(Hash) ? payload["meta"] : {}
      certificates = payload["certificates"].is_a?(Hash) ? payload["certificates"] : {}
      autoupdates = payload["autoupdates"].is_a?(Hash) ? payload["autoupdates"] : {}

      {
        profile_name: meta["name"].to_s.presence,
        profile_version: meta["version"].to_s.presence,
        ssl_verify: certificates["verify-ssl"],
        diagnostics_hosts_count: Array(payload["diagnostics-hosts"]).length,
        rcc_index_url: autoupdates["rcc-index"].to_s.presence
      }
    end

    def integer_or_nil(value)
      Integer(value)
    rescue ArgumentError, TypeError
      nil
    end

    def fetch_catalog_count_fallback
      result = rcc_exec("holotree", "catalogs", timeout: 10)
      return 0 unless result.success?

      parse_catalogs(preferred_output(result)).length
    end

    def fetch_space_count_fallback
      result = rcc_exec("holotree", "list", timeout: 10)
      return 0 unless result.success?

      preferred_output(result).to_s.each_line.count do |line|
        stripped = line.strip
        next false if stripped.blank?
        next false if stripped.start_with?("Identity", "--------")

        true
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

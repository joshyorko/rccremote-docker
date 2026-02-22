# frozen_string_literal: true

require "socket"

module RccRemote
  class StatusService
    def initialize(config: Configuration.new, storage: nil, operations: nil)
      @config = config
      @storage = storage || StorageService.new(config:)
      @operations = operations || OperationsService.new(config:)
    end

    def health_payload
      {
        status: "healthy",
        timestamp: Time.current.utc.iso8601,
        service: "rcc-remote-dashboard"
      }
    end

    def status_payload
      rcc = operations.rcc_info

      {
        timestamp: Time.current.utc.iso8601,
        services: {
          rccremote: rcc_service_payload(rcc)
        },
        rcc: {
          version: rcc[:version],
          available: rcc[:available],
          catalog_total_bytes: rcc[:catalog_total_bytes],
          newest_catalog_age_days: rcc[:newest_catalog_age_days],
          most_used_space: rcc[:most_used_space],
          settings_profile: rcc[:settings_profile],
          settings_version: rcc[:settings_version],
          ssl_verify: rcc[:ssl_verify],
          diagnostics_hosts_count: rcc[:diagnostics_hosts_count],
          rcc_index_url: rcc[:rcc_index_url]
        },
        statistics: {
          robots: storage.robot_count,
          catalogs: rcc[:catalog_count],
          hololib_zips: storage.zip_count,
          holotree_spaces: rcc[:space_count],
          active_blueprints: rcc[:active_blueprints]
        },
        paths: {
          robots: config.robots_path.to_s,
          hololib_zip: config.hololib_zip_path.to_s
        }
      }
    end

    private

    attr_reader :config, :storage, :operations

    def rcc_service_payload(rcc)
      if config.rcc_execution_mode == "local"
        {
          running: rcc[:available],
          mode: "local",
          command: config.rcc_binary
        }
      else
        {
          running: tcp_open?(config.rccremote_host, config.rccremote_port),
          host: config.rccremote_host,
          port: config.rccremote_port.to_s,
          mode: "docker_exec",
          container: config.rcc_container_name
        }
      end
    end

    def tcp_open?(host, port)
      Socket.tcp(host, port, connect_timeout: 2) { |socket| socket.close }
      true
    rescue StandardError
      false
    end
  end
end

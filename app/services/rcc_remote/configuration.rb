# frozen_string_literal: true

module RccRemote
  class Configuration
    ALLOWED_EXTENSIONS = %w[yaml yml zip txt py robot env].freeze

    DEFAULT_ROBOT_YAML = <<~YAML.freeze
      # Robot configuration
      tasks:
        Default:
          shell: python -m robot --report NONE --outputdir output --logtitle "Task log" tasks.robot

      environmentConfigs:
        - conda.yaml

      artifactsDir: output

      PATH:
        - .
      PYTHONPATH:
        - .
    YAML

    DEFAULT_CONDA_YAML = <<~YAML.freeze
      channels:
        - conda-forge

      dependencies:
        - python>=3.12
        - pip:
          - robotframework==7.3.2
    YAML

    def robots_path
      Pathname.new(ENV.fetch("ROBOTS_PATH", Rails.root.join("data/robots").to_s))
    end

    def hololib_zip_path
      Pathname.new(ENV.fetch("HOLOLIB_ZIP_PATH", Rails.root.join("data/hololib_zip").to_s))
    end

    def rccremote_host
      ENV.fetch("RCCREMOTE_HOST", "rccremote")
    end

    def rccremote_port
      Integer(ENV.fetch("RCCREMOTE_PORT", "4653"))
    rescue ArgumentError
      4653
    end

    def rcc_remote_origin
      ENV.fetch("RCC_REMOTE_ORIGIN", "").to_s
    end

    def rcc_container_name
      ENV.fetch("RCC_CONTAINER_NAME", "rccremote-dev")
    end

    def rcc_execution_mode
      ENV.fetch("RCC_EXECUTION_MODE", "local")
    end

    def rcc_binary
      ENV.fetch("RCC_BINARY", "rcc")
    end

    def hololib_zip_path_in_container
      ENV.fetch("HOLOLIB_ZIP_PATH_IN_CONTAINER", "/hololib_zip")
    end

    def robots_path_in_container
      ENV.fetch("ROBOTS_PATH_IN_CONTAINER", "/robots")
    end

    def hololib_zip_internal_path
      ENV.fetch("HOLOLIB_ZIP_INTERNAL_PATH", "/hololib_zip_internal")
    end
  end
end

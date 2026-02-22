# frozen_string_literal: true

require "fileutils"
require "time"

module RccRemote
  class StorageService
    def initialize(config: Configuration.new)
      @config = config
      ensure_directory(config.robots_path)
      ensure_directory(config.hololib_zip_path)
    end

    def list_robots
      robot_directories.map { |robot_path| robot_summary(robot_path) }
    end

    def robot_count
      robot_directories.count { |robot_path| robot_path.join("robot.yaml").file? }
    end

    def find_robot(robot_name)
      robot_path = robot_path_for(robot_name)
      return nil unless robot_path&.directory?

      robot_details(robot_path)
    end

    def read_robot_file(robot_name, filename)
      robot_path = robot_path_for(robot_name)
      return { error: "Robot not found", status: :missing_robot } unless robot_path&.directory?

      safe_filename = sanitize_name(filename.to_s.tr("/", "_"))
      return { error: "File not found", status: :missing_file } if safe_filename.blank?

      file_path = robot_path.join(safe_filename)
      return { error: "File not found", status: :missing_file } unless file_path.file?

      { filename: safe_filename, content: file_path.read }
    rescue StandardError => e
      { error: e.message, status: :error }
    end

    def create_robot(robot_name)
      safe_name = sanitize_name(robot_name)
      return { status: :invalid, error: "Robot name is required" } if safe_name.blank?

      robot_path = config.robots_path.join(safe_name)
      return { status: :conflict, error: "Robot already exists" } if robot_path.exist?

      FileUtils.mkdir_p(robot_path)
      robot_path.join("robot.yaml").write(Configuration::DEFAULT_ROBOT_YAML)
      robot_path.join("conda.yaml").write(Configuration::DEFAULT_CONDA_YAML)

      { status: :created, name: safe_name, path: robot_path.to_s }
    rescue StandardError => e
      { status: :error, error: e.message }
    end

    def delete_robot(robot_name)
      robot_path = robot_path_for(robot_name)
      return { status: :missing, error: "Robot not found" } unless robot_path&.directory?

      FileUtils.rm_rf(robot_path)
      { status: :deleted, name: robot_path.basename.to_s }
    rescue StandardError => e
      { status: :error, error: e.message }
    end

    def upload_robot_files(robot_name, files)
      robot_path = robot_path_for(robot_name, create: true)

      uploaded = []
      errors = []

      Array(files).each do |upload|
        next unless upload.respond_to?(:original_filename)

        filename = sanitize_name(upload.original_filename.to_s)

        if filename.blank?
          errors << "Invalid filename"
          next
        end

        unless allowed_file?(filename)
          errors << "#{filename}: File type not allowed"
          next
        end

        begin
          payload = upload.read
          robot_path.join(filename).binwrite(payload)
          uploaded << filename
        rescue StandardError => e
          errors << "#{filename}: #{e.message}"
        ensure
          upload.rewind if upload.respond_to?(:rewind)
        end
      end

      {
        message: "Uploaded #{uploaded.length} file(s)",
        uploaded:,
        errors:
      }
    end

    def update_robot_core_files(robot_name, robot_yaml:, conda_yaml:)
      robot_path = robot_path_for(robot_name)
      return { status: :missing, error: "Robot not found" } unless robot_path&.directory?

      robot_yaml_content = robot_yaml.to_s
      conda_yaml_content = conda_yaml.to_s

      if robot_yaml_content.blank? || conda_yaml_content.blank?
        return { status: :invalid, error: "robot.yaml and conda.yaml are required" }
      end

      robot_path.join("robot.yaml").write(robot_yaml_content)
      robot_path.join("conda.yaml").write(conda_yaml_content)

      { status: :updated, name: robot_path.basename.to_s }
    rescue StandardError => e
      { status: :error, error: e.message }
    end

    def list_hololib_zips
      ensure_directory(config.hololib_zip_path)

      config.hololib_zip_path.glob("*.zip").sort.map do |zip_file|
        stat = zip_file.stat

        {
          name: zip_file.basename.to_s,
          size: stat.size,
          size_mb: (stat.size / (1024.0 * 1024)).round(2),
          modified: stat.mtime.iso8601
        }
      end
    end

    def zip_count
      ensure_directory(config.hololib_zip_path)
      config.hololib_zip_path.glob("*.zip").count
    end

    def save_zip(upload)
      return { status: :invalid, error: "No file provided" } unless upload&.respond_to?(:original_filename)

      filename = sanitize_name(upload.original_filename.to_s)
      return { status: :invalid, error: "No file selected" } if filename.blank?
      return { status: :invalid, error: "Only ZIP files are allowed" } unless filename.downcase.end_with?(".zip")

      zip_path = config.hololib_zip_path.join(filename)
      zip_path.binwrite(upload.read)
      upload.rewind if upload.respond_to?(:rewind)

      { status: :saved, filename:, path: zip_path.to_s }
    rescue StandardError => e
      { status: :error, error: e.message }
    end

    def delete_zip(filename)
      safe_filename = sanitize_name(filename)
      return { status: :missing, error: "File not found" } if safe_filename.blank?

      zip_path = config.hololib_zip_path.join(safe_filename)
      return { status: :missing, error: "File not found" } unless zip_path.file?

      zip_path.delete
      { status: :deleted, filename: safe_filename }
    rescue StandardError => e
      { status: :error, error: e.message }
    end

    private

    attr_reader :config

    def robot_directories
      ensure_directory(config.robots_path)
      config.robots_path.children.select(&:directory?).sort_by { |path| path.basename.to_s }
    end

    def robot_path_for(robot_name, create: false)
      safe_name = sanitize_name(robot_name)
      return nil if safe_name.blank?

      path = config.robots_path.join(safe_name)
      FileUtils.mkdir_p(path) if create
      path
    end

    def robot_summary(robot_path)
      robot_yaml = robot_path.join("robot.yaml")
      conda_yaml = robot_path.join("conda.yaml")
      env_file = robot_path.join(".env")

      {
        name: robot_path.basename.to_s,
        path: robot_path.to_s,
        has_robot_yaml: robot_yaml.file?,
        has_conda_yaml: conda_yaml.file?,
        has_env_file: env_file.file?,
        robocorp_home: parse_robocorp_home(env_file),
        dependencies_count: count_dependencies(conda_yaml),
        is_valid: robot_yaml.file? && conda_yaml.file?
      }
    end

    def robot_details(robot_path)
      files = {}

      [ "robot.yaml", "conda.yaml", ".env" ].each do |file_name|
        file_path = robot_path.join(file_name)
        next unless file_path.file?

        files[file_name] = file_path.read
      rescue StandardError => e
        files[file_name] = "Error reading file: #{e.message}"
      end

      all_files = robot_path.glob("**/*").select(&:file?).map do |file_path|
        file_path.relative_path_from(robot_path).to_s
      end.sort

      {
        name: robot_path.basename.to_s,
        path: robot_path.to_s,
        files:,
        all_files:
      }
    end

    def parse_robocorp_home(env_file)
      return nil unless env_file.file?

      env_file.each_line do |line|
        next unless line.start_with?("ROBOCORP_HOME=")

        return line.split("=", 2).last.to_s.strip
      end

      nil
    end

    def count_dependencies(conda_yaml)
      return 0 unless conda_yaml.file?

      conda_yaml.each_line.count do |line|
        stripped = line.strip
        stripped.start_with?("-") && !stripped.start_with?("#")
      end
    end

    def allowed_file?(filename)
      extension = File.extname(filename).delete_prefix(".").downcase
      Configuration::ALLOWED_EXTENSIONS.include?(extension)
    end

    def sanitize_name(value)
      value.to_s.strip.gsub(/[^A-Za-z0-9._-]/, "_").gsub(/\A[._]+/, "")
    end

    def ensure_directory(path)
      FileUtils.mkdir_p(path)
    end
  end
end

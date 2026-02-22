# frozen_string_literal: true

class Robot
  include ActiveModel::Model
  include ActiveModel::Attributes

  attribute :name, :string
  attribute :path, :string
  attribute :has_robot_yaml, :boolean, default: false
  attribute :has_conda_yaml, :boolean, default: false
  attribute :has_env_file, :boolean, default: false
  attribute :robocorp_home, :string
  attribute :dependencies_count, :integer, default: 0
  attribute :is_valid, :boolean, default: false

  attr_accessor :files, :all_files

  validates :name, presence: true

  def initialize(attributes = {})
    super
    self.files ||= {}
    self.all_files ||= []
  end

  def valid_robot?
    is_valid
  end

  class << self
    def all(storage: default_storage)
      storage.list_robots.map { |attributes| build(attributes) }
    end

    def find(name, storage: default_storage)
      attributes = storage.find_robot(name)
      attributes ? build(attributes) : nil
    end

    def create_with_defaults(name, storage: default_storage)
      storage.create_robot(name)
    end

    def remove(name, storage: default_storage)
      storage.delete_robot(name)
    end

    def upload_files(name, files, storage: default_storage)
      storage.upload_robot_files(name, files)
    end

    private

    def build(attributes)
      robot = new(attributes.except(:files, :all_files))
      robot.files = attributes[:files] || {}
      robot.all_files = attributes[:all_files] || []
      robot
    end

    def default_storage
      RccRemote::StorageService.new
    end
  end
end

# frozen_string_literal: true

class Catalog
  include ActiveModel::Model

  attr_accessor :raw_line

  validates :raw_line, presence: true

  def catalog_id
    parts = raw_line.to_s.split(/\s+/)
    parts.find { |token| token.match?(/\A[a-f0-9]{16,}\z/) } || raw_line.to_s.first(16)
  end

  def robot_name
    raw_line.to_s.split(/\s+/).first || "unknown"
  end

  def components
    [ "Python Environment", "Conda Dependencies", "RCC Runtime" ]
  end

  class << self
    def fetch(operations: default_operations)
      result = operations.fetch_catalogs
      catalogs = result[:success] ? result[:catalogs].map { |line| new(raw_line: line) } : []
      [ catalogs, result ]
    end

    def rebuild(operations: default_operations)
      operations.rebuild_catalogs
    end

    private

    def default_operations
      RccRemote::OperationsService.new
    end
  end
end

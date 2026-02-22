# frozen_string_literal: true

class Catalog
  include ActiveModel::Model

  attr_accessor :blueprint, :platform, :directories, :files, :bytes,
                :relocations, :age_in_days, :days_since_last_use,
                :identity_yaml, :holotree

  def identity_key
    return nil if identity_yaml.blank?

    identity_yaml.to_s.split("/").last
  end

  def stale?
    return false if days_since_last_use.nil?

    days_since_last_use.to_i >= 30
  end

  def active?
    !stale?
  end

  def status
    return :unknown if days_since_last_use.nil?

    stale? ? :stale : :active
  end

  class << self
    def fetch(operations: default_operations)
      result = operations.fetch_catalogs
      catalogs = result[:success] ? result[:catalogs].map { |attributes| new(attributes) } : []
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

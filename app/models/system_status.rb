# frozen_string_literal: true

class SystemStatus
  include ActiveModel::Model

  attr_accessor :payload

  class << self
    def current(status_service: default_status_service)
      new(payload: status_service.status_payload)
    end

    def health(status_service: default_status_service)
      status_service.health_payload
    end

    private

    def default_status_service
      RccRemote::StatusService.new
    end
  end

  def services
    payload.fetch(:services, {})
  end

  def statistics
    payload.fetch(:statistics, {})
  end

  def rcc
    payload.fetch(:rcc, {})
  end

  def paths
    payload.fetch(:paths, {})
  end

  def timestamp
    payload[:timestamp]
  end
end

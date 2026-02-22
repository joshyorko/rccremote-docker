class Api::HealthController < ApplicationController
  def show
    render json: SystemStatus.health
  end
end

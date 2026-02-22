class Api::StatusController < ApplicationController
  def show
    render json: SystemStatus.current.payload
  end
end

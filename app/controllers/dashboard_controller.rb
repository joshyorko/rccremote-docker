class DashboardController < ApplicationController
  def index
    @status = SystemStatus.current
  end
end

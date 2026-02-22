class RobotsController < ApplicationController
  before_action :set_robot, only: :show

  def index
    @robots = Robot.all
  end

  def show
    return if @robot

    redirect_to robots_path, alert: "Robot not found"
  end

  def create
    result = Robot.create_with_defaults(params[:name])

    case result[:status]
    when :created
      redirect_to robot_path(result[:name]), notice: "Robot created successfully"
    when :conflict
      redirect_to robots_path, alert: result[:error]
    else
      redirect_to robots_path, alert: result[:error] || "Failed to create robot"
    end
  end

  def destroy
    result = Robot.remove(params[:id])

    case result[:status]
    when :deleted
      redirect_to robots_path, notice: "Robot deleted successfully"
    when :missing
      redirect_to robots_path, alert: "Robot not found"
    else
      redirect_to robots_path, alert: result[:error] || "Failed to delete robot"
    end
  end

  def upload
    uploaded_files = Array(params[:files]).compact
    if uploaded_files.empty?
      redirect_to robot_path(params[:id]), alert: "No files provided"
      return
    end

    result = Robot.upload_files(params[:id], uploaded_files)
    if result[:uploaded].any?
      notice = result[:message]
      notice += " (#{result[:errors].length} skipped)" if result[:errors].any?
      flash[:notice] = notice
    end
    flash[:alert] = result[:errors].first(3).join("; ") if result[:errors].any?

    redirect_to robot_path(params[:id])
  end

  private

  def set_robot
    @robot = Robot.find(params[:id])
  end
end

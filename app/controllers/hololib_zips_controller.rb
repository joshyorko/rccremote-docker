class HololibZipsController < ApplicationController
  def index
    @zips = HololibZip.all
  end

  def create
    result = HololibZip.upload(params[:file])

    case result[:status]
    when :invalid
      redirect_to hololib_zips_path, alert: result[:error]
      return
    when :error
      redirect_to hololib_zips_path, alert: result[:error] || "Failed to upload ZIP file"
      return
    end

    import_result = result[:import]

    if import_result[:success]
      redirect_to hololib_zips_path, notice: "ZIP uploaded and imported successfully"
      return
    end

    if import_result[:timed_out]
      redirect_to hololib_zips_path, alert: "ZIP uploaded but import timed out"
      return
    end

    redirect_to hololib_zips_path, alert: "ZIP uploaded but import failed: #{import_result[:error]}"
  end

  def destroy
    result = HololibZip.remove(params[:filename])

    case result[:status]
    when :deleted
      redirect_to hololib_zips_path, notice: "ZIP file deleted successfully"
    else
      redirect_to hololib_zips_path, alert: result[:error] || "Failed to delete ZIP file"
    end
  end
end

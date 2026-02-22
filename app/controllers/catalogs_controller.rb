class CatalogsController < ApplicationController
  def index
    @catalogs, result = Catalog.fetch
    @catalog_snapshot_source = result[:source].presence || "json"
    @catalog_snapshot_at = result[:snapshot_at]

    unless result[:success]
      @catalog_error = result[:details].presence || result[:error]
    end
  end

  def rebuild
    result = Catalog.rebuild

    respond_to do |format|
      format.html do
        if result[:success]
          redirect_to catalogs_path, notice: "Catalog rebuild completed successfully"
          return
        end

        message = result[:message].presence || "Catalog rebuild failed"
        details = result[:error].presence || result[:output].to_s
        redirect_to catalogs_path, alert: [ message, details ].compact.join(": ")
      end

      format.json do
        if result[:success]
          render json: {
            success: true,
            message: result[:message].presence || "Catalog rebuild completed successfully",
            output: result[:output].to_s
          }
          return
        end

        render json: {
          success: false,
          message: result[:message].presence || "Catalog rebuild failed",
          error: result[:error].presence || result[:output].to_s,
          output: result[:output].to_s
        }, status: :unprocessable_entity
      end
    end
  end
end

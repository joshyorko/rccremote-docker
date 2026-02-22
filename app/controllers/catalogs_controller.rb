class CatalogsController < ApplicationController
  def index
    @catalogs, result = Catalog.fetch

    if result[:success]
      @raw_output = result[:raw_output]
    else
      @raw_output = ""
      @catalog_error = result[:details].presence || result[:error]
    end
  end

  def rebuild
    result = Catalog.rebuild

    if result[:success]
      redirect_to catalogs_path, notice: "Catalog rebuild completed successfully"
      return
    end

    message = result[:message].presence || "Catalog rebuild failed"
    details = result[:error].presence || result[:output].to_s
    redirect_to catalogs_path, alert: [ message, details ].compact.join(": ")
  end
end

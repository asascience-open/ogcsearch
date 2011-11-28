require 'open-uri'

class ExtractController < ApplicationController

  before_filter :normalize_url, :only => [:index]

  def index
    file = open(@fixed_url)
    r = file.read
    wms_hrefs = WmsServer.extract(@fixed_url, r).uniq
    kml_hrefs = Kmx.extract(@fixed_url, r).uniq

    respond_to do |format|
      format.json { render :json => 
        {:wms => wms_hrefs, :kml => kml_hrefs}
      }
    end

  end

end
require 'open-uri'

class ExtractController < ApplicationController

  before_filter :normalize_url, :only => [:index]

  def index
    file = open(@fixed_url)
    r = file.read
    doc = Nokogiri::HTML(r)

    wms_hrefs = WmsServer.extract(@fixed_url,r,doc)
    kmx_hrefs = Kmx.extract(@fixed_url,r,doc)

    respond_to do |format|
      format.json { render :json => 
        {:wms => wms_hrefs, :kmx => kmx_hrefs}
      }
    end
  end

end
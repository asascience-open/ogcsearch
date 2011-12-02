require 'open-uri'

class ExtractController < ApplicationController

  before_filter :normalize_url, :only => [:index]

  def index

    wms_hrefs = []
    kmx_hrefs = []
    direct = false

    if @fixed_url =~ GETCAP_REGEX && @fixed_url =~ WMS_SERVICE_REGEX
      wms_hrefs << @fixed_url
      direct = true
    elsif @fixed_url =~ KMX_LINK_REGEX
      kmx_hrefs << @fixed_url
      direct = true if @fixed_url =~ KMZ_LINK_REGEX
    end

    unless direct
      file = open(@fixed_url)
      r = file.read
      doc = Nokogiri::HTML(r)
      wms_hrefs += WmsServer.extract(@fixed_url,r,doc)
      kmx_hrefs += Kmx.extract(@fixed_url,r,doc)
    end

    respond_to do |format|
      format.json { render :json => 
        {:wms => wms_hrefs, :kmx => kmx_hrefs}
      }
    end
  end

end
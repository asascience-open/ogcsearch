class WmsController < ApplicationController

  before_filter :normalize_url, :only => [:find, :parse, :status]

  def find
    server = WmsServer.where(url: @fixed_url).first
    server = [nil] if server.nil?
    respond_to do |format|
      format.json { render :json => server }
      format.xml { render :xml => server }
    end
  end

  def parse
    server = WmsServer.find_or_create_by(url: @fixed_url)
    if server.locked?
      render :text => "ALREADY PROCESSING", :status => 202
    else
      server.parse
      render :text => "OK", :status => 202
    end
  end

  def status
    server = WmsServer.where(url: @fixed_url).first
    if server.locked?
      render :text => "LOCKED", :status => 202
    else
      render :text => "OK", :status => 202
    end
  end

  def search
    layers = WmsLayer.fulltext_search(params[:terms])
    respond_to do |format|
      format.json { render :json => layers.as_json(
        :only => ["_id", :name, :title, :abstract, :queryable, :thumbnail, :bbox],
        :methods => [:likes_json, :wms_styles_json],
        :include => {:wms_server =>
                      { :only => [:name, :url, :map_formats, :exceptions],
                        :methods => [:likes_json, :web_mapping_projections]
                      }
                    }
                  )}
    end
  end

  private
    def normalize_url
      @fixed_url = WmsServer.normalize_url(params[:url])
      if @fixed_url.blank? || @fixed_url.nil?
        render :text => "Invalid URL parameter"
      end
    end

end

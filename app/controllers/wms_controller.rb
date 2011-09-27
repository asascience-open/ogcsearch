class WmsController < ApplicationController

  before_filter :normalize_url, :only => [:find, :parse, :status]

  def index
    @servers = WmsServer.all
    respond_to do |format|
      format.dataTable {
        render :json => { :aaData => @servers.as_json(
          :only => [:name, :title, :url, :keywords, :tags, :scanned],
          :methods => [:web_mapping_projections]
        )}
      }
      format.html
    end
  end

  def find
    server = WmsServer.where(url: @fixed_url).first
    server = [nil] if server.nil?
    respond_to do |format|
      format.json { render :json => server.as_json(
        :only => [:name, :url, :map_formats, :exceptions],
        :methods => [:likes_json, :web_mapping_projections],
        :include => {:wms_layers =>
                      {
                        :only => ["_id", :name, :title, :abstract, :queryable, :thumbnail, :bbox],
                        :methods => [:likes_json, :wms_styles_json]
                      }
                    }
                  )}
    end
  end

  def parse
    server = WmsServer.find_or_create_by(url: @fixed_url)
    if server.locked?
      render :text => "ALREADY PROCESSING", :status => 202
    else
      server.tags << params[:terms] unless params[:terms].nil?
      server.save
      server.parse
      render :text => "OK", :status => 202
    end
  end

  def status
    server = WmsServer.where(url: @fixed_url).first
    if server.nil?
      render :text => "SERVER UNKNOWN", :status => 202
    elsif server.locked?
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

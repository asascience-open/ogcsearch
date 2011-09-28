class WmsController < ApplicationController

  before_filter :normalize_url, :only => [:find, :parse, :status]

  def find
    server = WmsServer.where(url: @fixed_url).first
    server = [nil] if server.nil?
    respond_to do |format|
      format.json { render :json => server.as_json(
        :only => [:name, :url, :map_formats, :exceptions],
        :methods => [:likes_json],
        :include => {:wms_layers =>
                      {
                        :only => ["_id", :name, :title, :abstract, :queryable, :thumbnail, :bbox],
                        :methods => [:likes_json, :wms_styles_json, :web_mapping_projections]
                      }
                    }
                  )}
    end
  end

  def parse
    server = WmsServer.find_or_create_by(url: @fixed_url)
    server.tags << params[:terms] unless params[:terms].nil?
    server.save
    if server.locked?
      render :text => "ALREADY PROCESSING", :status => 202
    else
      server.parse if (params[:force] || server.scanned.nil? || server.scanned < 1.day.ago)
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
    # Paginate an array
    params[:page] ||= 1
    layers = Kaminari.paginate_array(layers).page(params[:page]).per(SEARCH_PER_PAGE)
    respond_to do |format|
      format.json { render :json => {
          :records => layers.total_count,
          :pages => layers.num_pages,
          :page => layers.current_page,
          :data => layers.as_json(
            :only => ["_id", :name, :title, :abstract, :queryable, :thumbnail, :bbox],
            :methods => [:likes_json, :wms_styles_json, :web_mapping_projections],
            :include => {:wms_server =>
                          { :only => [:name, :url, :map_formats, :exceptions],
                            :methods => [:likes_json]
                          }
                        }
          )}
        }
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

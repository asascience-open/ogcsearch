class WmsController < ApplicationController

  before_filter :normalize_url, :only => [:find, :parse, :status]

  def index
  end

  def populate
    columns = params[:sColumns].split(",")
    sort_direction = params[:sSortDir_0]
    sort_column = columns[params[:iSortingCols].to_i]
    page_num = (params[:iDisplayStart].to_i / params[:iDisplayLength].to_i) + 1
    if params[:sSearch].blank?
      servers = WmsServer.order_by(sort_column, sort_direction).page(page_num.to_i).per(params[:iDisplayLength].to_i)
    else
      servers = WmsServer.fulltext_search(params[:sSearch]).sort do |x,y|
        if sort_direction == "asc"
          y[sort_column.to_sym] <=> x[sort_column.to_sym]
        else
          x[sort_column.to_sym] <=> y[sort_column.to_sym]
        end
      end
      servers = Kaminari.paginate_array(servers).page(page_num).per(params[:iDisplayLength].to_i)
    end

    respond_to do |format|
      format.dataTable {
        render :json => {
        :sEcho => params[:sEcho],
        :iTotalRecords => servers.total_count,
        :iTotalDisplayRecords => servers.total_count,
        :aaData => servers.as_json(
          :only => [:name, :title, :url, :keywords, :tags, :scanned]
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

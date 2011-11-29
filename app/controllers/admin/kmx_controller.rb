class Admin::KmxController < Admin::AdminController

  def index

  end

  def populate
    columns = params[:sColumns].split(",")
    sort_direction = params[:sSortDir_0]
    sort_column = columns[params[:iSortingCols].to_i]
    page_num = (params[:iDisplayStart].to_i / params[:iDisplayLength].to_i) + 1
    if params[:sSearch].blank?
      servers = Kmx.order_by(sort_column, sort_direction).page(page_num.to_i).per(params[:iDisplayLength].to_i)
    else
      servers = Kmx.fulltext_search(params[:sSearch]).sort do |x,y|
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
          :aaData => servers.as_json({
            :methods => [:DT_RowId],
            :only => [:name, :title, :url, :keywords, :tags, :scanned]
          })
        }
      }
      format.html
    end
  end

  def destroy
    status = Kmx.where(id: params[:id]).destroy ? 200 : 500
    respond_to do |format|
      format.html
      format.json  { render :json => {}, :status => status }
    end
  end

  def update

  end

end
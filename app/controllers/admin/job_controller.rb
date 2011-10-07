class Admin::JobController < Admin::AdminController
  def index
  end

  def populate
    columns = params[:sColumns].split(",")
    sort_direction = params[:sSortDir_0]
    sort_column = columns[params[:iSortingCols].to_i]
    page_num = (params[:iDisplayStart].to_i / params[:iDisplayLength].to_i) + 1
    servers = Job.order_by(sort_column, sort_direction).page(page_num.to_i).per(params[:iDisplayLength].to_i)

    respond_to do |format|
      format.dataTable {
        render :json => {
          :sEcho => params[:sEcho],
          :iTotalRecords => servers.total_count,
          :iTotalDisplayRecords => servers.total_count,
          :aaData => servers.as_json({
            :methods => [:DT_RowId],
            :only => [:job_type, :job_data, :attempts, :run_at]
          })
        }
      }
      format.html
    end
  end

  def destroy
    status = Job.where(id: params[:id]).destroy ? 200 : 500
    respond_to do |format|
      format.html
      format.json  { render :json => {:status => status}, :status => status }
    end
  end

end

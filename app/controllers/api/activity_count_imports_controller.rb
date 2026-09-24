module Api
  class ActivityCountImportsController < WeeklyMarkupImportsController
    def create
      record, status = ActivityCounts::Import.call(delivery_id: params[:delivery_id], report_json: params[:report_json])
      render json: {ok: true, id: record.id, delivery_id: record.delivery_id, status: status}, status: status == :created ? :created : :ok
    rescue ActivityCounts::Import::InvalidReport
      render json: {ok: false, error: 'invalid_report'}, status: :unprocessable_entity
    end
  end
end

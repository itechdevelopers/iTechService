module Api
  class IphoneSalesImportsController < WeeklyMarkupImportsController
    def create
      report = params[:report].respond_to?(:to_unsafe_h) ? params[:report].to_unsafe_h : nil
      record, status = IphoneSales::Import.call(delivery_id: params[:delivery_id], report: report)
      render json: {ok: true, id: record.id, status: status}, status: status == :created ? :created : :ok
    rescue IphoneSales::Import::InvalidReport
      render json: {ok: false, error: 'invalid_report'}, status: :unprocessable_entity
    end
  end
end

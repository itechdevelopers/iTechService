module Api
  class WeeklyMarkupImportsController < ActionController::Base
    protect_from_forgery with: :null_session
    before_action :authenticate_import!

    def create
      record, status = WeeklyMarkup::Import.call(delivery_id: params[:delivery_id], report: params[:report].to_unsafe_h)
      render json: {ok: true, id: record.id, status: status}, status: status == :created ? :created : :ok
    rescue WeeklyMarkup::Import::InvalidReport => e
      persist_failure(e.message)
      render json: {ok: false, error: 'invalid_report'}, status: :unprocessable_entity
    end

    private

    def authenticate_import!
      expected = ENV['WEEKLY_MARKUP_IMPORT_TOKEN'].presence || token_from_linked_file
      supplied = request.authorization.to_s.sub(/\ABearer\s+/, '')
      valid = expected.present? && supplied.bytesize == expected.bytesize &&
              ActiveSupport::SecurityUtils.secure_compare(supplied, expected)
      return head(:unauthorized) unless valid
    end

    def token_from_linked_file
      File.read(Rails.root.join('config/weekly_markup_import_token')).strip
    rescue Errno::ENOENT
      ''
    end

    def persist_failure(message)
      delivery_id = params[:delivery_id].to_s
      return unless delivery_id.match?(/\A[0-9a-f]{64}\z/) && !WeeklyMarkupImport.exists?(delivery_id: delivery_id)
      report = params[:report].respond_to?(:to_unsafe_h) ? params[:report].to_unsafe_h : {}
      period_from = Date.iso8601(report.dig('period', 'from').to_s) rescue Date.current
      period_to = Date.iso8601(report.dig('period', 'to').to_s) rescue period_from
      calculated_at = Time.iso8601(report['calculated_at'].to_s) rescue Time.current
      record = WeeklyMarkupImport.find_or_initialize_by(delivery_id: delivery_id)
      return if record.status == 'successful'
      record.update!(period_from: period_from, period_to: period_to, calculated_at: calculated_at,
                     methodology_version: report['methodology_version'].presence || 'unknown', status: 'failed',
                     payload: {}, error_message: message.to_s.first(500))
    rescue ActiveRecord::RecordNotUnique, ActiveRecord::RecordInvalid
      nil
    end
  end
end

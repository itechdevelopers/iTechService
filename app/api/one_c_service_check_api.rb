require_relative 'concerns/body_parser'

class OneCServiceCheckApi < Grape::API
  version 'v1', using: :path
  before { authenticate! }

  helpers BodyParser

  namespace 'one_c' do
    resource 'service_checks' do
      desc 'Register a paid service check coming back from 1C'
      post ':uid/paid', requirements: { uid: /[^\/]+/ } do
        authorize :update_from_one_c, ServiceJobCheckout

        unless current_user.api?
          error!({ error: 'This endpoint requires API role' }, 403)
        end

        checkout = ServiceJobCheckout.find_by(uid: params[:uid])
        if checkout.nil?
          error!({ error: "Service check with uid '#{params[:uid]}' not found" }, 404)
        end

        if checkout.cancelled?
          error!({ error: "Service check with uid '#{params[:uid]}' was recalled" }, 422)
        end

        body_params = parse_request_body
        Rails.logger.info "[ServiceCheck] Payment callback for #{checkout.uid}: #{body_params.inspect}"

        result = ServiceJobs::RegisterCheckPayment.call(checkout: checkout, attributes: body_params)

        # Grape по умолчанию отвечает на POST кодом 201; для колбэка «событие
        # принято» ждут 200, и повторная доставка не должна выглядеть созданием.
        status 200
        { status: 'ok', archived: result[:archived], reason: result[:reason] }.compact
      end

      desc 'Register a cancelled or returned service check coming back from 1C'
      post ':uid/cancelled', requirements: { uid: /[^\/]+/ } do
        authorize :update_from_one_c, ServiceJobCheckout

        unless current_user.api?
          error!({ error: 'This endpoint requires API role' }, 403)
        end

        checkout = ServiceJobCheckout.find_by(uid: params[:uid])
        if checkout.nil?
          error!({ error: "Service check with uid '#{params[:uid]}' not found" }, 404)
        end

        body_params = parse_request_body
        Rails.logger.info "[ServiceCheck] Cancellation callback for #{checkout.uid}: #{body_params.inspect}"

        result = ServiceJobs::RegisterCheckCancellation.call(checkout: checkout, attributes: body_params)

        status 200
        { status: 'ok', returned: result[:returned], reason: result[:reason] }.compact
      end
    end
  end
end

require_relative 'concerns/body_parser'

class OneCOrderApi < Grape::API
  version 'v1', using: :path
  before { authenticate! }

  helpers BodyParser

  namespace 'one_c' do
    resource 'orders' do
      desc 'Update order status from 1C system (accepts Cyrillic statuses)'
      params do
        requires :status, type: String, desc: 'New status for the order (in Cyrillic)'
        optional :archive_reason, type: String, desc: 'Required when status is archive (in Cyrillic)'
        optional :archive_comment, type: String, desc: 'Optional comment for archive'
      end
      patch ':external_id/status', requirements: { external_id: /[^\/]+/ } do
        # Authorize with special 1C policy
        authorize :update_status_from_one_c, Order

        # Verify API user has correct role
        unless current_user.api?
          error!({ error: 'This endpoint requires API role' }, 403)
        end

        # Parse request body with Windows cleanup
        body_params = parse_request_body

        # Extract parameters (prefer body over URL params)
        cyrillic_status = body_params['status'] || params[:status]
        cyrillic_archive_reason = body_params['archive_reason'] || params[:archive_reason]
        archive_comment = body_params['archive_comment'] || params[:archive_comment]

        # Translate Cyrillic status to English
        english_status = OrderStatusTranslator.to_english(cyrillic_status, type: :status)

        if english_status.nil?
          error!({ error: "Unknown status value: '#{cyrillic_status}'" }, 422)
        end

        # Validate English status
        unless Order::STATUSES.include?(english_status)
          error!({ error: "Invalid status value: '#{english_status}'" }, 422)
        end

        # Find order by external_id
        sync_record = OrderExternalSync.one_c.synced.find_by(external_id: params[:external_id])

        if sync_record.nil?
          error!({ error: "Order with external_id '#{params[:external_id]}' not found or not synced" }, 404)
        end

        order = sync_record.order

        # Handle archive status
        english_archive_reason = nil
        if english_status == 'archive'
          if cyrillic_archive_reason.blank?
            error!({ error: 'Archive reason is required when status is archive' }, 422)
          end

          # Translate archive reason to English
          english_archive_reason = OrderStatusTranslator.to_english(cyrillic_archive_reason, type: :archive_reason)

          if english_archive_reason.nil?
            error!({ error: "Unknown archive reason value: '#{cyrillic_archive_reason}'" }, 422)
          end

          # Validate English archive reason
          unless Order::ARCHIVE_REASONS.include?(english_archive_reason)
            error!({ error: "Invalid archive reason value: '#{english_archive_reason}'" }, 422)
          end
        end

        # Set the flag to skip 1C sync callbacks
        order.skip_one_c_sync = true

        # Build update attributes with English values
        update_attrs = { status: english_status }

        if english_status == 'archive'
          update_attrs[:archive_reason] = english_archive_reason
          update_attrs[:archive_comment] = archive_comment if archive_comment.present?
        end

        # Log the update for debugging
        Rails.logger.info "[OneCOrderApi] Updating order #{order.id} (external_id: #{params[:external_id]}) " \
                         "status from '#{order.status}' to '#{english_status}' (received: '#{cyrillic_status}') via 1C API"

        if order.update(update_attrs)
          # Return success response with entity (will translate back to Cyrillic)
          present order, with: Entities::OneCOrderStatusEntity
        else
          # Return validation errors
          error!({ error: 'Failed to update order', details: order.errors.full_messages }, 422)
        end
      end

      desc 'Get order status by 1C external ID'
      get ':external_id/status', requirements: { external_id: /[^\/]+/ } do
        # Authorize read access
        authorize :read_from_one_c, Order

        # Verify API user
        unless current_user.api?
          error!({ error: 'This endpoint requires API role' }, 403)
        end

        # Find order
        sync_record = OrderExternalSync.one_c.synced.find_by(external_id: params[:external_id])

        if sync_record.nil?
          error!({ error: "Order with external_id '#{params[:external_id]}' not found or not synced" }, 404)
        end

        present sync_record.order, with: Entities::OneCOrderStatusEntity
      end
    end
  end
end
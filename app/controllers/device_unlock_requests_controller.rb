# frozen_string_literal: true

class DeviceUnlockRequestsController < ApplicationController
  # Цикл 1 — только список (пока пустой). new/create/show/update_status/history
  # добавим в Циклах 2–3 (см. docs/device-unlock-requests-feature.md §5).
  def index
    authorize DeviceUnlockRequest
    @device_unlock_requests =
      DeviceUnlockRequest.recent.includes(:client, :item, :comments)
  end
end

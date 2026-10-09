# frozen_string_literal: true

# Инстансы GREEN-API для диалогов с клиентами: подключить, сменить и
# проверить, не трогая окружение сервера.
class GreenApiInstancesController < ApplicationController
  before_action :set_channel, except: :index

  def index
    authorize GreenApiInstance
    @channels = GreenApi::Channel.all
  end

  # Состояние спрашиваем у GREEN-API отдельным запросом уже открытой страницы:
  # ответ идёт секунды, и открытие страницы не должно их ждать.
  def status
    authorize GreenApiInstance, :index?
    @status = GreenApi::InstanceStatus.call(@channel.key)
  end

  def edit
    authorize GreenApiInstance, :update?
    @instance = @channel.instance_record || GreenApiInstance.new(channel: @channel.key)
  end

  def update
    authorize GreenApiInstance, :update?
    result = GreenApi::ConnectInstance.call(channel: @channel.key, params: instance_params, user: current_user)
    return redirect_to(green_api_instances_path, connected_flash(result)) if result.success?

    @instance = result.record
    flash.now[:error] = t('.rejected', error: result.error) if result.status == :rejected
    render :edit
  end

  # Реквизиты, с которыми канал работает из окружения сервера, переезжают в
  # Айс с тем же токеном уведомлений — инстанс перенастраивать не придётся.
  def import_env
    authorize GreenApiInstance, :update?
    env = @channel.env_credentials
    result = GreenApi::ConnectInstance.call(
      channel: @channel.key, user: current_user,
      params: { api_url: env.api_url, media_url: env.media_url, id_instance: env.instance_id, api_token: env.token }
    )
    return redirect_to(green_api_instances_path, connected_flash(result)) if result.success?

    error = result.error || result.record.errors.full_messages.to_sentence
    redirect_to green_api_instances_path, flash: { error: t('.failed', error: error) }
  end

  def configure
    authorize GreenApiInstance, :update?
    credentials = @channel.credentials
    webhook, error = GreenApi::InstanceApi.new(credentials)
                                          .ensure_webhook(webhook_url: @channel.webhook_url,
                                                          webhook_token: credentials.webhook_token)
    redirect_to green_api_instances_path, webhook_flash(webhook, error)
  end

  # Страница спрашивает код снова и снова, пока аккаунт не подключится.
  def qr
    authorize GreenApiInstance, :update?
    render json: qr_payload(GreenApi::InstanceApi.for(@channel.key).qr)
  end

  def logout
    authorize GreenApiInstance, :update?
    response = GreenApi::InstanceApi.for(@channel.key).logout
    redirect_to green_api_instances_path, action_flash('logout', response, response['isLogout'] == true)
  end

  def reboot
    authorize GreenApiInstance, :update?
    response = GreenApi::InstanceApi.for(@channel.key).reboot
    redirect_to green_api_instances_path, action_flash('reboot', response, response['isReboot'] == true)
  end

  def password
    authorize GreenApiInstance, :update?
    response = GreenApi::InstanceApi.for(@channel.key).send_password(params[:password].to_s)
    return redirect_to(green_api_instances_path, notice: t('.accepted')) if response['status'] == true

    reason = response.dig('data', 'reason').presence
    error = reason ? t(".reasons.#{reason}", default: reason) : GreenApi::InstanceApi.failure_text(response)
    redirect_to green_api_instances_path, alert: t('.failed', error: error)
  end

  private

  # У MAX «уже подключён» в документации встречается под двумя именами.
  def qr_payload(response)
    return { status: 'error', text: GreenApi::InstanceApi.failure_text(response) } unless response['http_code'] == 200

    case response['type']
    when 'qrCode' then { status: 'qr', image: "data:image/png;base64,#{response['message']}" }
    when 'alreadyLogged', 'already_registered' then { status: 'authorized', text: t('green_api_instances.qr.authorized') }
    when 'passkeyRequired' then { status: 'passkey', text: t('green_api_instances.qr.passkey') }
    else { status: 'error', text: response['message'].presence || response['type'].to_s }
    end
  end

  def action_flash(action, response, done)
    return { notice: t("green_api_instances.#{action}.done") } if done

    { alert: t("green_api_instances.#{action}.failed", error: GreenApi::InstanceApi.failure_text(response)) }
  end

  def set_channel
    @channel = GreenApi::Channel.fetch(params[:channel])
  rescue KeyError
    raise ActiveRecord::RecordNotFound
  end

  def instance_params
    params.require(:green_api_instance).permit(:api_url, :media_url, :id_instance, :api_token)
  end

  def connected_flash(result)
    flash = webhook_flash(result.webhook, result.error)
    key = flash.keys.first
    { key => "#{t('green_api_instances.connected')} #{flash[key]}" }
  end

  def webhook_flash(webhook, error)
    case webhook
    when :already, :applied then { notice: t("green_api_instances.webhook_flash.#{webhook}") }
    else { alert: t('green_api_instances.webhook_flash.failed', error: error) }
    end
  end
end

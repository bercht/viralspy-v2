module Settings
  class ApiKeysController < ApplicationController
    before_action :set_provider, only: [ :create, :update, :destroy ]
    before_action :set_credential, only: [ :update, :destroy ]

    def show
      @credentials_by_provider = ApiCredential::PROVIDERS.index_with do |provider|
        current_tenant.api_credentials.find_by(provider: provider)
      end
    end

    def create
      credential = current_tenant.api_credentials.build(credential_params.merge(provider: @provider))

      if credential.save
        run_validation(credential)
        redirect_to settings_api_keys_path, notice: success_flash_for(credential)
      else
        redirect_to settings_api_keys_path, alert: credential.errors.full_messages.to_sentence
      end
    end

    def update
      authorize @credential

      if @credential.update(credential_params)
        run_validation(@credential)
        redirect_to settings_api_keys_path, notice: success_flash_for(@credential)
      else
        redirect_to settings_api_keys_path, alert: @credential.errors.full_messages.to_sentence
      end
    end

    def destroy
      authorize @credential

      @credential.destroy
      redirect_to settings_api_keys_path,
        notice: t("settings.api_keys.flash.destroyed", provider: provider_label(@provider))
    end

    private

    def set_provider
      @provider = params[:provider]
      unless ApiCredential::PROVIDERS.include?(@provider)
        redirect_to settings_api_keys_path, alert: t("settings.api_keys.flash.invalid_provider")
      end
    end

    def set_credential
      @credential = current_tenant.api_credentials.find_by!(provider: @provider)
    rescue ActiveRecord::RecordNotFound
      redirect_to settings_api_keys_path,
        alert: t("settings.api_keys.flash.not_found", provider: provider_label(@provider))
    end

    def credential_params
      params.require(:api_credential).permit(:api_key, :active)
    end

    def run_validation(credential)
      ApiCredentials::ValidateService.call(credential)
    end

    def success_flash_for(credential)
      credential.reload
      case credential.last_validation_status.to_sym
      when :verified
        t("settings.api_keys.flash.saved_verified", provider: provider_label(credential.provider))
      when :failed
        t("settings.api_keys.flash.saved_failed", provider: provider_label(credential.provider))
      when :quota_exceeded
        t("settings.api_keys.flash.saved_quota", provider: provider_label(credential.provider))
      else
        t("settings.api_keys.flash.saved_unknown", provider: provider_label(credential.provider))
      end
    end

    def provider_label(provider)
      t("settings.api_keys.providers.#{provider}.name")
    end
  end
end

module RequiresApiCredentials
  extend ActiveSupport::Concern

  private

  # Wire via `before_action :require_api_credentials_configured!` in controllers
  # that trigger analyses. No-op when current_tenant is nil (authentication
  # concern must run first). Redirects with a flash listing missing providers
  # and their use cases when the account lacks active ApiCredentials.
  def require_api_credentials_configured!
    return if current_tenant.nil?
    return if current_tenant.ready_for_analysis?

    flash[:alert] = api_credentials_missing_flash_message(current_tenant.missing_credentials_for_analysis)
    redirect_to api_credentials_redirect_target
  end

  def api_credentials_missing_flash_message(missing_providers)
    intro = I18n.t("api_credentials.missing.intro")
    cta   = I18n.t("api_credentials.missing.cta")

    items = missing_providers.map do |provider|
      provider_name = I18n.t("api_credentials.missing.providers.#{provider}", default: provider.to_s)
      use_case      = I18n.t("api_credentials.missing.use_cases.#{provider}", default: "")
      use_case.present? ? "#{provider_name} (#{use_case})" : provider_name
    end

    "#{intro} #{items.join(', ')}. #{cta}"
  end

  def api_credentials_redirect_target
    if main_app.respond_to?(:settings_api_keys_path)
      main_app.settings_api_keys_path
    else
      main_app.root_path
    end
  end
end

class ApplicationController < ActionController::Base
  include Pundit::Authorization

  before_action :authenticate_user!
  before_action :set_current_tenant

  helper_method :current_tenant, :current_account

  rescue_from Pundit::NotAuthorizedError, with: :user_not_authorized

  private

  def set_current_tenant
    ActsAsTenant.current_tenant = current_user&.account
  end

  def current_tenant
    ActsAsTenant.current_tenant
  end

  def current_account
    current_tenant
  end

  def user_not_authorized
    flash[:alert] = I18n.t("errors.not_authorized")
    redirect_back fallback_location: dashboard_path
  end
end

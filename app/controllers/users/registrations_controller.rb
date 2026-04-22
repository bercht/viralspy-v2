# frozen_string_literal: true

class Users::RegistrationsController < Devise::RegistrationsController
  layout "marketing"

  skip_before_action :authenticate_user!, only: [ :new, :create ]
  skip_before_action :set_current_tenant, only: [ :new, :create ]

  def create # rubocop:disable Metrics/MethodLength -- devise custom flow, intencionalmente verboso
    ActsAsTenant.without_tenant do
      ActiveRecord::Base.transaction do
        @account = Account.new(name: account_params[:name])

        unless @account.save
          build_resource(sign_up_params)
          resource.errors.add(:base, I18n.t("errors.signup.account_invalid"))
          clean_up_passwords(resource)
          set_minimum_password_length
          render :new, status: :unprocessable_entity and return
        end

        build_resource(sign_up_params.merge(account_id: @account.id))

        if resource.save
          if resource.active_for_authentication?
            set_flash_message! :notice, :signed_up
            sign_up(resource_name, resource)
            respond_with(resource, location: after_sign_up_path_for(resource)) and return
          else
            set_flash_message! :notice, :"signed_up_but_#{resource.inactive_message}"
            expire_data_after_sign_in!
            respond_with(resource, location: after_inactive_sign_up_path_for(resource)) and return
          end
        else
          clean_up_passwords(resource)
          set_minimum_password_length
          raise ActiveRecord::Rollback
        end
      end

      render :new, status: :unprocessable_entity if resource && !resource.persisted?
    end
  end

  protected

  def sign_up_params
    params.require(:user).permit(:first_name, :last_name, :email, :password, :password_confirmation)
  end

  def account_params
    raw = params.require(:user).permit(:account_name)
    { name: raw[:account_name] }
  end

  def after_sign_up_path_for(_resource)
    dashboard_path
  end
end

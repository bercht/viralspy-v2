# app/controllers/design_system_controller.rb
class DesignSystemController < ApplicationController
  skip_before_action :authenticate_user!
  skip_before_action :set_current_tenant

  def index
  end
end

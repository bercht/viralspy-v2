module Settings
  class LLMPreferencesController < ApplicationController
    def edit
      load_form_state
    end

    def update
      preferences = current_tenant.llm_preferences_with_defaults.merge(llm_preferences_params.to_h)

      if current_tenant.update(llm_preferences: preferences)
        redirect_to edit_settings_llm_preferences_path, notice: t("settings.llm_preferences.flash.updated")
      else
        load_form_state
        flash.now[:alert] = current_tenant.errors.full_messages.to_sentence
        render :edit, status: :unprocessable_entity
      end
    end

    private

    def llm_preferences_params
      params.require(:llm_preferences).permit(
        :transcription_provider,
        :transcription_model,
        :analysis_provider,
        :analysis_model,
        :generation_provider,
        :generation_model
      )
    end

    def load_form_state
      @preferences = current_tenant.llm_preferences_with_defaults
      @available_providers = current_tenant.api_credentials.active.where(last_validation_status: :verified).pluck(:provider)
    end
  end
end

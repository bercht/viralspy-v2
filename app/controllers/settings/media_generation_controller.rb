module Settings
  class MediaGenerationController < ApplicationController
    def show
      @heygen_credential = current_tenant.api_credentials.find_or_initialize_by(provider: "heygen")
      @preferences = current_tenant.media_generation_preferences
    end

    def update
      result = update_settings(settings_params)

      if result[:success]
        redirect_to settings_media_generation_path, notice: "Configurações salvas."
      else
        @heygen_credential = current_tenant.api_credentials.find_or_initialize_by(provider: "heygen")
        @preferences = current_tenant.media_generation_preferences
        flash.now[:alert] = result[:error]
        render :show, status: :unprocessable_content
      end
    end

    def avatars
      credential = current_tenant.api_credentials.find_by(provider: "heygen", active: true)
      if credential.nil?
        return render json: { error: "API key não configurada" }, status: :unprocessable_entity
      end

      provider = MediaGeneration::Factory.build(provider: "heygen", api_key: credential.api_key)
      render json: provider.fetch_avatars
    end

    def voices
      credential = current_tenant.api_credentials.find_by(provider: "heygen", active: true)
      if credential.nil?
        return render json: { error: "API key não configurada" }, status: :unprocessable_entity
      end

      provider = MediaGeneration::Factory.build(provider: "heygen", api_key: credential.api_key)
      render json: provider.fetch_voices
    end

    def validate_key
      credential = current_tenant.api_credentials.find_by(provider: "heygen", active: true)

      if credential.nil?
        render json: { valid: false, message: "Chave não configurada." }
        return
      end

      provider = MediaGeneration::Factory.build(provider: "heygen", api_key: credential.api_key)
      valid = provider.validate_api_key

      if valid
        credential.update!(last_validated_at: Time.current, last_validation_status: :verified)
        render json: { valid: true, message: "Chave válida." }
      else
        credential.update!(last_validation_status: :failed)
        render json: { valid: false, message: "Chave inválida. Verifique no dashboard HeyGen." }
      end
    end

    private

    def settings_params
      params.require(:settings).permit(:api_key, :avatar_id, :voice_id)
    end

    def update_settings(params)
      ActiveRecord::Base.transaction do
        if params[:api_key].present?
          credential = current_tenant.api_credentials.find_or_initialize_by(provider: "heygen")
          credential.api_key = params[:api_key]
          credential.active = true
          credential.save!
        end

        prefs = current_tenant.media_generation_preferences.dup
        prefs["avatar_id"] = params[:avatar_id] if params[:avatar_id].present?
        prefs["voice_id"] = params[:voice_id] if params[:voice_id].present?
        current_tenant.update!(media_generation_preferences: prefs)

        { success: true }
      end
    rescue ActiveRecord::RecordInvalid => e
      { success: false, error: e.message }
    end
  end
end

module MediaGeneration
  class Start
    Outcome = Struct.new(:success, :generated_media, :error, :error_code, keyword_init: true) do
      def success? = success
      def failure? = !success
    end

    def self.call(content_suggestion:, account:, script: nil, avatar_id: nil, voice_id: nil)
      new(content_suggestion:, account:, script:, avatar_id:, voice_id:).call
    end

    def initialize(content_suggestion:, account:, script: nil, avatar_id: nil, voice_id: nil)
      @content_suggestion = content_suggestion
      @account = account
      @override_script = script
      @override_avatar_id = avatar_id
      @override_voice_id = voice_id
    end

    def call
      api_key = resolve_api_key
      return failure(:missing_api_key, "HeyGen API key not configured") if api_key.nil?

      settings = resolve_settings
      avatar_id = @override_avatar_id.presence || settings[:avatar_id]
      voice_id  = @override_voice_id.presence  || settings[:voice_id]

      unless avatar_id.present? && voice_id.present?
        return failure(:missing_settings, "HeyGen avatar_id or voice_id not configured")
      end

      script = @override_script.presence || ScriptBuilder.build(suggestion: content_suggestion)
      provider = Factory.build(provider: "heygen", api_key: api_key)

      generated_media = GeneratedMedia.new(
        account: account,
        content_suggestion: content_suggestion,
        provider: "heygen",
        media_type: :avatar_video,
        status: :pending,
        prompt_sent: script,
        provider_params: { avatar_id: avatar_id, voice_id: voice_id }
      )

      result = provider.start_generation(
        script: script,
        avatar_id: avatar_id,
        voice_id: voice_id,
        title: "VS_#{content_suggestion.id}_#{Time.current.to_i}"
      )

      if result.success?
        generated_media.provider_job_id = result.job_id
        generated_media.status = :processing
        generated_media.started_at = Time.current
        generated_media.save!

        MediaGeneration::PollWorker.perform_in(10.seconds, generated_media.id)

        Outcome.new(success: true, generated_media: generated_media)
      else
        Rails.logger.warn("[MediaGeneration::Start] failed: #{result.error_code} — #{result.error} " \
                          "account_id=#{account.id} suggestion_id=#{content_suggestion.id}")

        generated_media.status = :failed
        generated_media.error_message = result.error
        generated_media.finished_at = Time.current
        generated_media.save!

        Outcome.new(success: false, error: result.error, error_code: result.error_code,
                    generated_media: generated_media)
      end
    end

    private

    attr_reader :content_suggestion, :account

    def resolve_api_key
      account.api_credentials.find_by(provider: "heygen", active: true)&.api_key
    end

    def resolve_settings
      prefs = account.media_generation_preferences || {}
      {
        avatar_id: prefs["avatar_id"].presence,
        voice_id: prefs["voice_id"].presence
      }
    end

    def failure(error_code, error_message)
      Outcome.new(success: false, error: error_message, error_code: error_code)
    end
  end
end

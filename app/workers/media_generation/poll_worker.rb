module MediaGeneration
  class PollWorker
    include Sidekiq::Worker

    sidekiq_options queue: "media_generation", retry: 3

    MAX_ATTEMPTS  = 60
    POLL_INTERVAL = 10

    def perform(generated_media_id, attempt = 1)
      generated_media = ActsAsTenant.without_tenant { GeneratedMedia.find(generated_media_id) }

      ActsAsTenant.with_tenant(generated_media.account) do
        return if generated_media.completed? || generated_media.failed?

        if attempt > MAX_ATTEMPTS
          generated_media.update!(
            status: :failed,
            error_message: "Polling timeout — vídeo não foi gerado em 10 minutos",
            finished_at: Time.current
          )
          broadcast_update(generated_media)
          return
        end

        api_key = generated_media.account.api_credentials
                                 .find_by(provider: "heygen", active: true)&.api_key

        if api_key.nil?
          generated_media.update!(
            status: :failed, error_message: "HeyGen API key not found", finished_at: Time.current
          )
          broadcast_update(generated_media)
          return
        end

        provider = MediaGeneration::Factory.build(provider: "heygen", api_key: api_key)
        result = provider.check_status(job_id: generated_media.provider_job_id)

        if result.failure? && result.error_code != :timeout
          generated_media.update!(
            status: :failed, error_message: result.error, finished_at: Time.current
          )
          broadcast_update(generated_media)
          return
        end

        case result.status
        when "completed"
          generated_media.update!(
            status: :completed, output_url: result.output_url, finished_at: Time.current
          )
          log_usage(generated_media)
          broadcast_update(generated_media)
        when "failed"
          generated_media.update!(
            status: :failed,
            error_message: result.error || "HeyGen generation failed",
            finished_at: Time.current
          )
          broadcast_update(generated_media)
        else
          self.class.perform_in(POLL_INTERVAL.seconds, generated_media_id, attempt + 1)
        end
      end
    end

    private

    def log_usage(generated_media)
      MediaGenerationUsageLog.create!(
        account: generated_media.account,
        generated_media: generated_media,
        provider: "heygen",
        duration_seconds: generated_media.duration_seconds,
        cost_cents: 0
      )
    end

    def broadcast_update(generated_media)
      Turbo::StreamsChannel.broadcast_replace_to(
        "media_generation_#{generated_media.account_id}",
        target: "generated_media_#{generated_media.id}",
        partial: "generated_medias/status",
        locals: { generated_media: generated_media }
      )
    end
  end
end

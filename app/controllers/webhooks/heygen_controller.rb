# app/controllers/webhooks/heygen_controller.rb
module Webhooks
  class HeygenController < ApplicationController
    skip_before_action :verify_authenticity_token
    skip_before_action :authenticate_user!
    skip_before_action :set_current_tenant

    before_action :verify_token

    VIDEO_STATUS_EVENT = "video_status"

    def receive
      unless event_type == VIDEO_STATUS_EVENT
        return head :ok
      end

      return head :ok if video_id.blank?

      # Webhook não carrega tenant — busca global necessária para encontrar o registro
      generated_media = ActsAsTenant.without_tenant { GeneratedMedia.find_by(provider_job_id: video_id) }

      if generated_media.nil?
        Rails.logger.warn("[Webhooks::HeygenController] GeneratedMedia not found for video_id=#{video_id}")
        return head :ok
      end

      return head :ok if generated_media.completed? || generated_media.failed?

      ActsAsTenant.with_tenant(generated_media.account) do
        case video_status
        when "completed"
          generated_media.update!(
            status: :completed,
            output_url: event_data["video_url"],
            finished_at: Time.current
          )
          log_usage(generated_media)
          broadcast_update(generated_media)
        when "failed"
          generated_media.update!(
            status: :failed,
            error_message: event_data["error"] || "HeyGen generation failed",
            finished_at: Time.current
          )
          broadcast_update(generated_media)
        end
      end

      head :ok
    end

    private

    def verify_token
      expected = ENV["HEYGEN_WEBHOOK_TOKEN"]

      if expected.blank?
        Rails.logger.error("[Webhooks::HeygenController] HEYGEN_WEBHOOK_TOKEN not configured")
        return head :internal_server_error
      end

      unless ActiveSupport::SecurityUtils.secure_compare(params[:token].to_s, expected)
        head :unauthorized
      end
    end

    def payload
      @payload ||= JSON.parse(request.body.tap(&:rewind).read)
    rescue JSON::ParserError
      {}
    end

    def event_type   = payload["event_type"]
    def event_data   = payload["event_data"] || {}
    def video_id     = event_data["video_id"]
    def video_status = event_data["status"]

    def log_usage(generated_media)
      MediaGenerationUsageLog.create!(
        account: generated_media.account,
        generated_media: generated_media,
        provider: "heygen",
        duration_seconds: generated_media.duration_seconds || 0,
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

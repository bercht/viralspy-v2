module Analyses
  class TranscribeStep
    def self.call(analysis)
      new(analysis).call
    end

    def initialize(analysis)
      @analysis = analysis
      @account = analysis.account
    end

    def call
      analysis.update!(status: :transcribing)

      mark_non_reels_as_skipped
      transcribe_selected_reels

      Analyses::Result.success(data: transcription_summary)
    rescue => e
      Rails.logger.error("[Analysis##{analysis.id}] TranscribeStep exception: #{e.class} - #{e.message}")
      mark_failed("TranscribeStep crashed: #{e.message}")
      Analyses::Result.failure(error: e.message, error_code: :transcribe_exception)
    end

    private

    attr_reader :analysis, :account

    def mark_non_reels_as_skipped
      analysis.posts
              .where(selected_for_analysis: true)
              .where.not(post_type: Post.post_types[:reel])
              .update_all(transcript_status: Post.transcript_statuses[:skipped])
    end

    def transcribe_selected_reels
      reels = analysis.posts
                      .where(selected_for_analysis: true, post_type: :reel)
                      .where(transcript_status: Post.transcript_statuses[:pending])
                      .to_a

      Rails.logger.info("[Analysis##{analysis.id}] TranscribeStep: starting for #{reels.size} reels")
      reels.each_with_index { |post, i| transcribe_single_post(post, i + 1, reels.size) }
    end

    def transcribe_single_post(post, index, total)
      Rails.logger.info("[Analysis##{analysis.id}] Transcribing reel #{index}/#{total} (post #{post.id})")

      if post.video_url.blank?
        Rails.logger.warn("[Analysis##{analysis.id}] Post #{post.id} has no video_url, marking skipped")
        post.update!(transcript_status: :skipped)
        return
      end

      provider = provider_for(:transcription)
      model    = model_for(:transcription)
      key      = api_key_for(provider)

      result = Transcription::Factory
                 .build(provider: provider, api_key: key)
                 .transcribe(video_url: post.video_url)

      if result.success?
        post.update!(transcript: result.transcript, transcript_status: :completed, transcribed_at: Time.current)
        Transcription::UsageLogger.log(
          result: result,
          account: account,
          provider: provider,
          model: model,
          post: post,
          analysis: analysis
        )
      else
        new_status = (result.error_code == :file_too_large) ? :skipped : :failed
        Rails.logger.warn("[Analysis##{analysis.id}] Transcription failed for post #{post.id}: #{result.error_code}")
        post.update!(transcript_status: new_status)
      end
    rescue ApiCredentials::NotConfiguredError
      raise
    rescue => e
      Rails.logger.error("[Analysis##{analysis.id}] Unexpected error transcribing post #{post.id}: #{e.class} - #{e.message}")
      post.update!(transcript_status: :failed)
    end

    def transcription_summary
      reels = analysis.posts.where(selected_for_analysis: true, post_type: :reel)
      {
        reels_selected: reels.count,
        completed: reels.where(transcript_status: :completed).count,
        failed: reels.where(transcript_status: :failed).count,
        skipped: reels.where(transcript_status: :skipped).count
      }
    end

    def mark_failed(message)
      analysis.update!(status: :failed, error_message: message, finished_at: Time.current)
    end

    # =========================================================================
    # Resolução de provider/model/key via account (BYOK — ADR-013).
    # use_case "transcription" tem seu próprio grupo de preferências.
    # =========================================================================

    def provider_for(_use_case)
      account.llm_preferences_with_defaults["transcription_provider"].to_sym
    end

    def model_for(_use_case)
      account.llm_preferences_with_defaults["transcription_model"]
    end

    def api_key_for(provider)
      credential = account.api_credential_for(provider.to_s)
      raise ApiCredentials::NotConfiguredError.new(provider: provider.to_s, use_case: "transcription") unless credential

      credential.encrypted_api_key
    end
  end
end

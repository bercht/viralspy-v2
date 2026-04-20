require "rails_helper"

RSpec.describe Analyses::TranscribeStep do
  let(:account) { create(:account) }
  let(:competitor) { create(:competitor, account: account) }
  let(:analysis) { create(:analysis, account: account, competitor: competitor, status: :transcribing) }
  let(:mock_provider) { instance_double(Transcription::Providers::AssemblyAI) }
  let!(:assemblyai_cred) { create(:api_credential, :assemblyai, account: account, encrypted_api_key: "aai-test-key") }

  before do
    allow(Transcription::Factory).to receive(:build)
      .with(provider: :assemblyai, api_key: "aai-test-key")
      .and_return(mock_provider)
  end

  def create_reel(video_url: "https://cdn.example.com/video.mp4", **opts)
    create(:post, :reel, :selected, account: account, analysis: analysis, competitor: competitor,
                                    video_url: video_url, **opts)
  end

  def create_carousel(**opts)
    create(:post, :carousel, :selected, account: account, analysis: analysis, competitor: competitor, **opts)
  end

  def create_image(**opts)
    create(:post, :image, :selected, account: account, analysis: analysis, competitor: competitor, **opts)
  end

  let(:success_result) { Transcription::Result.success(transcript: "Bom dia pessoal...", duration_seconds: 30) }

  describe ".call" do
    context "sets :transcribing status on entry" do
      before { allow(mock_provider).to receive(:transcribe).and_return(success_result) }

      it "sets analysis status to :transcribing before processing posts" do
        analysis.update!(status: :scoring)
        captured_status = nil

        allow_any_instance_of(described_class).to receive(:mark_non_reels_as_skipped) do |instance|
          captured_status = analysis.reload.status
          # call original
          instance.instance_variable_get(:@analysis).posts
                  .where(selected_for_analysis: true)
                  .where.not(post_type: Post.post_types[:reel])
                  .update_all(transcript_status: Post.transcript_statuses[:skipped])
        end

        ActsAsTenant.with_tenant(account) { described_class.call(analysis) }
        expect(captured_status).to eq("transcribing")
      end
    end

    context "happy path — all reels succeed" do
      let!(:reel1) { create_reel }
      let!(:reel2) { create_reel }

      before { allow(mock_provider).to receive(:transcribe).and_return(success_result) }

      it "transcribes all selected reels and leaves status at :transcribing (AnalyzeStep advances)" do
        ActsAsTenant.with_tenant(account) do
          result = described_class.call(analysis)

          expect(result).to be_success
          expect(analysis.reload.status).to eq("transcribing")
          expect(reel1.reload.transcript).to eq("Bom dia pessoal...")
          expect(reel1.reload.transcript_status).to eq("completed")
          expect(reel2.reload.transcript_status).to eq("completed")
        end
      end

      it "calls Transcription::Factory.build with assemblyai provider and credential key" do
        ActsAsTenant.with_tenant(account) do
          described_class.call(analysis)

          expect(Transcription::Factory).to have_received(:build)
            .with(provider: :assemblyai, api_key: "aai-test-key")
            .at_least(:once)
        end
      end

      it "creates TranscriptionUsageLog for each successful reel" do
        ActsAsTenant.with_tenant(account) do
          expect {
            described_class.call(analysis)
          }.to change(TranscriptionUsageLog, :count).by(2)
        end
      end

      it "logs with dynamic provider from preferences (assemblyai by default)" do
        ActsAsTenant.with_tenant(account) do
          described_class.call(analysis)

          log = TranscriptionUsageLog.last
          expect(log.provider).to eq("assemblyai")
        end
      end
    end

    context "one reel fails with timeout" do
      let!(:reel_ok) { create_reel(video_url: "https://cdn.example.com/ok.mp4") }
      let!(:reel_fail) { create_reel(video_url: "https://cdn.example.com/fail.mp4") }

      before do
        allow(mock_provider).to receive(:transcribe).with(video_url: "https://cdn.example.com/ok.mp4")
          .and_return(success_result)
        allow(mock_provider).to receive(:transcribe).with(video_url: "https://cdn.example.com/fail.mp4")
          .and_return(Transcription::Result.failure(error: "timeout", error_code: :timeout))
      end

      it "marks failed post as failed but continues pipeline" do
        ActsAsTenant.with_tenant(account) do
          result = described_class.call(analysis)

          expect(result).to be_success
          expect(reel_ok.reload.transcript_status).to eq("completed")
          expect(reel_fail.reload.transcript_status).to eq("failed")
          expect(analysis.reload.status).to eq("transcribing")
        end
      end
    end

    context "reel with file_too_large error" do
      let!(:big_reel) { create_reel }

      before do
        allow(mock_provider).to receive(:transcribe)
          .and_return(Transcription::Result.failure(error: "25MB exceeded", error_code: :file_too_large))
      end

      it "marks post as skipped (not failed)" do
        ActsAsTenant.with_tenant(account) do
          described_class.call(analysis)
          expect(big_reel.reload.transcript_status).to eq("skipped")
        end
      end
    end

    context "reel without video_url" do
      let!(:no_video_reel) { create_reel(video_url: nil) }

      before { allow(mock_provider).to receive(:transcribe) }

      it "marks post as skipped without calling the provider" do
        ActsAsTenant.with_tenant(account) do
          described_class.call(analysis)

          expect(mock_provider).not_to have_received(:transcribe)
          expect(no_video_reel.reload.transcript_status).to eq("skipped")
        end
      end
    end

    context "selected carousels and images" do
      let!(:carousel) { create_carousel }
      let!(:image) { create_image }

      before { allow(mock_provider).to receive(:transcribe) }

      it "marks them as skipped without calling provider" do
        ActsAsTenant.with_tenant(account) do
          described_class.call(analysis)

          expect(mock_provider).not_to have_received(:transcribe)
          expect(carousel.reload.transcript_status).to eq("skipped")
          expect(image.reload.transcript_status).to eq("skipped")
        end
      end
    end

    context "all reels fail — pipeline still advances" do
      let!(:reel1) { create_reel }
      let!(:reel2) { create_reel }

      before do
        allow(mock_provider).to receive(:transcribe)
          .and_return(Transcription::Result.failure(error: "network error", error_code: :download_failed))
      end

      it "leaves status at :transcribing even when all transcriptions fail (AnalyzeStep advances)" do
        ActsAsTenant.with_tenant(account) do
          result = described_class.call(analysis)

          expect(result).to be_success
          expect(analysis.reload.status).to eq("transcribing")
          expect(reel1.reload.transcript_status).to eq("failed")
          expect(reel2.reload.transcript_status).to eq("failed")
        end
      end
    end

    context "no selected reels" do
      before { allow(mock_provider).to receive(:transcribe) }

      it "returns success and leaves status at :transcribing without calling provider" do
        ActsAsTenant.with_tenant(account) do
          result = described_class.call(analysis)

          expect(result).to be_success
          expect(mock_provider).not_to have_received(:transcribe)
          expect(analysis.reload.status).to eq("transcribing")
        end
      end
    end

    context "unexpected exception during transcription of a single post" do
      let!(:reel) { create_reel }

      before do
        allow(mock_provider).to receive(:transcribe).and_raise(RuntimeError, "unexpected crash")
      end

      it "marks post as failed but pipeline continues at :transcribing" do
        ActsAsTenant.with_tenant(account) do
          result = described_class.call(analysis)

          expect(result).to be_success
          expect(reel.reload.transcript_status).to eq("failed")
          expect(analysis.reload.status).to eq("transcribing")
        end
      end
    end

    context "step-level exception (database down)" do
      before do
        allow_any_instance_of(described_class).to receive(:mark_non_reels_as_skipped)
          .and_raise(ActiveRecord::StatementInvalid, "PG::ConnectionBad")
      end

      it "returns failure result and marks analysis as failed" do
        ActsAsTenant.with_tenant(account) do
          result = described_class.call(analysis)

          expect(result).to be_failure
          expect(result.error_code).to eq(:transcribe_exception)
          expect(analysis.reload.status).to eq("failed")
          expect(analysis.reload.finished_at).to be_present
        end
      end
    end

    context "when assemblyai credential is missing" do
      let!(:reel) { create_reel }

      before do
        assemblyai_cred.destroy!
        allow(Transcription::Factory).to receive(:build)
      end

      it "marks analysis as failed with transcribe_exception and does not call Factory.build" do
        ActsAsTenant.with_tenant(account) do
          result = described_class.call(analysis)

          expect(result).to be_failure
          expect(result.error_code).to eq(:transcribe_exception)
          expect(analysis.reload.status).to eq("failed")
          expect(analysis.reload.finished_at).to be_present
          expect(Transcription::Factory).not_to have_received(:build)
        end
      end
    end

    context "when assemblyai credential is inactive" do
      let!(:reel) { create_reel }

      before do
        assemblyai_cred.update!(active: false)
        allow(Transcription::Factory).to receive(:build)
      end

      it "marks analysis as failed (inactive treated as missing)" do
        ActsAsTenant.with_tenant(account) do
          result = described_class.call(analysis)

          expect(result).to be_failure
          expect(result.error_code).to eq(:transcribe_exception)
          expect(analysis.reload.status).to eq("failed")
          expect(Transcription::Factory).not_to have_received(:build)
        end
      end
    end

    context "when transcription_provider preference is overridden to openai" do
      let!(:openai_cred) { create(:api_credential, :openai, account: account, encrypted_api_key: "sk-openai-key") }
      let!(:reel) { create_reel }
      let(:openai_provider) { instance_double(Transcription::Providers::OpenAI) }

      before do
        account.update!(llm_preferences: {
          "transcription_provider" => "openai",
          "transcription_model" => "gpt-4o-mini-transcribe"
        })
        allow(Transcription::Factory).to receive(:build)
          .with(provider: :openai, api_key: "sk-openai-key")
          .and_return(openai_provider)
        allow(openai_provider).to receive(:transcribe).and_return(success_result)
      end

      it "uses openai transcription provider from preferences" do
        ActsAsTenant.with_tenant(account) do
          result = described_class.call(analysis)

          expect(result).to be_success
          expect(Transcription::Factory).to have_received(:build)
            .with(provider: :openai, api_key: "sk-openai-key")
        end
      end
    end
  end
end

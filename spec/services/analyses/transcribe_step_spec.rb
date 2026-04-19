require "rails_helper"

RSpec.describe Analyses::TranscribeStep do
  let(:account) { create(:account) }
  let(:competitor) { create(:competitor, account: account) }
  let(:analysis) { create(:analysis, account: account, competitor: competitor, status: :transcribing) }
  let(:mock_provider) { instance_double(Transcription::Providers::OpenAI) }

  before do
    allow(Transcription::Factory).to receive(:build).and_return(mock_provider)
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
    context "happy path — all reels succeed" do
      let!(:reel1) { create_reel }
      let!(:reel2) { create_reel }

      before { allow(mock_provider).to receive(:transcribe).and_return(success_result) }

      it "transcribes all selected reels and advances status to analyzing" do
        ActsAsTenant.with_tenant(account) do
          result = described_class.call(analysis)

          expect(result).to be_success
          expect(analysis.reload.status).to eq("analyzing")
          expect(reel1.reload.transcript).to eq("Bom dia pessoal...")
          expect(reel1.reload.transcript_status).to eq("completed")
          expect(reel2.reload.transcript_status).to eq("completed")
        end
      end

      it "creates TranscriptionUsageLog for each successful reel" do
        ActsAsTenant.with_tenant(account) do
          expect {
            described_class.call(analysis)
          }.to change(TranscriptionUsageLog, :count).by(2)
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
          expect(analysis.reload.status).to eq("analyzing")
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

      it "advances to analyzing even when all transcriptions fail" do
        ActsAsTenant.with_tenant(account) do
          result = described_class.call(analysis)

          expect(result).to be_success
          expect(analysis.reload.status).to eq("analyzing")
          expect(reel1.reload.transcript_status).to eq("failed")
          expect(reel2.reload.transcript_status).to eq("failed")
        end
      end
    end

    context "no selected reels" do
      before { allow(mock_provider).to receive(:transcribe) }

      it "advances status without calling provider" do
        ActsAsTenant.with_tenant(account) do
          result = described_class.call(analysis)

          expect(result).to be_success
          expect(mock_provider).not_to have_received(:transcribe)
          expect(analysis.reload.status).to eq("analyzing")
        end
      end
    end

    context "unexpected exception during transcription of a single post" do
      let!(:reel) { create_reel }

      before do
        allow(mock_provider).to receive(:transcribe).and_raise(RuntimeError, "unexpected crash")
      end

      it "marks post as failed but pipeline continues" do
        ActsAsTenant.with_tenant(account) do
          result = described_class.call(analysis)

          expect(result).to be_success
          expect(reel.reload.transcript_status).to eq("failed")
          expect(analysis.reload.status).to eq("analyzing")
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
  end
end

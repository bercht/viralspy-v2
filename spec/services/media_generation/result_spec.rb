require "rails_helper"

RSpec.describe MediaGeneration::Result do
  describe "#success? e #failure?" do
    it "retorna true para success quando success: true" do
      result = described_class.new(success: true)
      expect(result.success?).to be true
      expect(result.failure?).to be false
    end

    it "retorna true para failure quando success: false" do
      result = described_class.new(success: false, error: "oops", error_code: :invalid_api_key)
      expect(result.success?).to be false
      expect(result.failure?).to be true
    end
  end

  describe "atributos" do
    subject(:result) do
      described_class.new(
        success: true,
        job_id: "job_123",
        output_url: "https://example.com/video.mp4",
        status: "completed",
        duration_seconds: 30,
        error: nil,
        error_code: nil
      )
    end

    it { expect(result.job_id).to eq("job_123") }
    it { expect(result.output_url).to eq("https://example.com/video.mp4") }
    it { expect(result.status).to eq("completed") }
    it { expect(result.duration_seconds).to eq(30) }
  end
end

require "rails_helper"

RSpec.describe Scraping::Apify::RunPoller do
  let(:client) { instance_double(Scraping::Apify::Client) }
  let(:run_id) { "run_abc" }
  let(:no_sleep) { ->(_) {} }

  def make_poller(**opts)
    described_class.new(
      client: client, run_id: run_id,
      poll_interval: 0.01, max_duration: 5, sleeper: no_sleep,
      **opts
    )
  end

  describe "#wait_for_completion!" do
    it "returns immediately when first poll is SUCCEEDED" do
      allow(client).to receive(:get_run).with(run_id)
                                        .and_return({ "status" => "SUCCEEDED", "id" => run_id })

      result = make_poller.wait_for_completion!
      expect(result["status"]).to eq("SUCCEEDED")
      expect(client).to have_received(:get_run).once
    end

    it "polls until SUCCEEDED" do
      allow(client).to receive(:get_run).with(run_id).and_return(
        { "status" => "READY" },
        { "status" => "RUNNING" },
        { "status" => "SUCCEEDED" }
      )

      result = make_poller.wait_for_completion!
      expect(result["status"]).to eq("SUCCEEDED")
      expect(client).to have_received(:get_run).exactly(3).times
    end

    it "raises RunFailedError on FAILED status" do
      allow(client).to receive(:get_run).and_return({ "status" => "FAILED" })

      expect { make_poller.wait_for_completion! }
        .to raise_error(Scraping::RunFailedError, /FAILED/)
    end

    it "raises RunFailedError on ABORTED and TIMED-OUT" do
      %w[ABORTED TIMED-OUT].each do |status|
        allow(client).to receive(:get_run).and_return({ "status" => status })
        expect { make_poller.wait_for_completion! }
          .to raise_error(Scraping::RunFailedError, /#{status}/)
      end
    end

    it "aborts and raises TimeoutError when exceeding max_duration" do
      allow(client).to receive(:get_run).and_return({ "status" => "RUNNING" })
      allow(client).to receive(:abort_run)

      poller = described_class.new(
        client: client, run_id: run_id,
        poll_interval: 0.01, max_duration: 0.05,
        sleeper: ->(s) { sleep s }
      )

      expect { poller.wait_for_completion! }.to raise_error(Scraping::TimeoutError, /exceeded/)
      expect(client).to have_received(:abort_run).with(run_id)
    end
  end
end

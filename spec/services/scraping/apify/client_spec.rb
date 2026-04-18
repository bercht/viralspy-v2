require "rails_helper"

RSpec.describe Scraping::Apify::Client do
  let(:token) { "apify_api_test_token_123" }
  let(:client) { described_class.new(token: token) }

  describe "#initialize" do
    it "raises if token is blank" do
      expect { described_class.new(token: "") }.to raise_error(ArgumentError, /APIFY_API_TOKEN/)
      expect { described_class.new(token: nil) }.to raise_error(ArgumentError, /APIFY_API_TOKEN/)
    end
  end

  describe "#start_run" do
    it "returns data hash on 201" do
      stub_request(:post, "https://api.apify.com/v2/acts/apify~instagram-profile-scraper/runs")
        .with(
          headers: { "Authorization" => "Bearer #{token}", "Content-Type" => "application/json" },
          body: { "username" => [ "foo" ] }.to_json
        )
        .to_return(
          status: 201,
          body: { "data" => { "id" => "run_abc", "status" => "READY" } }.to_json,
          headers: { "Content-Type" => "application/json" }
        )

      data = client.start_run(
        actor_id: "apify~instagram-profile-scraper",
        input: { "username" => [ "foo" ] }
      )

      expect(data).to eq({ "id" => "run_abc", "status" => "READY" })
    end

    it "raises ProfileNotFoundError on 404" do
      stub_request(:post, /apify\.com/).to_return(status: 404, body: "")

      expect { client.start_run(actor_id: "x", input: {}) }
        .to raise_error(Scraping::ProfileNotFoundError)
    end

    it "raises RateLimitError on 429" do
      stub_request(:post, /apify\.com/).to_return(status: 429, body: "")

      expect { client.start_run(actor_id: "x", input: {}) }
        .to raise_error(Scraping::RateLimitError)
    end

    it "raises generic Error on 500" do
      stub_request(:post, /apify\.com/).to_return(status: 503, body: "oops")

      expect { client.start_run(actor_id: "x", input: {}) }
        .to raise_error(Scraping::Error, /server error/)
    end

    it "raises ParseError when envelope is missing" do
      stub_request(:post, /apify\.com/)
        .to_return(status: 200, body: { "weird" => true }.to_json, headers: { "Content-Type" => "application/json" })

      expect { client.start_run(actor_id: "x", input: {}) }
        .to raise_error(Scraping::ParseError, /envelope/)
    end

    it "raises TimeoutError on read timeout" do
      stub_request(:post, /apify\.com/).to_timeout

      expect { client.start_run(actor_id: "x", input: {}) }
        .to raise_error(Scraping::TimeoutError)
    end
  end

  describe "#get_run" do
    it "returns data hash" do
      stub_request(:get, "https://api.apify.com/v2/actor-runs/run_abc")
        .to_return(
          status: 200,
          body: { "data" => { "id" => "run_abc", "status" => "SUCCEEDED" } }.to_json,
          headers: { "Content-Type" => "application/json" }
        )

      data = client.get_run("run_abc")
      expect(data["status"]).to eq("SUCCEEDED")
    end
  end

  describe "#get_dataset_items" do
    it "returns array directly (no envelope)" do
      stub_request(:get, "https://api.apify.com/v2/actor-runs/run_abc/dataset/items")
        .with(query: { format: "json", clean: "true" })
        .to_return(
          status: 200,
          body: [ { "shortCode" => "ABC" }, { "shortCode" => "DEF" } ].to_json,
          headers: { "Content-Type" => "application/json" }
        )

      items = client.get_dataset_items("run_abc")
      expect(items.size).to eq(2)
      expect(items.first["shortCode"]).to eq("ABC")
    end
  end

  describe "#abort_run" do
    it "returns silently on success" do
      stub_request(:post, "https://api.apify.com/v2/actor-runs/run_abc/abort").to_return(status: 200, body: "")
      expect { client.abort_run("run_abc") }.not_to raise_error
    end

    it "swallows errors and logs" do
      stub_request(:post, /abort/).to_return(status: 500, body: "")
      allow(Rails.logger).to receive(:warn)
      expect { client.abort_run("run_abc") }.not_to raise_error
      expect(Rails.logger).to have_received(:warn).with(/abort_run failed/)
    end
  end
end

require "rails_helper"

RSpec.describe "VCR + WebMock configuration" do
  it "blocks real HTTP in tests (VCR or WebMock intercepts)" do
    # VCR hooks into WebMock; unhandled requests raise VCR's error (which
    # wraps WebMock's block). Either way, real HTTP never goes out.
    expect { HTTParty.get("https://example.com") }
      .to raise_error(VCR::Errors::UnhandledHTTPRequestError)
  end

  describe ApifyCassetteSanitizer do
    it "redacts sensitive keys at any depth" do
      input = {
        "ownerFullName" => "Real Name",
        "ownerUsername" => "userhandle",
        "nested" => {
          "biography" => "Real bio text",
          "followersCount" => 5000,
          "data" => [
            { "email" => "a@b.com", "shortCode" => "ABC" }
          ]
        }
      }

      output = described_class.redact(input)

      expect(output["ownerFullName"]).to eq("REDACTED_FULLNAME")
      expect(output["ownerUsername"]).to eq("userhandle")
      expect(output["nested"]["biography"]).to eq("REDACTED_BIO")
      expect(output["nested"]["followersCount"]).to eq(5000)
      expect(output["nested"]["data"][0]["email"]).to eq("REDACTED_EMAIL")
      expect(output["nested"]["data"][0]["shortCode"]).to eq("ABC")
    end
  end
end

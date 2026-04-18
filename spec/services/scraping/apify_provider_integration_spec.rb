require "rails_helper"

# Integration spec que roda contra o Apify real (via VCR cassette).
#
# PARA GRAVAR O CASSETTE (uma vez, manualmente):
#   1. Garantir APIFY_API_TOKEN no .env apontando para conta Apify com créditos
#   2. Remover o cassette existente (se houver) ou trocar record: :none para :new_episodes
#   3. Rodar: bundle exec rspec spec/services/scraping/apify_provider_integration_spec.rb
#   4. Reverter para record: :none
#   5. Auditar spec/fixtures/vcr_cassettes/scraping/apify_provider_scrape_profile.yml:
#      - APIFY_API_TOKEN deve aparecer como <APIFY_TOKEN>
#      - ownerFullName, biography devem aparecer como REDACTED_*
#      - ownerUsername, followersCount, likesCount mantidos como vieram
#   6. Commitar o cassette
RSpec.describe Scraping::ApifyProvider do
  describe "#scrape_profile (integration, real Apify)" do
    cassette_path = Rails.root.join(
      "spec/fixtures/vcr_cassettes/scraping/apify_provider_scrape_profile.yml"
    )

    if File.exist?(cassette_path)
      it "successfully scrapes @curtbercht with 10 posts",
         vcr: { cassette_name: "scraping/apify_provider_scrape_profile", record: :none } do
        provider = described_class.new
        result = provider.scrape_profile(handle: "curtbercht", max_posts: 10)

        expect(result).to be_success
        expect(result.profile_data[:instagram_handle]).to eq("curtbercht")
        expect(result.profile_data[:followers_count]).to be > 0
        expect(result.posts).not_to be_empty
        expect(result.posts.size).to be <= 10

        types = result.posts.map { |p| p[:post_type] }.uniq
        expect(types).to all(be_in(%i[reel carousel image]))

        if (reel = result.posts.find { |p| p[:post_type] == :reel })
          expect(reel[:video_url]).to be_present
          expect(reel[:video_url]).to start_with("https://")
        end
      end
    else
      it "skipped: cassette not recorded yet" do
        skip "Run with recording enabled to generate the cassette (see spec comment)"
      end
    end
  end
end

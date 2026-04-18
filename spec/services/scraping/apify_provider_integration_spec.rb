require "rails_helper"

# Integration spec que roda contra o Apify real (via VCR cassette).
#
# PARA GRAVAR O CASSETTE (uma vez, manualmente):
#   1. Garantir APIFY_API_TOKEN no .env
#   2. Setar record: :new_episodes em spec/rails_helper.rb (default_cassette_options)
#   3. Rodar este spec — ele vai bater na API real e gravar o cassette
#   4. Reverter para record: :none em rails_helper.rb
#   5. Auditar o cassette gerado em spec/fixtures/vcr_cassettes/scraping/
#   6. Commitar o cassette

RSpec.describe Scraping::ApifyProvider do
  describe "#scrape_profile (integration, real Apify)" do
    it "successfully scrapes @curtbercht with 10 posts",
       vcr: { cassette_name: "scraping/apify_provider_scrape_profile" } do
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
  end
end

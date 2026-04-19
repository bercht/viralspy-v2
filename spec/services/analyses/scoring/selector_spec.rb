require "rails_helper"

RSpec.describe Analyses::Scoring::Selector do
  describe ".select_count" do
    context "com max_posts=30 (legacy)" do
      it { expect(described_class.select_count(:reel, 30)).to eq(12) }
      it { expect(described_class.select_count(:carousel, 30)).to eq(5) }
      it { expect(described_class.select_count(:image, 30)).to eq(3) }
    end

    context "com max_posts=50 (default)" do
      it { expect(described_class.select_count(:reel, 50)).to eq(20) }
      it { expect(described_class.select_count(:carousel, 50)).to eq(8) }
      it { expect(described_class.select_count(:image, 50)).to eq(5) }
    end

    context "com max_posts=100 (máximo)" do
      it { expect(described_class.select_count(:reel, 100)).to eq(20) }
      it { expect(described_class.select_count(:carousel, 100)).to eq(8) }
      it { expect(described_class.select_count(:image, 100)).to eq(5) }
    end

    context "com max_posts=15" do
      it { expect(described_class.select_count(:reel, 15)).to eq(6) }
      it { expect(described_class.select_count(:carousel, 15)).to eq(2) }
      it { expect(described_class.select_count(:image, 15)).to eq(1) }
    end

    context "com max_posts=10 (mínimo)" do
      it { expect(described_class.select_count(:reel, 10)).to eq(4) }
      it { expect(described_class.select_count(:carousel, 10)).to eq(1) }
      it { expect(described_class.select_count(:image, 10)).to eq(1) }
    end

    context "tipo desconhecido" do
      it "raises KeyError" do
        expect { described_class.select_count(:story, 50) }.to raise_error(KeyError)
      end
    end

    context "aceita strings também" do
      it { expect(described_class.select_count("reel", 30)).to eq(12) }
    end
  end
end

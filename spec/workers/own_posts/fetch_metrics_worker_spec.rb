require 'rails_helper'

RSpec.describe OwnPosts::FetchMetricsWorker, type: :worker do
  let(:account)     { create(:account) }
  let(:own_profile) do
    ActsAsTenant.with_tenant(account) do
      create(:own_profile, :with_token, account: account)
    end
  end
  let(:own_post) do
    ActsAsTenant.with_tenant(account) do
      create(:own_post, account: account, own_profile: own_profile,
        instagram_post_id: 'ig_test_001', post_type: 'reel')
    end
  end
  let(:api_double) { instance_double(Meta::GraphApi) }

  before do
    allow(Meta::GraphApi).to receive(:new).and_return(api_double)
    allow(api_double).to receive(:fetch_post_insights).and_return(
      { 'reach' => 5000, 'plays' => 12000 }
    )
  end

  subject(:worker) { described_class.new }

  describe '#perform' do
    it 'retorna early se own_post não for encontrado' do
      expect { worker.perform(999_999) }.not_to raise_error
      expect(api_double).not_to have_received(:fetch_post_insights)
    end

    it 'retorna early se token do own_profile estiver inválido' do
      ActsAsTenant.with_tenant(account) do
        expired_profile = create(:own_profile, :with_expired_token, account: account)
        post = create(:own_post, account: account, own_profile: expired_profile,
          instagram_post_id: 'ig_expired')
        worker.perform(post.id)
      end
      expect(api_double).not_to have_received(:fetch_post_insights)
    end

    it 'chama fetch_post_insights com métricas de reel' do
      worker.perform(own_post.id)
      expect(api_double).to have_received(:fetch_post_insights).with(
        'ig_test_001',
        metric_names: Meta::GraphApi::REEL_METRICS
      )
    end

    it 'chama fetch_post_insights com métricas de carousel' do
      carousel_post = ActsAsTenant.with_tenant(account) do
        create(:own_post, account: account, own_profile: own_profile,
          instagram_post_id: 'ig_carousel', post_type: 'carousel')
      end
      worker.perform(carousel_post.id)
      expect(api_double).to have_received(:fetch_post_insights).with(
        'ig_carousel',
        metric_names: Meta::GraphApi::CAROUSEL_METRICS
      )
    end

    it 'chama fetch_post_insights com métricas de image' do
      image_post = ActsAsTenant.with_tenant(account) do
        create(:own_post, account: account, own_profile: own_profile,
          instagram_post_id: 'ig_image', post_type: 'image')
      end
      worker.perform(image_post.id)
      expect(api_double).to have_received(:fetch_post_insights).with(
        'ig_image',
        metric_names: Meta::GraphApi::IMAGE_METRICS
      )
    end

    it 'chama add_metrics_snapshot e salva o own_post' do
      worker.perform(own_post.id)
      own_post.reload
      expect(own_post.metrics['reach']).to eq(5000)
      expect(own_post.metrics['plays']).to eq(12000)
      expect(own_post.metrics_last_fetched_at).not_to be_nil
    end

    it 'não levanta exceção em AuthenticationError — apenas loga e retorna' do
      allow(api_double).to receive(:fetch_post_insights)
        .and_raise(Meta::GraphApi::AuthenticationError, 'Token inválido')
      expect { worker.perform(own_post.id) }.not_to raise_error
    end

    it 'levanta exceção em erros genéricos para permitir retry do Sidekiq' do
      allow(api_double).to receive(:fetch_post_insights)
        .and_raise(RuntimeError, 'Unexpected error')
      expect { worker.perform(own_post.id) }.to raise_error(RuntimeError, 'Unexpected error')
    end
  end
end

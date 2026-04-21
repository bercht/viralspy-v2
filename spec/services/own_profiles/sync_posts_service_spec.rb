require 'rails_helper'

RSpec.describe OwnProfiles::SyncPostsService do
  let(:account)     { create(:account) }
  let(:own_profile) do
    ActsAsTenant.with_tenant(account) do
      create(:own_profile, :with_token, account: account)
    end
  end
  let(:api_double) { instance_double(Meta::GraphApi) }

  let(:raw_reel) do
    {
      'id'         => 'ig_001',
      'media_type' => 'REEL',
      'caption'    => 'Meu reel',
      'permalink'  => 'https://ig.com/p/abc',
      'timestamp'  => 1.hour.ago.iso8601
    }
  end

  let(:default_metrics) { { 'reach' => 1000, 'plays' => 3000 } }

  before do
    allow(Meta::GraphApi).to receive(:new).and_return(api_double)
    allow(api_double).to receive(:fetch_media).and_return([raw_reel])
    allow(api_double).to receive(:fetch_post_insights).and_return(default_metrics)
    allow(OwnPosts::FetchMetricsWorker).to receive(:perform_at)
  end

  subject(:service) { described_class.new(own_profile) }

  describe '#call' do
    context 'quando o token está ausente' do
      let(:own_profile) do
        ActsAsTenant.with_tenant(account) do
          create(:own_profile, account: account, meta_access_token: nil,
            meta_token_expires_at: 1.day.from_now)
        end
      end

      it 'retorna failure com error_code :invalid_token' do
        result = service.call
        expect(result).to be_failure
        expect(result.error_code).to eq(:invalid_token)
      end
    end

    context 'quando o token está expirado' do
      let(:own_profile) do
        ActsAsTenant.with_tenant(account) do
          create(:own_profile, :with_expired_token, account: account)
        end
      end

      it 'retorna failure com error_code :invalid_token' do
        result = service.call
        expect(result).to be_failure
        expect(result.error_code).to eq(:invalid_token)
      end
    end

    context 'happy path' do
      it 'retorna success com contagem de synced' do
        result = service.call
        expect(result).to be_success
        expect(result.data[:synced]).to eq(1)
        expect(result.data[:failed]).to eq(0)
      end

      it 'cria OwnPost para cada post retornado pela API' do
        expect { service.call }.to change { OwnPost.count }.by(1)
        ActsAsTenant.with_tenant(account) do
          post = OwnPost.last
          expect(post.instagram_post_id).to eq('ig_001')
          expect(post.post_type).to eq('reel')
        end
      end

      it 'não duplica OwnPost quando instagram_post_id já existe' do
        service.call
        expect { service.call }.not_to change { OwnPost.count }
      end

      it 'atualiza caption quando post já existe (upsert)' do
        ActsAsTenant.with_tenant(account) do
          create(:own_post, account: account, own_profile: own_profile,
            instagram_post_id: 'ig_001', caption: 'caption antiga')
        end
        updated_raw = raw_reel.merge('caption' => 'caption nova')
        allow(api_double).to receive(:fetch_media).and_return([updated_raw])

        service.call

        ActsAsTenant.with_tenant(account) do
          post = OwnPost.find_by(instagram_post_id: 'ig_001')
          expect(post.caption).to eq('caption nova')
        end
      end

      it 'persiste métricas no OwnPost criado' do
        service.call
        ActsAsTenant.with_tenant(account) do
          post = OwnPost.find_by(instagram_post_id: 'ig_001')
          expect(post.metrics['reach']).to eq(1000)
          expect(post.metrics['plays']).to eq(3000)
        end
      end

      it 'não falha se fetch_post_insights levantar erro (post salvo sem métricas)' do
        allow(api_double).to receive(:fetch_post_insights).and_raise(RuntimeError, 'API error')
        result = service.call
        expect(result).to be_success
        ActsAsTenant.with_tenant(account) do
          post = OwnPost.find_by(instagram_post_id: 'ig_001')
          expect(post).not_to be_nil
          expect(post.metrics).to eq({})
        end
      end

      it 'agenda FetchMetricsWorker para D+1, D+7, D+30 para posts novos' do
        service.call
        expect(OwnPosts::FetchMetricsWorker).to have_received(:perform_at).exactly(3).times
      end
    end

    context 'mapeamento de media_type' do
      {
        'REEL'           => 'reel',
        'CAROUSEL_ALBUM' => 'carousel',
        'IMAGE'          => 'image',
        'VIDEO'          => 'reel'
      }.each do |media_type, expected_post_type|
        it "mapeia #{media_type} → post_type #{expected_post_type}" do
          raw = raw_reel.merge('id' => "ig_#{media_type}", 'media_type' => media_type)
          allow(api_double).to receive(:fetch_media).and_return([raw])
          service.call
          ActsAsTenant.with_tenant(account) do
            post = OwnPost.find_by(instagram_post_id: "ig_#{media_type}")
            expect(post.post_type).to eq(expected_post_type)
          end
        end
      end
    end

    context 'posts antigos (posted_at muito no passado)' do
      it 'não agenda FetchMetricsWorker quando todos os D+ já passaram' do
        old_raw = raw_reel.merge('id' => 'ig_old', 'timestamp' => 60.days.ago.iso8601)
        allow(api_double).to receive(:fetch_media).and_return([old_raw])
        service.call
        expect(OwnPosts::FetchMetricsWorker).not_to have_received(:perform_at)
      end
    end

    context 'erros da Graph API' do
      it 'retorna failure com error_code :auth_error em AuthenticationError' do
        allow(api_double).to receive(:fetch_media)
          .and_raise(Meta::GraphApi::AuthenticationError, 'Token inválido')
        result = service.call
        expect(result).to be_failure
        expect(result.error_code).to eq(:auth_error)
      end

      it 'retorna failure com error_code :rate_limit em RateLimitError' do
        allow(api_double).to receive(:fetch_media)
          .and_raise(Meta::GraphApi::RateLimitError, 'Rate limit')
        result = service.call
        expect(result).to be_failure
        expect(result.error_code).to eq(:rate_limit)
      end

      it 'retorna failure com error_code :unknown em erro genérico' do
        allow(api_double).to receive(:fetch_media)
          .and_raise(RuntimeError, 'Unexpected error')
        result = service.call
        expect(result).to be_failure
        expect(result.error_code).to eq(:unknown)
      end
    end

    context 'quando a API retorna lista vazia' do
      it 'retorna failure' do
        allow(api_double).to receive(:fetch_media).and_return([])
        result = service.call
        expect(result).to be_failure
      end
    end
  end
end

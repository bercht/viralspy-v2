require 'rails_helper'

RSpec.describe Meta::GraphApi do
  let(:token) { 'fake_token_123' }
  let(:api)   { described_class.new(access_token: token) }
  let(:base_url) { 'https://graph.instagram.com/v21.0' }

  def stub_get(path, body:, status: 200)
    stub_request(:get, /#{Regexp.escape(base_url)}#{Regexp.escape(path)}/)
      .to_return(
        status: status,
        body: body.to_json,
        headers: { 'Content-Type' => 'application/json' }
      )
  end

  describe '#fetch_media' do
    it 'retorna array de posts com campos padrão' do
      stub_get('/me/media', body: {
        data: [
          { id: '123', caption: 'Post teste', media_type: 'REEL',
            permalink: 'https://ig.com/p/abc', timestamp: '2024-01-01T10:00:00+0000' }
        ]
      })
      result = api.fetch_media
      expect(result).to be_an(Array)
      expect(result.first['id']).to eq('123')
    end

    it 'retorna array vazio quando data está ausente' do
      stub_get('/me/media', body: {})
      expect(api.fetch_media).to eq([])
    end

    it 'passa limit e fields customizados como query params' do
      stub = stub_request(:get, /#{Regexp.escape(base_url)}\/me\/media/)
        .with(query: hash_including('limit' => '10', 'fields' => 'id,caption'))
        .to_return(status: 200, body: { data: [] }.to_json,
          headers: { 'Content-Type' => 'application/json' })
      api.fetch_media(fields: 'id,caption', limit: 10)
      expect(stub).to have_been_requested
    end
  end

  describe '#fetch_post_insights' do
    it 'retorna hash plano com métricas parseadas' do
      stub_get('/123/insights', body: {
        data: [
          { 'name' => 'reach',  'values' => [{ 'value' => 1200 }] },
          { 'name' => 'plays',  'values' => [{ 'value' => 3400 }] },
          { 'name' => 'saved',  'values' => [{ 'value' => 45 }] }
        ]
      })
      result = api.fetch_post_insights('123', metric_names: %w[reach plays saved])
      expect(result['reach']).to eq(1200)
      expect(result['plays']).to eq(3400)
      expect(result['saved']).to eq(45)
    end

    it 'retorna hash vazio quando data está ausente' do
      stub_get('/456/insights', body: {})
      result = api.fetch_post_insights('456', metric_names: %w[reach])
      expect(result).to eq({})
    end
  end

  describe '#fetch_profile' do
    it 'retorna hash com dados do perfil' do
      stub_get('/me', body: {
        id: '17841400000000001',
        username: 'meuperfil',
        followers_count: 5000
      })
      result = api.fetch_profile
      expect(result['username']).to eq('meuperfil')
      expect(result['followers_count']).to eq(5000)
    end
  end

  describe 'tratamento de erros' do
    it 'levanta AuthenticationError em 401' do
      stub_request(:get, /graph.instagram.com/)
        .to_return(status: 401, body: '{}',
          headers: { 'Content-Type' => 'application/json' })
      expect { api.fetch_media }.to raise_error(Meta::GraphApi::AuthenticationError, /401/)
    end

    it 'levanta RateLimitError em 429' do
      stub_request(:get, /graph.instagram.com/)
        .to_return(status: 429, body: '{}',
          headers: { 'Content-Type' => 'application/json' })
      expect { api.fetch_media }.to raise_error(Meta::GraphApi::RateLimitError, /429/)
    end

    it 'levanta ApiError quando response tem campo error' do
      stub_request(:get, /graph.instagram.com/)
        .to_return(
          status: 200,
          body: { error: { message: 'Invalid token', code: 190 } }.to_json,
          headers: { 'Content-Type' => 'application/json' }
        )
      expect { api.fetch_media }.to raise_error(Meta::GraphApi::ApiError, /Invalid token/)
    end

    it 'ApiError inclui o code da API' do
      stub_request(:get, /graph.instagram.com/)
        .to_return(
          status: 200,
          body: { error: { message: 'Err', code: 190 } }.to_json,
          headers: { 'Content-Type' => 'application/json' }
        )
      begin
        api.fetch_media
      rescue Meta::GraphApi::ApiError => e
        expect(e.code).to eq(190)
      end
    end

    it 'levanta ApiError em status HTTP inesperado' do
      stub_request(:get, /graph.instagram.com/)
        .to_return(status: 500, body: 'Internal Error',
          headers: { 'Content-Type' => 'text/plain' })
      expect { api.fetch_media }.to raise_error(Meta::GraphApi::ApiError, /HTTP 500/)
    end
  end
end

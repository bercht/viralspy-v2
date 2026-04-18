require "httparty"

module Scraping
  module Apify
    class Client
      include HTTParty

      base_uri "https://api.apify.com/v2"

      DEFAULT_OPEN_TIMEOUT = 10
      DEFAULT_READ_TIMEOUT = 30

      def initialize(token: ENV.fetch("APIFY_API_TOKEN", nil))
        @token = token.to_s.strip
        raise ArgumentError, "APIFY_API_TOKEN is not set" if @token.empty?
      end

      def start_run(actor_id:, input:)
        response = perform_request do
          self.class.post(
            "/acts/#{actor_id}/runs",
            headers: headers_json,
            body: input.to_json,
            timeout: DEFAULT_READ_TIMEOUT,
            open_timeout: DEFAULT_OPEN_TIMEOUT
          )
        end
        handle_response!(response).fetch("data")
      end

      def get_run(run_id)
        response = perform_request do
          self.class.get(
            "/actor-runs/#{run_id}",
            headers: headers_json,
            timeout: DEFAULT_READ_TIMEOUT,
            open_timeout: DEFAULT_OPEN_TIMEOUT
          )
        end
        handle_response!(response).fetch("data")
      end

      def get_dataset_items(run_id)
        response = perform_request do
          self.class.get(
            "/actor-runs/#{run_id}/dataset/items",
            headers: headers_json,
            query: { format: "json", clean: "true" },
            timeout: DEFAULT_READ_TIMEOUT,
            open_timeout: DEFAULT_OPEN_TIMEOUT
          )
        end
        raise_for_status!(response)
        response.parsed_response
      end

      def abort_run(run_id)
        response = self.class.post(
          "/actor-runs/#{run_id}/abort",
          headers: headers_json,
          timeout: DEFAULT_READ_TIMEOUT,
          open_timeout: DEFAULT_OPEN_TIMEOUT
        )
        raise_for_status!(response)
        nil
      rescue StandardError => e
        Rails.logger.warn("Scraping::Apify::Client#abort_run failed for #{run_id}: #{e.message}")
        nil
      end

      private

      attr_reader :token

      def headers_json
        {
          "Content-Type" => "application/json",
          "Authorization" => "Bearer #{token}"
        }
      end

      def handle_response!(response)
        raise_for_status!(response)
        parsed = response.parsed_response
        unless parsed.is_a?(Hash) && parsed.key?("data")
          raise Scraping::ParseError, "expected {data: ...} envelope, got: #{parsed.inspect[0..200]}"
        end
        parsed
      end

      def raise_for_status!(response)
        code = response.code
        return if code.between?(200, 299)

        case code
        when 401, 403
          raise Scraping::Error, "apify auth failed (#{code})"
        when 404
          raise Scraping::ProfileNotFoundError, "apify 404: resource not found"
        when 429
          raise Scraping::RateLimitError, "apify rate limit (#{code})"
        when 500..599
          raise Scraping::Error, "apify server error (#{code})"
        else
          raise Scraping::Error, "apify unexpected status #{code}: #{response.body&.slice(0, 200)}"
        end
      end

      def perform_request
        yield
      rescue Net::ReadTimeout, Net::OpenTimeout, HTTParty::Error => e
        raise Scraping::TimeoutError, "apify http timeout: #{e.message}"
      end
    end
  end
end

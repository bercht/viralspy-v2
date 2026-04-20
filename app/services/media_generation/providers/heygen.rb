module MediaGeneration
  module Providers
    class Heygen < MediaGeneration::BaseProvider
      include HTTParty
      base_uri "https://api.heygen.com"

      GENERATE_ENDPOINT  = "/v2/video/generate"
      STATUS_ENDPOINT    = "/v1/video.status.get"
      USER_INFO_ENDPOINT = "/v1/user.info"
      DIMENSION          = { width: 720, height: 1280 }.freeze

      def start_generation(script:, avatar_id:, voice_id:, title:)
        body = build_generate_body(script: script, avatar_id: avatar_id,
                                   voice_id: voice_id, title: title)
        response = self.class.post(GENERATE_ENDPOINT, headers: headers, body: body.to_json)
        handle_start_response(response)
      rescue Net::OpenTimeout, Net::ReadTimeout
        Result.new(success: false, error: "Request timed out", error_code: :timeout)
      end

      def check_status(job_id:)
        response = self.class.get(STATUS_ENDPOINT, headers: headers, query: { video_id: job_id })
        handle_status_response(response)
      rescue Net::OpenTimeout, Net::ReadTimeout
        Result.new(success: false, error: "Request timed out", error_code: :timeout)
      end

      def validate_api_key
        response = self.class.get(USER_INFO_ENDPOINT, headers: headers)
        response.code == 200
      rescue StandardError
        false
      end

      private

      def headers
        { "X-Api-Key" => api_key, "Content-Type" => "application/json" }
      end

      def build_generate_body(script:, avatar_id:, voice_id:, title:)
        {
          video_inputs: [
            {
              character: { type: "avatar", avatar_id: avatar_id, avatar_style: "normal" },
              voice: { type: "text", input_text: script, voice_id: voice_id },
              background: { type: "color", value: "#FAFAFA" }
            }
          ],
          dimension: DIMENSION,
          title: title,
          caption: false
        }
      end

      def handle_start_response(response)
        case response.code
        when 200, 202
          job_id = response.parsed_response&.dig("data", "video_id")
          return Result.new(success: false, error: "Missing video_id in response",
                            error_code: :parse_error) if job_id.nil?

          Result.new(success: true, job_id: job_id, status: "pending")
        when 401
          Result.new(success: false, error: "Invalid API key", error_code: :invalid_api_key)
        when 429
          Result.new(success: false, error: "Rate limit exceeded", error_code: :rate_limit)
        else
          msg = response.parsed_response&.dig("message") || "HTTP #{response.code}"
          Result.new(success: false, error: msg, error_code: :generation_failed)
        end
      rescue StandardError => e
        Result.new(success: false, error: e.message, error_code: :parse_error)
      end

      def handle_status_response(response)
        if response.code == 401
          return Result.new(success: false, error: "Invalid API key", error_code: :invalid_api_key)
        end

        data = response.parsed_response&.dig("data")
        return Result.new(success: false, error: "Invalid response shape",
                          error_code: :parse_error) if data.nil?

        case data["status"]
        when "pending", "processing"
          Result.new(success: true, status: data["status"], job_id: data["video_id"])
        when "completed"
          Result.new(success: true, status: "completed", job_id: data["video_id"],
                     output_url: data["video_url"])
        when "failed"
          Result.new(success: false, status: "failed",
                     error: data["error"] || "Generation failed",
                     error_code: :generation_failed)
        else
          Result.new(success: false, error: "Unknown status: #{data['status']}",
                     error_code: :parse_error)
        end
      rescue StandardError => e
        Result.new(success: false, error: e.message, error_code: :parse_error)
      end
    end
  end
end

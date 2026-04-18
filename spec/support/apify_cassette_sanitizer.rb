module ApifyCassetteSanitizer
  REDACT_KEYS = {
    "ownerFullName" => "REDACTED_FULLNAME",
    "fullName"      => "REDACTED_FULLNAME",
    "biography"     => "REDACTED_BIO",
    "email"         => "REDACTED_EMAIL",
    "businessEmail" => "REDACTED_EMAIL",
    "externalUrl"   => "REDACTED_URL"
  }.freeze

  def self.redact(obj)
    case obj
    when Array then obj.map { |el| redact(el) }
    when Hash
      obj.each_with_object({}) do |(k, v), acc|
        acc[k] = REDACT_KEYS.key?(k) ? REDACT_KEYS[k] : redact(v)
      end
    else
      obj
    end
  end
end

VCR.configure do |config|
  config.before_record do |interaction|
    body = interaction.response.body
    next unless body.is_a?(String) && (body.start_with?("[") || body.start_with?("{"))

    begin
      parsed = JSON.parse(body)
      sanitized = ApifyCassetteSanitizer.redact(parsed)
      interaction.response.body = JSON.generate(sanitized)
    rescue JSON::ParserError
      # corpo não é JSON — deixa passar
    end
  end
end

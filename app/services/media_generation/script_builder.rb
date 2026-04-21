module MediaGeneration
  class ScriptBuilder
    MAX_SCRIPT_CHARS = 1500

    def self.build(suggestion:)
      new(suggestion: suggestion).build
    end

    def initialize(suggestion:)
      @suggestion = suggestion
    end

    def build
      parts = []
      parts << format_hook if hook.present?
      body = clean_caption
      parts << body if body.present?
      parts << default_cta unless has_cta?(body)

      script = parts.join("\n\n")
      script.truncate(MAX_SCRIPT_CHARS, omission: ".")
    end

    private

    attr_reader :suggestion

    def hook
      suggestion.hook.to_s.strip
    end

    def format_hook
      h = hook.chomp(".").chomp(",")
      h.end_with?("!", "?") ? h : "#{h}!"
    end

    def clean_caption
      text = suggestion.caption_draft.to_s.dup
      text.gsub!(/#\S+/, "")
      text.gsub!(/@\S+/, "")
      text.gsub!(%r{https?://\S+}, "")
      text.strip.squeeze("\n")
    end

    def has_cta?(text)
      cta_patterns = [ /segue/, /me chama/, /comenta/, /salva/, /compartilha/,
                      /acessa/, /clica/, /link na bio/ ]
      cta_patterns.any? { |pattern| text.match?(pattern) }
    end

    def default_cta
      "Me segue para mais dicas como essa!"
    end
  end
end

module Analyses
  module PromptRenderer
    module_function

    PROMPTS_DIR = Rails.root.join("app/prompts").freeze

    def render(step:, kind:, locals: {})
      path = PROMPTS_DIR.join(step, "#{kind}.erb")
      raise ArgumentError, "Prompt not found: #{path}" unless path.exist?

      template = ERB.new(path.read, trim_mode: "-")
      b = binding
      locals.each { |k, v| b.local_variable_set(k, v) }
      template.result(b).strip
    end
  end
end

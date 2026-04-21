module SettingsHelper
  def llm_provider_options(available_providers)
    options = []
    options << [ "OpenAI", "openai" ] if available_providers.include?("openai")
    options << [ "Anthropic", "anthropic" ] if available_providers.include?("anthropic")
    options << [ "Nenhum configurado", "" ] if options.empty?
    options
  end

  def transcription_provider_options(available_providers)
    options = []
    options << [ "AssemblyAI (recomendado)", "assemblyai" ] if available_providers.include?("assemblyai")
    options << [ "OpenAI", "openai" ] if available_providers.include?("openai")
    options << [ "Nenhum configurado", "" ] if options.empty?
    options
  end

  def analysis_model_options(provider)
    case provider.to_s
    when "openai"
      [
        [ "gpt-4o-mini (recomendado, mais barato)", "gpt-4o-mini" ],
        [ "gpt-4o", "gpt-4o" ]
      ]
    when "anthropic"
      [
        [ "claude-haiku-4-5-20251001 (mais barato)", "claude-haiku-4-5-20251001" ],
        [ "claude-sonnet-4-6 (melhor qualidade)", "claude-sonnet-4-6" ]
      ]
    else
      [ [ "— selecione um provider —", "" ] ]
    end
  end

  def generation_model_options(provider)
    case provider.to_s
    when "anthropic"
      [
        [ "claude-sonnet-4-6 (recomendado)", "claude-sonnet-4-6" ],
        [ "claude-opus-4-6 (máxima qualidade)", "claude-opus-4-6" ],
        [ "claude-haiku-4-5-20251001 (mais barato)", "claude-haiku-4-5-20251001" ]
      ]
    when "openai"
      [
        [ "gpt-4o (recomendado)", "gpt-4o" ],
        [ "gpt-4o-mini (mais barato)", "gpt-4o-mini" ]
      ]
    else
      [ [ "— selecione um provider —", "" ] ]
    end
  end
end

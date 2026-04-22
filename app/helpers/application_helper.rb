module ApplicationHelper
  ANALYSIS_STEPS = [
    { status: :scraping, label: "Buscando posts" },
    { status: :scoring, label: "Pontuando posts" },
    { status: :transcribing, label: "Transcrevendo Reels" },
    { status: :analyzing, label: "Analisando conteúdo" },
    { status: :generating_suggestions, label: "Gerando sugestões" },
    { status: :completed, label: "Concluído" }
  ].freeze

  STATUS_ORDER = %i[
    pending
    scraping
    scoring
    transcribing
    analyzing
    generating_suggestions
    completed
  ].freeze

  def analysis_step_state(step_status, current_status)
    step_idx = STATUS_ORDER.index(step_status.to_sym) || 0
    current_idx = STATUS_ORDER.index(current_status.to_sym) || 0

    if current_idx > step_idx
      :done
    elsif current_idx == step_idx
      :active
    else
      :pending
    end
  end

  def analysis_failed_step_status(analysis)
    previous = analysis.try(:status_before_last_save)&.to_sym
    return previous if STATUS_ORDER.include?(previous) && previous != :pending

    message = analysis.error_message.to_s.downcase

    return :scraping if message.match?(/scrapestep|scraping failed|apify|scrape/)
    return :scoring if message.match?(/scoreandselectstep|score|scoring|metric/)
    return :transcribing if message.match?(/transcribestep|transcrib|assembly|audio/)
    return :analyzing if message.match?(/analyzestep|analyz|insight/)
    return :generating_suggestions if message.match?(/generatesuggestionsstep|suggestion|llm returned/)

    :generating_suggestions
  end
end

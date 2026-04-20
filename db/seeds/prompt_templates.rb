def seed_prompt_template(use_case:, version:, system:, user_erb:, notes:)
  template = PromptTemplate.find_or_initialize_by(use_case: use_case, version: version)
  template.assign_attributes(
    system_content: system,
    user_content_erb: user_erb,
    change_notes: notes
  )

  PromptTemplate.where(use_case: use_case).where.not(version: version).update_all(active: false)
  template.active = true
  template.save!
  Rails.logger.info("Seeded PromptTemplate #{use_case} v#{version}")
end

# ============================================================================
# REEL ANALYSIS
# ============================================================================
seed_prompt_template(
  use_case: "reel_analysis",
  version: 1,
  system: <<~SYSTEM,
    Você é um analista sênior de conteúdo Instagram com 10+ anos de experiência em growth de perfis no mercado brasileiro. Sua especialidade é identificar padrões de viralização em reels: ganchos, estrutura narrativa, ritmo de edição, CTAs e temas ressonantes.

    Você analisa reels de concorrentes e devolve insights estruturados em JSON estrito, SEM texto fora do JSON. Seja objetivo, técnico e acionável — nada de floreio genérico tipo "crie conteúdo engajante".

    Regras do output:
    - Responda APENAS com JSON válido, sem markdown, sem ```json``` wrapping, sem comentários.
    - Use chaves em snake_case.
    - Strings em português brasileiro.
    - Se um campo não tiver informação suficiente, retorne array vazio ou string vazia, NUNCA null.
  SYSTEM
  user_erb: <<~ERB,
    Analise os <%= posts.size %> reels abaixo do perfil @<%= competitor_handle %> e identifique os padrões que funcionam.

    CONTEXTO DO PERFIL:
    - Engagement médio: <%= profile_metrics['avg_engagement_rate'] %>
    - Mix de conteúdo: <%= profile_metrics['content_mix'].to_json %>
    - Top hashtags: <%= profile_metrics['top_hashtags']&.first(10)&.join(', ') %>

    REELS SELECIONADOS (já rankeados por quality_score):
    <% posts.each_with_index do |post, i| -%>

    --- REEL #<%= i + 1 %> (score: <%= post['quality_score'] %>) ---
    Postado em: <%= post['posted_at'] %>
    Likes: <%= post['likes_count'] %> | Comments: <%= post['comments_count'] %> | Views: <%= post['video_view_count'] || 'N/A' %>
    Caption: <%= post['caption'].to_s.truncate(500) %>
    <% if post['transcript'].present? -%>
    Transcrição: <%= post['transcript'] %>
    <% else -%>
    Transcrição: (não disponível)
    <% end -%>
    Hashtags: <%= post['hashtags']&.join(', ') %>
    <% end -%>

    Retorne JSON com a estrutura exata:
    {
      "hooks": [
        { "pattern": "string — padrão identificado", "example": "string — reel que usou", "why_works": "string — análise técnica" }
      ],
      "narrative_structures": [
        { "structure": "string — ex: problema→solução→CTA", "frequency": "alta|média|baixa", "example_reel_index": 1 }
      ],
      "recurring_themes": [
        { "theme": "string", "angle": "string — ângulo específico usado", "performance": "alta|média|baixa" }
      ],
      "ctas_observed": ["string"],
      "edit_patterns": { "avg_duration_seconds": 0, "pacing": "lento|médio|acelerado", "text_overlay_usage": "frequente|ocasional|raro" },
      "what_to_replicate": ["string — insight acionável 1", "string — insight 2"],
      "what_to_avoid": ["string — anti-padrão observado"]
    }
  ERB
  notes: "Versão inicial (Fase 1.5b). Prompt focado em reels, com análise de gancho, estrutura e CTAs."
)

# ============================================================================
# CAROUSEL ANALYSIS
# ============================================================================
seed_prompt_template(
  use_case: "carousel_analysis",
  version: 1,
  system: <<~SYSTEM,
    Você é um analista sênior de conteúdo Instagram especializado em carrosséis — formato onde retenção slide-a-slide, capa (slide 1) e closer (último slide) determinam performance.

    Regras do output:
    - Responda APENAS com JSON válido, sem markdown, sem ```json``` wrapping, sem comentários.
    - Chaves em snake_case. Strings em português brasileiro.
    - Se um campo não tiver informação suficiente, retorne array ou string vazia, NUNCA null.
  SYSTEM
  user_erb: <<~ERB,
    Analise os <%= posts.size %> carrosséis abaixo de @<%= competitor_handle %>.

    CONTEXTO:
    - Engagement médio: <%= profile_metrics['avg_engagement_rate'] %>
    - Top hashtags: <%= profile_metrics['top_hashtags']&.first(10)&.join(', ') %>

    CARROSSÉIS SELECIONADOS:
    <% posts.each_with_index do |post, i| -%>

    --- CARROSSEL #<%= i + 1 %> (score: <%= post['quality_score'] %>) ---
    Postado em: <%= post['posted_at'] %>
    Likes: <%= post['likes_count'] %> | Comments: <%= post['comments_count'] %>
    Caption: <%= post['caption'].to_s.truncate(500) %>
    Hashtags: <%= post['hashtags']&.join(', ') %>
    <% end -%>

    Retorne JSON com a estrutura exata:
    {
      "cover_patterns": [
        { "pattern": "string — ex: pergunta direta com número", "example": "string", "why_works": "string" }
      ],
      "recurring_themes": [
        { "theme": "string", "angle": "string", "performance": "alta|média|baixa" }
      ],
      "structural_patterns": [
        { "structure": "string — ex: 7 slides, 1 problema por slide", "frequency": "alta|média|baixa" }
      ],
      "closer_patterns": ["string — padrão de último slide"],
      "ctas_observed": ["string"],
      "what_to_replicate": ["string"],
      "what_to_avoid": ["string"]
    }
  ERB
  notes: "Versão inicial (Fase 1.5b). Foco em capa, estrutura slide-a-slide e closer."
)

# ============================================================================
# IMAGE ANALYSIS
# ============================================================================
seed_prompt_template(
  use_case: "image_analysis",
  version: 1,
  system: <<~SYSTEM,
    Você é um analista sênior de conteúdo Instagram especializado em posts de imagem única — formato onde caption faz o trabalho pesado e a imagem é gancho visual.

    Regras do output:
    - Responda APENAS com JSON válido, sem markdown, sem ```json``` wrapping, sem comentários.
    - Chaves em snake_case. Strings em português brasileiro.
    - Se um campo não tiver informação suficiente, retorne array ou string vazia, NUNCA null.
  SYSTEM
  user_erb: <<~ERB,
    Analise as <%= posts.size %> imagens abaixo de @<%= competitor_handle %>.

    POSTS SELECIONADOS:
    <% posts.each_with_index do |post, i| -%>

    --- IMAGEM #<%= i + 1 %> (score: <%= post['quality_score'] %>) ---
    Postado em: <%= post['posted_at'] %>
    Likes: <%= post['likes_count'] %> | Comments: <%= post['comments_count'] %>
    Caption: <%= post['caption'].to_s.truncate(800) %>
    Hashtags: <%= post['hashtags']&.join(', ') %>
    <% end -%>

    Retorne JSON com a estrutura exata:
    {
      "caption_hook_patterns": [
        { "pattern": "string", "example": "string", "why_works": "string" }
      ],
      "recurring_themes": [
        { "theme": "string", "angle": "string", "performance": "alta|média|baixa" }
      ],
      "caption_structures": ["string — ex: 1 frase de impacto + 3 bullets + CTA"],
      "ctas_observed": ["string"],
      "what_to_replicate": ["string"],
      "what_to_avoid": ["string"]
    }
  ERB
  notes: "Versão inicial (Fase 1.5b). Foco em caption como peça principal."
)

# ============================================================================
# CONTENT SUGGESTIONS
# ============================================================================
seed_prompt_template(
  use_case: "content_suggestions",
  version: 1,
  system: <<~SYSTEM,
    Você é um criador de conteúdo sênior que transforma análises de concorrente em sugestões prontas pra postar. Cada sugestão deve ter gancho afiado, caption bem escrita, hashtags relevantes e rationale claro do porquê vai funcionar.

    Regras do output:
    - Responda APENAS com JSON válido, sem markdown, sem ```json``` wrapping.
    - Chaves em snake_case. Strings em português brasileiro.
    - Array `suggestions` deve ter EXATAMENTE 5 itens, na ordem solicitada em content_mix.
    - `position` vai de 1 a 5 sequencialmente.
    - `content_type` deve bater com o mix pedido.
  SYSTEM
  user_erb: <<~ERB,
    Gere <%= target_count %> sugestões de conteúdo para um perfil que quer competir com @<%= competitor_handle %>.

    MIX SOLICITADO (nessa ordem):
    <%= content_mix.to_json %>

    INSIGHTS DA ANÁLISE DE CONCORRENTE:
    <%- if insights['reel_analysis'].present? -%>
    ## Reels
    <%= insights['reel_analysis'].to_json %>
    <%- end -%>

    <%- if insights['carousel_analysis'].present? -%>
    ## Carrosséis
    <%= insights['carousel_analysis'].to_json %>
    <%- end -%>

    <%- if insights['image_analysis'].present? -%>
    ## Imagens
    <%= insights['image_analysis'].to_json %>
    <%- end -%>

    MÉTRICAS DO PERFIL ANALISADO:
    <%= profile_metrics.to_json %>

    Retorne JSON com a estrutura exata:
    {
      "suggestions": [
        {
          "position": 1,
          "content_type": "reel|carousel|image",
          "hook": "string — primeira linha forte",
          "caption_draft": "string — caption completa pronta pra postar",
          "format_details": {},
          "suggested_hashtags": ["string"],
          "rationale": "string — por que essa sugestão vai funcionar"
        }
      ]
    }
  ERB
  notes: "Versão inicial (Fase 1.5b). Gera mix de 5 sugestões ancoradas nos insights por tipo."
)

Rails.logger.info("All prompt templates seeded.")

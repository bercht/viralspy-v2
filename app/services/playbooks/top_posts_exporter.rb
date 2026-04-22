module Playbooks
  class TopPostsExporter
    SECTION_DIVIDER = ("#" * 37).freeze
    POST_DIVIDER    = ("- " * 18).freeze

    def initialize(playbook)
      @playbook = playbook
    end

    def call
      analyses = @playbook.analyses
                          .where(status: :completed)
                          .includes(:competitor, posts: :competitor)

      return empty_export if analyses.none?

      all_posts = analyses.flat_map do |analysis|
        analysis.posts
                .where(post_type: [ :reel, :carousel ])
                .where("quality_score > 0")
                .to_a
      end

      deduped = all_posts
        .group_by(&:instagram_post_id)
        .transform_values { |dupes| dupes.max_by(&:quality_score) }
        .values

      by_competitor = deduped.group_by { |p| p.competitor.instagram_handle }

      reels_count    = deduped.count(&:reel?)
      carousel_count = deduped.count(&:carousel?)

      sections = [
        build_header(analyses.size, by_competitor.size, reels_count, carousel_count)
      ]

      by_competitor.each do |handle, posts|
        competitor = posts.first.competitor
        sections << build_competitor_section(handle, competitor, posts)
      end

      sections.join("\n\n")
    end

    private

    def build_header(analyses_count, competitors_count, reels_count, carousel_count)
      <<~TEXT.strip
        ViralSpy — Top Posts Export
        Playbook: #{@playbook.name}
        Nicho: #{@playbook.niche.presence || "–"}
        #{analyses_count} análises | #{competitors_count} competitors | #{reels_count} reels | #{carousel_count} carrosséis
        Gerado em: #{Time.current.strftime("%d/%m/%Y %H:%M")}
      TEXT
    end

    def build_competitor_section(handle, competitor, posts)
      followers = competitor.followers_count ? "#{competitor.followers_count} seguidores" : "seguidores desconhecidos"
      reels     = posts.select(&:reel?).sort_by { |p| -(p.quality_score || 0) }
      carousels = posts.select(&:carousel?).sort_by { |p| -(p.quality_score || 0) }

      lines = []
      lines << SECTION_DIVIDER
      lines << "@#{handle} (#{followers})"
      lines << SECTION_DIVIDER

      lines << build_type_block("REELS", reels, include_transcript: true)
      lines << build_type_block("CARROSSÉIS", carousels, include_transcript: false)

      lines.join("\n")
    end

    def build_type_block(title, posts, include_transcript:)
      lines = []
      lines << "\n--- #{title} (#{posts.size} posts) ---"

      if posts.empty?
        lines << "(nenhum post desta análise)"
        return lines.join("\n")
      end

      posts.each_with_index do |post, i|
        lines << "\n#{format_post(post, i + 1, include_transcript:)}"
        lines << POST_DIVIDER
      end

      lines.join("\n")
    end

    def format_post(post, index, include_transcript:)
      lines = []
      lines << "[#{index}] quality_score: #{post.quality_score.to_f.round(4)}"
      lines << "Data: #{post.posted_at&.strftime("%d/%m/%Y") || "–"}"

      metrics = "Likes: #{post.likes_count} | Comentários: #{post.comments_count}"
      metrics += " | Views: #{post.video_view_count || "–"}" if post.reel?
      lines << metrics

      lines << "Hashtags: #{post.hashtags.presence&.join(", ") || "–"}"
      lines << ""
      lines << "Caption:"
      lines << (post.caption.presence || "(sem caption)")

      if include_transcript
        lines << ""
        lines << "Transcrição:"
        lines << (post.transcript.presence || "(sem transcrição)")
      end

      lines.join("\n")
    end

    def empty_export
      <<~TEXT.strip
        ViralSpy — Top Posts Export
        Playbook: #{@playbook.name}
        Gerado em: #{Time.current.strftime("%d/%m/%Y %H:%M")}

        Nenhuma análise completa vinculada a este playbook.
      TEXT
    end
  end
end

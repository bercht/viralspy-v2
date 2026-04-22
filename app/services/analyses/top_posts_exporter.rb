module Analyses
  class TopPostsExporter
    TOP_REELS_COUNT = 8
    TOP_CAROUSELS_COUNT = 5
    DIVIDER = ("-" * 37).freeze
    SECTION_DIVIDER = ("=" * 37).freeze

    def initialize(analysis)
      @analysis = analysis
      @competitor = analysis.competitor
    end

    def call
      [ header, reels_section, carousels_section ].join("\n\n")
    end

    private

    def header
      <<~TEXT.strip
        ViralSpy — Top Posts Export
        Competitor: @#{@competitor.instagram_handle}
        Análise: #{@analysis.id} | Data: #{@analysis.created_at.strftime("%d/%m/%Y")}
        Gerado em: #{Time.current.strftime("%d/%m/%Y %H:%M")}
      TEXT
    end

    def reels_section
      posts = @analysis.posts.by_type(:reel).ranked.limit(TOP_REELS_COUNT)
      build_section("REELS", posts, include_transcript: true)
    end

    def carousels_section
      posts = @analysis.posts.by_type(:carousel).ranked.limit(TOP_CAROUSELS_COUNT)
      build_section("CARROSSÉIS", posts, include_transcript: false)
    end

    def build_section(title, posts, include_transcript:)
      lines = []
      lines << SECTION_DIVIDER
      lines << "#{title} (#{posts.size} posts)"
      lines << SECTION_DIVIDER

      if posts.empty?
        lines << "(nenhum post encontrado para este tipo)"
        return lines.join("\n")
      end

      posts.each_with_index do |post, i|
        lines << format_post(post, i + 1, include_transcript:)
        lines << DIVIDER
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

      hashtags_str = post.hashtags.presence&.join(", ") || "–"
      lines << "Hashtags: #{hashtags_str}"
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
  end
end

module AnalysesHelper
  def completed_locals(analysis)
    return {} unless analysis.completed?

    {
      profile_metrics: analysis.profile_metrics || {},
      posts_by_type: analysis.posts.where(selected_for_analysis: true).group_by(&:post_type),
      suggestions: analysis.content_suggestions.ordered
    }
  end

  def known_format_keys(content_type)
    case content_type
    when "reel"     then %w[duration_seconds structure]
    when "carousel" then %w[slides]
    when "image"    then %w[composition_tips text_overlay]
    else []
    end
  end
end

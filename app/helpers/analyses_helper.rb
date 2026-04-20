module AnalysesHelper
  def completed_locals(analysis)
    return {} unless analysis.completed?

    {
      profile_metrics: analysis.profile_metrics || {},
      posts_by_type: analysis.posts.where(selected_for_analysis: true).group_by(&:post_type),
      suggestions: analysis.content_suggestions.ordered
    }
  end
end

module Analyses
  module Scoring
    module Formula
      module_function

      MIN_INTERACTIONS = 3
      MIN_AGE = 6.hours

      def calculate(post:, followers:)
        return 0.0 unless eligible?(post)
        return 0.0 if followers.to_i <= 0

        engagement = post.likes_count + (post.comments_count * 3)
        base_rate = engagement.to_f / followers

        days = days_since(post.posted_at)
        maturity = [ days / 7.0, 1.0 ].min
        maturity_boost = 1.0 / [ maturity, 0.1 ].max

        (base_rate * maturity_boost * 1_000_000).round(4)
      end

      def eligible?(post)
        return false unless post.posted_at.present?
        return false if post.likes_count + post.comments_count < MIN_INTERACTIONS
        return false if post.posted_at > MIN_AGE.ago

        true
      end

      def days_since(posted_at)
        [ ((Time.current - posted_at) / 1.day), 0.25 ].max
      end
    end
  end
end

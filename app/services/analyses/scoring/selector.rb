module Analyses
  module Scoring
    module Selector
      SELECTION_RATIOS = { reel: 0.40, carousel: 0.17, image: 0.10 }.freeze
      SELECTION_CAPS   = { reel: 20,   carousel: 8,    image: 5    }.freeze

      module_function

      def select_count(post_type, max_posts)
        key = post_type.to_sym
        ratio = SELECTION_RATIOS.fetch(key)
        cap   = SELECTION_CAPS.fetch(key)

        [ (max_posts.to_i * ratio).floor, cap ].min
      end
    end
  end
end

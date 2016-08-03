module Optimizely
  module Helpers
    module Group
      OVERLAPPING_POLICY = 'overlapping'
      RANDOM_POLICY = 'random'

      module_function

      def random_policy?(group)
        group['policy'] == RANDOM_POLICY
      end
    end
  end
end

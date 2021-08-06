# frozen_string_literal: true

module Apidiesel
  module Processors
    class Hash < ContainerAttribute
      def process(subset, path: nil, element_idx: nil)
        children.map { |child| child.execute(subset, path: path) }
                .reduce({}) { |memo, element| memo.merge(element) }
      end
    end
  end
end

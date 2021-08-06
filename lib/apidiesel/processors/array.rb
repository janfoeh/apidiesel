# frozen_string_literal: true

module Apidiesel
  module Processors
    class Array < ContainerAttribute
      def child
        children.first
      end

      def children=(value)
        value = [*value]

        unless value.one? && value.first.is_a?(Processors::Hash)
          raise "arrays only allow for a single Hash subprocessor"
        end

        @children = value
      end

      def process(subset, path: nil, element_idx: nil)
        subset.map
              .with_index do |element, idx|
          child.execute(element, path: path, element_idx: idx)
        end
      end
    end
  end
end

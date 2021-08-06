# frozen_string_literal: true

module Apidiesel
  module Processors
    class ContainerAttribute < Attribute
      attr_accessor :children

      def after_initialize
        @children = []
      end

      def display(indent = 0)
        [super].concat(
          children.map { |child| child.display(indent + 2) }
        ).join("\n")
      end
    end
  end
end

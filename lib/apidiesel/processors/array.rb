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

      def process(subset, path: nil, element_idx: nil, response_model: nil, response_model_klass: nil)
        # For primitive arrays (without child processors, eg. `array :some_value`)
        # there is nothing else to do but return the raw value
        return subset unless child

        subset.map
              .with_index do |element, idx|
          child.execute(
            element,
            path: path,
            response_model: response_model,
            response_model_klass: response_model_klass
          )
        end
      end

      def to_model(parent_klass = nil)
        attribute_name = write_key

        if child.nil?
          raise "Primitive arrays cannot be root elements" if parent_klass.nil?

          parent_klass.class_eval do
            attribute attribute_name
          end

          unless optional
            parent_klass.class_eval do
              validates attribute_name, presence: true
            end
          end

          return
        end

        klass = child.to_model(klass)

        return klass unless parent_klass

        parent_klass.class_eval do
          attribute attribute_name

          define_method("#{attribute_name}_model") do
            klass
          end
        end

        unless optional
          parent_klass.class_eval do
            validates attribute_name, presence: true
          end
        end
      end
    end
  end
end

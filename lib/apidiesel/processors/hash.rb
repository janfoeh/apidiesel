# frozen_string_literal: true

module Apidiesel
  module Processors
    class Hash < ContainerAttribute
      def execute(input, path:, element_idx: nil, response_model: nil, response_model_klass: nil)
        if response_model_klass
          response_model = response_model_klass.new

          super

          response_model
        else
          super
        end
      end

      def process(subset, path: nil, element_idx: nil, response_model: nil, **_kargs)
        return nil if subset.nil? || subset.empty?

        result =
          children.each_with_object({}) do |child, result|
            result[child.write_key] =
              child.execute(
                subset,
                path: path,
                response_model: response_model,
                response_model_klass: response_model&.attribute_model(child.write_key)
              )
          end

        if response_model
          result.each { |write_key, value| response_model.send("#{write_key}=", value) }
          response_model
        else
          result
        end
      end

      def to_model(parent_klass = nil)
        # Hashes are always represented in their own
        # ActiveModel
        klass = Class.new(Apidiesel::ResponseModel)
        klass.klass_name = "Apidiesel::ResponseModel::Hash"
        klass.write_key  = write_key

        children.each do |child|
          child.to_model(klass)
        end

        return klass unless parent_klass

        attribute_name = write_key

        # If we've been given a `parent_klass`, we're a
        # Hash nested within another
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

        (parent_klass.submodels ||= []) << attribute_name
      end

      def serializable_hash(options = {})
        result = attributes.transform_keys(&:to_sym).slice(*basic_attributes)

        submodel_attributes.each do |submodel_attribute|
          result[submodel_attribute] = send(submodel_attribute)&.serializable_hash(options)
        end

        result
      end
    end
  end
end

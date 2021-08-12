# frozen_string_literal: true

module Apidiesel
  # ResponseModel is the ActiveModel instance you receive back when you call an endpoint
  # with the `active_model: true` argument.
  class ResponseModel
    include ActiveModel::Model
    include ActiveModel::Attributes
    include ActiveModel::Validations
    include ActiveModel::Dirty
    include ActiveModel::Serializers::JSON

    validate do
      submodels.compact
                .reject(&:valid?)
                .each do |invalid_submodel|
        errors.add(:base, "Nested item :#{invalid_submodel.write_key} is invalid")
      end
    end

    class << self
      attr_accessor :klass_name
      attr_accessor :submodels
      attr_accessor :write_key

      def model_name
        ActiveModel::Name.new(self, nil, klass_name)
      end
    end

    def attribute_model(attr_name)
      if respond_to?("#{attr_name}_model")
        send("#{attr_name}_model")
      end
    end

    def write_key
      self.class.write_key
    end

    def inspect
      basic_attribute_values =
        basic_attributes(as_hash: true).map { |key, value| "#{key}: #{value}"}

      output =
        ["<##{self.class.klass_name}:0x#{object_id.to_s(16)} #{basic_attribute_values}>"]

      submodels(as_hash: true).each do |name, submodel|
        output << "#{name}: #{submodel.inspect}"
      end

      output.join("\n")
    end

    private

    def submodel_attribute_names
      self.class.submodels || []
    end

    def submodels(as_hash: false)
      fetch_attributes(submodel_attribute_names, as_hash: as_hash)
    end

    def basic_attribute_names
      attributes.keys.map(&:to_sym) - submodel_attribute_names
    end

    def basic_attributes(as_hash: false)
      fetch_attributes(basic_attribute_names, as_hash: as_hash)
    end

    def fetch_attributes(names, as_hash: false)
      if as_hash
        names.each_with_object({}) do |name, hash|
          hash[name] = send(name)
        end
      else
        names.map { |name| send(name) }
      end
    end
  end
end

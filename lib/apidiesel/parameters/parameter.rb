# frozen_string_literal: true

module Apidiesel
  module Parameters
    class Parameter
      attr_reader :input_name
      attr_reader :output_name
      attr_reader :fetch
      attr_reader :default
      attr_reader :submit
      attr_reader :optional
      attr_reader :optional_if_present
      attr_reader :required_if_present
      attr_reader :typecast
      attr_reader :allowed_values
      attr_reader :kargs

      def initialize(input_name:, output_name: nil, fetch: false, submit: true, default: nil,
                    optional: nil, optional_if_present: nil, required_if_present: nil, typecast: nil,
                    allowed_values: nil, **kargs)
        @input_name          = input_name
        @output_name         = output_name || input_name
        @fetch               = fetch
        @default             = default
        @submit              = submit
        @optional            = optional
        @optional_if_present = optional_if_present
        @required_if_present = required_if_present
        @typecast            = typecast
        @kargs               = kargs

        after_initialize if respond_to?(:after_initialize)
      end

      def process(parameters:, config:)
        result = {}
        value  = parameters[input_name]

        if fetch && value.nil?
          value = fetch_from(config)
        end

        if value.blank? && !optional?(parameters)
          raise Apidiesel::InputError, "missing argument #{input_name}"
        end

        if value.present? && allowed_values
          unless allowed_values.include?(value)
            raise Apidiesel::InputError, "'#{value}' is not a valid value for #{input_name}"
          end

          value = allowed_values[value] if allowed_values.is_a? Hash
        end

        value = value.send(typecast) if value && typecast.is_a?(Symbol)

        value ||= default

        if respond_to?(:after_processing)
          value = after_processing(value, parameters: parameters, config: config)
        end

        result[output_name] = value if value

        result
      end

      private

      def fetch_from(config)
        lookup_name =
          fetch.is_a?(Symbol) ? fetch : input_name

        config.fetch(lookup_name)
      end

      def optional?(parameters)
        result = optional

        if optional_if_present
          result = true if parameters[optional_if_present].present?
        end

        if required_if_present
          result = false if parameters[required_if_present].present?
        end

        result
      end
    end
  end
end

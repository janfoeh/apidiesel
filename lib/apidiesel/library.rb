# frozen_string_literal: true

module Apidiesel
  class Library
    class << self
      def filters
        @filters ||= {}
      end

      def formatters
        @formatters ||= {}
      end

      def response(name = :default, scenario: :default, attributes_optional: false, attributes_allow_nil: true, **args, &block)
        builder = FilterBuilder.new(optional: attributes_optional, allow_nil: attributes_allow_nil)

        builder.instance_eval(&block)

        filters    = self.filters[name] ||= {}
        formatters = self.formatters[name] ||= {}

        [*scenario].each do |scenario_label|
          filters[scenario_label]     ||= []
          formatters[scenario_label]  ||= []

          filters[scenario_label].replace(builder.response_filters)
          formatters[scenario_label].replace(builder.response_formatters)

          if args[:unnested_hash]
            formatters[scenario_label] << lambda do |_, response|
              if response.is_a?(Hash) && response.keys.length == 1
                response.values.first
              else
                response
              end
            end
          end
        end
      end
    end
  end
end

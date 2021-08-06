# frozen_string_literal: true

module Apidiesel
  class Library
    class << self
      def processors
        @processors ||= {}
      end

      def response(name = :default, scenario: :default, attributes_optional: false,
                    attributes_allow_nil: true, &block)
        builder =
          FilterBuilder.new(optional: attributes_optional, allow_nil: attributes_allow_nil)

        builder.instance_eval(&block)

        processors = self.processors[name] ||= {}

        [*scenario].each do |scenario_label|
          processors[scenario_label] = builder.root_processor
        end
      end
    end
  end
end

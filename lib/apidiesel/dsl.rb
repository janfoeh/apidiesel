# frozen_string_literal: true

module Apidiesel
  module Dsl
    # Defines the input parameters expected for this API endpoint.
    #
    # @example
    #   expects do
    #     string :query
    #     integer :per_page, :optional => true, :default => 10
    #   end
    #
    # See the {Apidiesel::Dsl::ExpectationBuilder ExpectationBuilder} instance methods
    # for more information on what to use within `expect`.
    #
    # @macro [attach] expects
    #   @yield [Apidiesel::Dsl::ExpectationBuilder]
    def expects(&block)
      builder = ExpectationBuilder.new
      builder.instance_eval(&block)

      config.parameter_validations.replace(builder.parameter_validations)
      config.parameters_to_filter.replace(builder.parameters_to_filter)
    end

    # Defines the expected content and format of the response for this API endpoint.
    #
    # @example
    #   responds_with do
    #     string :user_id
    #   end
    #
    # See the {Apidiesel::Dsl::FilterBuilder} instance methods for more information
    # on what to use within `responds_with`.
    #
    # You can define multiple _scenarios_ in which different responses are returned by the API,
    # such as successful and failure situations. Out of the box, Apidiesel supports scenarios
    # labelled `:http_<http status code>` (eg. `:http_204`) or `:http_<http status code class>xx`
    # (eg. `:http_2xx`). If one exists, it is used over the default one:
    #
    # @example
    # ```ruby
    # responds_with(scenario: :http_403) do
    #   # no body in response for 403
    # end
    #
    # responds_with(scenario: [:http_4xx, http_5xx]) do
    #   integer :error_code
    #   string  :error_message
    # end
    #
    # responds_with do
    #   string :firstname
    #   string :lastname
    # end
    # ```
    #
    # If you have different needs for scenario selection, you can configure a different
    # detector in your endpoints `config`:
    #
    # ```ruby
    #   class MyEndpoint < Apidiesel::Endpoint
    #     config.response_detector ->(request:, config:) {
    #       # Your Proc receives the current `Apidiesel::Request`, plus
    #       # the endpoints `Apidiesel::Config`, and is expected to return
    #       # either a specific scenario name `Symbol` or `:default`
    #     }
    # ```
    #
    # @macro [attach] responds_with
    #   @param scenario             [Symbol, Array<Symbol>]
    #   @param attributes_optional  [Boolean] default for all attributes: if true, no exception
    #     is raised if an attribute is not present in the response
    #   @param attributes_allow_nil [Boolean] default for all attributes: if true, no exception
    #     will be raised if an attributes value is not of the defined type, but nil
    #   @yield [Apidiesel::Dsl::FilterBuilder]
    def responds_with(scenario: :default, attributes_optional: false, attributes_allow_nil: true, **args, &block)
      builder = FilterBuilder.new(optional: attributes_optional, allow_nil: attributes_allow_nil)

      builder.instance_eval(&block)

      [*scenario].each do |scenario_label|
        config.response_filters[scenario_label]     ||= []
        config.response_formatters[scenario_label]  ||= []

        config.response_filters[scenario_label].replace(builder.response_filters)
        config.response_formatters[scenario_label].replace(builder.response_formatters)

        if args[:unnested_hash]
          config.response_formatters[scenario_label] << lambda do |_, response|
            if response.is_a?(Hash) && response.keys.length == 1
              response.values.first
            else
              response
            end
          end
        end
      end
    end

    # Semantic sugar for `responds_with` blocks with an explicit `scenario` label
    #
    # @see {responds_with}
    def responds_with_on(scenario, **kargs, &block)
      responds_with(scenario: scenario, **kargs, &block)
    end

    def action(label, &block)
      subklass       = Class.new(self, &block)
      subklass.label = label

      actions << subklass
    end
  end
end

# frozen_string_literal: true

module Apidiesel

  # An abstract base class for API endpoints.
  class Endpoint
    extend Dsl

    attr_accessor :api
    attr_reader :config

    # accessors for class instance variables
    # (class-level variables, not shared with subclasses)
    class << self
      include Handlers

      attr_accessor :label

      def config
        @config ||=
          Config.new do
            url_value             nil
            url_args              nil
            http_method           nil
            http_basic_username   nil
            http_basic_password   nil
            parameter_validations []
            parameters_to_filter  []
            response_filters      []
            response_formatters   []
            parameter_formatter   nil
            parameters_as         :auto
          end
      end

      %i(http_method http_basic_username http_basic_password parameters_as).each do |config_key|
        define_method(config_key) do |value = nil|
          value.present? ? config.set(config_key, value) : config.fetch(config_key)
        end
      end

      def actions
        @actions ||= []
      end

      def for(label)
        actions.find { |action| action.label == label }
      end

      def format_parameters(&block)
        config.set(:parameter_formatter, block)
      end

      # Defines this Endpoints URL, or modifies the base URL set on `Api`
      #
      # Given keyword arguments such as `path:` will be applied to
      # the `URI` object supplied to `Api.url`.
      #
      # Accepts a `Proc`, which will be called at request time with
      # the URL constructed so far and the current `Request` object.
      #
      # A string value and all keyword arguments can contain
      # placeholders for all arguments supplied to the endpoint in
      # Rubys standard `String.%` syntax.
      #
      # @example
      #   class Api < Apidiesel::Api
      #     url 'https://foo.example'
      #
      #     register_endpoints
      #   end
      #
      #   module Endpoints
      #     # modify the base URL set on `Api`
      #     class EndpointA < Apidiesel::Endpoint
      #       url path: '/endpoint_a'
      #     end
      #
      #     # replace the base URL set on `Api`
      #     class EndpointB < Apidiesel::Endpoint
      #       url 'https://subdomain.foo.example'
      #     end
      #
      #     # modify the base URL set on `Api` with a
      #     # 'username' argument placeholder
      #     class EndpointC < Apidiesel::Endpoint
      #       url path: '/endpoint_c/%{username}'
      #
      #       expects do
      #         string :username, submit: false
      #       end
      #     end
      #
      #     # dynamically determine the URL with a
      #     # `Proc` object
      #     class EndpointD < Apidiesel::Endpoint
      #       url ->(url, request) {
      #         url.path = '/' + request.endpoint_arguments[:username]
      #                                 .downcase
      #         url
      #       }
      #
      #       expects do
      #         string :username, submit: false
      #       end
      #     end
      #   end
      #
      # @overload url(value)
      #   @param value [String, URI] a complete URL string or `URI`
      #
      # @overload url(**kargs)
      #   @option **kargs [String] any method name valid on Rubys `URI::Generic`
      #
      # @overload url(value)
      #   @param value [Proc] a callback that returns a URL string at request time.
      #     Receives the URL contructed so far and the current `Request` instance.
      def url(value = nil, **kargs)
        if value && kargs.any?
          raise ArgumentError, "you cannot supply both argument and keyword args"
        end

        config.set(:url_value, value) if value
        config.set(:url_args, kargs) if kargs.any?
      end

      # When subclassing to create an `action`, we chain our configuration into
      # the subclasses config
      def inherited(subklass)
        subklass.config.parent = config
      end
    end

    # Returns current class name formatted for use as a method name
    #
    # Example: {Apidiesel::Endpoints::Foo} will return `foo`
    #
    # @return [String] the demodulized, underscored name of the current Class
    def self.name_as_method
      ::ActiveSupport::Inflector.underscore( ::ActiveSupport::Inflector.demodulize(self.name) )
    end
    private_class_method :name_as_method

    # @param api [Apidiesel::Api] a reference to the parent Api object
    def initialize(api)
      @api = api

      parent_config        = self.class.config.dup
      parent_config.parent = api.config

      @config = Config.new(parent: parent_config)
    end

    # Performs the endpoint-specific input validations on `*args` according to the endpoints
    # `expects` block, executes the API request and prepares the data according to the
    # endpoints `responds_with` block.
    #
    # @option **args see specific, non-abstract `Apidiesel::Endpoint`
    # @return [Apidiesel::Request]
    def build_request(**args)
      params = {}

      config.parameter_validations.each do |validation|
        validation.call(api, config, args, params)
      end

      if config.parameter_formatter
        params = config.parameter_formatter.call(params)
      else
        params.except!(*config.parameters_to_filter)
      end

      unless config.include_nil_parameters
        params.delete_if { |key, value| value.nil? }
      end

      request = Apidiesel::Request.new(endpoint: self, endpoint_arguments: args, parameters: params)
      request.url = build_url(args, request)

      request
    end

    def process_response(response_data)
      processed_result = {}

      response_data = case response_data
      when Hash
        response_data.deep_symbolize_keys
      when Array
        response_data.map do |element|
          element.is_a?(Hash) ? element.deep_symbolize_keys : element
        end
      else
        response_data
      end

      if config.response_filters.none? && config.response_formatters.none?
        return response_data
      end

      config.response_filters.each do |filter|
        response_data = filter.call(response_data)
      end

      config.response_formatters.each do |filter|
        processed_result = filter.call(response_data, processed_result)
      end

      processed_result
    end

      protected

    # @return [URI]
    def build_url(endpoint_arguments, request)
      url = case config.url_value
      when String
        URI( config.url_value % endpoint_arguments )
      when URI
        config.url_value
      when Proc
        config.url_value.call(base_url, request)
      when nil
        config.base_url
      end

      url_args = config.url_args.transform_values do |value|
        value % endpoint_arguments
      end

      if append_path = url_args.delete(:append_path)
        url_string = url.to_s

        unless url_string.end_with?("/")
          url_string << "/"
        end

        append_path.delete_prefix!("/")

        url = URI.join(url_string, append_path)
      end

      url_args.each do |name, value|
        url.send("#{name}=", value)
      end

      url
    end

    def logger
      api.logger
    end
  end
end

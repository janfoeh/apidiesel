module Apidiesel

  # An abstract base class for API endpoints.
  class Action
    extend Dsl

    # accessors for class instance variables
    # (class-level variables, not shared with subclasses)
    class << self
      include Handlers

      attr_reader :url_value, :url_args

      # Array for storing parameter validation closures. These closures are called with the request
      # parameters before the request is made and have the opportunity to check and modify them.
      def parameter_validations
        @parameter_validations ||= []
      end

      # Array for storing action argument names which are not to be submitted as parameters
      def parameters_to_filter
        @parameters_to_filter ||= []
      end

      # Array for storing filter closures. These closures are called with the received data
      # after a request is made and have the opportunity to modify or check it before the
      # data is returned
      def response_filters
        @response_filters ||= []
      end

      def response_formatters
        @response_formatters ||= []
      end

      def format_parameters(&block)
        @parameter_formatter = block
      end

      def parameter_formatter
        @parameter_formatter
      end

      # Combined getter/setter for this actions' endpoint
      #
      # @param [String] value
      def endpoint(value = nil)
        if value
          @endpoint = value
        else
          @endpoint
        end
      end

      # Defines this Actions URL, or modifies the base URL set on `Api`
      #
      # Given keyword arguments such as `path:` will be applied to
      # the `URI` object supplied to `Api.url`.
      #
      # Accepts a `Proc`, which will be called at request time with
      # the URL constructed so far and the current `Request` object.
      #
      # A string value and all keyword arguments can contain
      # placeholders for all arguments supplied to the action in
      # Rubys standard `String.%` syntax.
      #
      # @example
      #   class Api < Apidiesel::Api
      #     url 'https://foo.example'
      #
      #     register_actions
      #   end
      #
      #   module Actions
      #     # modify the base URL set on `Api`
      #     class ActionA < Apidiesel::Action
      #       url path: '/action_a'
      #     end
      #
      #     # replace the base URL set on `Api`
      #     class ActionB < Apidiesel::Action
      #       url 'https://subdomain.foo.example'
      #     end
      #
      #     # modify the base URL set on `Api` with a
      #     # 'username' argument placeholder
      #     class ActionC < Apidiesel::Action
      #       url path: '/action_c/%{username}'
      #
      #       expects do
      #         string :username, submit: false
      #       end
      #     end
      #
      #     # dynamically determine the URL with a
      #     # `Proc` object
      #     class ActionD < Apidiesel::Action
      #       url ->(url, request) {
      #         url.path = '/' + request.action_arguments[:username]
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
      #   @param [String, URI] value a complete URL string or `URI`
      #
      # @overload url(**kargs)
      #   @option **kargs [String] any method name valid on Rubys `URI::Generic`
      #
      # @overload url(value)
      #   @param [Proc] value a callback that returns a URL string at request time.
      #                       Receives the URL contructed so far and the current
      #                       `Request` instance.
      def url(value = nil, **kargs)
        if value && kargs.any?
          raise ArgumentError, "you cannot supply both argument and keyword args"
        end

        @url_value  = value
        @url_args   = kargs
      end

      # Combined getter/setter for the HTTP method used
      #
      # Falls back to the Api setting if blank.
      #
      # @param [String] value
      def http_method(value = nil)
        if value
          @http_method = value
        else
          @http_method
        end
      end
    end

    attr_accessor :api

    # Hook method that is called by {Apidiesel::Api} to register this Action on itself.
    #
    # Example: when {Apidiesel::Api} calls this method inherited on {Apidiesel::Actions::Foo},
    # it itself gains a `Apidiesel::Api#foo` instance method to instantiate and call the Foo action.
    #
    # Executed in {Apidiesel::Api} through
    #
    #   Apidiesel::Actions.constants.each do |action|
    #     Apidiesel::Actions.const_get(action).register(self)
    #   end
    def self.register(caller)
      caller.class_eval <<-EOT
        def #{name_as_method}(*args)
          execute_request(#{name}, *args)
        end
      EOT
    end

      private

    # Returns current class name formatted for use as a method name
    #
    # Example: {Apidiesel::Actions::Foo} will return `foo`
    #
    # @return [String] the demodulized, underscored name of the current Class
    def self.name_as_method
      ::ActiveSupport::Inflector.underscore( ::ActiveSupport::Inflector.demodulize(self.name) )
    end

      public

    # @param [Apidiesel::Api] api A reference to the parent Api object
    def initialize(api)
      @api = api
    end

    # Getter/setter for the parameters to be used for creating the API request. Prefilled
    # with the `op` action key.
    #
    # @return [Hash]
    def parameters
      @parameters ||= {}
    end

    def endpoint
      self.class.endpoint
    end

    def http_method
      self.class.http_method || @api.class.http_method || :get
    end

    # Performs the action-specific input validations on `*args` according to the actions
    # `expects` block, executes the API request and prepares the data according to the
    # actions `responds_with` block.
    #
    # @option **args see specific, non-abstract `Apidiesel::Action`
    # @return [Apidiesel::Request]
    def build_request(**args)
      params = {}

      self.class.parameter_validations.each do |validation|
        validation.call(args, params)
      end

      if self.class.parameter_formatter
        params = self.class.parameter_formatter.call(params)
      else
        params.except!(*self.class.parameters_to_filter)
      end

      request = Apidiesel::Request.new(action: self, action_arguments: args, parameters: params)
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

      if self.class.response_filters.none? && self.class.response_formatters.none?
        return response_data
      end

      self.class.response_filters.each do |filter|
        response_data = filter.call(response_data)
      end

      self.class.response_formatters.each do |filter|
        processed_result = filter.call(response_data, processed_result)
      end

      processed_result
    end

      protected

    # @return [URI]
    def build_url(action_arguments, request)
      url = case self.class.url_value
      when String
        URI( self.class.url_value % action_arguments )
      when URI
        self.class.url_value
      when Proc
        self.class.url_value.call(base_url, request)
      when nil
        base_url
      end

      url_args = self.class.url_args.transform_values do |value|
        value % action_arguments
      end

      url_args.each do |name, value|
        url.send("#{name}=", value)
      end

      url
    end

    def base_url
      @api.class.url.nil? ? URI('http://') : @api.class.url.dup
    end

    # @return [Hash] Apidiesel configuration options
    def config
      Apidiesel::CONFIG[environment]
    end

    def logger
      @api.logger
    end
  end
end

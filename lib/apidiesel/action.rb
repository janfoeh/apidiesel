module Apidiesel

  # An abstract base class for API endpoints.
  class Action
    extend Dsl

    # accessors for class instance variables
    # (class-level variables, not shared with subclasses)
    class << self
      include Handlers

      attr_reader :url_args, :url_proc

      # Hash for storing validation closures. These closures are called with the request
      # parameters before the request is made and have the opportunity to check and modify them.
      def parameter_validations
        @parameter_validations ||= []
      end

      # Hash for storing filter closures. These closures are called with the received data
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

      # Combined getter/setter for this actions URL
      #
      # Falls back to the Api setting if blank.
      #
      # @param [String] value
      def url(value = nil, **args, &block)
        if block_given?
          @url_proc = block
          return @url_proc
        end

        return @url unless value || args.any?

        if value
          @url = URI.parse(value)
        else
          @url_args = args
        end
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

    attr_accessor :api, :parameters

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
      @api        = api
      @parameters = {}
    end

    def endpoint
      self.class.endpoint
    end

    def base_url
      if self.class.url.nil? || self.class.url.is_a?(Proc)
        @api.class.url.dup
      else
        self.class.url.dup
      end
    end

    def url
      parametrize_url
      build_url
    end

    def http_method
      self.class.http_method || @api.class.http_method
    end

    # Performs the action-specific input validations on `*args` according to the actions
    # `expects` block, executes the API request and prepares the data according to the
    # actions `responds_with` block.
    #
    # @param [Hash] *args see specific, non-abstract `Apidiesel::Action`
    # @return [Apidiesel::Request]
    def build_request(*args)
      args = args && args.first.is_a?(Hash) ? args.first : {}

      params = {}

      self.class.parameter_validations.each do |validation|
        validation.call(args, params)
      end

      if self.class.parameter_formatter
        params = self.class.parameter_formatter.call(params)
      end

      Apidiesel::Request.new action: self, parameters: params
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

    def parametrize_url
      return unless self.class.url_proc

      result = self.class.url_proc.call(self)

      if result.is_a?(Hash)
        @url_args = result
      elsif result.is_a?(String)
        @url = result
      end
    end

    def build_url
      url       = @url || self.class.url || @api.class.url
      url_args  = @url_args || self.class.url_args

      if url_args
        url_args.each do |key, value|
          url.send("#{key}=", value)
        end
      end

      url
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

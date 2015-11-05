module Apidiesel

  # An abstract base class for API endpoints.
  class Action
    extend Dsl

    # accessors for class instance variables
    # (class-level variables, not shared with subclasses)
    class << self

      # Hash for storing validation closures. These closures are called with the request
      # parameters before the request is made and have the opportunity to check and modify them.
      def parameter_validations
        @parameter_validations ||= []
      end

      # Hash for storing filter closures. These closures are called with the received data
      # after a request is made and have the opportunity to modify or check it before the
      # data is returned
      def data_filters
        @data_filters ||= []
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
      def url(value = nil)
        if value
          @url = value
        else
          @url
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
          execute_request #{name}.new(self).build_request(*args)
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

    def url
      self.class.url || @api.class.url
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

    def process_response(response_hash)
      processed_result = {}

      response_hash.symbolize_keys!

      return response_hash if self.class.data_filters.none?

      self.class.data_filters.each do |filter|
        filter.call(response_hash, processed_result)
      end

      processed_result
    end

      protected

    # @return [Hash] Apidiesel configuration options
    def config
      Apidiesel::CONFIG[environment]
    end

    def logger
      @api.logger
    end
  end
end

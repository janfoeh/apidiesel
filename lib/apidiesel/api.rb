module Apidiesel

  # This is the abstract main interface class for the Apidiesel gem. It is meant to be
  # inherited from:
  #
  #   module MyApi
  #     class Api < Apidiesel::Api
  #     end
  #   end
  #
  # Apidiesel expects there to be an `Actions` namespace alongside the same scope,
  # in which it can find the individual endpoint definitions for this API:
  #
  #   module MyApi
  #     class Api < Apidiesel::Api
  #     end
  #
  #     module Actions
  #       class Action1; end
  #       class Action2; end
  #     end
  #   end
  #
  #   # Registers endpoints Action1 and Action2
  #   MyApi::Api.register_actions
  #
  class Api
    class << self
      def request_handlers
        @request_handlers ||= []
      end

      def response_handlers
        @response_handlers ||= []
      end

      def config(key = nil, value = nil)
        @config ||= {}

        if key && value
          @config[key] = value
        else
          @config
        end
      end

      # Combined getter/setter for this actions URL
      #
      # Falls back to the Api setting if blank.
      #
      # @param [String] value
      def url(base_url = nil)
        if base_url
          config[:url] = base_url
        else
          config[:url]
        end
      end

      # Combined getter/setter for the HTTP method used
      #
      # Falls back to the Api setting if blank.
      #
      # @param [String] value
      def http_method(value = nil)
        if value
          config[:http_method] = value
        else
          config[:http_method]
        end
      end

      # Registers a handler for requests and/or responses
      #
      # @param [Class] klass

      def use(klass, *args, &block)
        request_handler  = "#{klass.name}::RequestHandler".safe_constantize
        response_handler = "#{klass.name}::ResponseHandler".safe_constantize

        request_handlers  << request_handler.new(*args, &block) if request_handler
        response_handlers << response_handler.new(*args, &block) if response_handler
      end

      # Registers the individual API endpoint definitions
      def register_actions
        namespace = "#{self.name.deconstantize}::Actions".safe_constantize

        namespace.constants.each do |action|
          namespace.const_get(action).register(self)
        end
      end

      def logger(logger = nil)
        if logger
          @logger = logger
        else
          @logger
        end
      end
    end

    # @param [Hash] *args
    def initialize(*args)
      @config = args.extract_options!.reverse_merge(self.class.config)
    end

    def logger
      self.class.logger
    end

      protected

    def execute_request(action_klass, *args)
      request = action_klass.new(self).build_request(*args)

      self.class.request_handlers.each do |handler|
        request = handler.run(request, @config)
        break if request.response_body.present?
      end

      unless request.response_body.present?
        raise "All request handlers failed to deliver a response"
      end

      self.class.response_handlers.each do |handler|
        request = handler.run(request, @config)
      end

      request.process_response

      request
    end

  end
end

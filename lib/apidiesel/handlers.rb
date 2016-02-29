module Apidiesel
  module Handlers
    def request_handlers
      @request_handlers ||= []
    end

    def response_handlers
      @response_handlers ||= []
    end

    def exception_handlers
      @exception_handlers ||= []
    end

    # Registers a handler for requests, responses and/or exceptions
    #
    # @param [Class] klass
    def use(klass, *args, &block)
      request_handler   = "#{klass.name}::RequestHandler".safe_constantize
      response_handler  = "#{klass.name}::ResponseHandler".safe_constantize
      exception_handler = "#{klass.name}::ExceptionHandler".safe_constantize

      request_handlers   << request_handler.new(*args, &block) if request_handler
      response_handlers  << response_handler.new(*args, &block) if response_handler
      exception_handlers << exception_handler.new(*args, &block) if exception_handler
    end
  end
end
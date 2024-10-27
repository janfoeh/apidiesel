# frozen_string_literal: true

module Apidiesel
  module Handlers
    # Registers a handler for requests, responses and/or exceptions
    #
    # @param klass  [Class]
    # @param args   [Array<Object>] passed through to the handler
    # @param kargs  [Array<Object>] passed through to the handler
    # @return [void]
    def use(klass, *args, on: :all, **kargs, &block)
      instance =
        klass.new(*args, **kargs, &block)

      config.request_handlers.append(instance) if instance.respond_to?(:handle_request) && (on == :all || on == :request)
      config.response_handlers.append(instance) if instance.respond_to?(:handle_response) && (on == :all || on == :response)
      config.exception_handlers.append(instance) if instance.respond_to?(:handle_exception) && (on == :all || on == :exception)
    end
  end
end

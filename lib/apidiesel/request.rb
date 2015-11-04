module Apidiesel

  # Wrapper for API requests
  class Request
    attr_accessor :action, :parameters, :response, :http_request_response, :completed

    # @param [Apidiesel::Action] action
    def initialize(action:, parameters:, completed: false)
      @action     = action
      @parameters = parameters
      @completed  = completed
    end

    def completed?
      @completed
    end

    def process_response
      return false unless response && response.success?

      response.process_data_through(action)
    end
  end
end

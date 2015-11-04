module Apidiesel

  # Wrapper for API responses.
  class Response
    attr_accessor :data, :result, :status_code
    attr_writer :success

    # @param data the raw response data
    # @param result data after processing by the action
    # @param [true, false] success
    # @param [Array, nil] errors
    # @param [Fixnum, nil] status_code
    def initialize(data: nil, result: nil, success: true, errors: nil, status_code: nil)
      @data          = data
      @result        = result
      @success       = success
      @errors        = errors
      @status_code   = status_code
    end

    def success?
      @success
    end

    def failed?
      !success?
    end

    def process_data_through(action)
      @result = action.process_response(@data)
    end
  end
end
